-- qisim world: one player's peak and session, the parts of Main that run inline (mirrored line by
-- line; engine.luau's MIRRORS stops a run when one of the copied lines changes in Main).
local World = {}
World.__index = World

-- E = Engine.load(...); opts = { passes = { x2, auto, vip }, inGroup = bool, id = number }
function World.new(E, opts)
	local self = setmetatable({}, World)
	self.E, self.C, self.M = E, E.Config, E.M
	local P = E.newPlayer(opts.id or 1)
	self.player = P
	local d = self.M.defaultData()
	d.everBuilt = {} -- Main onJoin: a new save has built nothing yet (Auto Build, D85)
	self.d = d
	self.s = { player = P, data = d, passes = opts.passes or {}, inGroup = opts.inGroup == true, plot = {} }
	E.sessions[P] = self.s
	self.src, self.sink = {}, {} -- the qi ledger by cause
	self.lastSeen = nil
	return self
end

function World:now()
	return self.E.clock.t
end

-- qi in and out by cause: runs fn and books the qi change
function World:book(cause, fn, ...)
	local before = self.d.qi
	local r = table.pack(fn(...))
	local delta = self.d.qi - before
	if delta > 0 then
		self.src[cause] = (self.src[cause] or 0) + delta
	elseif delta < 0 then
		self.sink[cause] = (self.sink[cause] or 0) - delta
	end
	return table.unpack(r, 1, r.n)
end

-- Main onJoin (the qi parts, in its order): welcomed, tips, offline qi, idle chest summons, the return
-- screen paying the chest's qi, sessions + 1. A fresh session forgets the per-session fields.
function World:join()
	local C, M, s, d = self.C, self.M, self.s, self.d
	s.chestShown, s.btCost, s.orbs, s.orbTimer, s.handsAt, s.btAskUntil = nil, nil, 0, 0, 0, nil
	if d.welcomed == nil then
		d.welcomed = (d.sessions or 0) > 0
	end
	if d.tips == nil then
		d.tips = d.welcomed and { orb = true, pill = true, chest = true } or {}
	end
	local hasChest = M.hasIdleChest(d)
	local now = math.floor(self:now())
	local lastSeen = self.lastSeen
	local away = math.clamp(now - (lastSeen or now), 0, C.OFFLINE_CAP + C.DAO_OFFLINE_SECONDS * M.dao(d, "meditation"))
	local offlineGain = 0
	if away > 60 then
		offlineGain = math.floor(M.rate(s, true) * away * C.OFFLINE_RATE)
		d.qi += offlineGain
		self.src.offline = (self.src.offline or 0) + offlineGain
	end
	local newSummons = if hasChest then math.floor(away / C.CHEST_SUMMON_EVERY) else 0
	newSummons = math.clamp(C.CHEST_SUMMON_MAX - (d.chestSummons or 0), 0, newSummons)
	d.chestSummons = (d.chestSummons or 0) + newSummons
	local showChest = hasChest and (offlineGain > 0 or d.chestSummons > 0 or (d.chestQi or 0) > 0)
	if showChest then
		s.chestShown = true
		if (d.chestQi or 0) > 0 then
			self.src.chest = (self.src.chest or 0) + d.chestQi
			d.qi += d.chestQi
			d.chestQi = 0
		end
	end
	d.sessions = (d.sessions or 0) + 1
	self.E.Missions.refresh(self.player, s) -- Main onJoin: Sect Missions top up
	-- the server this session joins: its tide and altar clocks start at a random point
	self.tideNext = self:now() + math.random(0, C.TIDE_INTERVAL)
	self.altarNext = self.tideNext + C.TIDE_INTERVAL / 2
	return offlineGain, away
end

function World:leave()
	self.d.last = math.floor(self:now())
	self.lastSeen = math.floor(self:now())
end

-- Main's 1 s loop body for one session (income, play time, the daily gift clock, the week, the pill
-- brew, the orb drop) plus the server's tide schedule
function World:tick(dt)
	local C, M, s, d = self.C, self.M, self.s, self.d
	if self:now() >= self.tideNext then
		self.tideNext += C.TIDE_INTERVAL
		M.startTide()
	end
	local gain = M.rate(s) * dt
	d.qi += gain
	self.src.income = (self.src.income or 0) + gain
	d.playSec = (d.playSec or 0) + dt
	local today = C.giftDay()
	if d.giftDay ~= today then
		d.giftDay, d.giftPlay, d.giftIdx = today, 0, 1
	end
	d.giftPlay = (d.giftPlay or 0) + dt
	local week = C.rankWeek()
	if d.week ~= week then
		d.week, d.weekSec = week, 0
	end
	d.weekSec = (d.weekSec or 0) + dt
	d.peakRate = math.max(d.peakRate or 0, gain / math.max(dt, 1e-3))
	d.peakSteady = math.max(d.peakSteady or 0, M.rate(s, true))
	if d.owned.furnace and not d.pillReady then
		d.pillTimer = (d.pillTimer or 0) + dt
		if d.pillTimer >= C.PILL_INTERVAL then
			d.pillReady = true
		end
	end
	if d.owned.array then
		s.orbTimer = (s.orbTimer or 0) + dt
		if s.orbTimer >= C.ORB_INTERVAL then
			s.orbTimer = 0
			-- spawnOrb: at most ORB_MAX waiting, on a free spot
			if s.orbs < C.ORB_MAX and s.orbs < #self.E.orbSpots then
				s.orbs += 1
			end
		end
	end
