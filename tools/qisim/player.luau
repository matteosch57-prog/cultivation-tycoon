-- qisim player: how a player plays, second by second. Each choice copies what the game shows: the
-- HUD "Next" arrow (Config.guidePick), red dots for gifts / pill / chest / shop gift, the Rebirth
-- chip, the Karma Shop. Walking time comes from the real pad positions (Config.PADS x, z) at the real
-- walk speed (Config.MOVE.walk); Heavenly Hands builds without walking.
--
-- Profiles: sessions per day and minutes per session come from the 2025 Roblox benchmark (GameAnalytics,
-- thousands of Roblox titles, 2025): sessions/day median 2.0, P75 3.5, P90 6; average session median
-- 6.6 min, P75 14.5, P90 26.4, P95 37. "regular" is the old sims' 2 x 30 min for comparison.
local Player = {}

Player.PROFILES = {
	median = { perDay = 2, minutes = 7, react = 4.5, path = 1.35, orbEvery = 60, patience = 20, pillDelay = 30, giftDelay = 20, rebirthDelay = 30, recruitBias = 2 },
	engaged = { perDay = 3, minutes = 15, react = 3.5, path = 1.3, orbEvery = 40, patience = 15, pillDelay = 15, giftDelay = 10, rebirthDelay = 15, recruitBias = 2 },
	hooked = { perDay = 4, minutes = 26, react = 3, path = 1.25, orbEvery = 30, patience = 10, pillDelay = 8, giftDelay = 5, rebirthDelay = 8, recruitBias = 2 },
	regular = { perDay = 2, minutes = 30, react = 3.5, path = 1.3, orbEvery = 30, patience = 15, pillDelay = 10, giftDelay = 10, rebirthDelay = 10, recruitBias = 2 },
	-- live first session (2026-10-25 data): rebirth 2 players do it in one long sitting, no offline pay between
	onesit = { perDay = 1, minutes = 90, react = 3.5, path = 1.3, orbEvery = 40, patience = 15, pillDelay = 15, giftDelay = 10, rebirthDelay = 15, recruitBias = 2 },
	-- same sitting at the median player's pace (react 4.5 s, orbs every 60 s)
	onesitslow = { perDay = 1, minutes = 90, react = 4.5, path = 1.35, orbEvery = 60, patience = 20, pillDelay = 30, giftDelay = 20, rebirthDelay = 30, recruitBias = 2 },
}
-- karma: the cheapest next level of any line first (the red dots light whatever karma covers; ties in
-- Config.DAO order). 2026-10-26 Karma Upgrades (PS99 Upgrades)
local SPAWN = { x = 0, z = 64 } -- placeOnPeak: (0, ISLAND_RADIUS - 8)

local function dist(a, b)
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- W = World.new(...), prof = a PROFILES entry (+ overrides). Returns a stepper.
function Player.new(W, prof, opts)
	opts = opts or {}
	local self = {
		W = W, prof = prof, pos = { x = SPAWN.x, z = SPAWN.z }, busy = 0, lastOrb = -1e9,
		first = {}, -- [code] = playSec of the first time (journal codes: pad ids, realm<n>, rebirth<n>)
		events = {}, -- { t, day, code }
		wait = { any = 0, progress = 0, by = {} }, -- seconds idle with nothing (any) / no pad (progress) affordable
		gaps = { last = 0, longest = 0 }, -- seconds between two pad buys (builds, hires, breakthroughs)
		altar = opts.altar or 0, -- share of altar rounds the player goes to and wins alone
		buyWelcome = opts.buyWelcome, -- playSec at which the Welcome Pouch is bought (nil = never)
		day = 0,
		playBy = {}, -- ["r<realm>"] = seconds played in that realm
	}
	return setmetatable(self, { __index = Player })
end

function Player:note(code)
	local t = math.floor(self.W.d.playSec or 0)
	if self.first[code] == nil then
		self.first[code] = t
	end
	table.insert(self.events, { t = t, day = self.day, code = code })
end

function Player:walk(to)
	local C = self.W.C
	local secs = dist(self.pos, to) * self.prof.path / C.walkSpeed(self.W.M.dao(self.W.d, "steps")) -- Swift Steps
	self.pos = { x = to.x, z = to.z }
	return secs
end


-- qi/s an offer adds, measured with the game's rate(): own it for a moment and read the rate
function Player:gain(o)
	local W, M, d, s = self.W, self.W.M, self.W.d, self.W.s
	local before = M.rate(s)
	if o.kind == "build" then
		d.owned[o.id] = true
		local after = M.rate(s)
		d.owned[o.id] = nil
		return after - before
	elseif o.kind == "hire" then
		d.workers = d.workers or {}
		local was = d.workers[o.of]
		d.workers[o.of] = o.n
		local after = M.rate(s)
		d.workers[o.of] = was
		return after - before
	end
	return 0 -- a breakthrough or the chest: bought for what it opens, not for qi/s
