-- Analytics (B01 step 7): the first-session funnel, session ends, recruits and the qi economy.
-- EVENTS is the catalogue: every custom event name, its fields and the question it answers.
-- Fields are built here from positional values, so a call site can never send a key Roblox ignores
-- (only CustomField01..03 are read) or an unbounded value (a UserId, free text). 100 names per
-- experience and a name is permanent once a published server sends it: prefer a new field value.
-- Roblox drops every event sent from Studio, so Studio prints them instead.
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Journal = require(script.Parent:WaitForChild("Journal"))

local Telemetry = {}

local STUDIO = RunService:IsStudio()
local KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

Telemetry.EVENTS = {
	FunnelTime = {
		fields = { "step (FUNNEL name)", "minutes played when it landed (minuteBucket)" },
		question = "How long does a new player take to reach each funnel step (does the guide arrow speed it up)?",
	},
	SessionEnd = {
		fields = { "buildings owned this realm (builtBucket)", "session minutes (minuteBucket)", "first | return" },
		question = "Where do players stop, and does a first session end earlier than a return visit?",
	},
	IdleChest = {
		fields = { "hours away (hourBucket)", "free summons waiting", "realm (realmBucket)" },
		question = "How long do players stay away, and do they come back to open the idle chest?",
	},
	Recruit = {
		fields = { "rarity name", "realm (realmBucket)", "kept | benched" }, -- value = rolls (an x10 / x50 sums its outcomes)
		question = "Do the live roll results match the shown odds (R8), and how much do players recruit?",
	},
	Feature = {
		fields = { "pill | orb | gift | hands | streak | autoOn | autoOff (the Auto Build switch, D85)", "realm (realmBucket)" },
		question = "Are the pill, the qi orbs, the playtime gifts, Heavenly Hands and the Daily Blessing used, or ignored?",
	},
	Mission = {
		fields = { "done | daily | rank | hide | show", "done/daily: group; rank: the rank reached (31+ past the Rainbow relics); hide/show: the tracker tab", "done/daily: stars; rank: minutes played (minuteBucket)" },
		question = "Which Sect Missions get finished, and how fast do players climb the ranks?",
	},
	ServerHealth = {
		fields = { "heartbeat fps (hbBucket)", "server memory (memBucket)", "players (playersBucket)" },
		question = "Are servers healthy: the worst 5 minutes of each server, does it slow down as it fills?",
	},
	DataStorePressure = {
		fields = { "budget | throttle", "budget: request type; throttle: exp | srv | key | queue | throttled | overlimit", "players (playersBucket)" },
		question = "Do saves run short of DataStore budget or get throttled, and at what server size?",
	},
	SaveIssue = {
		fields = { "locked | error | newer (a load that could not take the save: the player was asked to rejoin)" },
		question = "How often does a join fail to load a save, and why?",
	},
	DiscipleBought = {
		fields = { "item key (elder ... primordial)", "realm (realmBucket)", "minutes played over all sessions (minuteBucket)" },
		question = "When in the climb do players buy a disciple, and which tier (D28 realm gates)?",
	},
	AltarRound = {
		fields = { "claimed | faded", "players who stood on it (9 = 9+)", "winner's realm (realmBucket) or none" },
		question = "Do players fight for the Heavenly Altar, how many per round, and who wins it?",
	},
	KarmaShop = {
		fields = { "node key (Config.DAO)", "level bought (past an endless line's list: \"11+\")", "life (lifeBucket)" },
		question = "Which Karma Shop nodes do players buy first, and in which life?",
	},
	Reincarnate = {
		fields = { "life that ended (lifeBucket)", "realm reached (deepBucket)", "hours played in that life (hourBucket)" },
		question = "Do players reincarnate at the gate or push deeper, and how long is a life?",
	},
	Menu = {
		fields = { "disciples | reinc | karma | group | index | ranks | settings (the HUD menus and panels; the Shop has its own event)", "realm (realmBucket)" },
		question = "Which HUD menus do players open, and when in the climb (data audit 2026-10-22)?",
	},
	Shop = {
		fields = {
			"open | prompt | bought | closed",
			"open: hud | pad | pill; else the item key (Config SHOP_PASSES / SHOP_PRODUCTS)",
			"realm (realmBucket)",
		},
		question = "Where do players open the shop, which items get a prompt, and how many prompts end in a buy?",
	},
	Sword = {
		fields = {
			"ride (a mount from the HUD button) | snap (the server put a flyer back, once per 10 s per rider)",
			"ride: sword key (Config.SWORD_RIDE tiers); snap: speed | ceiling | bound | islet",
			"realm (realmBucket)",
		},
		question = "Do sword owners actually ride, which sword do they pick (D76), and how often does the flight check snap riders back (false positives on laggy phones)?",
	},
	Build = {
		fields = { "pad id (Config.PADS)", "realm (realmBucket)", "minutes played over all sessions (minuteBucket)" },
		question = "In what order and how fast do players build, and which buildings do they skip?",
	},
	LeaveState = {
		fields = {
			"minutes since the last purchase (minuteBucket)",
			"pads they could afford when leaving (0 | 1 | 2 | 3+)",
			"share of the session standing still 2+ min (afk0_10 | afk10_50 | afk50plus)",
		},
		question = "Do players leave stuck waiting for qi (a wall), with things to buy (lost), or after idling?",
	},
	Social = {
		fields = {
			"friends_here (at leave, a friend was here) | next_door (a peak beside a friend's) | invite (prompt opened) | group_claim (first group gift) | favorite_claim (favorite gift)",
			"friends_here: most friends here at once (1 | 2 | 3); invite: friends here now (0 to 3)",
			"friends_here: session minutes; group_claim, favorite_claim: minutes played over all sessions (minuteBucket)",
		},
		question = "Do sessions with a friend last longer than SessionEnd's (all sessions), do players invite, and does the group gift get claimed (D35)?",
	},
	ClientFps = {
		fields = { "zone (PerfScene.ZONES: disciples | hub | peak | bridge | sky)", "median fps of the window (fpsBucket)", "phone | tablet | pc | console" },
		question = "Where in the world do phones lose fps (owner's Pixel near the disciples, 2026-10-23), and on which devices?",
	},
	ClientLoad = {
		fields = {
			"zone (PerfScene.ZONES)",
			"live particles within 80 studs of the camera (loadBucket)",
			"h<highlights>|g<billboard + surface guis>|p<visible parts> (loadBucket each)",
		},
		question = "What does the scene hold where fps drops: particles, Highlights, in-world guis or parts?",
	},
}

