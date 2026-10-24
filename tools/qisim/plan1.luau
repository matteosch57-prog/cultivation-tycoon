-- qisim Plan 1 (owner pick 2026-10-24, thread "Rework pricing so pads take waiting"): the real qisim
-- with the pad rules of Plan 1 laid over it, to read the numbers before anything is built.
--   * a pad costs T(realm) seconds of the price income: the away rate (no pill, tide, friends) without
--     anything paid (2x Qi pass, Welcome Pouch, Robux disciples) and without the rebirth boost; free
--     disciples count (owner: "free disciples should be taken in account"). T is the wait of a player
--     at the fewest rebirths the realm needs, so every rebirth past that is +50% faster there.
--   * prices are set again after every buy (a recruit, orbs or a pill in between shorten the wait)
--   * the open pads spread +-SPREAD around T by catalogue cost (cheap ones come sooner)
--   * realm 1 builds the disciple core first; a breakthrough keeps the core (platform, Lotus Isles,
--     Disciple Hall, Quarters, bridges, Qi Array) and rebuilds the rest
-- lune run tools/qisim/plan1.luau <median|engaged|hooked|regular> <days> <seeds> [none|all] [k=v ...]
--   k: tmul (all T x), spread, discpow (1 = free disciples fully counted, 0.5 = square root), today=1,
--      offcap (s of offline kept), offrate (offline share), welcome=1 (buys the Welcome Pouch)
local process = require("@lune/process")
local Engine = require("./engine")
local World = require("./world")
local Player = require("./player")
local ROOT = process.cwd:gsub("/tools/qisim/?$", ""):gsub("/$", "")
local a = process.args
local profName, days, seeds = a[1] or "engaged", tonumber(a[2] or "14"), tonumber(a[3] or "3")
local passes = a[4] == "all" and { x2 = true, auto = true, vip = true } or {}
local K = { tmul = 1, spread = 0.3, discpow = 1, today = 0, welcome = 0, offcap = -1, offrate = -1 }
for i = 5, #a do
	local k, v = a[i]:match("^(%w+)=([%d%.]+)$")
	if k then K[k] = tonumber(v) end
end
-- owner 2026-10-24: realm 1 "5-10 s sometimes", realms 2-3 "start to wait 30 s sometimes", then up to
-- 5 min, realms 8-10 "20-30 min of wait per pad for a full f2p"
local T = { 5, 40, 55, 90, 150, 300, 1000, 5000, 6000, 7000 }
for i = 5, #a do -- T=7,40,... sets the whole table
	local list = a[i]:match("^T=([%d,]+)$")
	if list then
		T = {}
		for n in list:gmatch("%d+") do table.insert(T, tonumber(n)) end
	end