end

-- refreshPads' offers: { id, kind = "build" | "hire" | "breakthrough" | "chest", cost, x, z, pad }
function World:offers()
	local C, M, s, d = self.C, self.M, self.s, self.d
	local list = {}
	local all = true
	local ownedCount = 0
	for _ in d.owned do
		ownedCount += 1
	end
	local price = M.priceRate(s)
	for _, pad in C.PADS do
		local locked = pad.kind == "isle" and M.dao(d, "isles") < (pad.karma or 1)
		if not d.owned[pad.id] and C.padOpen(pad, d.realm) and not locked then
			if C.neededForBreakthrough(pad) then
				all = false
			end
			local ready = ownedCount >= (pad.unlock or 0)
			for _, r in pad.req do
				if not d.owned[r] then
					ready = false
				end
			end
			if ready then
				table.insert(list, { id = pad.id, kind = "build", x = pad.x, z = pad.z, pad = pad })
			end
		end
	end
	-- Main pricePads: the open pads keep their price until the next buy
	local ready = {}
	for _, o in list do
		table.insert(ready, o.id)
	end
	M.pricePads(s, ready)
	for _, o in list do
		o.cost = s.padPrice[o.id]
	end
	if all and M.rebirths(d) >= C.rebirthsFor(d.realm + 1) then
		-- the breakthrough pad's price is set when it appears (not repriced by publish)
		s.btCost = s.btCost or math.floor(price * C.BREAKTHROUGH_SECONDS)
		table.insert(list, { id = "breakthrough", kind = "breakthrough", cost = s.btCost, x = 0, z = 14 })
	else
		s.btCost = nil
	end
	if M.hasIdleChest(d) and ((d.chestQi or 0) > 0 or (d.chestSummons or 0) > 0) and not s.chestShown then
		table.insert(list, { id = "chest", kind = "chest", cost = 0, x = C.IDLE_CHEST_PAD.X, z = C.IDLE_CHEST_PAD.Z })
	end
	for id, spec in C.WORKERS do
		if d.owned[id] and ((d.workers or {})[id] or 0) < C.WORKER_MAX then
			local pad = C.padById(id)
			local n = ((d.workers or {})[id] or 0) + 1
			local key = "hire_" .. id
			s.padPrice[key] = s.padPrice[key] or C.workerCost(pad, n, d.realm, M.padRate(s)) -- Main refreshPads
			table.insert(list, { id = key, kind = "hire", cost = s.padPrice[key], x = spec.x, z = spec.z, of = id, n = n })
		end
	end
	return list
end

-- the HUD "Next" pick (Config.guidePick, the real function) over the open building pads
function World:guide(list)
	local parts = {}
	for _, o in list do
		if o.kind == "build" or o.kind == "breakthrough" then
			table.insert(parts, { o = o, GetAttribute = function(p, k)
				if k == "PadId" then
					return p.o.id
				elseif k == "Cost" then
					return p.o.cost
				end
				return nil
			end })
		end
	end
	if #parts == 0 then
		return nil
	end
	local p = self.C.guidePick(parts)
	return p and p.o
end

