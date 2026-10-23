-- Cultivation Tycoon: all tunable numbers live here (single source of truth).
local Config = {}

Config.PLOT_COUNT = 6
Config.PLOT_RADIUS = 280 -- distance from the hub to each peak centre (room for the sky islets, Config.ISLETS)
Config.ISLAND_RADIUS = 72 -- the home island (the heart islet); expansions add lobes to islets (ISLAND_LOBES). 66 until 2026-10-23 (owner: "more space, slightly bigger", room for the Floating Lotus Isles at its sides)
Config.HUB_RADIUS = 44 -- owner 2026-10-22: "central space can be slightly bigger" (was 36)

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
-- Floating Lotus Isles (Builders.lotusIsle): free scriptless Creator Store meshes, rebuilt by id: a puffy
-- cloud (model 4862433614), a rock floating islet (5565039117), a bronze ding (132759878349743) and an
-- ancient palace lantern (91953058256983, its texture). Empty = not loaded: part stand-ins.
Config.SKY_MESH = {
	cloud = "rbxassetid://4862430258",
	islet = "rbxassetid://5564853241",
	isletTop = "rbxassetid://5564879293", -- the same model's grass top
	ding = "rbxassetid://84550079612246",
	lantern = "rbxassetid://131650726315765",
	lanternTex = "rbxassetid://130929930789056",
}
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

