-- Cultivation Tycoon: all tunable numbers live here (single source of truth).
local Config = {}

Config.PLOT_COUNT = 6
Config.PLOT_RADIUS = 280 -- distance from the hub to each peak centre (room for the sky islets, Config.ISLETS)
Config.ISLAND_RADIUS = 66 -- the home island (the heart islet); expansions add lobes to islets (ISLAND_LOBES)
Config.HUB_RADIUS = 36

Config.BASE_RATE = 1 -- qi/s with nothing built
Config.OFFLINE_CAP = 4 * 3600 -- seconds of offline qi kept
-- offline qi pays this share of the rate (owner 2026-10-22, "idle should pay half"): an hour played
-- is worth twice an hour away (research 2026-10-22_full_game_sim: offline was 81% of late qi)
Config.OFFLINE_RATE = 0.5
-- Idle chest (D39, owner pick A): the offline qi plus one free summon per CHEST_SUMMON_EVERY s away
-- (at most CHEST_SUMMON_MAX waiting), opened on the return screen. Free summons don't move the pace
-- (tools/sim_game.py CHEST_SUMMON_EVERY): they are the fun of coming back.
Config.CHEST_SUMMON_EVERY = 3600
Config.CHEST_SUMMON_MAX = 4
Config.IDLE_CHEST_AT = Vector3.new(26, 0, 52) -- on the peak (frame space): beside the x2 qi pad, away from the spawn (owner 2026-10-22)
-- A brand-new save finds the chest already full (owner: "give a full one at start, green pad in
-- front, with the full animation to get the loop into their heads"): CHEST_STARTER_QI waiting and
-- CHEST_STARTER_SUMMONS free summons, opened by stepping on the green pad at IDLE_CHEST_PAD.
Config.CHEST_STARTER_QI = 150
Config.CHEST_STARTER_SUMMONS = 3
Config.IDLE_CHEST_PAD = Vector3.new(24, 0, 45)
Config.AUTOSAVE = 60
Config.DATASTORE = "CultivationTycoon_v1"
Config.MOCK_DATASTORE = true -- Studio only: every Play is a new player, nothing saved (false = the _studio store)
Config.DATA_VERSION = 1 -- save record format; SaveStore.migrate lifts older records to it
Config.SAVE_LEASE = 150 -- s a session lock lives without a refresh (autosave refreshes it)
Config.SAVE_RETRIES = 3 -- DataStore attempts per load/save (backoff 1 s, 2 s)
Config.SAVE_LOCK_WAITS = 6 -- tries to take a lock held by another live session on join
Config.SAVE_LOCK_WAIT = 5 -- s between those tries
Config.SAVE_MIN_BUDGET = 2 -- an autosave waits for this much UpdateAsync budget (leave, close, receipts never wait)
Config.SAVE_STAGGER = 0.3 -- s between players in one autosave pass

-- Server health (ServerHealth.luau, ported from Gladiator RNG)
Config.HEALTH_SAMPLE = 30 -- s between [SRVHEALTH] / [DSMON] samples
Config.HEALTH_EVENT = 300 -- s between ServerHealth events (the window's worst sample)
Config.HEALTH_LOW_FPS = 40 -- server heartbeat fps under this = an alert
Config.HEALTH_ALERT_PING = 450 -- ms
Config.HEALTH_LOW_BUDGET = 5 -- a DataStore budget under this = an alert + DataStorePressure
Config.HEALTH_PRESSURE_COOLDOWN = 60 -- s between DataStorePressure events of one series (they accumulate)

-- Phone performance (B01 step 3): small Ball / Cylinder parts become clones of one low-poly mesh
-- (art/meshes, tools/lowpoly_meshes.py, uploaded by the owner). nil = off (plain parts).
Config.LOWPOLY_BALL = "rbxassetid://75794578549559"
Config.LOWPOLY_CYLINDER = "rbxassetid://90367641492097"
Config.LOWPOLY_MAX = 2 -- studs across: bigger balls and cylinders stay true parts
-- Pond boulders (owner 2026-10-22, pick B): tools/rock_meshes.py writes art/meshes/rock_1..4.obj,
-- the owner uploads them (R11). Empty = not uploaded yet: the rims use tilted block stones instead.
Config.ROCK_MESH = { "", "", "", "" }
-- Koi (owner 2026-10-22: "just find a model"): a free Creator Store fish, `length` studs nose to
-- tail, `turn` = the rotation that points its nose toward -Z (this mesh faces +Z). mesh "" = no koi.
Config.KOI = { mesh = "rbxassetid://5946959434", texture = "rbxassetid://5946959571", length = 3, turn = CFrame.Angles(0, math.pi, 0) }
-- Leaf-card tree canopies (src/server/Nature.luau, tools/nature_assets.py writes art/meshes/canopy_*.obj).
-- The owner uploads them (R11); empty = not uploaded yet, the old part trees stay. The leaf textures
-- live in src/server/NatureKit.model.json as SurfaceAppearances.
Config.NATURE_MESH = {
	sakura = "rbxassetid://99741618115048",
	ginkgo = "rbxassetid://89967761874874",
	round = "rbxassetid://112145916039641",
	pine = "rbxassetid://91206435364540",
}

-- Movement (Movement.client.luau, owner 2026-10-21: "walking a bit faster, redo moving and jumping,
-- fit our style"): a cultivator's light step. Roblox defaults are walk 16, jump height 7.2.
Config.MOVE = {
	walk = 28, -- studs/s (owner 2026-10-22: "way faster")
	jumpHeight = 8.5, -- studs
	floatFall = 0.45, -- share of gravity taken away while falling (a soft, floaty landing)
	airSteps = 1, -- cloud steps: jump again in the air, once per jump
	stepUp = 46, -- studs/s upward on a cloud step (~5.4 studs higher)
}

-- Realms: each breakthrough multiplies income and costs.
Config.REALMS = {
	"Qi Condensation",
	"Foundation Establishment",
	"Core Formation",
	"Nascent Soul",
	"Soul Transformation",
	"Void Refinement",
	"Body Integration",
	"Mahayana",
	"Tribulation Transcendence",
	"True Immortal",
}

-- Reincarnation (docs/research/2026-10-21_reincarnation_design.md): from REINC_REALM a player may
-- start a new life at realm 1. Past Lives: every realm above REINC_REALM - 1 reached in a FINISHED
-- life (`soulPeak`, monotonic) multiplies all qi by PAST_LIVES_MULT in later lives. Karma is paid
-- per reincarnation from how deep that life went. Every disciple follows into the next life (D44).
-- D37 (owner: "40m is long to hook, 5-10m is good"): the gate is realm 2, so the first new life
-- comes ~10 min in; x1.5 per realm deeper keeps each life a little longer than the last (10, 14,
-- 20 ... ~75 min by life 9, ~4 h by life 14 for 2 x 30 min a day; research 2026-10-21_economy_math).
Config.REINC_REALM = 2
-- D40 (owner: "resets: whatever research says, of similar games"): a reset must make the climb back
-- clearly faster (idle games: the multiplier; Roblox rebirth games: keep part of the progress; both
-- automate the rebuild). A new life lands at REINC_LAND_SHARE of the deepest realm, fully built, and
-- Past Lives pays x2.5 per realm deeper: lives stay 10 to 40 min for ~2 weeks, ~1 h by life 30, ~4 h
-- by life 40, with no hard wall (tools/sim_game.py LAND_HALF; research 2026-10-22_full_game_sim)
Config.PAST_LIVES_MULT = 2.5
Config.REINC_LAND_SHARE = 0.5
function Config.pastLivesMult(soulPeak)
	return Config.PAST_LIVES_MULT ^ math.max(0, (soulPeak or 0) - (Config.REINC_REALM - 1))
end
-- Karma: KARMA_GROWTH ^ (realms past the gate), 1 at the gate, ~25 eight realms deeper, so the whole
-- Karma Shop takes about two weeks of lives. Paid only for a NEW record depth (D37): with the gate at
-- realm 2 and Old Foundations a reset is minutes, so repeating it must pay nothing.
-- `built` = share of this realm's pads owned (0..1) so progress inside a realm counts too
-- Karma Shop (the Dao Tree): permanent nodes bought with karma, `costs[i]` = price of level i.
-- Comfort and choices, all capped; nothing copies a paid pass (2x qi, auto orbs, VIP).
Config.DAO = {
	{ key = "seat", name = "Disciple Seat", line = "+1 disciple slot", costs = { 25 } },
	{ key = "foundation", name = "Old Foundations", line = "Lives start fully built", costs = { 8 } },
	{ key = "elixir", name = "Elixir Mastery", line = "Pills last 30 s more", costs = { 5, 15 } },
	{ key = "meditation", name = "Deep Meditation", line = "+2 h offline Qi", costs = { 5, 15 } },
	{ key = "echo", name = "Soul Echo", line = "+10% Karma", costs = { 8, 16, 32, 64, 128 } },
	{ key = "hands", name = "Heavenly Hands", line = "Build without walking", costs = { 5 } },
}
Config.HANDS_COOLDOWN = 0.4 -- s between two Heavenly Hands builds (server side)
Config.DAO_PILL_SECONDS = 30 -- elixir, per level
Config.DAO_OFFLINE_SECONDS = 2 * 3600 -- meditation, per level
Config.DAO_ECHO = 0.1 -- echo, karma per level
function Config.daoNode(key)
	for _, n in Config.DAO do
		if n.key == key then
			return n
		end
	end
	return nil
end

Config.KARMA_GROWTH = 1.5
function Config.karmaFor(realm, built)
	return math.floor(Config.KARMA_GROWTH ^ (realm - Config.REINC_REALM + (built or 0)))
end
Config.REALM_INCOME_MULT = 3 -- income x3 per realm
-- Owner direction (D25): the first realms are fast laps, then it gets hard; realm 10 is the long goal
-- (reincarnation comes after it). Costs x5 per realm up to REALM_COST_LATE_FROM (realms 2 to 5 take
-- ~5 to 10 min each), then x10 per realm (realm 10 lands ~day 21 for 2 x 30 min a day;
-- tools/sim_economy.py, research 2026-10-21_economy_math)
Config.REALM_COST_MULT = 5
Config.REALM_COST_LATE = 10
Config.REALM_COST_LATE_FROM = 5
Config.BREAKTHROUGH_COST = 300000 -- the old fixed price (x costMult); read only by the older sims
-- D48: the breakthrough costs BREAKTHROUGH_SECONDS of the price income (Main priceRate: buildings x
-- realm x disciples x Past Lives x Harmony, no pill, tide or paid pass) the realm ends on, so the save-up after the
-- last building is the same short goal whatever the realm holds (research 2026-10-22_island_by_realm)
Config.BREAKTHROUGH_SECONDS = 90

-- Pads of one realm. Players CHOOSE: a pad opens once `unlock` buildings are owned (any of
-- them) and its `req` pads (hard dependencies) are owned, which keeps 3 to 5 pads open at once.
-- `feature` = what the building does besides qi/s (shown on its price card).
-- `x`,`z` = pad position in the peak's local frame (+Z faces the hub bridge).
-- The Main Hall (mainhall1..5) is ONE building upgraded in place; each level replaces the last.
-- expand1/expand2 add lobes of land (Config.ISLAND_LOBES) to the islets where their districts grow.
-- `district` groups buildings (layout A, owner 2026-10-21): fields (Spirit Fields), dao (Alchemy
-- and Training), disciples, heart (the avenue, plaza, Main Hall). DISTRICT_BONUS below. Each
-- district stands on its own islet (Sky Islets, Config.ISLETS; `islet` overrides, e.g. the summit).
Config.PADS = {
	{ id = "path", name = "Stone Path", cost = 10, income = 1, unlock = 0, req = {}, x = 0, z = 40, district = "heart" },
	{ id = "vein1", name = "Spirit Vein", cost = 25, income = 2, unlock = 0, req = {}, x = -156, z = -38, district = "fields" },
	{ id = "lanterns", name = "Lantern Row", cost = 60, income = 3, unlock = 0, req = {}, x = 10, z = 30, district = "heart" },
	{ id = "mainhall1", name = "Thatched Hut", cost = 90, income = 4, unlock = 1, req = {}, x = 0, z = -30, feature = "Main Hall", district = "heart" },
	{ id = "platform", name = "Meditation Platform", cost = 150, income = 4, unlock = 2, req = {}, x = 0, z = 0, feature = "Disciples meditate", district = "heart" },
	{ id = "garden", name = "Herb Garden", cost = 300, income = 8, unlock = 3, req = {}, x = -158, z = -66, district = "fields" },
	{ id = "vein2", name = "Twin Spirit Vein", cost = 600, income = 14, unlock = 4, req = {}, x = -84, z = -54, district = "fields" },
	{ id = "mainhall2", name = "Sect Hall", cost = 900, income = 20, unlock = 4, req = { "mainhall1" }, x = 0, z = -30, feature = "Hall level 2", district = "heart" },
	{ id = "furnace", name = "Alchemy Furnace", cost = 1200, income = 10, unlock = 6, req = {}, x = 104, z = -34, feature = "2x Qi pills", district = "dao" },
	{ id = "hall", name = "Disciple Hall", cost = 1500, income = 10, unlock = 6, req = {}, x = -100, z = -172, feature = "Recruit disciples", district = "disciples" },
	{ id = "gate", name = "Sect Gate", cost = 2200, income = 25, unlock = 8, req = {}, x = 0, z = 52, district = "heart" },
	{ id = "array", name = "Qi Gathering Array", cost = 3200, income = 30, unlock = 9, req = {}, x = 112, z = -98, feature = "Qi orbs", district = "dao" },
	{ id = "mainhall3", name = "Great Hall", cost = 4500, income = 45, unlock = 9, req = { "mainhall2" }, x = 0, z = -30, feature = "Hall level 3", district = "heart" },
	{ id = "quarters1", name = "Disciple Quarters", cost = 5000, income = 5, unlock = 10, req = { "hall", "expand1" }, x = -128, z = -176, feature = "+1 disciple slot", district = "disciples" },
	{ id = "expand1", name = "Expand the Peak", cost = 6000, income = 0, unlock = 11, req = {}, x = -14, z = 8, feature = "More land" },
	{ id = "bamboo", name = "Bamboo Grove", cost = 7500, income = 60, unlock = 12, req = { "expand1" }, x = -124, z = -60, district = "fields" },
	{ id = "training", name = "Training Ground", cost = 8500, income = 60, unlock = 12, req = { "expand1" }, x = 126, z = -64, district = "dao" },
	{ id = "mainhall4", name = "Sect Palace", cost = 11000, income = 100, unlock = 13, req = { "mainhall3" }, x = 0, z = -30, feature = "Hall level 4", district = "heart" },
	{ id = "bell", name = "Bell Tower", cost = 12000, income = 90, unlock = 14, req = { "expand2" }, x = 54, z = -112, district = "heart", islet = "summit" },
	{ id = "koi", name = "Koi Pond", cost = 13000, income = 90, unlock = 14, req = { "expand1" }, x = -98, z = -34, district = "fields" },
	{ id = "quarters2", name = "Grand Quarters", cost = 15000, income = 10, unlock = 15, req = { "quarters1", "expand1" }, x = -130, z = -206, feature = "+1 disciple slot", district = "disciples" },
	{ id = "expand2", name = "Expand the Peak II", cost = 18000, income = 0, unlock = 16, req = { "expand1" }, x = 14, z = 8, feature = "More land" },
	{ id = "pagoda1", name = "Pagoda", cost = 21000, income = 150, unlock = 17, req = { "expand2" }, x = 72, z = -146, district = "heart", islet = "summit" },
	{ id = "library", name = "Scripture Library", cost = 23000, income = 170, unlock = 18, req = { "expand2" }, x = 40, z = -140, district = "heart", islet = "summit" },
	{ id = "moongate", name = "Moon Gate Garden", cost = 24000, income = 170, unlock = 18, req = { "expand2" }, x = 44, z = -184, district = "dao", islet = "summit" },
	{ id = "pagoda2", name = "Pagoda Spire", cost = 26000, income = 200, unlock = 19, req = { "pagoda1" }, x = 72, z = -146, district = "heart", islet = "summit" },
	{ id = "mainhall5", name = "Celestial Palace", cost = 30000, income = 300, unlock = 20, req = { "mainhall4", "expand2" }, x = 0, z = -30, feature = "Hall level 5", district = "heart" },
	-- District resources (option C, owner 2026-10-21): more copies and new types. Economy sim
	-- 2026-10-21: incomes halved from the first pass (realm 10 on day 16 regular, day 33 casual; D25 kept).
	{ id = "vein3", name = "Third Spirit Vein", cost = 1800, income = 10, unlock = 7, req = { "vein2" }, x = -144, z = -84, district = "fields" },
	{ id = "firelotus1", name = "Fire Lotus Pond", cost = 2000, income = 12, unlock = 7, req = { "furnace" }, x = 148, z = -94, district = "dao" },
	{ id = "firelotus2", name = "Twin Fire Lotus", cost = 5500, income = 25, unlock = 10, req = { "firelotus1" }, x = 148, z = -34, district = "dao" },
	{ id = "garden2", name = "Second Lotus Garden", cost = 8000, income = 35, unlock = 12, req = { "garden", "expand1" }, x = -158, z = -102, district = "fields" },
	{ id = "tea1", name = "Spirit Tea Terrace", cost = 9500, income = 40, unlock = 13, req = { "expand1" }, x = -94, z = -78, district = "fields" },
	{ id = "spring1", name = "Meditation Spring", cost = 10000, income = 42, unlock = 13, req = { "expand1" }, x = -94, z = -200, district = "disciples" },
	{ id = "garden3", name = "Third Lotus Garden", cost = 12500, income = 50, unlock = 15, req = { "garden2" }, x = -130, z = -26, district = "fields" },
	{ id = "tea2", name = "High Tea Terrace", cost = 14000, income = 55, unlock = 15, req = { "tea1" }, x = -124, z = -94, district = "fields" },
	{ id = "spring2", name = "Twin Spring", cost = 16000, income = 62, unlock = 16, req = { "spring1" }, x = -94, z = -144, district = "disciples" },
	{ id = "jade1", name = "Jade Quarry", cost = 20000, income = 80, unlock = 18, req = { "expand2" }, x = 158.5, z = -122, district = "dao" },
	{ id = "thunder1", name = "Thunder Crystal", cost = 22000, income = 88, unlock = 19, req = { "expand2" }, x = 90, z = -66, district = "dao" },
	{ id = "jade2", name = "Deep Jade Quarry", cost = 25000, income = 95, unlock = 20, req = { "jade1" }, x = 162, z = -64, district = "dao" },
	{ id = "thunder2", name = "Storm Crystal", cost = 28000, income = 110, unlock = 21, req = { "thunder1" }, x = 170, z = -102, district = "dao" },
	{ id = "jade3", name = "Heart of Jade", cost = 29000, income = 115, unlock = 22, req = { "jade2" }, x = 137.5, z = -120, district = "dao" },
	-- Sky Islets (owner pick B 2026-10-22): nothing stands by default, roads and trees included.
	-- A bridge opens its islet (every pad there needs it, Config.isletOf); paths and groves raise
	-- Harmony (HARMONY_STEP each). Prices simmed (tools/sim_game.py, research 2026-10-22_islets_prices):
	-- each sits on the ladder at its unlock rung; the pace cost is the extra walks, not the qi.
	-- So paths and groves stand on the line you already walk: a path just past each bridge, and the
	-- Fields and Alchemy groves flank their bridges on the home island (`tree` = the grove's kind).
	-- DECOR_OPTIONAL: a breakthrough does not need them (Config.neededForBreakthrough).
	{ id = "bridge_fields", name = "Fields Bridge", cost = 15, income = 0, unlock = 1, req = {}, x = -52, z = -25, feature = "Opens the Spirit Fields", islet = "heart", kind = "bridge" },
	{ id = "bridge_dao", name = "Alchemy Bridge", cost = 800, income = 0, unlock = 5, req = {}, x = 52, z = -26, feature = "Opens Alchemy and Training", islet = "heart", kind = "bridge" },
	{ id = "bridge_disciples", name = "Disciple Bridge", cost = 1000, income = 0, unlock = 6, req = {}, x = -114, z = -105, feature = "Opens the Disciples' islet", islet = "fields", kind = "bridge" },
	{ id = "bridge_summit", name = "Summit Bridge", cost = 15000, income = 0, unlock = 16, req = { "expand2" }, x = 91, z = -97, feature = "Opens the Summit", islet = "dao", kind = "bridge" },
	{ id = "path_heart", name = "Plaza Ring", cost = 120, income = 0, unlock = 2, req = {}, x = -10, z = 16, islet = "heart", kind = "path" },
	{ id = "grove_heart", name = "Plum Grove", cost = 250, income = 0, unlock = 3, req = {}, x = -22, z = 40, islet = "heart", kind = "grove" },
	{ id = "path_fields", name = "Fields Path", cost = 400, income = 0, unlock = 4, req = {}, x = -81, z = -39, islet = "fields", kind = "path" },
	{ id = "grove_fields", name = "Sakura Grove", cost = 900, income = 0, unlock = 5, req = { "bridge_fields" }, x = -42, z = -2, islet = "heart", tree = "sakura", kind = "grove" },
	{ id = "path_dao", name = "Alchemy Path", cost = 2500, income = 0, unlock = 8, req = {}, x = 81, z = -41, islet = "dao", kind = "path" },
	{ id = "path_disciples", name = "Disciple Path", cost = 3000, income = 0, unlock = 9, req = {}, x = -108, z = -135, islet = "disciples", kind = "path" },
	{ id = "grove_dao", name = "Maple Grove", cost = 4000, income = 0, unlock = 10, req = { "bridge_dao" }, x = 42, z = -2, islet = "heart", tree = "maple", kind = "grove" },
	{ id = "grove_disciples", name = "Pine Grove", cost = 6000, income = 0, unlock = 12, req = {}, x = -117, z = -143, islet = "disciples", kind = "grove" },
	{ id = "path_summit", name = "Summit Stair", cost = 20000, income = 0, unlock = 17, req = {}, x = 72, z = -114, islet = "summit", kind = "path" },
	{ id = "grove_summit", name = "Summit Pines", cost = 24000, income = 0, unlock = 18, req = {}, x = 74, z = -126, islet = "summit", kind = "grove" },
}
-- Sky Islets (owner pick B 2026-10-22; research 2026-10-22_space_and_buildables; mock
-- docs/art/mocks/peak_layouts.html): the peak is a home island (the heart: plaza, Main Hall) and
-- district islets in the sky, each opened by its bridge pad (`bridge`, built from islet `from`).
-- x, z, r in studs (peak frame, +Z faces the hub). Bridges span 14 to 21 studs of sky. An islet
-- whose bridge is not built shows as dry ground (visible land to grow into, like TPT2's plots).
-- Islets and lobes stay 13+ studs clear of the neighbour peaks at PLOT_RADIUS 280 (checked by
-- the layout script in that research note).
Config.ISLETS = {
	heart = { x = 0, z = 0, r = 66 },
	fields = { x = -124, z = -60, r = 54, from = "heart", bridge = "bridge_fields" },
	dao = { x = 126, z = -64, r = 56, from = "heart", bridge = "bridge_dao" },
	disciples = { x = -100, z = -172, r = 44, from = "fields", bridge = "bridge_disciples" },
	summit = { x = 44, z = -140, r = 44, from = "dao", bridge = "bridge_summit" },
}
Config.ISLET_ORDER = { "heart", "fields", "dao", "disciples", "summit" }
-- Expansions add a lobe of land to an islet (owner 2026-10-21: "little by little"); `exp` = the
-- expansion level that adds it; x, z in the peak frame.
Config.ISLAND_LOBES = {
	{ islet = "fields", x = -154, z = -94, r = 28, exp = 1 }, -- second lotus garden
	{ islet = "disciples", x = -130, z = -206, r = 24, exp = 1 }, -- grand quarters
	{ islet = "dao", x = 154, z = -108, r = 32, exp = 2 }, -- jade quarries, thunder crystals
	{ islet = "summit", x = 44, z = -178, r = 26, exp = 2 }, -- moon gate
}
Config.PLAZA_RING = 21 -- the Plaza Ring path round the meditation platform (path_heart)
function Config.expansionLevel(owned)
	return (owned.expand1 and 1 or 0) + (owned.expand2 and 1 or 0)
end
function Config.islandRadius(owned)
	return Config.ISLAND_RADIUS
end
function Config.islandLobes(owned)
	local level, list = Config.expansionLevel(owned), {}
	for _, l in Config.ISLAND_LOBES do
		if l.exp <= level then
			table.insert(list, l)
		end
	end
	return list
end
-- the islet a pad stands on: its `islet`, else its district's (the heart for the rest)
function Config.isletOf(pad)
	if pad.islet then
		return pad.islet
	end
	if pad.district and Config.ISLETS[pad.district] then
		return pad.district
	end
	return "heart"
end
-- is the islet open (its bridge built)? The heart always is.
function Config.isletOpen(owned, name)
	local b = Config.ISLETS[name].bridge
	return b == nil or owned[b] == true
end
-- the islet whose land holds (x, z) (lobes included), or the nearest one, and how far outside
-- its edge (x, z) is (negative = on the land)
function Config.isletAt(x, z)
	local best, bestD = "heart", math.huge
	for name, i in Config.ISLETS do
		local d = math.sqrt((x - i.x) ^ 2 + (z - i.z) ^ 2) - i.r
		if d < bestD then
			best, bestD = name, d
		end
	end
	for _, l in Config.ISLAND_LOBES do
		local d = math.sqrt((x - l.x) ^ 2 + (z - l.z) ^ 2) - l.r
		if d < bestD then
			best, bestD = l.islet, d
		end
	end
	return best, bestD
end
-- the two ends of an islet's bridge (peak frame): on the rim of `from`, and on its own rim
function Config.bridgeEnds(name)
	local i = Config.ISLETS[name]
	local f = Config.ISLETS[i.from]
	local d = Vector3.new(i.x - f.x, 0, i.z - f.z).Unit
	return Vector3.new(f.x, 0, f.z) + d * f.r, Vector3.new(i.x, 0, i.z) - d * i.r
end
-- Harmony (research 2026-10-22: decor pays through a capped rating, like Retail Tycoon 2 and
-- Restaurant Tycoon 2): every owned path or grove adds HARMONY_STEP to all qi, up to HARMONY_MAX.
Config.HARMONY_STEP = 0.02
Config.HARMONY_MAX = 0.2
-- Paths and groves are a choice, not a chore (economy sim 2026-10-22_islets_prices: as required pads
-- they added 14 walk-and-buy steps a realm): a breakthrough and the "built" count skip them.
Config.DECOR_OPTIONAL = true
function Config.neededForBreakthrough(pad)
	return not (Config.DECOR_OPTIONAL and (pad.kind == "path" or pad.kind == "grove"))
end
function Config.harmonyMult(owned)
	local n = 0
	for _, pad in Config.PADS do
		if (pad.kind == "path" or pad.kind == "grove") and owned[pad.id] then
			n += 1
		end
	end
	return 1 + math.min(n * Config.HARMONY_STEP, Config.HARMONY_MAX)
end
for _, pad in Config.PADS do
	-- every pad on an islet needs that islet's bridge (the bridge itself needs the one before it)
	local b = Config.ISLETS[Config.isletOf(pad)].bridge
	if b and pad.id ~= b then
		table.insert(pad.req, b)
	end
	if (pad.kind == "path" or pad.kind == "grove") and not pad.feature then
		pad.feature = string.format("+%d%% Harmony", math.floor(Config.HARMONY_STEP * 100 + 0.5))
	end
end
-- District bonus (layout A): each OTHER owned qi building in the same district adds this share
-- to a building's income, so where you build matters. Economy sim 2026-10-21: realm 10 a day
-- sooner, the fast-then-hard steps kept; never above 0.10 (0.20 flattens D25's step).
Config.DISTRICT_BONUS = 0.05
Config.DISTRICT_NAMES = { fields = "Fields", dao = "Alchemy", disciples = "Disciple" }
function Config.districtMult(owned, pad)
	if not pad.district or pad.district == "heart" or pad.income <= 0 then -- the heart is the hub, not a resource district
		return 1
	end
	local n = 0
	for _, other in Config.PADS do
		if other ~= pad and other.district == pad.district and other.income > 0 and owned[other.id] then
			n += 1
		end
	end
	return 1 + Config.DISTRICT_BONUS * n
end
-- highest Main Hall level owned (0 = none)
function Config.mainHallLevel(owned)
	for lv = 5, 1, -1 do
		if owned["mainhall" .. lv] then
			return lv
		end
	end
	return 0
end

-- Sect workers (research 2026-10-21_workers, mock docs/art/mocks/workers.html): a hire pad
-- beside an owned building, up to WORKER_MAX workers each. The n-th costs WORKER_COST[n] x the
-- building's cost (x costMult); each adds WORKER_BONUS x the building's income. A breakthrough
-- or a new life sends them home with the buildings. Spots and looks: src/server/Workers.luau.
-- `x`, `z` = the hire pad on the peak.
Config.WORKER_MAX = 2 -- owner 2026-10-22: "every farming spot should have 2 farmers, not 3 on one only"
Config.WORKER_BONUS = 0.5 -- simmed (research 2026-10-21_economy_math): ~9% faster climb; above 1.0 eats the hard part
Config.WORKER_COST = { 0.5, 1 }
Config.WORKERS = {
	garden = { name = "Farmer", x = -143, z = -63.5 },
	garden2 = { name = "Farmer", x = -142.5, z = -96.5 },
	garden3 = { name = "Farmer", x = -127.5, z = -41 },
	tea1 = { name = "Farmer", x = -108, z = -71 },
	tea2 = { name = "Farmer", x = -124, z = -80 },
	vein1 = { name = "Miner", x = -145, z = -44 },
	vein2 = { name = "Miner", x = -95, z = -57.5 },
	vein3 = { name = "Miner", x = -137, z = -75.5 },
	furnace = { name = "Alchemist", x = 111.5, z = -44.5 },
	training = { name = "Fighter", x = 112, z = -74 },
}
function Config.workerCost(pad, n, realm)
	return math.floor(pad.cost * Config.WORKER_COST[n] * Config.costMult(realm))
end

-- Guide trail (src/client/Guide.client.luau): chevrons from the feet to the next pad
Config.GUIDE_BUILT = 5 -- always shown in realm 1 until this many buildings stand
Config.GUIDE_IDLE = 20 -- afterwards only after this many seconds standing still

-- Features
Config.PILL_INTERVAL = 180 -- seconds between pills from the Alchemy Furnace
Config.PILL_DURATION = 60 -- seconds of 2x qi
Config.ORB_INTERVAL = 20 -- seconds between qi orbs from the Qi Gathering Array
Config.ORB_MAX = 3 -- orbs waiting on a peak at most
Config.ORB_VALUE = 15 -- an orb is worth this many seconds of income
-- Spirit Tide (server-wide event, research 2026-10-21_tycoon_study): every peak earns x TIDE_MULT
Config.TIDE_FIRST = 240 -- s after the server starts
Config.TIDE_INTERVAL = 600 -- s from one tide's start to the next
Config.TIDE_DURATION = 90
Config.TIDE_MULT = 2
Config.TIDE_WARN = 30 -- s of heads-up before a tide
-- Friends here (D35, research 2026-10-21_playing_together): each Roblox friend on the server adds
-- FRIEND_STEP to live qi (not offline, gifts or packs), at most FRIEND_MAX friends
Config.FRIEND_STEP = 0.1
Config.FRIEND_MAX = 3
-- Group gift (D35): a member of the game's Roblox group who claimed it earns GROUP_BONUS more qi
-- everywhere. 0 = no group yet: the Group button is hidden (the owner pastes the group id, R5)
Config.GROUP_ID = 172156768 -- Cultivation Tycoon community (owner, 2026-10-22)
Config.GROUP_BONUS = 0.1
-- Heavenly Gift (D36): a brand-new save's intro screen pays this once (the first four buildings,
-- 10 + 25 + 60 + 90, with no wait; Economy check 2026-10-21: realms 2 to 5 move under a minute)
Config.WELCOME_QI = 200
-- Heavenly Altar (owner idea 2026-10-21, mock A docs/art/mocks/altar_A_phone.jpg): king of the hill
-- over the hub. It opens half a tide cycle after each tide (never with one); stand on it ALONE for
-- ALTAR_HOLD s to claim it (two or more on it pause the timer); Palm Strike pushes, a fall locks
-- you out until the round ends. Rewards are seconds of the player's own income (fair at any
-- realm, no stacking power): the winner ALTAR_WIN_SECONDS + a light aura until the next round (only
-- ALTAR_SOLO_SECONDS if nobody else came to fight), everyone else who stood on it
-- ALTAR_JOIN_SECONDS. That is ~+20% live income per round on average (research 2026-10-21_economy_math).
Config.ALTAR_FIRST = Config.TIDE_FIRST + Config.TIDE_INTERVAL / 2 -- s after the server starts
Config.ALTAR_INTERVAL = Config.TIDE_INTERVAL
Config.ALTAR_WARN = 30 -- s of heads-up (walking from a peak to the hub takes ~20 s)
Config.ALTAR_WINDOW = 60 -- s the altar stays open without a claim
Config.ALTAR_HOLD = 20
Config.ALTAR_WIN_SECONDS = 300
Config.ALTAR_JOIN_SECONDS = 60
Config.ALTAR_SOLO_SECONDS = 120
Config.ALTAR_HEIGHT = 15 -- studs above the hub plaza
Config.ALTAR_RADIUS = 9
Config.ALTAR_PUSH_COOLDOWN = 2
Config.ALTAR_PUSH_REACH = 9 -- studs in front of the striker
Config.ALTAR_PUSH_SPEED = 62 -- knockback, studs/s (sideways), plus a hop
Config.ALTAR_BRAZIERS = 8 -- rim braziers: they light one by one as the holder's timer runs
-- Playtime gifts, D49 (owner 2026-10-22: "always show the next reward, reset daily, up to 2 h
-- online"): gift i is claimable after GIFT_TIMES[i] seconds of play TODAY (UTC day, summed over
-- every session; the ladder restarts at 00:00 UTC). Each pays GIFT_VALUE[i] seconds of income (no
-- tide, no pill) and GIFT_SUMMONS[i] free summons (into the idle chest's summons). Simmed: no
-- change to the pace, gifts are ~9% of a regular player's qi (tools/sim_game.py GIFT_DAILY).
Config.GIFT_TIMES = { 300, 600, 1200, 1800, 2700, 3600, 5400, 7200 }
Config.GIFT_VALUE = { 120, 180, 240, 300, 420, 540, 720, 900 }
Config.GIFT_SUMMONS = { 0, 0, 1, 0, 1, 0, 2, 3 }
Config.GIFT_DAILY = true -- read by the sim
function Config.giftDay(t)
	return math.floor((t or os.time()) / 86400)
end
Config.SLOT_PADS = { "quarters1", "quarters2" } -- each owned one adds a disciple slot

-- `vip` = owns the VIP Sect pass (VIP_SLOTS more)
function Config.maxDisciples(owned, vip)
	local n = Config.MAX_DISCIPLES + (vip and Config.VIP_SLOTS or 0)
	for _, id in Config.SLOT_PADS do
		if owned[id] then
			n += 1
		end
	end
	return n
end

-- Shop (docs/design/MONETIZATION.md, D17; screen = mock B, D24). The owner creates every pass and
-- product and sets its price (R5): paste the ids here. id 0 = not created yet: the item shows
-- "Soon" and never prompts. Prices are never written here: the client reads each one from
-- MarketplaceService (regional pricing changes them per player).
-- `seconds` (Qi packs) = seconds of the buyer's income (no tide, no pill, like gifts).
Config.SHOP_PASSES = {
	{ key = "x2", id = 2045637564, name = "2x Qi", line = "Double income forever" },
	{ key = "auto", id = 2047412977, name = "Auto Orbs", line = "Orbs fly to you" },
	{ key = "vip", id = 2048210735, name = "VIP Sect", line = "+1 disciple, gold name" },
}
Config.SHOP_PRODUCTS = {
	-- the entry door (owner 2026-10-21, research 2026-10-22_cheap_buys): 5 Robux, once per player, an
	-- Elder plus `qiBonus` more qi forever (kept through every life); offered once by WELCOME
	{ key = "welcome", id = 3721094927, name = "Welcome Pouch", line = "Elder + 10% Qi forever", rarity = "Elder", qiBonus = 0.1, limit = 1 },
	{ key = "pill", id = 3721095019, name = "Instant Pill", line = "2x Qi for 60 s now" },
	{ key = "pack1", id = 3721095093, name = "Qi Pouch", line = "10 min of income", seconds = 600 },
	{ key = "pack2", id = 3721095259, name = "Qi Chest", line = "1 hour of income", seconds = 3600 },
	{ key = "pack3", id = 3721095401, name = "Qi Vault", line = "6 hours of income", seconds = 21600 },
	-- a disciple of a FIXED rarity (never random, R8); joins like a recruit (takes the weakest seat
	-- when full). Every tier from Elder up is sold (owner, D28), priced by the owner as a ladder.
	{ key = "elder", id = 3721095583, name = "Elder", line = "+150% Qi disciple", rarity = "Elder", limit = 8 },
	{ key = "immortal", id = 3721095692, name = "Immortal", line = "+400% Qi disciple", rarity = "Immortal", limit = 8 },
	-- `limit` = times one player may buy it: the chase tiers once each, Elder / Immortal one sect's
	-- worth (bought disciples are never trimmed, so this bounds the list and the save); `minRealm` = on sale only from
	-- that realm (bought from the start they would flatten the early climb: economy check, D28)
	{ key = "celestial", id = 3721095787, name = "Celestial", line = "+900% Qi disciple", rarity = "Celestial", limit = 1, minRealm = 3 },
	{ key = "dao", id = 3721095866, name = "Dao Ancestor", line = "+2,000% Qi disciple", rarity = "Dao Ancestor", limit = 1, minRealm = 5 },
	{ key = "emperor", id = 3721095940, name = "Heavenly Emperor", line = "+4,500% Qi disciple", rarity = "Heavenly Emperor", limit = 1, minRealm = 7 },
	{ key = "primordial", id = 3721095995, name = "Primordial", line = "+10,000% Qi disciple", rarity = "Primordial", limit = 1, minRealm = 9 },
}
Config.PASS_QI_MULT = 2 -- 2x Qi pass: every qi/s, offline and gifts included
-- The Welcome Pouch offer card: once, after a big building (one with a `feature`) from `after` s of
-- play, or after any building from `late` s (owner: "after a big building after 5-10 minutes")
Config.WELCOME = { after = 300, late = 600 }
Config.VIP_SLOTS = 1
Config.DISCIPLE_CAP = 8 -- disciples kept at most (the largest sect's seats: MAX_DISCIPLES + VIP + SLOT_PADS)
Config.RECEIPTS_KEPT = 50 -- PurchaseIds remembered per player (a retried receipt is granted once)
-- World shop (research 2026-10-21_shop_placement, mock docs/art/mocks/shop_layout_A.png, D33): each
-- item stands where it acts, on the owner's peak. `x` = across the peak; `z` = along it, or
-- `fromRim` = studs inside the entrance arch (follows the island's size); `needs` = the building that
-- must stand first (no pad offers what the player cannot use yet). Beside the path, never on it.
-- Spots checked in Studio Play on a full peak (2026-10-21): every pad 7+ studs from any building.
Config.SHOP_PEAK_PADS = {
	{ key = "x2", x = 15, fromRim = 8 }, -- right of the path, the first thing on the peak
	{ key = "vip", x = -15, fromRim = 8 }, -- left of it, under the arch whose name turns gold
	{ key = "pill", x = 90, z = -34, needs = "furnace" }, -- the furnace brews this pill; beside it (Sky Islets)
	{ key = "auto", x = 106, z = -84, needs = "array" }, -- the orbs come from the Gathering Array, beside it (Sky Islets)
}
-- (x, z) of a SHOP_PEAK_PADS entry on an island of `radius`
function Config.shopPeakSpot(e, radius)
	return e.x, e.fromRim and (radius - e.fromRim) or e.z
end
-- Disciple Garden: every peak's side island holds only the disciples for sale, along a walk from
-- its bridge, cheapest first and Primordial at the end (src/server/Shop.luau). At SHOP_ISLAND_AT in
-- the peak's frame (beside the entrance, clear of the largest peak and the neighbours).
-- (55, 122) and 28: the island's lobes stay outside the 100.5-stud terrain clear of the largest peak and
-- ~8 studs clear of the neighbour peak's largest island (Play check 2026-10-21)
Config.SHOP_ISLAND_AT = Vector3.new(55, 0, 122)
Config.SHOP_ISLAND_RADIUS = 28
Config.SHOP_DISCIPLE_PADS = { "elder", "immortal", "celestial", "dao", "emperor", "primordial" } -- along the walk, first to last

-- the Shop product that sells disciple rarity `name` (nil when it is not sold)
function Config.shopKeyOf(name)
	for _, it in Config.SHOP_PRODUCTS do
		if it.rarity == name then
			return it.key
		end
	end
	return nil
end

function Config.shopItem(key)
	for _, list in { Config.SHOP_PASSES, Config.SHOP_PRODUCTS } do
		for _, it in list do
			if it.key == key then
				return it, list == Config.SHOP_PASSES
			end
		end
	end
	return nil, false
end

-- Disciples: recruited at the Disciple Hall, each adds a % bonus to income.
Config.MAX_DISCIPLES = 5
Config.RECRUIT_BASE = 500
-- How many recruits one press buys (owner 2026-10-22: an x1 / x10 / x50 selector shows above the seal
-- on a press or a hover, even without the qi, and hides RECRUIT_PICK_SECONDS after; the pick sticks to
-- the seal). A press is all or nothing at recruitBatchCost.
Config.RECRUIT_COUNTS = { 1, 10, 50 }
Config.RECRUIT_PICK_SECONDS = 5
-- D44 (owner pick 2 of 3, research 2026-10-22_choice_and_recruits): each recruit in a realm costs
-- RECRUIT_POW x the last (restarts at a breakthrough): at 1.05 the 50th costs ~11x the first.
Config.RECRUIT_POW = 1.05 -- owner pick 2026-10-22 (was 1.25): x10 / x50 = the next 10 / 50 prices
Config.RECRUIT_GROWTH = 0.5 -- the old linear rule, read only by the older sims (sim_pacing, sim_economy)
-- D44: a pad of the realm costs at least PRICE_FLOOR_S seconds of income (rate without the pill,
-- tide and friends), so every building stays a small saving goal and you pick which comes first
-- (DevForum rule of thumb; tools/sim_game.py). Open pads are repriced as income grows.
Config.PRICE_FLOOR_S = 20
-- the first life stays fast (D25 "first realms fast", the 5-10 min hook): the floor starts here
Config.PRICE_FLOOR_FROM_LIFE = 2
Config.RARITIES = {
	{ name = "Outer Disciple", weight = 60, bonus = 0.10, color = Color3.fromRGB(200, 200, 200) },
	{ name = "Inner Disciple", weight = 28, bonus = 0.25, color = Color3.fromRGB(90, 200, 120) },
	{ name = "Core Disciple", weight = 9, bonus = 0.60, color = Color3.fromRGB(80, 150, 255) },
	{ name = "Elder", weight = 2.5, bonus = 1.50, color = Color3.fromRGB(190, 100, 255) },
	{ name = "Immortal", weight = 0.5, bonus = 4.00, color = Color3.fromRGB(255, 200, 60) },
	{ name = "Celestial", weight = 0.12, bonus = 9.00, color = Color3.fromRGB(110, 225, 235) },
	{ name = "Dao Ancestor", weight = 0.03, bonus = 20.00, color = Color3.fromRGB(230, 50, 60) },
	{ name = "Heavenly Emperor", weight = 0.008, bonus = 45.00, color = Color3.fromRGB(255, 140, 40) },
	{ name = "Primordial", weight = 0.002, bonus = 100.00, color = Color3.fromRGB(255, 110, 220) }, -- its aura cycles every colour
}

-- Building palettes cycle with the realm.
Config.PALETTES = {
	{ stone = Color3.fromRGB(150, 150, 145), wood = Color3.fromRGB(120, 80, 50), roof = Color3.fromRGB(90, 60, 45), trim = Color3.fromRGB(190, 170, 120), glow = Color3.fromRGB(120, 220, 255) },
	{ stone = Color3.fromRGB(200, 225, 210), wood = Color3.fromRGB(140, 40, 40), roof = Color3.fromRGB(40, 140, 100), trim = Color3.fromRGB(230, 230, 220), glow = Color3.fromRGB(120, 255, 180) },
	{ stone = Color3.fromRGB(235, 225, 200), wood = Color3.fromRGB(110, 30, 30), roof = Color3.fromRGB(200, 150, 40), trim = Color3.fromRGB(255, 220, 120), glow = Color3.fromRGB(255, 210, 110) },
}

-- What each realm from REALM_LOOK_FROM shows around its peak (src/server/RealmLook.luau, ROADMAP M3)
Config.REALM_LOOK_FROM = 6
Config.REALM_TINT_CLOUD = 0.35 -- how far the rim clouds lean to the realm colour (more read as smoke)
-- Realm 9+ lightning (RealmLook.client; owner pick B, research in REINCARNATION "What each realm
-- shows"): a strike every STORM_EVERY s per peak on screen, 2 to 4 flickers (real flashes have 2 to 4
-- return strokes ~40 to 80 ms apart), thunder delayed by distance
Config.STORM_EVERY = { 8, 18 }
Config.STORM_FLICKERS = { 2, 4 }
Config.STORM_SEE = 700 -- studs: farther peaks never strike
Config.STORM_HEAR = 320 -- studs: thunder plays within this
Config.STORM_SOUND_SPEED = 400 -- studs per second (thunder rolls in after the flash)
Config.REALM_FALL_ANGLE = 0.95 -- the realm 8 waterfall, front right beside the first one (twin falls clear of every lobe)
Config.REALM_TINT = {
	[6] = Color3.fromRGB(185, 166, 255), -- Void Refinement: violet
	[7] = Color3.fromRGB(150, 225, 190), -- Body Integration: jade
	[8] = Color3.fromRGB(255, 215, 140), -- Mahayana: warm gold
	[9] = Color3.fromRGB(150, 165, 215), -- Tribulation: storm blue
	[10] = Color3.fromRGB(255, 200, 60), -- True Immortal: the Immortal rarity's gold
}
-- one line per realm toast (a breakthrough says what changed on the peak)
Config.REALM_LOOK_LINE = {
	[6] = "Void clouds gather around your peak",
	[7] = "Rocks rise and float around your peak",
	[8] = "A second waterfall pours from your peak",
	[9] = "A storm gathers over your peak",
	[10] = "A halo crowns your Main Hall",
}
Config.REALM_LOOK_LINE_LATER = "Your halo takes a new colour"
-- realm 11 and deeper climb the rarity ladder from Celestial (then cycle)
function Config.realmTint(realm)
	if Config.REALM_TINT[realm] then
		return Config.REALM_TINT[realm]
	end
	local ladder = #Config.RARITIES - 5 -- Celestial .. Primordial
	return Config.RARITIES[6 + (realm - 11) % ladder].color
end
function Config.realmLookLine(realm)
	return Config.REALM_LOOK_LINE[realm] or (realm > 10 and Config.REALM_LOOK_LINE_LATER or nil)
end

function Config.realmName(realm)
	if realm > #Config.REALMS then
		return "Immortal Realm " .. realm
	end
	return Config.REALMS[realm]
end

function Config.costMult(realm)
	local early = math.min(realm, Config.REALM_COST_LATE_FROM) - 1
	return Config.REALM_COST_MULT ^ early * Config.REALM_COST_LATE ^ math.max(0, realm - Config.REALM_COST_LATE_FROM)
end

function Config.incomeMult(realm)
	return Config.REALM_INCOME_MULT ^ (realm - 1)
end

-- `recruits` = disciples recruited in the current realm (data.realmRecruits)
function Config.recruitCost(realm, recruits)
	return math.floor(Config.RECRUIT_BASE * Config.costMult(realm) * Config.RECRUIT_POW ^ recruits)
end

-- the qi price of one press of `n` recruits, paid all or nothing: the real price of the next n
-- recruits (owner 2026-10-22: "x10 should be the next x10 price"), with RECRUIT_POW 1.05 so x10 is
-- ~13 singles and x50 ~210 (at 1.25, x50 was ~280,000). Sim: the recruit rule never moved the pace.
function Config.recruitBatchCost(realm, recruits, n)
	local total = 0
	for i = 0, n - 1 do
		total += Config.recruitCost(realm, recruits + i)
	end
	return total
end

-- how far one press of `n` recruits moves data.realmRecruits: one per recruit
function Config.recruitStep(n)
	return n
end

-- a pad's price: its cost x costMult, or PRICE_FLOOR_S seconds of `income` (qi/s) when that is more
-- (from life PRICE_FLOOR_FROM_LIFE on; `lives` = data.lives)
function Config.padCost(pad, realm, income, lives)
	local floor = (lives or 1) >= Config.PRICE_FLOOR_FROM_LIFE and (income or 0) * Config.PRICE_FLOOR_S or 0
	return math.floor(math.max(pad.cost * Config.costMult(realm), floor))
end

-- The recruit reveal (mock recruit_b, owner pick 2026-10-21): a qi orb flies `fly` s from the
-- Recruit button, then charges one `step` per rarity above the first (an Outer Disciple bursts at
-- once, an Elder after 3 steps), bursts and shows the card for `hold` s (+ `holdPer` per tier).
Config.REVEAL = { fly = 0.4, step = 0.3, hold = 1.6, holdPer = 0.25 }
-- the x10 / x50 reveal (mock docs/art/mocks/recruit_multi_A.mp4, owner pick A 2026-10-22 "give it
-- some juice and sound"): the orbs land in a grid by `pop`, open one after another (`wave` s apart,
-- the gap shrinking with the count down to `waveMin`; a rare orb holds the wave `rarePause` s: Core
-- or better at x10, Elder or better at x50 (`rareFrom` / `rareFromBig`, else x50 stalls on its Cores),
-- and `zoom` s after the last one the best grows into the usual card, held `hold` s
Config.REVEAL_MULTI = { pop = 1.3, wave = 1.2, waveMin = 0.035, waveMax = 0.12, rareFrom = 3, rareFromBig = 4, rarePause = 0.3, zoom = 0.35, hold = 2.2 }
function Config.revealMultiWave(n)
	local m = Config.REVEAL_MULTI
	return math.clamp(m.wave / n, m.waveMin, m.waveMax)
end
-- the rarity index from which an orb counts as rare in an `n` reveal
function Config.revealMultiRare(n)
	local m = Config.REVEAL_MULTI
	return n > 10 and m.rareFromBig or m.rareFrom
end
-- when each orb of `results` opens ({ rarity = name } list), and when the best card bursts after
-- them (Juice lights the platform then)
function Config.revealMultiTimes(results)
	local m = Config.REVEAL_MULTI
	local wave = Config.revealMultiWave(#results)
	local rare = Config.revealMultiRare(#results)
	local times, at = {}, m.pop
	for i, r in results do
		times[i] = at
		at += wave
		if Config.rarityIndex(r.rarity) >= rare then
			at += m.rarePause
		end
	end
	return times, at - wave + m.zoom
end

-- The disciple icons and their auras (D34): one uploaded 1024 x 1024 sheet drawn by
-- tools/disciple_atlas.html (art/ui/disciple_atlas.png). Cells are { x, y, w, h } in px.
Config.DISCIPLE_ATLAS = {
	image = "rbxassetid://114202512373902",
	cells = {
		glow = { 0, 0, 256, 256 },
		rays12 = { 256, 0, 256, 256 },
		rays8 = { 512, 0, 256, 256 },
		ring = { 768, 0, 256, 256 },
		yinyang = { 0, 256, 256, 256 },
		halo = { 256, 256, 256, 104 },
		cloud = { 256, 384, 128, 80 },
		flame = { 384, 384, 80, 128 },
		sparkle = { 512, 256, 64, 64 },
		mote = { 576, 256, 64, 64 },
		fig1 = { 0, 512, 128, 128 },
		fig2 = { 128, 512, 128, 128 },
		fig3 = { 256, 512, 128, 128 },
		fig4 = { 384, 512, 128, 128 },
		fig5 = { 512, 512, 128, 128 },
		fig6 = { 640, 512, 128, 128 },
		fig7 = { 768, 512, 128, 128 },
		fig8 = { 896, 512, 128, 128 },
		fig9 = { 0, 640, 128, 128 },
	},
}

-- The UI icon set (owner 2026-10-22: the box-built icons "look AI"; pick A "sticker" of
-- docs/art/mocks/icons_board.jpg): one uploaded 1024 x 1024 sheet of 128 px cells drawn by
-- docs/art/mocks/icons.html?view=atlas&style=A (art/ui/icon_atlas.png). `keys` = cell index, row
-- by row, in the mock's ORDER. Robux is Roblox's own icon (ROBUX_ICON, ships with the client).
Config.ICON_ATLAS = {
	image = "rbxassetid://83850133060052",
	cell = 128,
	keys = {
		-- cell 4 (disciple) is unused: Toy draws the disciple atlas figure
		qi = 0, karma = 1, shop = 3, pill = 5, gift = 6, tide = 7,
		hall = 8, goal = 9, x2 = 10, auto = 11, vip = 12, hands = 13, rebirth = 14, like = 15,
		invite = 16, group = 17, palm = 18, chest = 19, altar = 20, pack1 = 21, pack2 = 22, pack3 = 23,
		sworn = 24, seat = 25, foundation = 26, elixir = 27, meditation = 28, echo = 29,
		bag = 3, -- the shop's qi pouch
	},
}
Config.ROBUX_ICON = "rbxasset://textures/ui/common/robux_color.png"

-- index of a rarity in RARITIES (1 = Outer Disciple)
function Config.rarityIndex(name)
	for i, r in Config.RARITIES do
		if r.name == name then
			return i
		end
	end
	return 1
end

-- seconds from the Recruit press to the burst (Juice lights the platform then)
function Config.revealBurst(name)
	return Config.REVEAL.fly + (Config.rarityIndex(name) - 1) * Config.REVEAL.step
end

function Config.rarity(name)
	for _, r in Config.RARITIES do
		if r.name == name then
			return r
		end
	end
	return Config.RARITIES[1]
end

function Config.padById(id)
	for _, p in Config.PADS do
		if p.id == id then
			return p
		end
	end
	return nil
end

-- pads a breakthrough needs (the HUD's "built" total)
Config.REQUIRED_PADS = 0
for _, pad in Config.PADS do
	if Config.neededForBreakthrough(pad) then
		Config.REQUIRED_PADS += 1
	end
end

-- D48 (owner pick A 2026-10-22: "unlock more with the realms"; research 2026-10-22_island_by_realm,
-- mock docs/art/mocks/realm_land.png): the island opens over the realms. REALM_PADS[r] = the pads
-- that first open in realm r; every realm offers its own and all earlier ones (rebuilt each realm).
-- Realm 1 keeps the Main Hall, the pill furnace, the Disciple Hall and the qi orbs (first tutorials).
-- The building looks thread reads Config.padRealm for its skin steps.
Config.REALM_PADS = {
	{ "path", "vein1", "lanterns", "mainhall1", "bridge_fields", "platform", "path_heart", "garden", "grove_heart", "vein2", "mainhall2", "bridge_dao", "furnace", "bridge_disciples", "hall", "array" },
	{ "path_fields", "grove_fields", "vein3", "firelotus1", "gate", "path_dao", "mainhall3", "path_disciples", "quarters1", "firelotus2", "grove_dao", "expand1", "bamboo", "training" },
	{ "garden2", "grove_disciples", "mainhall4", "tea1", "spring1", "koi", "quarters2", "garden3", "tea2", "expand2", "spring2" },
	{ "bell", "bridge_summit", "pagoda1", "path_summit", "library", "moongate", "jade1", "grove_summit", "pagoda2", "thunder1", "mainhall5", "jade2", "thunder2", "jade3" },
}
local padRealm = {}
for r, ids in Config.REALM_PADS do
	for _, id in ids do
		padRealm[id] = r
	end
end
for _, pad in Config.PADS do -- a pad left out of REALM_PADS opens with the last step, never silently in realm 1
	padRealm[pad.id] = padRealm[pad.id] or #Config.REALM_PADS
end
-- the realm a pad first opens in
function Config.padRealm(pad)
	return padRealm[pad.id]
end
-- is the pad offered in this realm?
function Config.padOpen(pad, realm)
	return padRealm[pad.id] <= realm
end
-- how many pads a breakthrough needs in this realm (the HUD's "built" total)
function Config.requiredPads(realm)
	local n = 0
	for _, pad in Config.PADS do
		if Config.neededForBreakthrough(pad) and Config.padOpen(pad, realm) then
			n += 1
		end
	end
	return n
end

return Config
