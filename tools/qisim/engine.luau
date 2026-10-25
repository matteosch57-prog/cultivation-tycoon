-- qisim engine: the game's own qi code, run outside Roblox (Lune, https://lune-org.github.io).
--
-- Every qi rule comes from the real source, not a copy:
--   * src/shared/Config.luau is loaded as it is (every price, rate and table).
--   * the economy functions of src/server/Main.server.luau (rate, priceRate, roll, addDisciple,
--     reincarnate, and the Recruit / Chest / Pill / Gift / Streak / Welcome / Karma handlers) are cut
--     out of Main's text by name and compiled here with stubs for the parts that draw or save.
-- What Main does inline (the 1 s income tick, the offline pay at join, the pad offers, a pad buy,
-- the breakthrough, hires, orbs) is mirrored below, each with the Main line it copies in MIRRORS: a
-- run stops with an error when one of those lines is no longer in Main, so the sim cannot drift
-- silently. The same check runs for Shop's daily gift and the altar and shrine payouts.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Engine = {}

-- Main lines the inline mirrors depend on (a changed line = re-check that mirror)
local MIRRORS = {
	main = {
		"local gain = rate(s) * dt", -- income tick
		"d.giftPlay = (d.giftPlay or 0) + dt",
		"d.peakSteady = math.max(d.peakSteady or 0, rate(s, true))",
		"if d.pillTimer >= Config.PILL_INTERVAL then",
		"if s.orbTimer >= Config.ORB_INTERVAL then",
		"offlineGain = math.floor(rate(s, true) * away * Config.OFFLINE_RATE)", -- join
		"local away = math.clamp(os.time() - (lastSeen or os.time()), 0, Config.OFFLINE_CAP + Config.DAO_OFFLINE_SECONDS * dao(data, \"meditation\"))",
		"local newSummons = if hasChest then math.floor(away / Config.CHEST_SUMMON_EVERY) else 0",
		"newSummons = math.clamp(Config.CHEST_SUMMON_MAX - (data.chestSummons or 0), 0, newSummons)",
		"local hasChest = hasIdleChest(data)",
		"local locked = pad.kind == \"isle\" and dao(s.data, \"isles\") < (pad.karma or 1)", -- offers
		"local ready = ownedCount >= (pad.unlock or 0)",
		"pricePads(s, ready)",
		"local cost = s.padPrice[pad.id]",
		"s.padPrice = nil -- every open pad is priced again from the new income",
		"s.data.owned = Config.keptAtBreakthrough(s.data.owned) -- the disciple core stays (PAD_KEEP)",
		"if all and not s.pads.breakthrough and rebirths(s.data) >= Config.rebirthsFor(s.data.realm + 1) then",
		"local cost = math.floor(priceRate(s) * Config.BREAKTHROUGH_SECONDS) -- D48",
		"local startQi = math.floor(padRate(s) * Config.BREAKTHROUGH_START_SECONDS) -- the new realm's first pads at once",
		"s.padPrice[key] = Config.workerCost(pad, n, s.data.realm, padRate(s))",
		"s.data.chestQi = (s.data.chestQi or 0) + Config.CHEST_STARTER_QI",
		"s.data.freeRecruits = math.max(s.data.freeRecruits or 0, Config.FREE_RECRUITS)",
		"local gain = math.floor(rate(s) * Config.ORB_VALUE)", -- orbs
		"if #s.orbs >= Config.ORB_MAX then",
		"s.data.everBuilt[pad.id] = true -- Auto Build rebuilds it from now on (D85)", -- Auto Build
		"local part = Config.guidePick(can)",
		"s.autoAt = now + Config.AUTO_BUILD_GAP",
		"d.everBuilt[pad.id] = true",
	},
	shop = { "local gain = math.floor(api.rate(s, true) * Config.SHOP_FREE_SECONDS)" },
	dots = { "return (d.playSec or 0) >= Config.DOT_SHOP_FIRST and d.shopFreeDay ~= os.time() // 86400" },
	altar = { "local gain = math.floor(ctx.rate(s, true) * seconds)", "contested and Config.ALTAR_WIN_SECONDS or Config.ALTAR_SOLO_SECONDS" },
	bless = { "local mine = math.floor(api_.rate(s, true) * Config.BLESS_SECONDS)" },
	-- Missions.init's ctx in Main, mirrored in Engine.load
	missionsCtx = {
		"giftLeft = Config.GIFT_TIMES[d.giftIdx or 1] ~= nil,",
		"furnace = d.owned.furnace == true,",
		"reborn = rebirths(d) >= 1,",
		"streakReady = (d.streak or {}).last ~= Config.giftDay(),",
		"canBreak = not Config.rebirthOpen(d.realm, rebirths(d), d.owned),",
	},
}