end

-- expected qi/s from n recruits: each roll's rarity bonus over the weakest working seat (Config.RARITIES
-- weights, the shown odds), as discipleMult counts it
function Player:recruitGain(n)
	local W, C, M, d, s = self.W, self.W.C, self.W.M, self.W.d, self.W.s
	local max = M.maxDisciples(s)
	local bonuses = {}
	for _, name in d.disciples do
		table.insert(bonuses, C.discBonus(name, false))
	end
	table.sort(bonuses, function(a, b)
		return a > b
	end)
	local total = 0
	for _, r in C.RARITIES do
		total += r.weight
	end
	local gainMult = 0
	for _ = 1, n do
		local weakest = #bonuses >= max and bonuses[max] or 0
		local e = 0
		for _, r in C.RARITIES do
			e += r.weight / total * math.max(0, r.bonus - weakest)
		end
		gainMult += e
		-- the expected newcomer takes a seat when there is room (a simple running estimate)
		if #bonuses < max then
			table.insert(bonuses, e)
			table.sort(bonuses, function(a, b)
				return a > b
			end)
		end
	end
	local rate = M.rate(s)
	return rate * gainMult / M.discipleMult(s)
end

-- one decision when not busy; returns seconds it keeps the player busy (0 = nothing to do)
function Player:act()
	local W, C, M, d, s, prof = self.W, self.W.C, self.W.M, self.W.d, self.W.s, self.prof
	local hands = M.dao(d, "hands") > 0
	-- HUD claims (no walking)
	if d.welcomed == false then
		W:call("welcomeFn", "welcome")
		return prof.react
	end
	if self.buyWelcome and (d.playSec or 0) >= self.buyWelcome and not (d.shopBought and d.shopBought.welcome) then
		W:grant("welcome")
		d.shopBought = d.shopBought or {}
		d.shopBought.welcome = 1
		self:note("iap_welcome")
		return prof.react * 2
	end
	-- a brand-new save's first Blessing waits for the first breakthrough (Config.STREAK_NEW_*, the
	-- client's firstCardDue; no STREAK_NEW_REALM = the old card at join)
	local newWait = C.STREAK_NEW_REALM and (d.sessions or 1) <= 1 and (d.best or d.realm or 1) < C.STREAK_NEW_REALM and (d.playSec or 0) < (C.STREAK_NEW_LATEST or 0)
	if not self.streakDone and not newWait then
		self.streakDone = true
		local r = W:call("streakFn", "streak")
		if r then
			self:note("streak")
			return prof.react
		end
	end
	if W:shopFreeReady() then
		W:shopFree()
		self:note("shopFree")
		return prof.react * 2 -- opens the shop, taps the gift
	end
	local gi = d.giftIdx or 1
	if C.GIFT_TIMES[gi] and (d.giftPlay or 0) >= C.GIFT_TIMES[gi] + prof.giftDelay then
		if W:call("giftFn", "gift") then
			self:note("gift" .. gi)
			return prof.react
		end
	end
	if (d.chestSummons or 0) > 0 and (s.chestShown or not W.M.hasIdleChest(d)) then -- gift summons open at once (giveSummons)
		W:call("chestFn", "chest", d.chestSummons)
		return prof.react * 2
	end
	if (d.freeRecruits or 0) > 0 then -- the recruit tutorial's free recruit (Tips.client; the platform's needs no hall)
		W:call("recruitFn", "recruit", 1)
		self:note("freeRecruit")
		return prof.react * 2
	end
	if d.pillReady and d.owned.furnace then
		self.pillSeen = self.pillSeen or (d.playSec or 0)
		if (d.playSec or 0) - self.pillSeen >= prof.pillDelay then
			self.pillSeen = nil
			W:call("pillFn", "pill")
			return prof.react
		end
	end
	local pick, pickCost
	for _, node in C.DAO do
		local cost = C.daoCost(node, M.dao(d, node.key))
		if cost and (d.karma or 0) >= cost and (not pickCost or cost < pickCost) then
			pick, pickCost = node.key, cost
		end
	end
	if pick then
		local lv = M.dao(d, pick)
		W:call("daoFn", "karma", pick)
		self:note("dao_" .. pick .. (lv + 1))
		return prof.react * 2
	end
	if C.rebirthOpen(d.realm, M.rebirths(d), d.owned) then
		self:note("open" .. M.rebirths(d) + 1)
	end
	if C.rebirthOpen(d.realm, M.rebirths(d), d.owned) and d.qi >= C.rebirthPrice(M.rebirths(d)) then
		self.rebirthSeen = self.rebirthSeen or (d.playSec or 0)
		-- qi goes to 0 at a rebirth and disciples stay: spend what is over the price on recruits first
		-- (since 2026-10-25 the Rebirth button does that itself: Config.leftoverRecruits in Main reincarnate)
		if d.owned.hall and not C.leftoverRecruits then
			local spare = d.qi - C.rebirthPrice(M.rebirths(d))
			for i = #C.RECRUIT_COUNTS, 1, -1 do
				local n = C.RECRUIT_COUNTS[i]
				if C.recruitBatchCost(d.realm, d.realmRecruits or 0, n) <= spare then
					W:call("recruitFn", "recruit", n)
					return prof.react
				end
			end
		end
		if (d.playSec or 0) - self.rebirthSeen >= prof.rebirthDelay then
			self.rebirthSeen = nil
			if W:reincarnate() then
				self:note("rebirth" .. (d.lives - 1))
				self.pos = { x = SPAWN.x, z = SPAWN.z }
				return prof.react * 2
			end
		end
	end
	-- pads: the HUD's Next pick when affordable (players follow the arrow); otherwise the best
	-- payback among what they can afford: a pad, a hire or a recruit (qi spent / qi/s gained, read
	-- from the game's own rate())
	local list = W:offers()
	local target = W:guide(list)
	local pick = target and target.cost <= d.qi and target or nil
	-- orbs (the Auto Orbs pass picks them while on the peak)
	if not pick and s.orbs > 0 then
		if s.passes.auto then
			while s.orbs > 0 do
				W:pickOrb()
			end
		elseif (d.playSec or 0) - self.lastOrb >= prof.orbEvery then
			self.lastOrb = d.playSec or 0
			local secs = prof.react
			local spots = W.E.orbSpots
			for i = 1, s.orbs do
				secs += self:walk(spots[(i - 1) % #spots + 1])
				W:pickOrb()
			end
			return secs
		end
	end
	local recruitN, bestPay = nil, math.huge
	if not pick then
		for _, o in list do
			if o.cost <= d.qi then
				local pay = o.kind == "chest" and 0 or o.cost / math.max(self:gain(o), 1e-9)
				if pay < bestPay then
					pick, bestPay = o, pay
				end
			end
		end
		if d.owned.hall then
			for i = #C.RECRUIT_COUNTS, 1, -1 do
				local n = C.RECRUIT_COUNTS[i]
				local cost = C.recruitBatchCost(d.realm, d.realmRecruits or 0, n)
				if cost <= d.qi then
					local pay = cost / math.max(self:recruitGain(n), 1e-9)
					if pay < bestPay * prof.recruitBias then
						pick, recruitN, bestPay = nil, n, pay
					end
					break
				end
			end
		end
	end
	if recruitN then
		W:call("recruitFn", "recruit", recruitN)
		self.recruits = (self.recruits or 0) + recruitN
		return prof.react
	end
	if pick then
		local secs = prof.react
		if not (hands and pick.kind ~= "chest") then
			secs += self:walk(pick)
		end
		if W:buy(pick) then
			if pick.kind ~= "chest" then
				local gap = (d.playSec or 0) - self.gaps.last
				self.gaps.longest = math.max(self.gaps.longest, gap)
				self.gaps.last = (d.playSec or 0)
			end
			if pick.kind == "breakthrough" then
				self:note("realm" .. d.realm .. "_life" .. (d.lives or 1))
				self:note("realm" .. d.realm)
			elseif pick.kind == "build" then
				self:note(pick.id)
			end
		end
		return secs
	end
	return 0
end

-- play one session of `seconds`
function Player:session(seconds)
	local W = self.W
	W:join()
	self.streakDone = false
	self.pos = { x = SPAWN.x, z = SPAWN.z }
	self.busy = 0
	local altarNext = W.altarNext
	for _ = 1, seconds do
		W.E.clock.t += 1
		W:tick(1)
		local rk = "r" .. W.d.realm
		self.playBy[rk] = (self.playBy[rk] or 0) + 1
		-- the altar: a share of rounds the player walks to the hub and holds it alone (~60 s away)
		if W:now() >= altarNext then
			altarNext += W.C.ALTAR_INTERVAL
			if self.altar > 0 and math.random() < self.altar then
				W:altar(false)
				self.busy += 60
				self:note("altar")
			end
		end
		-- Auto Build (D85) runs on the server whatever the player is doing
		local auto = W:autoBuild()
		if auto then
			self.autoBuilds = (self.autoBuilds or 0) + 1
			local gap = (W.d.playSec or 0) - self.gaps.last
			self.gaps.longest = math.max(self.gaps.longest, gap)
			self.gaps.last = (W.d.playSec or 0)
			if auto.kind == "build" then
				self:note(auto.id)
			end
		end
		if self.busy > 0 then
			self.busy -= 1
		else
			local secs = self:act()
			-- what an idle second means: nothing to buy at all, or no pad to buy (only recruits)
			if secs <= 0 then
				local key = "r" .. W.d.realm
				self.wait.any += 1
				self.wait.by[key] = (self.wait.by[key] or 0) + 1
			end
			self.busy = math.max(0, secs - 1)
		end
	end
	W:leave()
end

return Player