end
local function target(realm)
	return (T[math.min(realm, #T)]) * K.tmul
end
local CORE = { platform = true, hall = true, quarters1 = true, quarters2 = true, array = true, bridge_fields = true, bridge_dao = true, bridge_disciples = true, bridge_summit = true }
for i = 1, 8 do
	CORE["lotus" .. i] = true
end
-- realm 1: the disciple core first (catalogue cost floor, unlock rung)
local EARLY = { platform = { 40, 1 }, bridge_disciples = { 60, 2 }, hall = { 120, 3 }, bridge_dao = { 200, 4 }, array = { 350, 5 } }

local function runOne(seed)
	local E = Engine.load(ROOT, seed)
	local C = E.Config
	local plan = K.today ~= 1
	if K.offcap >= 0 then C.OFFLINE_CAP = K.offcap end
	if K.offrate >= 0 then C.OFFLINE_RATE = K.offrate end
	if plan then
		for _, pad in C.PADS do
			local e = EARLY[pad.id]
			if e then
				pad.cost, pad.unlock = e[1], e[2]
			end
		end
	end
	local W = World.new(E, { passes = passes, inGroup = false })
	local M, s, d = W.M, W.s, W.d
	local prof = Player.PROFILES[profName]
	local P = Player.new(W, prof, { buyWelcome = K.welcome == 1 and 300 or nil })
	-- the price income (see the header)
	local function priceBase()
		local r = M.rate(s, true)
		if s.passes.x2 then r /= C.PASS_QI_MULT end
		r /= 1 + (d.qiBonus or 0)
		r /= C.rebirthMult(M.rebirths(d))
		-- Robux disciples out: their bonus off the disciple multiplier
		local dm = M.discipleMult(s)
		local paid = 0
		for name, n in d.boughtDisciples or {} do
			paid += C.discBonus(name) * n
		end
		local free = math.max(1, dm - paid)
		return r / dm * free ^ K.discpow
	end
	local prices = {} -- [pad id] = price, cleared after every buy
	local offers0 = W.offers
	W.offers = function(self)
		local list = offers0(self)
		if not plan then return list end
		local builds = {}
		for _, o in list do
			if o.kind == "build" then table.insert(builds, o) end
		end
		table.sort(builds, function(x, y) return x.pad.cost < y.pad.cost end)
		local base = priceBase()
		local t = target(d.realm) * C.rebirthMult(C.rebirthsFor(d.realm))
		for i, o in builds do
			if not prices[o.id] then
				local f = #builds > 1 and (1 - K.spread) + 2 * K.spread * (i - 1) / (#builds - 1) or 1
				prices[o.id] = math.floor(math.max(o.pad.cost, t * f * base))
			end
			o.cost = prices[o.id]
		end
		return list
	end
	local buy0 = W.buy
	W.buy = function(self, o)
		if not plan then return buy0(self, o) end
		local keep
		if o.kind == "breakthrough" then
			keep = {}
			for id in d.owned do
				if CORE[id] then keep[id] = true end
			end
		end
		local ok = buy0(self, o)
		if ok and (o.kind == "build" or o.kind == "breakthrough" or o.kind == "hire") then
			table.clear(prices)
		end
		if ok and keep then
			for id in keep do d.owned[id] = true end
		end
		return ok
	end
	local re0 = W.reincarnate
	W.reincarnate = function(self)
		local ok = re0(self)
		if ok then table.clear(prices) end
		return ok
	end
	-- the probe (waits while playing: pads paid from the qi a session started with don't count): per realm, the first life that plays it ("first") and later lives ("replay")
	local rows, last, bank, firstLife = {}, 0, 0, {}
	local function row()
		firstLife[d.realm] = firstLife[d.realm] or d.lives
		local k = string.format("realm %2d %s", d.realm, firstLife[d.realm] == d.lives and "first " or "replay")
		rows[k] = rows[k] or { gaps = {}, n = 0, green = 0, play = 0, real = {} }
		return rows[k]
	end
	-- what a pad costs in minutes of play: its price over the qi earned per second in the last 10 min of
	-- play (income, orbs, pills, tide, gifts; not offline, chest, streak or the Welcome Pouch)
	local NOT_PLAY = { offline = true, chest = true, streak = true, welcome = true }
	local ring = {}
	local function earned()
		local t = 0
		for k2, v in W.src do
			if not NOT_PLAY[k2] and v > 0 then t += v end
		end
		return t
	end
	local function playRate()
		local n = #ring
		if n < 2 then return nil end
		local a1, b2 = ring[1], ring[n]
		if b2[1] - a1[1] < 60 then return nil end
		return (b2[2] - a1[2]) / (b2[1] - a1[1])
	end
	local b1 = W.buy
	W.buy = function(self, o)
		local r = row()
		local pr = o.kind == "build" and playRate()
		if pr and pr > 0 then table.insert(r.real, o.cost / pr) end
		local ok = b1(self, o)
		if ok and o.kind == "build" then
			local t = d.playSec or 0
			-- a pad paid from the qi the player came back with (offline, chest) is not a wait
			if bank <= 0 then table.insert(r.gaps, t - last) end
			bank -= o.cost
			last = t
		elseif ok and o.kind == "breakthrough" then
			last = d.playSec or 0
			table.clear(ring) -- a new realm earns at a new rate
		end
		return ok
	end
	local re1 = W.reincarnate
	W.reincarnate = function(self)
		local ok = re1(self)
		if ok then
			last = d.playSec or 0
			table.clear(ring)
		end
		return ok
	end
	local j0 = W.join
	W.join = function(self, ...)
		local r = j0(self, ...)
		last = d.playSec or 0
		bank = d.qi -- (the play-rate window carries over: playSec doesn't count the time away)
		return r
	end
	local t0 = W.tick
	W.tick = function(self, dt)
		t0(self, dt)
		local r = row()
		r.play += dt
		table.insert(ring, { d.playSec or 0, earned() })
		while #ring > 2 and ring[#ring][1] - ring[1][1] > 600 do table.remove(ring, 1) end
		if math.floor(d.playSec or 0) % 5 == 0 then
			local g = false
			for _, x in self:offers() do
				if x.kind == "build" and x.cost <= d.qi then g = true end
			end
			r.n += 1
			if g then r.green += 1 end
		end
	end
	local gap = math.floor(14 * 3600 / prof.perDay)
	for day = 1, days do
		P.day = day
		local ds = E.clock.t
		for i = 1, prof.perDay do
			E.clock.t = ds + (i - 1) * gap
			P:session(prof.minutes * 60)
		end
		E.clock.t = ds + 86400
	end
	return { P = P, W = W, rows = rows }
end

local function fmt(t)
	if not t or t == math.huge then return "-" end
	if t < 90 then return string.format("%.0fs", t) end
	return t < 5400 and string.format("%.0fm", t / 60) or string.format("%.1fh", t / 3600)
end
local runs = {}
for seed = 1, seeds do
	table.insert(runs, runOne(seed))
end
local function med(code)
	local v = {}
	for _, r in runs do table.insert(v, r.P.first[code] or math.huge) end
	table.sort(v)
	return v[math.ceil(#v / 2)]
end
local out = {}
for _, c in { "realm2", "rebirth1", "rebirth2", "rebirth3", "rebirth5", "rebirth10", "realm5", "realm7", "realm9", "realm11" } do
	table.insert(out, c .. " " .. fmt(med(c)))
end
local extra = {}
for i = 5, #a do table.insert(extra, a[i]) end
print(string.format("### %s %s, %d days, passes %s %s | %s", K.today == 1 and "TODAY" or "PLAN 1", profName, days, a[4] or "none", table.concat(extra, " "), table.concat(out, ", ")))
-- pooled over the seeds
local pool = {}
for _, r in runs do
	for k, v in r.rows do
		pool[k] = pool[k] or { gaps = {}, n = 0, green = 0, play = 0, real = {} }
		for _, g in v.gaps do table.insert(pool[k].gaps, g) end
		for _, g in v.real do table.insert(pool[k].real, g) end
		pool[k].n += v.n
		pool[k].green += v.green
		pool[k].play += v.play
	end
end
local keys = {}
for k in pool do table.insert(keys, k) end
table.sort(keys)
local function q(t, f)
	if #t == 0 then return nil end
	local c = table.clone(t)
	table.sort(c)
	return c[math.max(1, math.ceil(#c * f))]
end
print("                    play/seed  pads   wait typical  slow 10%   longest   green   | price in play time: pads typical slow 10%")
for _, k in keys do
	local r = pool[k]
	if #r.gaps > 0 or #r.real > 0 then
		print(string.format("  %s  %8s  %5d   %10s  %8s  %8s   %3.0f%%   | %5d %8s %8s", k, fmt(r.play / seeds), math.floor(#r.gaps / seeds), fmt(q(r.gaps, 0.5)), fmt(q(r.gaps, 0.9)), fmt(q(r.gaps, 1)), 100 * r.green / math.max(1, r.n), math.floor(#r.real / seeds), fmt(q(r.real, 0.5)), fmt(q(r.real, 0.9))))
	end
end
local R = runs[math.ceil(#runs / 2)]
local tot = 0
for _, v in R.P.playBy do tot += v end
local sum = 0
for _, v in R.W.src do sum += v end
local led = {}
for k2, v in R.W.src do table.insert(led, { k2, v }) end
table.sort(led, function(x, y) return x[2] > y[2] end)
local ls = {}
for _, e in led do table.insert(ls, string.format("%s %.0f%%", e[1], 100 * e[2] / sum)) end
print(string.format("  end (seed %d): realm %d, life %d, disciples %d; idle (nothing to buy at all) %.0f%%; qi from %s", math.ceil(#runs / 2), R.W.d.realm, R.W.d.lives, #R.W.d.disciples, 100 * R.P.wait.any / tot, table.concat(ls, ", ")))