-- the Main functions run as they are, in Main's order
local FUNCTIONS = {
	"hasIdleChest", "deepCopy", "defaultData", "discLooks", "discShiny", "dao", "maxDisciples", "rebirths", "karmaGain",
	"discipleMult", "boosted", "startTide", "tideOn", "friendCount", "rate", "priceRate", "padRate", "pricePads", "giveIdleChest", "roll", "byBonus",
	"giveSummons", "indexAdd", "addDisciple", "clearsBusy", "recruitPress", "reincarnate",
}
local HANDLERS = { "chestFn", "recruitFn", "pillFn", "giftFn", "streakFn", "welcomeFn", "daoFn" }

local function cut(src, startPat, what)
	local a = string.find(src, startPat, 1, true)
	assert(a, "qisim: Main no longer has " .. what)
	-- a top-level block ends at the first `end` (or `end)`) at column 0 after its start
	local e1 = string.find(src, "\nend\n", a, true)
	local e2 = string.find(src, "\nend)\n", a, true)
	local e = e1
	local len = 4
	if e2 and (not e1 or e2 < e1) then
		e, len = e2, 5
	end
	assert(e, "qisim: no end for " .. what)
	return string.sub(src, a, e + len)
end

local function checkMirrors(texts)
	local missing = {}
	for file, lines in MIRRORS do
		for _, line in lines do
			if not string.find(texts[file], line, 1, true) then
				table.insert(missing, file .. ": " .. line)
			end
		end
	end
	if #missing > 0 then
		error("qisim: these source lines changed, re-check the sim's mirror of them:\n  " .. table.concat(missing, "\n  "))
	end
end

-- the sim clock: os.time, os.clock and workspace:GetServerTimeNow all read it
local function newClock(start)
	return { t = start }
end

local function noop() end
local stubMeta = { __index = function()
	return noop
end }
local function stub()
	return setmetatable({}, stubMeta)
end

-- a player stand-in: attributes are kept (the handlers read a few back)
local function newPlayer(id)
	local attrs = {}
	return {
		UserId = id,
		DisplayName = "Sim" .. id,
		Name = "Sim" .. id,
		Parent = true,
		AccountAge = 365,
		SetAttribute = function(_, k, v)
			attrs[k] = v
		end,
		GetAttribute = function(_, k)
			return attrs[k]
		end,
	}
end

