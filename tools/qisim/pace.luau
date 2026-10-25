-- qisim pace (2026-10-25, rebirth 1 and 2 pace tune): realm and rebirth times with Config knobs changed,
-- optionally with the auto build overlay (anything built before is bought without walking, as
-- options.luau "auto"). Prints the timeline of the median seed: when each realm starts, when each
-- rebirth opens (every required pad built) and when it is bought.
-- lune run tools/qisim/pace.luau <profile> <days> <seeds> <base|auto> [k=v ...]
--   k=v sets Config[k]: a number (REBIRTH_PRICE=60000) or a list (PAD_SECONDS=5,25,30,...).
--   RR=3:1,5:2,7:4,... replaces Config.REBIRTH_REALMS.
-- Live check (2026-10-25 data, 1,616 players): realm 2 3.9 min, rebirth 1 10.2, rebirth 2 62.
-- "onesitslow" (one long sitting at the median player's pace) lands on it: 3.0 / 9.8 / 61.
local process = require("@lune/process")
local Engine = require("./engine")
local World = require("./world")
local Player = require("./player")
local ROOT = process.cwd:gsub("/tools/qisim/?$", ""):gsub("/$", "")
local a = process.args
local profName, days, seeds, mode = a[1] or "onesitslow", tonumber(a[2] or "1"), tonumber(a[3] or "8"), a[4] or "base"
local auto = mode == "auto"
local sets = {}
for i = 5, #a do
	local k, v = a[i]:match("^([%w_]+)=(.+)$")
	if k == "RR" then
		local t = {}
		for r, n in v:gmatch("(%d+):(%d+)") do
			t[tonumber(r)] = tonumber(n)
		end
		sets.REBIRTH_REALMS = t
	elseif k and v:find(",") then
		local t = {}
		for n in v:gmatch("[%d%.]+") do
			table.insert(t, tonumber(n))
		end
		sets[k] = t
	elseif k then
		sets[k] = tonumber(v)
	end
end

local function runOne(seed)
	local E = Engine.load(ROOT, seed)
	for k, v in sets do
		assert(E.Config[k] ~= nil, "no Config." .. k)
		E.Config[k] = v
	end
	local W = World.new(E, { passes = {}, inGroup = false })
	local prof = Player.PROFILES[profName]
	local P = Player.new(W, prof, {})
	P.leftover = process.env.PACE_LEFTOVER ~= nil -- the rebirth screen's "recruit with leftover qi" (option)
	if process.env.PACE_EVENTS then
		local call0 = W.call
		W.call = function(self, fn, kind, n, ...)
			if fn == "recruitFn" then
				P:note("recruit x" .. tostring(n) .. " qi " .. math.floor(W.d.qi))
			end
			return call0(self, fn, kind, n, ...)
		end
	end
	if auto then
		local ever, flag = {}, false
		local walk0, buy0, act0 = P.walk, W.buy, P.act
		P.walk = function(self, to)
			if to.kind == "build" and ever[to.id] then
				return 0
			end
			return walk0(self, to)
		end
		W.buy = function(self, o)
			local wasAuto = o.kind == "build" and ever[o.id]
			local ok = buy0(self, o)
			if ok and o.kind == "build" then
				flag = flag or wasAuto
				ever[o.id] = true
			end
			return ok
		end
		P.act = function(self)
			local s = act0(self)
			if flag then
				flag = false
				return 1
			end
			return s
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
	return P, W
end

local function fmt(t)
	if not t or t == math.huge then
		return "-"
	end
	return t < 5400 and string.format("%.1fm", t / 60) or string.format("%.1fh", t / 3600)
end
local runs = {}
for s = 1, seeds do
	local P, W = runOne(s)
	table.insert(runs, { P = P, W = W })
end
local function med(c)
	local v = {}
	for _, r in runs do
		table.insert(v, r.P.first[c] or math.huge)
	end
	table.sort(v)
	return v[math.ceil(#v / 2)]
end
local out = {}
for _, c in { "realm2", "open1", "rebirth1", "realm3", "realm4", "open2", "rebirth2", "rebirth3", "rebirth5", "rebirth10", "realm7", "realm9" } do
	if med(c) ~= math.huge then
		table.insert(out, c .. " " .. fmt(med(c)))
	end
end
local R = runs[math.ceil(#runs / 2)]
local tot = 0
for _, v in R.P.playBy do
	tot += v
end
if process.env.PACE_EVENTS then -- PACE_EVENTS=from,to (minutes): every event of the median seed in that window
	local f, t = process.env.PACE_EVENTS:match("([%d%.]+),([%d%.]+)")
	for _, e in R.P.events do
		if e.t >= tonumber(f) * 60 and e.t <= tonumber(t) * 60 and not e.code:match("^open") then
			print(string.format("  %6.1fm %s", e.t / 60, e.code))
		end
	end
end
print(string.format("%s %s %s | %s | wait %.1f%%", profName, mode, #a >= 5 and table.concat(a, " ", 5) or "(today)", table.concat(out, ", "), 100 * R.P.wait.any / tot))