-- The onboarding funnel: one-time per player, steps in order. A step counts once it is true now or
-- the player has broken through (a breakthrough resets the owned pads but every earlier step happened).
Telemetry.FUNNEL = {
	{
		name = "Joined",
		done = function()
			return true
		end,
	},
	{
		name = "First building",
		done = function(_, built)
			return built >= 1
		end,
	},
	{
		name = "Main Hall",
		done = function(d)
			return d.owned.mainhall1 == true
		end,
	},
	{
		name = "Five buildings",
		done = function(_, built)
			return built >= 5
		end,
	},
	{
		name = "Disciple Hall",
		done = function(d)
			return d.owned.hall == true
		end,
	},
	{
		name = "First recruit",
		done = function(d)
			return (d.recruited or 0) >= 1
		end,
	},
	{
		name = "First expansion",
		done = function(d)
			return d.owned.expand1 == true
		end,
	},
	{
		name = "Celestial Palace",
		done = function(d)
			return d.owned.mainhall5 == true
		end,
	},
	{
		name = "Breakthrough",
		done = function(d)
			return (d.best or 1) >= 2
		end,
	},
}

-- Buckets keep every field value inside a small fixed set (8,000 combinations per event at most).
local MINUTES = { 1, 2, 3, 5, 10, 20, 40, 80 }
function Telemetry.minuteBucket(sec)
	local m = sec / 60
	local lo = 0
	for _, hi in MINUTES do
		if m < hi then
			return lo .. "-" .. hi
		end
		lo = hi
	end
	return lo .. "+"
end

local BUILT = { 1, 3, 6, 11, 16, 21, 27 }
function Telemetry.builtBucket(n)
	local lo = 0
	for _, hi in BUILT do
		if n < hi then
			return hi - lo == 1 and tostring(lo) or (lo .. "-" .. (hi - 1))
		end
		lo = hi
	end
	return lo .. "+"
end

function Telemetry.lifeBucket(n)
	return n >= 6 and "6+" or (n >= 4 and "4-5" or tostring(n))
end

function Telemetry.deepBucket(realm)
	return realm >= 13 and "13+" or tostring(realm)
end

local HOURS = { 1, 3, 10, 30, 100 }
function Telemetry.hourBucket(sec)
	local h, lo = sec / 3600, 0
	for _, hi in HOURS do
		if h < hi then
			return lo .. "-" .. hi
		end
		lo = hi
	end
	return lo .. "+"