function Engine.load(root, seed)
	local texts = {
		main = fs.readFile(root .. "/src/server/Main.server.luau"),
		shop = fs.readFile(root .. "/src/server/Shop.luau"),
		dots = fs.readFile(root .. "/src/server/Dots.luau"),
		altar = fs.readFile(root .. "/src/server/Altar.luau"),
		bless = fs.readFile(root .. "/src/server/Bless.luau"),
		missions = fs.readFile(root .. "/src/server/Missions.luau"),
	}
	texts.missionsCtx = texts.main -- the ctx lines live in Main
	checkMirrors(texts)
	local clock = newClock(1761200000) -- a fixed epoch: UTC days and weeks fall the same way each run
	math.randomseed(seed or 1)
	local simOs = setmetatable({
		time = function()
			return math.floor(clock.t)
		end,
		clock = function()
			return clock.t
		end,
	}, { __index = os })
	local attrsW = {}
	local workspaceStub = {
		GetServerTimeNow = function()
			return clock.t
		end,
		SetAttribute = function(_, k, v)
			attrsW[k] = v
		end,
		GetAttribute = function(_, k)
			return attrsW[k]
		end,
	}
	local RandomStub = {
		new = function()
			return {
				NextNumber = function(_, a, b)
					a, b = a or 0, b or 1
					return a + (b - a) * math.random()
				end,
				NextInteger = function(_, a, b)
					return math.random(a, b)
				end,
			}
		end,
	}
	local sessions = {}
	local errors = {}
	local env = setmetatable({
		Config = nil, -- set below
		sessions = sessions,
		workspace = workspaceStub,
		os = simOs,
		Random = RandomStub,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Enum = roblox.Enum,
		ColorSequence = roblox.ColorSequence,
		NumberSequence = roblox.NumberSequence,
		NumberRange = roblox.NumberRange,
		notify = stub(),
		publish = noop,
		Telemetry = stub(),
		Guard = { allow = function()
			return true
		end },
		Ranks = stub(),
		lightning = noop,
		rebuild = noop,
		refreshPads = noop,
		buildDisciples = noop,
		buildWorkers = noop,
		showIdleChest = noop,
		save = noop,
		friendsOf = {},
		task = { spawn = noop, delay = noop, wait = noop, defer = function(f, ...)
			f(...)
		end },
		Missions = nil, -- set below (the real Missions.luau)
		-- Main reports a caught error with warn + print ("... error:"): the sim keeps every one and
		-- the run fails on them, so a stub gap can never turn into silently skipped code
		warn = function(...)
			table.insert(errors, table.concat(table.pack(...), " "))
		end,
		print = function(...)
			local line = ""
			for i = 1, select("#", ...) do
				line ..= tostring((select(i, ...))) .. " "
			end
			if string.find(line, "error", 1, true) then
				table.insert(errors, line)
			end
		end,
	}, { __index = function(_, k)
		local v = _G[k]
		if v == nil then
			error("qisim: Main code reads a name the sim does not provide: " .. tostring(k), 2)
		end
		return v
	end })
	-- Config, as the game loads it
	local Config = luau.load(fs.readFile(root .. "/src/shared/Config.luau"), { debugName = "Config", environment = env })()
	env.Config = Config
	if require("@lune/process").env.QISIM_MISSIONS == "0" then
		Config.MISSIONS_ON = false -- QISIM_MISSIONS=0: the game without Sect Missions, to compare
	end
	for _, h in HANDLERS do
		env[h] = {}
	end
	-- the Main functions, in Main's order
	local parts = {}
	for _, name in FUNCTIONS do
		local text = cut(texts.main, "\nlocal function " .. name .. "(", name)
		table.insert(parts, { at = string.find(texts.main, text, 1, true), text = text })
	end
	for _, h in HANDLERS do
		local text = cut(texts.main, "\n" .. h .. ".OnServerInvoke = ", h)
		table.insert(parts, { at = string.find(texts.main, text, 1, true), text = text })
	end
	-- single top-level lines the functions above read
	for _, line in { "\nlocal rng = Random.new()\n", "\nlocal CHEST_BATCH = 50\n" } do
		local at = string.find(texts.main, line, 1, true)
		assert(at, "qisim: Main no longer has the line" .. line)
		table.insert(parts, { at = at, text = line })
	end
	table.sort(parts, function(a, b)
		return a.at < b.at
	end)
	local chunk = {}
	for _, p in parts do
		table.insert(chunk, p.text)
	end
	local exports = {}
	for _, name in FUNCTIONS do
		table.insert(exports, name .. " = " .. name)
	end
	table.insert(chunk, "\nreturn { " .. table.concat(exports, ", ") .. " }\n")
	-- Sect Missions, the real module (its header requires swapped for the sim's Config), loaded first: luau.load copies the environment
	local mText = fs.readFile(root .. "/src/server/Missions.luau")
	local body = string.find(mText, "\nlocal Missions = {}", 1, true)
	assert(body, "qisim: Missions.luau no longer has its module table")
	env.HttpService = { JSONEncode = function()
		return ""
	end }
	local Missions = luau.load(string.sub(mText, body), { debugName = "Missions", environment = env })()
	env.Missions = Missions
	local M = luau.load(table.concat(chunk, "\n"), { debugName = "Main(economy)", environment = env })()
	local missionQi, missionRanks = {}, {}
	Missions.init({
		sessions = sessions,
		rate = M.rate,
		publish = noop,
		notify = stub(),
		telemetry = setmetatable({
			source = function(_, _, gain, why)
				missionQi[why] = (missionQi[why] or 0) + gain
			end,
			custom = function(player, name, what, a)
				if name == "Mission" and what == "rank" then
					missionRanks[tonumber(a)] = sessions[player].data.playSec or 0
				end
			end,
		}, stubMeta),
		giveSummons = M.giveSummons,
		addDisciple = M.addDisciple,
		ctx = function(player, s)
			local d = s.data
			return {
				others = false, -- the sim plays alone
				giftLeft = Config.GIFT_TIMES[d.giftIdx or 1] ~= nil,
				furnace = d.owned.furnace == true,
				reborn = M.rebirths(d) >= 1,
				streakReady = (d.streak or {}).last ~= Config.giftDay(),
				canBreak = not Config.rebirthOpen(d.realm, M.rebirths(d), d.owned),
			}
		end,
	})
	-- Shop's product grant (Welcome Pouch, Qi packs, Starter Pack, bought disciples), as it is
	env.api = { rate = M.rate, addDisciple = M.addDisciple, notify = stub(), tideBell = noop }
	local grantText = cut(texts.shop, "\nlocal function realm(", "Shop realm") .. cut(texts.shop, "\nlocal function grantProduct(", "Shop grantProduct")
	local grantProduct = luau.load(grantText .. "\nreturn grantProduct\n", { debugName = "Shop(grant)", environment = env })()
	-- the orb spots (Main ORB_SPOTS), read from Main's text
	local orbStart = string.find(texts.main, "\nlocal ORB_SPOTS = {", 1, true)
	assert(orbStart, "qisim: Main no longer has ORB_SPOTS")
	local orbBlock = string.sub(texts.main, orbStart, string.find(texts.main, "\n}\n", orbStart, true))
	local orbSpots = {}
	for x, z in string.gmatch(orbBlock, "Vector2%.new%((%-?[%d%.]+), (%-?[%d%.]+)%)") do
		table.insert(orbSpots, { x = tonumber(x), z = tonumber(z) })
	end
	assert(#orbSpots > 0, "qisim: no orb spots read")
	local api = {
		grantProduct = grantProduct,
		orbSpots = orbSpots,
		Config = Config,
		M = M,
		env = env,
		clock = clock,
		sessions = sessions,
		errors = errors,
		handlers = {},
		newPlayer = newPlayer,
		Missions = Missions,
		missionQi = missionQi,
		missionRanks = missionRanks, -- rank -> play seconds when it was reached
	}
	for _, h in HANDLERS do
		api.handlers[h] = env[h].OnServerInvoke
	end
	return api
end

return Engine