-- a pad paid for (buyPad + the pad's onBuy, qi parts): build, hire, breakthrough (its Confirm), chest
function World:buy(o)
	local C, M, s, d = self.C, self.M, self.s, self.d
	if o.kind == "chest" then
		s.chestShown = true
		d.tips = d.tips or {}
		d.tips.chest = true
		local gain = d.chestQi or 0
		d.chestQi = 0
		d.qi += gain
		self.src.chest = (self.src.chest or 0) + gain
		return true
	end
	if d.qi < o.cost then
		return false
	end
	d.qi -= o.cost
	if o.kind == "build" then
		self.sink.build = (self.sink.build or 0) + o.cost
		d.owned[o.id] = true
		d.everBuilt[o.id] = true
		s.padPrice = nil
		if o.id == "platform" then
			M.giveIdleChest(s) -- the idle chest, once the first recruits are done too (the Recruit handler gives it then)
		end
		if o.id == "hall" and (d.recruited or 0) == 0 and not (d.tips and d.tips.recruit) then
			d.freeRecruits = math.max(d.freeRecruits or 0, C.FREE_RECRUITS)
		end
		self.E.Missions.bump(self.player, "build", 1)
	elseif o.kind == "hire" then
		self.sink.hire = (self.sink.hire or 0) + o.cost
		d.workers = d.workers or {}
		d.workers[o.of] = o.n
		s.padPrice = nil
	elseif o.kind == "breakthrough" then
		self.sink.breakthrough = (self.sink.breakthrough or 0) + o.cost
		d.realm += 1
		d.best = math.max(d.best or 1, d.realm)
		d.climbed = (d.climbed or 0) + 1
		d.owned = C.keptAtBreakthrough(d.owned)
		d.workers = {}
		s.padPrice = nil
		self.sink.reset = (self.sink.reset or 0) + d.qi
		d.qi = 0
		d.pillReady = false
		d.pillTimer = 0
		d.realmRecruits = 0
		s.btCost = nil
		local startQi = math.floor(M.padRate(s) * C.BREAKTHROUGH_START_SECONDS) -- Main: the new realm's first pads at once
		d.qi = startQi
		self.src.breakthrough = (self.src.breakthrough or 0) + startQi
		self.E.Missions.bump(self.player, "breakthrough", 1)
	end
	return true
end

-- Main autoBuildTick (D85): an offer built or hired before builds itself once affordable, in the HUD
-- "Next" order (Config.guidePick), one per AUTO_BUILD_GAP s; never the breakthrough, the chest or a hire.
-- Returns the offer bought, or nil
function World:autoBuild()
	local C, s, d = self.C, self.s, self.d
	if d.autoOff or not C.autoBuildOpen(d) or self:now() < (s.autoAt or 0) then
		return nil
	end
	local can = {}
	for _, o in self:offers() do
		if o.kind == "build" and d.everBuilt[o.id] and d.qi >= o.cost then
			table.insert(can, { o = o, GetAttribute = function(p, k)
				if k == "PadId" then
					return p.o.id
				elseif k == "Cost" then
					return p.o.cost
				end
				return nil
			end })
		end
	end
	if #can == 0 then
		return nil
	end
	local o = C.guidePick(can).o
	s.autoAt = self:now() + C.AUTO_BUILD_GAP
	self:buy(o)
	return o
end

-- an orb picked up (checkOrbs)
function World:pickOrb()
	local s, d = self.s, self.d
	if s.orbs <= 0 then
		return 0
	end
	s.orbs -= 1
	local gain = math.floor(self.M.rate(s) * self.C.ORB_VALUE)
	d.qi += gain
	self.src.orb = (self.src.orb or 0) + gain
	d.tips = d.tips or {}
	d.tips.orb = true
	self.E.Missions.bump(self.player, "orb", 1)
	return gain
end

-- the Shop's free daily gift (Shop ClaimShopFree, Dots.freeReady)
function World:shopFreeReady()
	local d = self.d
	return (d.playSec or 0) >= self.C.DOT_SHOP_FIRST and d.shopFreeDay ~= math.floor(self:now()) // 86400
end
function World:shopFree()
	if not self:shopFreeReady() then
		return 0
	end
	local d = self.d
	local gain = math.floor(self.M.rate(self.s, true) * self.C.SHOP_FREE_SECONDS)
	d.shopFreeDay = math.floor(self:now()) // 86400
	d.qi += gain
	self.src.shopFree = (self.src.shopFree or 0) + gain
	return gain
end

-- the Heavenly Altar won alone (Altar reward: ALTAR_SOLO_SECONDS of the away rate) or contested
function World:altar(contested)
	local C = self.C
	local gain = math.floor(self.M.rate(self.s, true) * (contested and C.ALTAR_WIN_SECONDS or C.ALTAR_SOLO_SECONDS))
	self.d.qi += gain
	self.src.altar = (self.src.altar or 0) + gain
	self.E.Missions.bump(self.player, "altar", 1)
	return gain
end

-- a Robux product (Shop grantProduct, the real function)
function World:grant(key)
	local it = self.C.shopItem(key)
	return self:book("iap_" .. key, self.E.grantProduct, self.player, self.s, it)
end

-- the remote handlers (Main's own functions), booked in the ledger
function World:call(handler, cause, ...)
	return self:book(cause, self.E.handlers[handler], self.player, ...)
end

function World:reincarnate()
	local before, recruits0 = self.d.qi, self.d.realmRecruits or 0
	local realm0 = self.d.realm
	local res = self.M.reincarnate(self.player, self.s)
	if res then
		local price = self.C.rebirthPrice(self.d.lives - 2)
		-- the leftover recruits Main reincarnate bought before the reset (Config.leftoverRecruits)
		local spent = 0
		if res.recruits and res.recruits > 0 then
			spent = self.C.recruitBatchCost(realm0, recruits0, res.recruits)
			self.sink.recruit = (self.sink.recruit or 0) + spent
		end
		self.sink.rebirth = (self.sink.rebirth or 0) + price
		self.sink.reset = (self.sink.reset or 0) + (before - price - spent)
		self.s.btCost = nil
	end
	return res
end

return World
