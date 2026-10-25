-- qisim run: lune run tools/qisim/run.luau [profile] [days] [seeds] [passes: none|all] [altar share]
-- prints realm and rebirth times, waiting, and the qi ledger, for the median of the seeds
local process = require("@lune/process")
local Engine = require("./engine")
local World = require("./world")
local Player = require("./player")

local ROOT = process.cwd:gsub("/tools/qisim/?$", ""):gsub("/$", "")
local args = process.args
local profName = args[1] or "median"
local days = tonumber(args[2] or "3")
local seeds = tonumber(args[3] or "3")
local passes = args[4] == "all" and { x2 = true, auto = true, vip = true } or {}
local altar = tonumber(args[5] or "0")

local function runOne(seed)
	local E = Engine.load(ROOT, seed)
	local W = World.new(E, { passes = passes, inGroup = false })
	local prof = Player.PROFILES[profName]
	local P = Player.new(W, prof, { altar = altar })
	local gap = math.floor(14 * 3600 / prof.perDay)
	for day = 1, days do
		P.day = day
		local dayStart = E.clock.t
		for i = 1, prof.perDay do
			E.clock.t = dayStart + (i - 1) * gap
			P:session(prof.minutes * 60)
		end
		E.clock.t = dayStart + 86400
	end
	return P, W
end

local function fmt(t)
	if not t then
		return "-"
	end
	return t < 5400 and string.format("%.1f min", t / 60) or string.format("%.1f h", t / 3600)
end

local runs = {}
for seed = 1, seeds do
	local P, W = runOne(seed)
	table.insert(runs, { P = P, W = W })
end
local function median(vals)
	table.sort(vals)
	return vals[math.ceil(#vals / 2)]
end
print(string.format("### %s (%d x %d min a day, %d days, passes %s, altar %.2f), median of %d seeds", profName, Player.PROFILES[profName].perDay, Player.PROFILES[profName].minutes, days, args[4] or "none", altar, seeds))
local codes = { "realm2", "rebirth1", "rebirth2", "rebirth3", "rebirth4", "rebirth5", "rebirth6", "rebirth7", "rebirth8", "rebirth9", "rebirth10", "rebirth12", "rebirth15", "rebirth20", "realm5", "realm7", "realm9", "realm11", "realm13", "realm15" }
for _, c in codes do
	local v = {}
	for _, r in runs do
		table.insert(v, r.P.first[c] or math.huge)
	end
	local m = median(v)
	if m ~= math.huge then
		print(string.format("  %-10s %s", c, fmt(m)))
	end
end
local R = runs[math.ceil(#runs / 2)]
local d = R.W.d
print(string.format("  end: realm %d, life %d, karma %d, disciples %d, recruited %d, play %s", d.realm, d.lives, d.karma or 0, #d.disciples, d.recruited, fmt(d.playSec)))
local tot = 0
for _, v in R.P.playBy do
	tot += v
end
local ms = d.missions
if ms then
	local mq = 0
	for _, v in R.W.E.missionQi do
		mq += v
	end
	local all = 0
	for _, v in R.W.src do
		all += v
	end
	print(string.format("  sect missions: rank %d (%s), %d stars, mission qi %.1f%% of sources (qi paid by rewards: %s)", ms.rank, (R.W.C.missionRank(ms.rank)), ms.total, 100 * mq / math.max(all, 1), (function()
		local t = {}
		for k, v in R.W.E.missionQi do
			table.insert(t, k .. " " .. math.floor(v))
		end
		return table.concat(t, ", ")
	end)()))
	local rk = {}
	for r = 2, ms.rank do
		local t = R.W.E.missionRanks[r]
		if t then
			table.insert(rk, string.format("r%d %s", r, fmt(t)))
		end
	end
	print("  rank reached at play time: " .. table.concat(rk, ", "))
end
print(string.format("  waiting (idle, nothing affordable): %.1f%% of play; longest gap between pad buys %d s", 100 * R.P.wait.any / tot, R.P.gaps.longest))
local line = {}
for r = 1, 30 do
	local k = "r" .. r
	if R.P.playBy[k] then
		table.insert(line, string.format("r%d %.0f%%", r, 100 * (R.P.wait.by[k] or 0) / R.P.playBy[k]))
	end
end
print("  waiting by realm: " .. table.concat(line, ", "))
local function ledger(t)
	local sum, out = 0, {}
	for _, v in t do
		sum += v
	end
	for k, v in t do
		table.insert(out, { k, v })
	end
	table.sort(out, function(a, b)
		return a[2] > b[2]
	end)
	local s = {}
	for _, e in out do
		table.insert(s, string.format("%s %.0f%%", e[1], 100 * e[2] / sum))
	end
	return table.concat(s, ", ")
end
-- QISIM_TIMELINE=1: realm and rebirth times of the median seed, and how long each step took
if process.env.QISIM_TIMELINE then
	local last, line = 0, {}
	for _, e in R.P.events do
		if e.code:match("^realm%d+_life") or e.code:match("^rebirth%d+$") or (e.code:match("^open%d+$") and R.P.first[e.code] == e.t and not line[e.code]) then
			line[e.code] = true
			table.insert(line, string.format("%s %s (+%.1f)", e.code, fmt(e.t), (e.t - last) / 60))
			last = e.t
		end
	end
	print("  timeline: " .. table.concat(line, ", "))
end
print("  qi sources: " .. ledger(R.W.src))
print("  qi sinks: " .. ledger(R.W.sink))
local errs = 0
for _, r in runs do
	for _, e in r.W.E.errors do
		errs += 1
		if errs <= 5 then
			print("  GAME CODE ERROR: " .. e)
		end
	end
end
if errs > 0 then
	error(string.format("qisim: %d errors inside the game's code (see above)", errs))
end