end

function Telemetry.realmBucket(realm)
	return realm >= 4 and "4+" or tostring(realm)
end

local function fields(...)
	local values = { ... }
	if #values == 0 then
		return nil
	end
	local t = {}
	for i, v in values do
		t[KEYS[i]] = tostring(v)
	end
	return t
end

-- One budget for every event type (Roblox: 120 + 20 x players requests per minute per server).
-- Over budget the event is counted, never silently lost: the count is printed once a minute.
local budget, budgetAt, dropped = 0, 0, 0
local function spend(player)
	if not player.Parent then
		return false
	end
	local now = os.clock()
	if now - budgetAt >= 60 then
		if dropped > 0 then
			warn("[Tycoon][analytics] events over budget")
			print("[Tycoon][analytics] dropped", dropped, "events in the last minute")
		end
		budget, budgetAt, dropped = 0, now, 0
	end
	if budget >= 100 + 15 * #game:GetService("Players"):GetPlayers() then
		dropped += 1
		return false
	end
	budget += 1
	return true
end

local function send(what, fn, ...)
	if STUDIO then
		local fieldText = ""
		for _, v in { ... } do
			if type(v) == "table" then
				local parts = {}
				for k, f in v do
					table.insert(parts, k:sub(-2) .. "=" .. f)
				end
				table.sort(parts)
				fieldText = " {" .. table.concat(parts, ", ") .. "}"
			end
		end
		print("[Tycoon][analytics] " .. what .. fieldText)
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[Tycoon][analytics] send failed")
		print("[Tycoon][analytics]", what, err)
	end
end

-- events the journal skips: server-wide, or already noted another way (Build = its "buy:" sink)
local NOT_JOURNAL = { ServerHealth = true, DataStorePressure = true, SessionEnd = true, LeaveState = true, Build = true, ClientFps = true, ClientLoad = true }

-- `value` = how many times it happened (the dashboard sums it): a batch sends one event, not N
function Telemetry.customValue(player, name, value, ...)
	assert(Telemetry.EVENTS[name], "uncatalogued event " .. tostring(name))
	if not NOT_JOURNAL[name] then
		local first, second = ...
		local code = (first ~= nil and first ~= "") and (name .. ":" .. tostring(first)) or name
		if name == "Shop" then
			code ..= ":" .. tostring(second) -- which item, or where it was opened
		end
		for _ = 1, value do
			Journal.note(player, code)
		end
	end
	if spend(player) then
		send(name, AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value, fields(...))
	end
end

function Telemetry.custom(player, name, ...)
	Telemetry.customValue(player, name, 1, ...)
end

-- Log every funnel step that has become true, in order, and time it. `d.funnel` = steps logged
-- (saved, so a returning player never re-logs); `d.playSec` = seconds played over every session.
function Telemetry.funnel(player, d)
	local built = 0
	for id in d.owned do
		if Config.padById(id) then
			built += 1
		end
	end
	local nextStep = (d.funnel or 0) + 1
	local step = Telemetry.FUNNEL[nextStep]
	while step and (step.done(d, built) or ((d.best or 1) >= 2)) do
		d.funnel = nextStep
		if spend(player) then
			send(
				"funnel " .. step.name,
				AnalyticsService.LogOnboardingFunnelStepEvent,
				AnalyticsService,
				player,
				nextStep,
				step.name
			)
		end
		Telemetry.custom(player, "FunnelTime", step.name, Telemetry.minuteBucket(d.playSec or 0))
		nextStep += 1
		step = Telemetry.FUNNEL[nextStep]
	end
end

-- Client fps (PerfReport.client): one window of one zone, checked and bucketed here so a client
-- can only ever send catalogued values. One event a window; the fps bucket gets an "s" suffix when
-- the slow 5% of frames ran under half the median (a stutter rather than a steady low).
local ZONES = { disciples = true, hub = true, peak = true, bridge = true, sky = true }
local DEVICES = { phone = true, tablet = true, pc = true, console = true }
function Telemetry.fpsBucket(fps)
	for _, hi in { 15, 20, 25, 30, 40, 50 } do
		if fps < hi then
			return "fps" .. hi
		end
	end
	return "fps50plus"
end
function Telemetry.loadBucket(n, edges)
	local lo = 0
	for _, hi in edges do
		if n < hi then
			return lo .. "-" .. (hi - 1)
		end
		lo = hi
	end
	return lo .. "+"
