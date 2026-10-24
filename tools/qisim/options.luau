-- qisim options (2026-10-24, core loop after minute 10): auto build and sect missions as overlays on the real sim.
-- lune run tools/qisim/options.luau <profile> <days> <seeds> <base|auto|missions|both> [missionGap s] [mission s of income]
local process = require("@lune/process")
local Engine = require("./engine")
local World = require("./world")
local Player = require("./player")
local ROOT = process.cwd:gsub("/tools/qisim/?$", ""):gsub("/$", "")
local a = process.args
local profName, days, seeds, mode = a[1] or "engaged", tonumber(a[2] or "7"), tonumber(a[3] or "3"), a[4] or "base"
local mGap, mSec = tonumber(a[5] or "180"), tonumber(a[6] or "45")
local auto = mode == "auto" or mode == "both"
local missions = mode == "missions" or mode == "both"
local function runOne(seed)
	local E = Engine.load(ROOT, seed)
	local W = World.new(E, { passes = {}, inGroup = false })
	local prof = table.clone(Player.PROFILES[profName])
	local P = Player.new(W, prof, {})
	local ever, flag = {}, false
	P.manual = { early = 0, mid = 0 }
	local walk0 = P.walk
	P.walk = function(self, to)
		if auto and to.kind == "build" and ever[to.id] then return 0 end
		return walk0(self, to)
	end
	local buy0 = W.buy
	W.buy = function(self, o)
		local wasAuto = auto and o.kind == "build" and ever[o.id]
		local ok = buy0(self, o)
		if ok and o.kind == "build" then
			if wasAuto then flag = true else
				local t = W.d.playSec or 0
				if t >= 600 and t < 3600 then P.manual.mid += 1 end
			end
			ever[o.id] = true
		end
		return ok
	end
	local act0 = P.act
	P.act = function(self)
		local s = act0(self)
		if flag then flag = false return 1 end
		return s
	end
	local nextM = mGap
	local tick0 = W.tick
	W.tick = function(self, dt)
		tick0(self, dt)
		if missions and (self.d.playSec or 0) >= nextM then
			nextM += mGap
			local g = math.floor(self.M.rate(self.s, true) * mSec)
			self.d.qi += g
			self.src.mission = (self.src.mission or 0) + g
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
local function fmt(t) if not t or t == math.huge then return "-" end return t < 5400 and string.format("%.0fm", t / 60) or string.format("%.1fh", t / 3600) end
local runs = {}
for s = 1, seeds do local P, W = runOne(s) table.insert(runs, { P = P, W = W }) end
local function med(c) local v = {} for _, r in runs do table.insert(v, r.P.first[c] or math.huge) end table.sort(v) return v[math.ceil(#v / 2)] end
local out = {}
for _, c in { "realm2", "rebirth1", "rebirth2", "rebirth3", "rebirth5", "rebirth10", "realm7", "realm9", "realm11", "realm13" } do table.insert(out, c .. " " .. fmt(med(c))) end
local R = runs[math.ceil(#runs / 2)]
local sum = 0 for _, v in R.W.src do sum += v end
local tot = 0 for _, v in R.P.playBy do tot += v end
print(string.format("%-8s %s | end realm %d life %d | manual pads min10-60 %d | mission qi %.0f%% | wait %.1f%%", mode, table.concat(out, ", "), R.W.d.realm, R.W.d.lives, R.P.manual.mid, 100 * (R.W.src.mission or 0) / sum, 100 * R.P.wait.any / tot))
