-- qisim pad waits (Plan 1, owner pick 2026-10-24): how long each pad takes, per realm, first life
-- there or a replay. The prices are the game's own (Config.padPrice via Main pricePads).
--   * "wait" = time between two pad buys while playing (pads paid from the qi a session started with
--     don't count)
--   * "price in play time" = a pad's price over the qi earned per second in the last 10 min of play
--     (income, orbs, pills, tide, gifts; not offline, chest, streak or the Welcome Pouch)
-- lune run tools/qisim/waits.luau <median|engaged|hooked|regular> <days> <seeds> [none|all] [k=v ...]
--   k: T=5,40,... (Config.PAD_SECONDS), spread, offcap (s of offline kept), offrate (offline share),
--      welcome=1 (buys the Welcome Pouch), MH=2,3,... (Config.MAINHALL_SECONDS), WS=0.6,1.2
--      (Config.WORKER_SECONDS)
local process = require("@lune/process")
local Engine = require("./engine")
local World = require("./world")
local Player = require("./player")
local ROOT = process.cwd:gsub("/tools/qisim/?$", ""):gsub("/$", "")
local a = process.args
local profName, days, seeds = a[1] or "engaged", tonumber(a[2] or "14"), tonumber(a[3] or "3")
local passes = a[4] == "all" and { x2 = true, auto = true, vip = true } or {}
local K = { welcome = 0, offcap = -1, offrate = -1 }
for i = 5, #a do
	local k, v = a[i]:match("^(%w+)=([%d%.]+)$")
	if k then K[k] = tonumber(v) end
end
local lists = {}
for i = 5, #a do -- T=5,40,... sets Config.PAD_SECONDS; MH= and WS= the Main Hall and hire shares
	local k, list = a[i]:match("^(%u+)=([%d,%.]+)$")
	if k then
		lists[k] = {}
		for n in list:gmatch("[%d%.]+") do table.insert(lists[k], tonumber(n)) end
	end
end
local T = lists.T

local function runOne(seed)
	local E = Engine.load(ROOT, seed)
	local C = E.Config
	if T then C.PAD_SECONDS = T end
	if lists.MH then C.MAINHALL_SECONDS = lists.MH end
	if lists.WS then C.WORKER_SECONDS = lists.WS end
	if K.spread then C.PAD_SPREAD = K.spread end
	if K.offcap >= 0 then C.OFFLINE_CAP = K.offcap end
	if K.offrate >= 0 then C.OFFLINE_RATE = K.offrate end
	local W = World.new(E, { passes = passes, inGroup = false })
	local M, s, d = W.M, W.s, W.d
	local prof = Player.PROFILES[profName]
	local P = Player.new(W, prof, { buyWelcome = K.welcome == 1 and 300 or nil })
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
	local order = {} -- the builds and hires of each realm's first life, in buy order (the Main Hall probe)
	local b1 = W.buy
	W.buy = function(self, o)
		local r = row()
		if (o.kind == "build" or o.kind == "hire") and firstLife[d.realm] == d.lives and d.qi >= o.cost then
			order[d.realm] = order[d.realm] or {}
			table.insert(order[d.realm], { id = o.id, cost = o.cost })
		end
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
	return { P = P, W = W, rows = rows, order = order }
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
print(string.format("### %s %s, %d days, passes %s %s | %s", "PADS", profName, days, a[4] or "none", table.concat(extra, " "), table.concat(out, ", ")))
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
-- the Main Hall probe (seed of the median run): where each level falls in its realm's build order
-- ("3/24" = the 3rd of 24 builds), and the hires (how many, their share of the realm's build qi)
print("  Main Hall order and hires, first life of each realm (seed " .. math.ceil(#runs / 2) .. "):")
for realm = 1, 12 do
	local list = R.order[realm]
	if list then
		local builds, hires, hq, bq, mh = 0, 0, 0, 0, {}
		for _, e in list do
			if e.id:match("^hire_") then
				hires += 1
				hq += e.cost
			else
				builds += 1
				bq += e.cost
				local lv = e.id:match("^mainhall(%d)$")
				if lv then table.insert(mh, "L" .. lv .. " " .. builds) end
			end
		end
		print(string.format("    realm %2d: %d builds; Main Hall at %s; %d hires (%.0f%% of build qi)", realm, builds, table.concat(mh, ", "), hires, 100 * hq / math.max(1, bq)))
	end
end