end
local function num(v, max)
	v = tonumber(v)
	return (v and v == v) and math.clamp(v, 0, max) or nil
end
function Telemetry.clientPerf(player, t)
	if type(t) ~= "table" or not ZONES[t.zone] or not DEVICES[t.device] then
		return
	end
	local p50, p5 = num(t.p50, 1000), num(t.p5, 1000)
	if not p50 or not p5 then
		return
	end
	local fps = Telemetry.fpsBucket(p50)
	if p5 < p50 * 0.5 then
		fps ..= "s" -- the slow 5% of frames ran under half the median: a stutter, not a steady low
	end
	if STUDIO then
		print(string.format("[Tycoon][perf] %s %s p50 %.0f p5 %.0f parts %s particles %s highlights %s guis %s", t.zone, t.device, p50, p5, tostring(t.parts), tostring(t.particles), tostring(t.highlights), tostring(t.guis)))
	end
	Telemetry.custom(player, "ClientFps", t.zone, fps, t.device)
	local particles, highlights, guis, parts = num(t.particles, 1e6), num(t.highlights, 1e4), num(t.guis, 1e4), num(t.parts, 1e6)
	if particles and highlights and guis and parts then
		Telemetry.custom(
			player,
			"ClientLoad",
			t.zone,
			Telemetry.loadBucket(particles, { 100, 300, 1000, 3000, 10000 }),
			"h" .. Telemetry.loadBucket(highlights, { 1, 6, 16, 32 })
				.. "|g" .. Telemetry.loadBucket(guis, { 21, 61, 151 })
				.. "|p" .. Telemetry.loadBucket(parts, { 2000, 6000, 15000 })
		)
	end
end

-- Qi flows. Sinks are sent per purchase; income is summed per player and sent with each autosave
-- (one event per source per minute instead of one per second).
function Telemetry.sink(player, d, amount, sku)
	Journal.note(player, "buy:" .. sku)
	Journal.bought(player)
	if amount > 0 and spend(player) then
		send(
			"sink " .. sku,
			AnalyticsService.LogEconomyEvent,
			AnalyticsService,
			player,
			Enum.AnalyticsEconomyFlowType.Sink,
			"Qi",
			math.floor(amount),
			math.floor(d.qi),
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			sku
		)
	end
end

function Telemetry.source(player, d, amount, sku, timed)
	if sku ~= "income" and sku ~= "orb" and amount >= 1 then -- the minute sums are not actions
		Journal.note(player, "get:" .. sku)
	end
	if amount >= 1 and spend(player) then
		local kind = timed and Enum.AnalyticsEconomyTransactionType.TimedReward
			or Enum.AnalyticsEconomyTransactionType.Gameplay
		send(
			"source " .. sku,
			AnalyticsService.LogEconomyEvent,
			AnalyticsService,
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Qi",
			math.floor(amount),
			math.floor(d.qi),
			kind.Name,
			sku
		)
	end
end

-- Qi bought with Robux (Qi packs): an IAP source, so the dashboard splits it from play
function Telemetry.iapSource(player, d, amount, sku)
	if amount >= 1 and spend(player) then
		send(
			"source " .. sku,
			AnalyticsService.LogEconomyEvent,
			AnalyticsService,
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Qi",
			math.floor(amount),
			math.floor(d.qi),
			Enum.AnalyticsEconomyTransactionType.IAP.Name,
			sku
		)
	end
end

-- Karma (earned at a rebirth, spent in the Karma Shop): its own currency on the economy dashboard,
-- so the rebirth loop's flow can be read next to Qi's. No journal line: Reincarnate and KarmaShop
-- already note the action.
function Telemetry.karma(player, d, source, amount, sku)
	if amount >= 1 and spend(player) then
		send(
			(source and "source karma " or "sink karma ") .. sku,
			AnalyticsService.LogEconomyEvent,
			AnalyticsService,
			player,
			source and Enum.AnalyticsEconomyFlowType.Source or Enum.AnalyticsEconomyFlowType.Sink,
			"Karma",
			math.floor(amount),
			math.floor(d.karma or 0),
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			sku
		)
	end
end

function Telemetry.realm(player, realm)
	if spend(player) then
		send(
			"realm " .. realm,
			AnalyticsService.LogProgressionEvent,
			AnalyticsService,
			player,
			"Realm",
			Enum.AnalyticsProgressionType.Complete,
			realm - 1,
			Config.realmName(realm - 1)
		)
	end
end

return Telemetry