-- Rebirth = Muscle Legends' rebirth, copied as it is (owner 2026-10-22: "copy the successful games,
-- don't reinvent the wheel"; research docs/research/2026-10-22_rebirth_standard.md). The price is qi
-- and rises by the same step every rebirth (theirs: 10k strength, +5k each); a rebirth resets qi,
-- buildings and realm (back to realm 1, built: D56) and keeps every disciple (their pets); each
-- rebirth adds REBIRTH_BONUS qi forever (theirs: +5%, adding up) and pays karma (their gems, +step
-- each rebirth); rebirth counts open the deeper realms (their gyms). `rebirths` = lives - 1.
-- Economy sim (tools/sim_game.py b18f691): the realm table binds, the qi price barely matters.
Config.REBIRTH_PRICE = 100000
Config.REBIRTH_PRICE_STEP = 50000
Config.REBIRTH_BONUS = 0.5 -- Economy: +50% a rebirth (Muscle Legends' literal +5% made every life longer)
Config.REBIRTH_KARMA = 2
Config.REBIRTH_KARMA_STEP = 1
-- realm -> rebirths needed to break through into it (realms not listed are always open)
Config.REBIRTH_REALMS = { [3] = 1, [5] = 2, [7] = 4, [9] = 6, [11] = 9, [13] = 12, [15] = 16, [17] = 20 } -- Economy sim (first rebirth ~11 to 15 min)
function Config.rebirthPrice(rebirths)
	return Config.REBIRTH_PRICE + Config.REBIRTH_PRICE_STEP * (rebirths or 0)
end
function Config.rebirthMult(rebirths)
	return 1 + Config.REBIRTH_BONUS * (rebirths or 0)
end
function Config.rebirthKarma(rebirths)
	return Config.REBIRTH_KARMA + Config.REBIRTH_KARMA_STEP * (rebirths or 0)
end
-- is a rebirth open? Only when the next breakthrough waits for rebirths: every required pad of the
-- realm built and fewer rebirths than the next realm needs (economy second opinion 2026-10-22: with
-- the qi price alone the chip went gold 20 to 90 s after every rebirth and a min-maxer skipped the
-- whole gate table on day 1). `owned` = data.owned.
function Config.rebirthOpen(realm, rebirths, owned)
	if (rebirths or 0) >= Config.rebirthsFor(realm + 1) then
		return false
	end
	for _, pad in Config.PADS do
		if Config.neededForBreakthrough(pad) and Config.padOpen(pad, realm) and not owned[pad.id] then
			return false
		end
	end
	return true
end
-- rebirths needed to enter `realm` (the highest table entry at or below it, so the gates stack)
function Config.rebirthsFor(realm)
	local need, last = 0, 0
	for r, n in Config.REBIRTH_REALMS do
		if realm >= r and n > need then
			need = n
		end
		last = math.max(last, r)
	end
	-- past the table the gates go on (every odd realm, +ceil(i/2) rebirths: 19 = 25, 21 = 30, 23 = 36,
	-- 25 = 42 ...) so a rebirth always has a reason (economy second opinion 2026-10-22)
	local n, i = Config.REBIRTH_REALMS[last] or 0, 9
	for r = last + 2, realm, 2 do
		n += math.ceil(i / 2)
		i += 1
		if realm >= r then
			need = n
		end
	end
	return need
end
-- Karma Shop (the Dao Tree): permanent nodes bought with karma, `costs[i]` = price of level i.
-- Comfort and choices, all capped; nothing copies a paid pass (2x qi, auto orbs, VIP).
Config.DAO = {
	{ key = "seat", name = "Disciple Seat", line = "+1 disciple slot", costs = { 25 } },
	{ key = "elixir", name = "Elixir Mastery", line = "Pills last 30 s more", costs = { 5, 15 } },
	{ key = "meditation", name = "Deep Meditation", line = "+2 h offline Qi", costs = { 5, 15 } },
	{ key = "echo", name = "Soul Echo", line = "+10% Karma", costs = { 8, 16, 32, 64, 128 } },
	{ key = "hands", name = "Heavenly Hands", line = "Build without walking", costs = { 5 } },
	-- owner 2026-10-23 ("karma + pads once unlocked"): bought once, the Floating Lotus Isle pads (kind
	-- "isle") are offered every life from then on, and are built with qi like any pad
	{ key = "isles", name = "Floating Isles", line = "Unlock the Lotus Isles", costs = { 12, 30 } }, -- level 2: isles 4 to 8
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

Config.REALM_INCOME_MULT = 3 -- income x3 per realm
-- Owner direction (D25): the first realms are fast laps, then it gets hard; realm 10 is the long goal
-- (reincarnation comes after it). Costs x5 per realm up to REALM_COST_LATE_FROM (realms 2 to 5 take
-- ~5 to 10 min each), then x10 per realm (realm 10 lands ~day 21 for 2 x 30 min a day;
-- tools/sim_economy.py, research 2026-10-21_economy_math)
Config.REALM_COST_MULT = 5
Config.REALM_COST_LATE = 5 -- economy second opinion 2026-10-22: x10 stalled a regular player at realm 14 from day 21
Config.REALM_COST_LATE_FROM = 5
Config.BREAKTHROUGH_COST = 300000 -- the old fixed price (x costMult); read only by the older sims
-- D48: the breakthrough costs BREAKTHROUGH_SECONDS of the price income (Main priceRate: buildings x
-- realm x disciples; no pill, tide, rebirth boost, Harmony or paid pass) the realm ends on, so the save-up after the
-- last building is the same short goal whatever the realm holds (research 2026-10-22_island_by_realm)
Config.BREAKTHROUGH_SECONDS = 90
-- the breakthrough pad opens a confirm screen; its Confirm counts this long after the offer (s)
Config.BREAKTHROUGH_ASK_SECONDS = 120

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
	-- Floating Lotus Isles (owner pick C 2026-10-22, captures docs/art/captures/2026-10-22_platform_C_v2_islets.jpg):
	-- jade lotus discs on rock islets floating over the Meditation Platform, each seating `seats` more
	-- disciples; floating stepping stones let the player jump up to each, one after the other
	-- (Builders.lotusIsle). The model floats over the platform; `x`/`z` place only the buy pad.
	{ id = "lotus1", name = "Floating Lotus Isle", cost = 9000, income = 20, unlock = 12, req = { "platform", "expand1" }, x = -24, z = -8, feature = "+4 disciple seats", district = "heart", seats = 4, kind = "isle" },
	{ id = "lotus2", name = "Twin Lotus Isle", cost = 19000, income = 40, unlock = 16, req = { "lotus1", "expand2" }, x = 24, z = -8, feature = "+4 disciple seats", district = "heart", seats = 4, kind = "isle" },
	{ id = "lotus3", name = "Heavenly Lotus Isle", cost = 31000, income = 60, unlock = 21, req = { "lotus2" }, x = 0, z = -19, feature = "+4 disciple seats", district = "heart", seats = 4, kind = "isle" },
	-- five more (owner 2026-10-23: "add like 5 more, the easy to spot strong player thing"): the
	-- second level of the Floating Isles karma node (`karma` = the node level a pad needs)
	{ id = "lotus4", name = "Cloud Lotus Isle", cost = 40000, income = 70, unlock = 22, req = { "lotus3" }, x = 34, z = -40, feature = "+4 disciple seats", district = "heart", seats = 4, kind = "isle", karma = 2 },
	{ id = "lotus5", name = "Moon Lotus Isle", cost = 52000, income = 80, unlock = 23, req = { "lotus4" }, x = -34, z = -40, feature = "+4 disciple seats", district = "heart", seats = 4, kind = "isle", karma = 2 },
	{ id = "lotus6", name = "Star Lotus Isle", cost = 66000, income = 90, unlock = 24, req = { "lotus5" }, x = -40, z = -14, feature = "+4 disciple seats", district = "heart", seats = 4, kind = "isle", karma = 2 },
	{ id = "lotus7", name = "Sun Lotus Isle", cost = 82000, income = 100, unlock = 25, req = { "lotus6" }, x = -40, z = 24, feature = "+4 disciple seats", district = "heart", seats = 4, kind = "isle", karma = 2 },
	{ id = "lotus8", name = "Immortal Lotus Isle", cost = 100000, income = 110, unlock = 26, req = { "lotus7" }, x = 32, z = 34, feature = "+4 disciple seats", district = "heart", seats = 4, kind = "isle", karma = 2 },
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
	{ id = "grove_heart", name = "Plum Grove", cost = 250, income = 0, unlock = 3, req = {}, x = 40, z = 24, islet = "heart", kind = "grove" },
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
	heart = { x = 0, z = 0, r = 72 }, -- = ISLAND_RADIUS
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
	if pad.kind == "isle" then
		return false -- the Lotus Isles are a karma unlock: never what a breakthrough waits on
	end
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
-- Incense Blessing (owner pick A 2026-10-22, src/server/Bless.luau): hold a neighbour's shrine
-- prompt BLESS_HOLD s; both get BLESS_SECONDS of their own offline-rate income (PROPOSED, the
-- economy check confirms). Once per visitor and sect a UTC day; at most BLESS_GIVE_MAX given and
-- BLESS_GET_MAX received a day. The owner's share needs a real giver: Roblox account age and play
-- time (alts feed nobody, research 2026-10-22_neighbour_visits).
Config.BLESS_SHRINE_AT = Vector3.new(-17, 0, 44) -- home island, left of the avenue, plaque facing it (pot on a pedestal, lanterns either side)
Config.BLESS_HOLD = 3
Config.BLESS_SECONDS = 120
Config.BLESS_GIVE_MAX = 5
Config.BLESS_GET_MAX = 5
Config.BLESS_MIN_ACCOUNT_DAYS = 7
Config.BLESS_MIN_PLAY = 600
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
-- tide, no pill), GIFT_SUMMONS[i] free summons (into the idle chest's summons), GIFT_PILL[i] s of
-- 2x qi and a GIFT_RARITY[i] disciple (owner: "make them interesting": an Elder at 45 min, an
-- Immortal at 2 h). Simmed 2026-10-22 (tools/sim_game.py): every player kind's lives end on the
-- same days as before, within a minute or two of play.
Config.GIFT_TIMES = { 300, 600, 1200, 1800, 2700, 3600, 5400, 7200 }
-- Red dots (server Dots.luau). The Shop's leads to its free daily gift (owner: "to clean shop one, give
-- a small free daily gift"): SHOP_FREE_SECONDS of income (no tide, no pill), once per UTC day, first
-- offered after DOT_SHOP_FIRST s of play; claiming it is what clears the dot. The Sect Gift's (unclaimed
-- group gift) lights at most once per DOT_GROUP_SECONDS.
Config.DOT_SHOP_FIRST = 120
Config.SHOP_FREE_SECONDS = 300
Config.DOT_GROUP_SECONDS = 24 * 3600
Config.GIFT_VALUE = { 180, 120, 0, 300, 0, 900, 0, 0 }
Config.GIFT_SUMMONS = { 0, 1, 0, 3, 0, 0, 5, 0 }
Config.GIFT_PILL = { 0, 0, 300, 0, 0, 0, 0, 0 } -- seconds of 2x qi (adds to a running pill)
Config.GIFT_RARITY = { "", "", "", "", "Elder", "", "", "Immortal" } -- a disciple of that rarity
Config.GIFT_DAILY = true -- read by the sim
-- what gift i pays (the HUD chip and the Free Gifts page draw it)
function Config.giftPrize(i)
	if not Config.GIFT_TIMES[i] then
		return nil
	end
	local r = Config.GIFT_RARITY[i]
	return { at = Config.GIFT_TIMES[i], qiSec = Config.GIFT_VALUE[i] or 0, summons = Config.GIFT_SUMMONS[i] or 0, pill = Config.GIFT_PILL[i] or 0, rarity = r ~= "" and r or nil }
end
-- Daily Blessing (login streak, D58, owner pick A: "elder d7 is super late, should be day 2 at
-- least. I'd say even one tier more day 2"): one claim per UTC day (Config.giftDay); a missed day
-- PAUSES the ladder (owner), it never resets. After day 7 it starts again at day 1. A day gives
-- `qiSec` seconds of income (no tide, no pill), `summons` free summons (into the idle chest's pool)
-- and/or a disciple of `rarity`; a disciple day pays once per save, a repeat pays `again` instead.
-- Economy check 2026-10-22 (tools/sim_game.py STREAK): pace unchanged, the streak is 0.2-1.4% of all qi.
Config.STREAK = {
	{ qiSec = 300, summons = 1 },
	{ rarity = "Immortal", again = { summons = 3 } },
	{ qiSec = 600, summons = 2 },
	{ qiSec = 900 },
	{ summons = 3 },
	{ qiSec = 1800 },
	{ rarity = "Celestial", again = { summons = 3 } }, -- owner: "day 2 and 7 should show actual skins of immortal and celestial"
}
-- Roblox badges (D58, docs/design/BADGES.md): the owner creates each in Creator Hub and pastes its
-- id here; 0 = not created yet, nothing is awarded. Checked on every publish (Badges.luau).
Config.BADGES = {
	founder = 0, -- Sect Founder: first building
	disciple = 0, -- First Disciple
	realm2 = 0, -- Foundation Laid
	realm3 = 0, -- Golden Core
	streak7 = 0, -- Loyal Cultivator: day 7 of the Daily Blessing
	elder = 0, -- Elder's Favour: an Elder or rarer
	realm4 = 0, -- Nascent Soul
	friends = 0, -- Sect of Friends: a friend on the server
	realm8 = 0, -- Mahayana
	reborn = 0, -- Reborn: first reincarnation
}
function Config.giftDay(t)
	return math.floor((t or os.time()) / 86400)
end
Config.SLOT_PADS = { "quarters1", "quarters2", "lotus1", "lotus2", "lotus3", "lotus4", "lotus5", "lotus6", "lotus7", "lotus8" } -- each owned one adds its pad's `seats` (1 when missing)

-- `vip` = owns the VIP Sect pass (VIP_SLOTS more)
function Config.maxDisciples(owned, vip)
	local n = Config.MAX_DISCIPLES + (vip and Config.VIP_SLOTS or 0)
	for _, id in Config.SLOT_PADS do
		if owned[id] then
			local pad = Config.padById(id)
			n += pad and pad.seats or 1
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
	-- worth (bought disciples are never trimmed, so this bounds the list and the save). Every item is on
	-- sale at every realm (owner 2026-10-22: "open all products to any level"); an item may still set
	-- `minRealm` (Shop.luau and Shop.client read it), none does.
	{ key = "celestial", id = 3721095787, name = "Celestial", line = "+900% Qi disciple", rarity = "Celestial", limit = 1 },
	{ key = "dao", id = 3721095866, name = "Dao Ancestor", line = "+2,000% Qi disciple", rarity = "Dao Ancestor", limit = 1 },
	{ key = "emperor", id = 3721095940, name = "Heavenly Emperor", line = "+4,500% Qi disciple", rarity = "Heavenly Emperor", limit = 1 },
	{ key = "primordial", id = 3721095995, name = "Primordial", line = "+10,000% Qi disciple", rarity = "Primordial", limit = 1 },
}
Config.PASS_QI_MULT = 2 -- 2x Qi pass: every qi/s, offline and gifts included
-- The Welcome Pouch offer card: once, after a big building (one with a `feature`) from `after` s of
-- play, or after any building from `late` s (owner: "after a big building after 5-10 minutes")
Config.WELCOME = { after = 300, late = 600 }
Config.VIP_SLOTS = 1
-- The four cultivator looks (Cultivators.luau): each disciple keeps the one it was rolled with (D60)
Config.DISCIPLE_LOOKS = { "sword", "lotus", "monk", "elder" }
Config.LOOK_NAMES = { sword = "Sword", lotus = "Lotus", monk = "Monk", elder = "Sage" }
-- The disciple index (D60, owner pick B + C 2026-10-22: "B better, with the C stars system. Max 5 stars
-- each, giving a qi boost, low but good to get. Some summons at each step"): one entry per rarity and
-- look; a star at each of INDEX_STARS pulls of it, INDEX_STAR_BONUS income per star (forever, every
-- life), INDEX_STEP_SUMMONS free summons each INDEX_STEP_STARS stars. Numbers: the economy pass.
-- Owner 2026-10-23 ("show some with red and blue stars like the beads, we'll let them grow that far"):
-- 15 stars, shown five at a time like the life beads: gold 1-5, then red 6-10 over the gold, then
-- blue 11-15 (Config.STAR_COLORS, Config.starRow)
Config.INDEX_STARS = { 1, 3, 10, 30, 100, 200, 300, 500, 700, 1000, 1500, 2000, 3000, 4000, 5000 }
Config.STAR_ROW = 5
Config.STAR_COLORS = { Color3.fromHex("FFD34D"), Color3.fromHex("FF4A4A"), Color3.fromHex("4AA8FF") }
Config.INDEX_STAR_BONUS = 0.0025 -- +0.25% a star (economy pass 2026-10-22: 0.005 sped the climb up by 2-3 days)
Config.INDEX_STEP_STARS = 10
-- A disciple's own stars (owner 2026-10-22: "stars should count on their performance too. And they
-- could show when you look at them"): a working disciple's bonus x (1 + this x the stars of its index
-- entry), so a five-star disciple works twice as hard (fifteen stars: four times). Bee Swarm Simulator's gifted bee, per seat.
-- Kept out of prices like the index (sim_game.py DISCIPLE_STAR_BONUS: +1 life in 30 days at most).
Config.DISCIPLE_STAR_BONUS = 0.2
Config.INDEX_STEP_SUMMONS = 3
Config.DISCIPLE_CAP = 41 -- disciples kept at most (the largest sect's seats: MAX_DISCIPLES + VIP + SLOT_PADS)
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
	{ name = "Outer Disciple", weight = 59.84, bonus = 0.10, color = Color3.fromRGB(200, 200, 200) },
	{ name = "Inner Disciple", weight = 28, bonus = 0.25, color = Color3.fromRGB(90, 200, 120) },
	{ name = "Core Disciple", weight = 9, bonus = 0.60, color = Color3.fromRGB(80, 150, 255) },
	{ name = "Elder", weight = 2.5, bonus = 1.50, color = Color3.fromRGB(190, 100, 255) },
	{ name = "Immortal", weight = 0.5, bonus = 4.00, color = Color3.fromRGB(255, 200, 60) },
	{ name = "Celestial", weight = 0.12, bonus = 9.00, color = Color3.fromRGB(110, 225, 235) },
	{ name = "Dao Ancestor", weight = 0.03, bonus = 20.00, color = Color3.fromRGB(230, 50, 60) },
	{ name = "Heavenly Emperor", weight = 0.008, bonus = 45.00, color = Color3.fromRGB(255, 140, 40) },
	{ name = "Primordial", weight = 0.002, bonus = 100.00, color = Color3.fromRGB(255, 110, 220) }, -- its aura cycles every colour
}

-- The weights are the shown odds in % and add up to exactly 100 (Roblox's paid random item rule:
-- qi is sold for Robux, so every recruit shows its odds first; Outer took the 0.16 they were over).

-- Named disciples (owner pick "All" 2026-10-23, mock docs/art/mocks/2026-10-23_disciple_roster.html):
-- like Bee Swarm Simulator's bees and Anime Vanguards' units, every index entry (rarity x look) is a
-- character with its own name and face; the rarity is its frame and colour. Names are labels only:
-- data.index stays keyed by Config.indexKey(rarity, look). Index = rarity tier 1..9.
Config.DISCIPLE_NAMES = {
	sword = { "Ah Fan", "Shen Yi", "Zhao Feng", "Swift Blade Han", "Azure Sword Lan", "Starfall Chen", "Sword Ancestor", "Dragon Emperor", "Pangu" },
	lotus = { "Xiao Mei", "Lin Er", "Su Qing", "Moon Lotus Yue", "Jade Fairy Ling", "Cloud Weaver Xi", "Lotus Mother", "Phoenix Empress", "Nuwa" },
	monk = { "Little Bao", "Brother Tie", "Monk Kong", "Iron Bell Ming", "Golden Bell Bo", "Thunder Monk Lei", "Furnace Patriarch", "Sun King", "Hundun" },
	elder = { "Old Wu", "Uncle Gu", "Master Lu", "Old Pine Song", "Crane Immortal He", "Moon Sage Yin", "Yin-Yang Patriarch", "Star Emperor", "Hongjun" },
}
-- Pity (copy Anime Defenders / Anime Vanguards: a guaranteed Legendary at 50 pulls, Mythic at 400):
-- `at` recruits in a row without `rarity` or better makes the next one that rarity. Our players
-- recruit far more (sim_game: ~700 on day 1, ~56,000 by day 30), so the guarantees sit on the high
-- tiers. Every roll counts (recruits, idle chest, gifts' summons); data.pity holds the counts.
Config.PITY = { { rarity = "Celestial", at = 1000 }, { rarity = "Dao Ancestor", at = 5000 } }
-- Shiny (copy Pet Simulator 99's Shiny pets): SHINY_CHANCE of every roll comes out Shiny, on top of
-- its rarity: a sparkling frame and SHINY_MULT x its bonus. data.shinyIndex marks each entry found.
Config.SHINY_CHANCE = 0.01
Config.SHINY_MULT = 1.5

-- Building palettes cycle with the realm.
Config.PALETTES = {
	{ stone = Color3.fromRGB(150, 150, 145), wood = Color3.fromRGB(120, 80, 50), roof = Color3.fromRGB(90, 60, 45), trim = Color3.fromRGB(190, 170, 120), glow = Color3.fromRGB(120, 220, 255) },
	{ stone = Color3.fromRGB(200, 225, 210), wood = Color3.fromRGB(140, 40, 40), roof = Color3.fromRGB(40, 140, 100), trim = Color3.fromRGB(230, 230, 220), glow = Color3.fromRGB(120, 255, 180) },
	{ stone = Color3.fromRGB(235, 225, 200), wood = Color3.fromRGB(110, 30, 30), roof = Color3.fromRGB(200, 150, 40), trim = Color3.fromRGB(255, 220, 120), glow = Color3.fromRGB(255, 210, 110) },
}

-- Hub rankings (src/server/Ranks.luau): one OrderedDataStore per board (+ one per country)
Config.RANKS = {
	sects = { store = "Ranks1", title = "Greatest Sects", order = 2 }, -- realms climbed * 1000 + lives
	qi = { store = "RanksQi1", title = "Richest Qi", order = 1 }, -- best qi/s ever
	week = { store = "RanksWeek1", title = "This Week", order = 3, weekly = true }, -- seconds played this week
}
-- the week number (weeks start Monday 00:00 UTC; day 0 = 1970-01-01, a Thursday)
function Config.rankWeek(t)
	return math.floor((math.floor((t or os.time()) / 86400) + 3) / 7)
end
Config.RANK_TOP = 10 -- rows read and shown
Config.RANK_WALL_GAP = 5 -- the hub gap (between bridges 5 and 6) where the wall stands
Config.RANK_WALL_R = 25 -- studs from the hub centre
-- HUD teleports (owner 2026-10-22: "MY BASE" and "RANKINGS" at the top of the HUD): seconds between two
-- jumps, and how far in front of the ranking wall you land (facing it)
Config.TELEPORT_COOLDOWN = 3
Config.TELEPORT_RANK_FRONT = 9 -- 13 put the follow camera inside the cauldron and the altar
-- The Robux purchase moment (BuyMoment.client, owner pick A "Spotlight" 2026-10-22): seconds for the
-- item's pop, the hold on screen, the flight home; the HUD bumps the qi counter at buyArrive()
Config.BUY_MOMENT = { pop = 0.45, hold = 1.7, fly = 0.6 }
function Config.buyArrive()
	local b = Config.BUY_MOMENT
	return b.pop + b.hold + b.fly
end
Config.RANK_SEE = 140 -- studs: the boards' text draws within this
-- Free Creator Store models on the ranking wall (owner: "search free assets"), rebuilt from their
-- meshes by RankBoard (no inserted scripts): "Chinese Gate Door" and "Chinese Lion Stone Statue" by
-- funshine_4321 (assets 131931560252959, 78030834541623).
Config.RANK_GATE = { name = "Gate", height = 29, size = Vector3.new(26.567, 29.477, 5.462), parts = {
	{ mesh = "rbxassetid://7299159581", texture = "rbxassetid://7299159924", size = Vector3.new(5.462, 9.489, 26.567), at = CFrame.new(0, 24.7322, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	{ mesh = "rbxassetid://7299136679", texture = "rbxassetid://7299137242", size = Vector3.new(2.213, 24.828, 22.612), at = CFrame.new(-0.0459, 12.4141, -0.0386, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
} }
-- "ancient chinese bronze vessel" and "chinese indoor lantern" by staticleelee (assets 92874522498149,
-- 134122657957600): the wall's braziers and lanterns (owner: "make the lights better").
Config.RANK_DING = { name = "Ding", height = 2.6, size = Vector3.new(9.8, 6.363, 6.447), parts = {
	{ size = Vector3.new(0.4, 1.6, 2.0), at = CFrame.new(4.1001, 2.0453, 1.9434, 0, 1, 0, 0, 0, 1, 1, 0, 0), color = "506D54", material = "CorrodedMetal" },
	{ mesh = "rbxassetid://6249538345", size = Vector3.new(4.575, 2.47, 7.4), at = CFrame.new(0, 4.2805, 0.0894, 0, 0, 1, 0, 1, 0, -1, 0, 0), color = "506D54", material = "CorrodedMetal" },
	{ mesh = "rbxassetid://12449090364", size = Vector3.new(1.7, 1.247, 0.85), at = CFrame.new(0, 4.0454, 2.6001, -1, 0, 0, 0, 0, 1, 0, 1, 0), color = "506D54", material = "CorrodedMetal" },
	{ mesh = "rbxassetid://12449090364", size = Vector3.new(1.9, 1.047, 0.85), at = CFrame.new(3.8750, 5.8393, 0.1021, 0, 0, 1, 0, 1, 0, -1, 0, 0), color = "506D54", material = "CorrodedMetal" },
	{ mesh = "rbxassetid://7356523804", size = Vector3.new(2.629, 2.602, 1.198), at = CFrame.new(3.9390, 4.2071, 0.0703, 0, 0, -1, 0, 1, 0, 1, 0, 0), color = "27462D", material = "Concrete" },
	{ mesh = "rbxassetid://7356523804", size = Vector3.new(2.629, 2.602, 1.414), at = CFrame.new(4.0469, 4.2071, 0.0703, 0, 0, -1, 0, 1, 0, 1, 0, 0), color = "506D54", material = "CorrodedMetal" },
	{ mesh = "rbxassetid://15227880665", size = Vector3.new(7.387, 3.045, 4.502), at = CFrame.new(-0.0068, 1.5226, 0.1255, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = "506D54", material = "CorrodedMetal" },
	{ size = Vector3.new(0.4, 1.6, 2.0), at = CFrame.new(4.1001, 2.0453, -1.7256, 0, 1, 0, 0, 0, 1, 1, 0, 0), color = "506D54", material = "CorrodedMetal" },
	{ mesh = "rbxassetid://12449090364", size = Vector3.new(1.9, 1.047, 0.85), at = CFrame.new(-3.9248, 5.8393, 0.1021, 0, 0, 1, 0, 1, 0, -1, 0, 0), color = "506D54", material = "CorrodedMetal" },
	{ mesh = "rbxassetid://12449090364", size = Vector3.new(1.7, 1.247, 0.85), at = CFrame.new(0, 4.0454, -2.6001, 1, 0, 0, 0, 0, 1, 0, -1, 0), color = "506D54", material = "CorrodedMetal" },
	{ mesh = "rbxassetid://7356523804", size = Vector3.new(2.629, 2.602, 1.198), at = CFrame.new(-3.9531, 4.2071, 0.0703, 0, 0, 1, 0, 1, 0, -1, 0, 0), color = "27462D", material = "Concrete" },
	{ mesh = "rbxassetid://7356523804", size = Vector3.new(2.629, 2.602, 1.414), at = CFrame.new(-4.0615, 4.2071, 0.0703, 0, 0, 1, 0, 1, 0, -1, 0, 0), color = "506D54", material = "CorrodedMetal" },
	{ size = Vector3.new(0.4, 1.6, 2.0), at = CFrame.new(-4.1001, 2.0453, -1.7256, 0, -1, 0, 0, 0, 1, -1, 0, 0), color = "506D54", material = "CorrodedMetal" },
	{ size = Vector3.new(0.4, 1.6, 2.0), at = CFrame.new(-4.1001, 2.0453, 1.9434, 0, -1, 0, 0, 0, 1, -1, 0, 0), color = "506D54", material = "CorrodedMetal" },
} }
-- the glowing core (Neon, a real PointLight sits in it) stands in for the original's lit panel
Config.RANK_LANTERN = { name = "Lantern", height = 7, glowAt = 0.52, size = Vector3.new(6, 8.546, 6.004), parts = {
	{ mesh = "rbxassetid://99854118578965", size = Vector3.new(6.004, 8.31, 6.0), at = CFrame.new(0, 4.1548, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), color = "694028", material = "Wood" },
	{ mesh = "rbxassetid://99854118578965", size = Vector3.new(5.604, 8.546, 5.6), at = CFrame.new(0, 4.2732, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), color = "750000", material = "Wood" },
	{ mesh = "rbxassetid://3377804925", size = Vector3.new(1.433, 0.228, 1.394), at = CFrame.new(0.0059, 3.8852, 0, 0, 0, 1, 0, -1, 0, 1, 0, 0), color = "1B2A35", material = "Wood" },
	{ mesh = "rbxassetid://3377804925", size = Vector3.new(1.827, 0.169, 1.608), at = CFrame.new(0.0059, 3.7947, 0, 0, 0, 1, 0, -1, 0, 1, 0, 0), color = "750000", material = "Wood" },
	{ mesh = "rbxassetid://3377804925", size = Vector3.new(1.397, 1.107, 1.262), at = CFrame.new(0.0059, 4.4470, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), color = "FFB25A", material = "Neon" },
	{ mesh = "rbxassetid://3377804925", size = Vector3.new(0.709, 0.353, 0.709), at = CFrame.new(0.0059, 5.2923, 0, 0, 0, 1, 0, -1, 0, 1, 0, 0), color = "1B2A35", material = "Wood" },
	{ mesh = "rbxassetid://3377804925", size = Vector3.new(1.827, 0.169, 1.608), at = CFrame.new(0.0059, 5.1002, 0, 0, 0, 1, 0, -1, 0, 1, 0, 0), color = "750000", material = "Wood" },
	{ mesh = "rbxassetid://3377804925", size = Vector3.new(1.44, 0.22, 1.467), at = CFrame.new(0.0059, 5.1525, 0, 0, 0, 1, 0, -1, 0, 1, 0, 0), color = "750000", material = "Wood" },
	{ mesh = "rbxassetid://3377804925", size = Vector3.new(1.106, 0.298, 1.202), at = CFrame.new(0.0059, 5.1915, 0, 0, 0, 1, 0, -1, 0, 1, 0, 0), color = "750000", material = "Wood" },
	{ mesh = "rbxassetid://3377804925", size = Vector3.new(1.433, 0.169, 1.394), at = CFrame.new(0.0059, 4.9881, 0, 0, 0, 1, 0, -1, 0, 1, 0, 0), color = "1B2A35", material = "Wood" },
} }
Config.RANK_LION = { name = "Lion", height = 7, size = Vector3.new(38.665, 48.386, 28.575), parts = {
	{ mesh = "rbxassetid://7280531958", texture = "rbxassetid://7280532422", size = Vector3.new(38.665, 48.388, 28.576), at = CFrame.new(0, 24.1921, 0) },
} }
Config.RANK_REFRESH = 300 -- s between store reads (DevForum: a global board needs no faster)
Config.RANK_WRITE_EVERY = 60 -- s between write rounds (one SetAsync per changed score)
Config.RANK_TICK = 30 -- s between a session's score reports (play time, rate)
Config.RANK_MIN_BUDGET = 10 -- requests of that type left before the board may spend one

-- Building skins (research docs/research/2026-10-22_visible_progression.md, mocks
-- docs/art/mocks/2026-10-22_skins_*.jpg): every building is recoloured after it is built
-- (src/server/Skin.luau) so a peak shows how far its owner has come from the next peak over.
-- A grade maps Style.PAL keys (ART_BIBLE palette) to a colour, or { colour, material }; keys left out
-- keep the art colour. Grade 2 is the art itself.
local hex = Color3.fromHex
Config.SKIN_GRADES = {
	{ name = "Timber", map = { vermilion = hex("8A5A3B"), tile = hex("7D6B4F"), tileDark = hex("5E4F3A"), gold = hex("6B5A45"), plaster = hex("CDBB9A"), jade = hex("6E8060") } },
	{ name = "Red Lacquer", map = {} },
	{ name = "Jade", map = { vermilion = hex("2E6F5A"), tile = hex("2F7A5E"), tileDark = hex("21573F"), plaster = hex("F2EFE6"), stone = hex("D9D6CC"), stoneLight = hex("E6E3DA") } },
	{ name = "Imperial Gold", map = { tile = hex("D9A43A"), tileDark = hex("A87A22"), plaster = hex("F0D9A8"), gold = hex("F2C14E"), stone = hex("E4D7B5") } },
	{ name = "White Jade", map = { tile = hex("E8ECEF"), tileDark = hex("B9C3CC"), vermilion = hex("EDE6D8"), plaster = { hex("FFFFFF"), Enum.Material.Marble }, timber = hex("D8CFC0"), timberDark = hex("A89F8E"), gold = hex("F5D27A"), stone = { hex("EEF0F2"), Enum.Material.Marble }, stoneLight = hex("F7F8F9"), jade = hex("9FE3CF") } },
}
-- Later lives top out higher (owner pick A, 2026-10-22: the material follows the realm; lives add what
-- a reset cannot take): from realm 4 a life N >= 2 builds in SKIN_LIFE_TOP[N - 1] instead of Imperial Gold.
table.insert(Config.SKIN_GRADES, { name = "Void Amethyst", map = { tile = hex("6B4FA8"), tileDark = hex("4A3478"), vermilion = hex("3B2E5A"), plaster = hex("EAE4F5"), gold = hex("CFC6E8"), stone = hex("C9C3D6"), stoneLight = hex("DDD8E6") } })
table.insert(Config.SKIN_GRADES, { name = "Celestial Azure", map = { tile = hex("4FA3D9"), tileDark = hex("2F78A8"), vermilion = hex("F2F6FA"), plaster = { hex("FFFFFF"), Enum.Material.Marble }, gold = hex("FFD36A"), stone = { hex("E8EEF4"), Enum.Material.Marble }, stoneLight = hex("F4F8FB"), timberDark = hex("2B4F6E") } })
Config.SKIN_REALM_GRADES = { 1, 2, 3, 4 } -- realms 1 to 4 (the island opens over the same 4 realms, Config.REALM_PADS)
Config.SKIN_LIFE_TOP = { 5, 6, 7 } -- lives 2, 3, 4+ at realm 4 and above
-- Lives also add light and aura that a reset never takes back: real stone lanterns round the Main
-- Hall (SKIN_LANTERNS per life, R3: a visible lamp with a real light) and slow motes over every
-- big building from SKIN_MOTE_FROM (level = realm grade step + lives - 1). Phone budget (R16 rule 6):
-- one emitter per building of SKIN_MOTE_MIN studs or more, Rate SKIN_MOTE_RATE x (level - from + 1)
-- capped at SKIN_MOTE_MAX, Lifetime ~5 s: under 20 live motes a building; lanterns capped at 8 lights.
Config.SKIN_LANTERNS = { 0, 4, 6, 8 } -- lives 1, 2, 3, 4+
-- The Main Hall grows each life (owner: "bigger later", "for people to see easily who's better"),
-- scaled about its front step so it grows back and sideways, away from the plaza.
Config.SKIN_HALL_SCALE = { 1, 1.08, 1.15 } -- lives 1, 2, 3+ (1.3 put the Celestial Palace wings on the islet bridges, mock 2026-10-22_hall_scale)
Config.SKIN_MOTE_FROM = 3
Config.SKIN_MOTE_MIN = 16
Config.SKIN_MOTE_RATE = 1
Config.SKIN_MOTE_MAX = 4
Config.SKIN_MOTE_COLOR = { Color3.fromHex("FFB070"), Color3.fromHex("FFB070"), Color3.fromHex("9FF5C8"), Color3.fromHex("FFD36A"), Color3.fromHex("E8F6FF"), Color3.fromHex("C9B5FF"), Color3.fromHex("A8DCFF") } -- by grade
-- grade index for a peak at `realm` in life `lives`
function Config.skinFor(realm, lives)
	realm, lives = realm or 1, lives or 1
	local top = #Config.SKIN_REALM_GRADES
	if lives > 1 and realm >= top then
		return Config.SKIN_LIFE_TOP[math.min(lives - 1, #Config.SKIN_LIFE_TOP)]
	end
	return Config.SKIN_REALM_GRADES[math.clamp(realm, 1, top)]
end
-- how much light and aura: the realm's step (1 to 4) plus one per extra life
function Config.skinLevel(realm, lives)
	return math.clamp(realm or 1, 1, #Config.SKIN_REALM_GRADES) + (lives or 1) - 1
end
function Config.skinName(realm, lives)
	return Config.SKIN_GRADES[Config.skinFor(realm, lives)].name
end
-- the overhead status title (StatusTitle.client): realms 1 to 5 climb the rarity colours, then the realm tint
function Config.realmColor(realm)
	if realm <= 5 then
		return Config.RARITIES[math.max(1, realm)].color
	end
	return Config.realmTint(realm)
end
Config.TITLE_SEE = 110 -- studs: farther titles are hidden
-- The player's own aura (src/server/PlayerAura.luau, owner pick B: realm aura + life beads). One
-- bead per rebirth on a halo of AURA_BEAD_BAND slots; each full band the beads take the next colour
-- (owner: "like 20 yellow then 20 red then 20 blue and with more aura each time... easily to 100").
-- After the last band the halo stays full.
-- The ground glyph textures (owner pick 2026-10-23: our WC3-style set, tools/aura_textures.py; the
-- owner uploads upload/auras/*.png and pastes the image ids here). White art tinted per realm. A realm
-- whose two ids are 0 keeps the UI-drawn glyph (AuraGlyph RECIPES); runes from realm 6 and the light
-- column from realm 9 need their own ids.
Config.AURA_TEX = {
	glow = 97261261909185, -- aura_glow.png
	column = 136175245864583, -- aura_column.png (unused since 2026-10-23: the column is particles now)
	runes = 105666316409518, -- aura_runes_2x2.png (a 2 x 2 flipbook)
	realms = { -- realm = { aura_r<n>_a.png, aura_r<n>_b.png }
		[2] = { 101462076907885, 116445156630131 },
		[3] = { 78351354918107, 139521718891710 },
		[4] = { 82692031342257, 102753656570417 },
		[5] = { 136482327832298, 112348904539057 },
		[6] = { 131839890508081, 71277369931412 },
		[7] = { 127679238936600, 78699647461511 },
		[8] = { 82830787818404, 139794889534766 },
		[9] = { 106824336271041, 110215277572986 },
		[10] = { 135856301285308, 117237264599559 },
	},
}
Config.AURA_BEAD_BAND = 20
Config.AURA_BEAD_COLORS = { Color3.fromHex("FFD36A"), Color3.fromHex("FF4A4A"), Color3.fromHex("4AA8FF"), Color3.fromHex("B46BFF"), Color3.fromHex("BFF2E0") } -- rebirths 1-20, 21-40, 41-60, 61-80, 81-100
function Config.ordinal(n)
	local t = n % 100
	local suffix = (t >= 11 and t <= 13) and "th" or ({ "st", "nd", "rd" })[n % 10] or "th"
	return n .. suffix
end

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

-- The named disciples' faces (2026-10-23): one 1024 x 1024 sheet of 160 px portraits drawn by
-- docs/art/mocks/2026-10-23_disciple_roster.html?view=atlas (art/ui/disciple_faces.png), 6 a row,
-- cell = (tier - 1) x 4 + look - 1 in DISCIPLE_LOOKS order. "" falls back to the old per-rarity figure.
Config.DISCIPLE_FACES = { image = "rbxassetid://101021423288352", cell = 160, cols = 6 } -- uploaded 2026-10-23
-- the { x, y } px offset of a rarity and look's face in DISCIPLE_FACES
function Config.faceCell(rarityName, look)
	local li = table.find(Config.DISCIPLE_LOOKS, look) or 1
	local i = (Config.rarityIndex(rarityName) - 1) * #Config.DISCIPLE_LOOKS + li - 1
	local f = Config.DISCIPLE_FACES
	return Vector2.new((i % f.cols) * f.cell, (i // f.cols) * f.cell)
end

-- The UI icon set (owner 2026-10-22: the box-built icons "look AI"; pick A "sticker" of
-- docs/art/mocks/icons_board.jpg): one uploaded 1024 x 1024 sheet of 128 px cells drawn by
-- docs/art/mocks/icons.html?view=atlas&style=A (art/ui/icon_atlas.png). `keys` = cell index, row
-- by row, in the mock's ORDER. Robux is Roblox's own icon (ROBUX_ICON, ships with the client).
Config.ICON_ATLAS = {
	image = "rbxassetid://88666296128668", -- 31 icons (+ trophy for Ranks), uploaded 2026-10-22
	cell = 128,
	keys = {
		-- cell 4 (disciple) is unused: Toy draws the disciple atlas figure
		qi = 0, karma = 1, shop = 3, pill = 5, gift = 6, tide = 7,
		hall = 8, goal = 9, x2 = 10, auto = 11, vip = 12, hands = 13, rebirth = 14, like = 15,
		invite = 16, group = 17, palm = 18, chest = 19, altar = 20, pack1 = 21, pack2 = 22, pack3 = 23,
		sworn = 24, seat = 25, isles = 25, foundation = 26, elixir = 27, meditation = 28, echo = 29, trophy = 30,
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

-- the index key of a rarity and look: "Elder|lotus"
function Config.indexKey(name, look)
	return name .. "|" .. look
end

-- stars of one index entry pulled `count` times (0..#INDEX_STARS)
function Config.indexStars(count)
	local n = 0
	for _, at in Config.INDEX_STARS do
		if (count or 0) >= at then
			n += 1
		end
	end
	return n
end

-- every star of an index ({ [key] = pulls }) and the income multiplier they give
function Config.indexTotalStars(index)
	local n = 0
	for _, count in index or {} do
		n += Config.indexStars(count)
	end
	return n
end
-- the STAR_ROW slots that show `stars`: each slot's colour, nil for an empty slot. The band's colour
-- fills from the left over the band before (6 stars = one red, four gold), like the life beads.
function Config.starRow(stars)
	local n, row = Config.STAR_ROW, {}
	local band = math.max(1, math.ceil((stars or 0) / n))
	local lit = (stars or 0) - (band - 1) * n
	for i = 1, n do
		row[i] = i <= lit and Config.STAR_COLORS[band] or Config.STAR_COLORS[band - 1]
	end
	return row
end

-- the colour of star number `n` (1..#INDEX_STARS): gold, red or blue (Config.STAR_COLORS)
function Config.starColor(n)
	return Config.STAR_COLORS[math.clamp(math.ceil((n or 1) / Config.STAR_ROW), 1, #Config.STAR_COLORS)]
end

-- a working disciple's bonus multiplier from its own entry's stars (`count` = that entry's pulls)
function Config.discipleStarMult(count)
	return 1 + Config.DISCIPLE_STAR_BONUS * Config.indexStars(count)
end
function Config.indexMult(index)
	return 1 + Config.INDEX_STAR_BONUS * Config.indexTotalStars(index)
end

-- seconds from the Recruit press to the burst (Juice lights the platform then)
function Config.revealBurst(name)
	return Config.REVEAL.fly + (Config.rarityIndex(name) - 1) * Config.REVEAL.step
end

-- a disciple's name: its rarity's tier in its look's list (Config.DISCIPLE_NAMES)
function Config.discipleName(rarityName, look)
	local names = Config.DISCIPLE_NAMES[look] or Config.DISCIPLE_NAMES.sword
	return names[Config.rarityIndex(rarityName)] or rarityName
end

-- a disciple's bonus: its rarity's, x SHINY_MULT when Shiny
function Config.discBonus(rarityName, shiny)
	return Config.rarity(rarityName).bonus * (shiny and Config.SHINY_MULT or 1)
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
	{ "path_fields", "grove_fields", "vein3", "firelotus1", "gate", "path_dao", "mainhall3", "path_disciples", "quarters1", "firelotus2", "grove_dao", "expand1", "bamboo", "training", "lotus1" },
	{ "garden2", "grove_disciples", "mainhall4", "tea1", "spring1", "koi", "quarters2", "garden3", "tea2", "expand2", "spring2", "lotus2" },
	{ "bell", "bridge_summit", "pagoda1", "path_summit", "library", "moongate", "jade1", "grove_summit", "pagoda2", "thunder1", "mainhall5", "jade2", "thunder2", "jade3", "lotus3", "lotus4", "lotus5", "lotus6", "lotus7", "lotus8" },
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

-- Ambience pack (owner 2026-10-22 "let's do it all", research docs/research/2026-10-22_ambience_and_perf_easy_wins.md).
-- Wind (Ambience.client): workspace.GlobalWind = WIND_BASE, plus a gust every WIND_GUST_GAP s that swells to
-- WIND_GUST over WIND_GUST_RISE s and falls back as slowly; grass, Fire, smoke and every emitter with
-- WindAffectsDrag (petals, leaves, clouds, mist) lean with it. The wind bed swells with each gust.
Config.WIND_BASE = Vector3.new(5, 0, 2.5) -- studs/s
Config.WIND_GUST = 1.8 -- x WIND_BASE at a gust's peak
Config.WIND_GUST_RISE = 3 -- s up, and again down
Config.WIND_GUST_GAP = { 7, 16 } -- s of calm between two gusts
Config.WIND_BED = { id = 9114057128, vol = 0.06, gustVol = 0.14 } -- Desert Wind Whistley Light Gusts 2 (92 s loop)
-- Place reverb: under a roof (a ray up from the camera's subject hits a building within INDOOR_ROOF studs)
-- the hall reverb and a muffled outdoor bed; outside the open-air reverb.
Config.INDOOR_ROOF = 40
Config.REVERB_OUT = Enum.ReverbType.Plain
Config.REVERB_IN = Enum.ReverbType.StoneRoom
Config.INDOOR_MUFFLE = -14 -- dB on the Ambience group's high band indoors (Equalizer)
-- Music ducking: the Music group's compressor listens to the SFX group, so a gong or a hall bell lowers the
-- music under it for a moment (CompressorSoundEffect SideChain)
Config.DUCK = { threshold = -22, ratio = 3, attack = 0.04, release = 0.8 }
-- Footsteps (Footsteps.client, ported from Gladiator RNG D247): the Kenney CC0 step atlas the owner already
-- uploaded on this account; regions in seconds of the file. Steps/s = base + perSpeed x ground speed.
Config.STEPS = {
	atlas = "rbxassetid://139087376065421",
	range = 60, -- studs from the camera
	volume = 0.5,
	pitchJitter = 0.07,
	volumeJitter = 0.15,
	cadenceBase = 1.6,
	cadencePerSpeed = 0.045,
	firstStep = 0.6,
	minSpeed = 3,
	landMinAir = 0.3,
	landVolume = 1.4,
	rollOffMin = 10,
	sets = {
		stone = { { 0.0460, 0.1558 }, { 0.4518, 0.5634 }, { 0.8594, 0.9761 }, { 1.2721, 1.3865 }, { 1.6825, 1.8008 } },
		wood = { { 2.0968, 2.2147 }, { 2.5107, 2.6084 }, { 2.9044, 3.0111 }, { 3.3071, 3.4213 }, { 3.7173, 3.8346 } },
		sand = { { 4.1306, 4.3386 }, { 4.6346, 4.8483 }, { 5.1443, 5.3579 }, { 5.6539, 5.8622 }, { 6.1582, 6.3674 } },
		grass = { { 6.6634, 6.8017 }, { 7.0977, 7.2734 }, { 7.5694, 7.7484 }, { 8.0444, 8.1625 }, { 8.4585, 8.5927 } },
	},
	-- surface = { atlas set, pitch, gain }; a material not listed steps as stone
	surfaces = {
		stone = { "stone", 1, 1 },
		wood = { "wood", 1, 1 },
		grass = { "grass", 1, 1.1 },
		dirt = { "sand", 0.82, 0.9 },
	},
	materials = {
		Wood = "wood", WoodPlanks = "wood", Grass = "grass", LeafyGrass = "grass", Ground = "dirt", Mud = "dirt", Sand = "dirt",
	},
}

-- Day and night (owner 2026-10-23: light C by day, "N2: 10-4m"): DAY_SECONDS of the place's own Lighting
-- (light C, authored in Edit), then NIGHT_SECONDS of the NIGHT look (blue hour just after sunset, mock
-- docs/art/mocks/2026-10-23_night_N2_*), each change a NIGHT_FADE s blend. Every client computes the phase
-- from the server clock, so all players see the same hour with nothing replicated (DayNight.client).
Config.DAY_SECONDS = 600
Config.NIGHT_SECONDS = 240
Config.NIGHT_FADE = 20
Config.NIGHT = {
	ClockTime = 18.35,
	Brightness = 1.8,
	Ambient = Color3.fromRGB(100, 92, 130),
	OutdoorAmbient = Color3.fromRGB(140, 125, 170),
	ColorShift_Top = Color3.fromRGB(255, 165, 135),
	ExposureCompensation = 0.15,
	atmosphere = { Color = Color3.fromRGB(205, 150, 165), Decay = Color3.fromRGB(75, 85, 145), Glare = 0.1, Haze = 1.6 },
	color = { TintColor = Color3.fromRGB(235, 228, 255), Brightness = 0, Saturation = 0.05, Contrast = 0.1 },
	bloom = { Threshold = 1.3, Intensity = 0.45 },
	sunRays = { Intensity = 0.1 },
}
Config.NIGHT_BED = { id = 9112762281, vol = 0.18 } -- Crickets And Cicadas 1: the birds fade out, the crickets in

return Config
