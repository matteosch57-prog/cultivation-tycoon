-- qisim replay: play the sim through a real save's sessions (their lengths and the time between
-- them, from journal.sess) with that save's passes and purchases, and compare where it ends.
-- lune run tools/qisim/replay.luau <save.json> [seeds]   (a save = the record's `data` table, as JSON)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Engine = require("./engine")
local World = require("./world")
local Player = require("./player")

local ROOT = process.cwd:gsub("/tools/qisim/?$", ""):gsub("/$", "")
local save = serde.decode("json", fs.readFile(process.args[1]))
save = save.data or save
local seeds = tonumber(process.args[2] or "9")
local prof = Player.PROFILES[process.args[3] or "hooked"]
local passes = {}
for k in (save.simPasses or {}) do
	passes[k] = true
end
-- sessions: "start|seconds|afk|built"
local sess = {}
for _, line in (save.journal and save.journal.sess) or {} do
	local st, len = string.match(line, "^(%d+)|(%d+)")
	table.insert(sess, { start = tonumber(st), len = tonumber(len) })
end
assert(#sess > 0, "the save has no journal.sess")
local welcomeAt = save.journal and save.journal.first and save.journal.first["iap_welcome"] or save.welcomeAt

local results = {}
for seed = 1, seeds do
	local E = Engine.load(ROOT, seed)
	local W = World.new(E, { passes = passes, inGroup = save.groupClaimed == true })
	if save.groupClaimed then
		W.d.groupClaimed = true
	end
	local P = Player.new(W, prof, { buyWelcome = welcomeAt })
	for _, ss in sess do
		E.clock.t = ss.start
		P.day = math.floor(ss.start / 86400)
		P:session(ss.len)
	end
	table.insert(results, { P = P, W = W })
end

local function med(get)
	local v = {}
	for _, r in results do
		table.insert(v, get(r))
	end
	table.sort(v)
	return v[math.ceil(#v / 2)], v[1], v[#v]
end
local function show(name, real, get)
	local m, lo, hi = med(get)
	print(string.format("  %-22s save %-12s sim %s (range %s to %s)", name, tostring(real), tostring(m), tostring(lo), tostring(hi)))
end
print(string.format("### replay of %d sessions (%s s), passes: %s, %d seeds, profile %s", #sess, table.concat((function()
	local t = {}
	for _, s in sess do
		table.insert(t, s.len)
	end
	return t
end)(), " + "), next(passes) and "x2/auto/vip" or "none", seeds, process.args[3] or "hooked"))
show("realm", save.realm, function(r) return r.W.d.realm end)
show("lives", save.lives, function(r) return r.W.d.lives end)
show("karma (unspent)", save.karma, function(r) return r.W.d.karma or 0 end)
show("recruited", save.recruited, function(r) return r.W.d.recruited end)
show("disciples kept", #(save.disciples or {}), function(r) return #r.W.d.disciples end)
show("qi at the end", math.floor(save.qi or 0), function(r) return math.floor(r.W.d.qi) end)
show("peak steady qi/s", math.floor(save.peakSteady or 0), function(r) return math.floor(r.W.d.peakSteady or r.W.M.rate(r.W.s, true)) end)
local first = (save.journal and save.journal.first) or {}
for _, c in { "hall", "array", "realm2", "rebirth1", "realm3", "realm4" } do
	show("first " .. c .. " (s)", first[c] or "-", function(r) return r.P.first[c] or 99999 end)
end
