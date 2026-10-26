-- Cultivation Tycoon: all tunable numbers live here (single source of truth).
local Config = {}

Config.PLOT_COUNT = 6
Config.PLOT_RADIUS = 280 -- distance from the hub to each peak centre (room for the sky islets, Config.ISLETS)
Config.ISLAND_RADIUS = 72 -- the home island (the heart islet); expansions add lobes to islets (ISLAND_LOBES). 66 until 2026-10-23 (owner: "more space, slightly bigger", room for the Floating Lotus Isles at its sides)
Config.HUB_RADIUS = 60 -- owner 2026-10-22: "central space can be slightly bigger" (was 36); 2026-10-23: "ranking panels are blocking some bridges, make the central a bit bigger" (was 44)

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
-- The chest arrives once the Meditation Platform stands AND the first CHEST_AFTER_RECRUITS recruits are
-- done (owner 2026-10-24: "idle chest should be given AFTER the first 3 recruits")
Config.CHEST_AFTER_RECRUITS = 3
Config.CHEST_STARTER_QI = 150
Config.CHEST_STARTER_SUMMONS = 3
Config.IDLE_CHEST_PAD = Vector3.new(24, 0, 45)
Config.AUTOSAVE = 60
Config.DATASTORE = "CultivationTycoon_v1"
Config.MOCK_DATASTORE = true -- Studio only: every Play is a new player, nothing saved (false = the _studio store)
Config.DATA_VERSION = 1 -- save record format; SaveStore.migrate lifts older records to it
Config.SAVE_LEASE = 150 -- s a session lock lives without a refresh (autosave refreshes it)
Config.SAVE_RETRIES = 3 -- DataStore attempts per load/save (backoff 1 s, 2 s)
Config.SAVE_LOCK_WAITS = 33 -- tries to take a lock held by another live session on join: 33 x 5 s outlasts SAVE_LEASE, so a
-- rejoin right after a server crash waits on the loading screen instead of being kicked (owner 2026-10-23)
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
Config.CAMERA_ZOOM = 15 -- studs: the follow camera's start distance (Roblox's 12.5 + 20%, owner 2026-10-24)
-- a fall into the sky (owner 2026-10-24: "make the respawn faster when falling"): below this world Y
-- (the land stands at ~2) the avatar is set back on its peak at once, no death (Main voidWatch)
Config.VOID_Y = -30
Config.MOVE = {
	walk = 30.8, -- studs/s (owner 2026-10-22: "way faster"; 2026-10-24 +10%, swords too: their speeds are x this)
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
-- a faster start (owner 2026-10-24: "make realm 1-2 20% faster still, and life 1 too"): in realms up to
-- START_REALMS pads, hires and recruits cost START_PRICE of their price, and so does the first rebirth
Config.START_REALMS = 2
Config.START_PRICE = 0.8
function Config.startMult(realm)
	return if realm <= Config.START_REALMS then Config.START_PRICE else 1
end
function Config.rebirthPrice(rebirths)
	local first = (rebirths or 0) == 0 and Config.START_PRICE or 1
	return math.floor((Config.REBIRTH_PRICE + Config.REBIRTH_PRICE_STEP * (rebirths or 0)) * first)
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
-- what a closed rebirth waits for (owner 2026-10-23: "should indicate clearly what's missing"):
-- nil when open; "realm", r = it opens in realm r (the realm before the next rebirth gate);
-- "build", n = this realm is the gate, n required buildings still to build
function Config.rebirthNeed(realm, rebirths, owned)
	rebirths = rebirths or 0
	if rebirths >= Config.rebirthsFor(realm + 1) then
		local r = realm + 1
		while rebirths >= Config.rebirthsFor(r + 1) and r < realm + 500 do
			r += 1
		end
		return "realm", r
	end
	local n = 0
	for _, pad in Config.PADS do
		if Config.neededForBreakthrough(pad) and Config.padOpen(pad, realm) and not owned[pad.id] then
			n += 1
		end
	end
	if n > 0 then
		return "build", n
	end
	return nil
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
	-- owner 2026-10-26 ("then the karmic shop is useless no?"): with Auto Build (D85) Hands makes it full,
	-- Mega Mansion Tycoon's whole-house Auto Build: new buildings build themselves too
	{ key = "hands", name = "Heavenly Hands", line = "Auto Build for new buildings", costs = { 5 } },
	-- owner 2026-10-23 ("karma + pads once unlocked"): bought once, the Floating Lotus Isle pads (kind
	-- "isle") are offered every life from then on, and are built with qi like any pad
	{ key = "isles", name = "Floating Isles", line = "Unlock the Lotus Isles", costs = { 12, 30 } }, -- level 2: isles 4 to 8
}
Config.HANDS_COOLDOWN = 0.4 -- s between two Heavenly Hands builds (server side)
-- Auto Build (D85, owner 2026-10-25: "long term isn't so interesting once you build the same things
-- 50 times"): Mega Mansion Tycoon's "Auto Build" pass ("build your house as you can afford each
-- purchase"), free here and only for buildings the save has built before, in any life (data.everBuilt;
-- not hires). It buys in the HUD "Next" order (guidePick), one every AUTO_BUILD_GAP s while the
-- owner is in the game; the breakthrough and the rebirth stay the player's own. AUTO_BUILD_FROM:
-- "breakthrough" = from the first breakthrough of life 1, "rebirth" = from life 2.
Config.AUTO_BUILD_FROM = "breakthrough"
Config.AUTO_BUILD_GAP = 1.2 -- s between two auto builds: a cascade to watch, not one pop
function Config.autoBuildOpen(d)
	local lives, best = d.lives or 1, d.best or 1
	if Config.AUTO_BUILD_FROM == "rebirth" then
		return lives > 1
	end
	return lives > 1 or best > 1
end
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
-- a breakthrough starts the new realm with this many seconds of the new pad income in qi (owner pick
-- 2026-10-24: 7 of 25 realm-2 leavers quit within 30 s of their first breakthrough, sect gone, qi 0 and
-- nothing affordable; AdVenture Capitalist / Egg, Inc. restart a reset with something to spend at once)
Config.BREAKTHROUGH_START_SECONDS = 60
Config.BOOST_TAG_SECONDS = 20 -- the gold realm boost ("x3") beside the income line after a breakthrough (Hud)

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
	-- vein1 just past the Fields Bridge, beside the trail (owner pick A 2026-10-24: new players stopped after
	-- that bridge, ~105 studs of empty islet before the next pad; was x = -156, z = -38)
	{ id = "vein1", name = "Spirit Vein", cost = 25, income = 2, unlock = 0, req = {}, x = -92, z = -48, district = "fields" },
	{ id = "lanterns", name = "Lantern Row", cost = 60, income = 3, unlock = 0, req = {}, x = 10, z = 30, district = "heart" },
	{ id = "mainhall1", name = "Thatched Hut", cost = 90, income = 4, unlock = 1, req = {}, x = 0, z = -30, feature = "Main Hall", district = "heart" },
	{ id = "platform", name = "Meditation Platform", cost = 40, income = 4, unlock = 1, req = {}, x = 0, z = 0, feature = "Disciples meditate", district = "heart" },
	{ id = "garden", name = "Herb Garden", cost = 300, income = 8, unlock = 3, req = {}, x = -158, z = -66, district = "fields" },
	{ id = "vein2", name = "Twin Spirit Vein", cost = 600, income = 14, unlock = 4, req = {}, x = -84, z = -54, district = "fields" },
	{ id = "mainhall2", name = "Sect Hall", cost = 900, income = 20, unlock = 4, req = { "mainhall1" }, x = 0, z = -30, feature = "Hall level 2", district = "heart" },
	{ id = "furnace", name = "Alchemy Furnace", cost = 1200, income = 10, unlock = 6, req = {}, x = 104, z = -34, feature = "2x Qi pills", district = "dao" },
	{ id = "hall", name = "Disciple Hall", cost = 120, income = 10, unlock = 3, req = {}, x = -100, z = -172, feature = "Recruit disciples", district = "disciples" },
	{ id = "gate", name = "Sect Gate", cost = 2200, income = 25, unlock = 8, req = {}, x = 0, z = 52, district = "heart" },
	{ id = "array", name = "Qi Gathering Array", cost = 350, income = 30, unlock = 5, req = {}, x = 112, z = -98, feature = "Qi orbs", district = "dao" },
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
	{ id = "pagoda2", name = "Pagoda Spire", cost = 26000, income = 200, unlock = 19, req = { "pagoda1" }, x = 58, z = -146, district = "heart", islet = "summit" }, -- its pad beside the Pagoda (on pagoda1's spot it stood inside the built Pagoda: owner 2026-10-24); the spire still stacks on pagoda1 (Builders.pagoda2)
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
	{ id = "bridge_dao", name = "Alchemy Bridge", cost = 200, income = 0, unlock = 4, req = {}, x = 52, z = -26, feature = "Opens Alchemy and Training", islet = "heart", kind = "bridge" },
	{ id = "bridge_disciples", name = "Disciple Bridge", cost = 60, income = 0, unlock = 2, req = {}, x = -114, z = -105, feature = "Opens the Disciples' islet", islet = "fields", kind = "bridge" },
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
Config.WORKER_COST = { 0.5, 1 } -- the floor: the n-th hire never costs less than this x the building's catalogue cost
-- hires are priced like the pads (D82; owner 2026-10-24: "workers are super cheap, their price doesn't
-- evolve"): the n-th costs WORKER_SECONDS[n] x a pad's price (PAD_SECONDS[realm] s of the pad income),
-- so it climbs with the income and is priced again after every buy (Main pricePads)
Config.WORKER_SECONDS = { 0.5, 1 }
Config.WORKERS = {
	garden = { name = "Farmer", x = -143, z = -63.5 },
	garden2 = { name = "Farmer", x = -142.5, z = -96.5 },
	garden3 = { name = "Farmer", x = -127.5, z = -41 },
	tea1 = { name = "Farmer", x = -108, z = -71 },
	tea2 = { name = "Farmer", x = -124, z = -80 },
	vein1 = { name = "Miner", x = -101, z = -43 },
	vein2 = { name = "Miner", x = -95, z = -57.5 },
	vein3 = { name = "Miner", x = -137, z = -75.5 },
	furnace = { name = "Alchemist", x = 111.5, z = -44.5 },
	training = { name = "Fighter", x = 112, z = -74 },
}
-- `income` = Main padRate (nil: the floor only)
function Config.workerCost(pad, n, realm, income)
	return math.floor(math.max(pad.cost * Config.WORKER_COST[n], Config.padSeconds(realm) * Config.WORKER_SECONDS[n] * (income or 0)) * Config.startMult(realm))
end

-- Guide trail (src/client/Guide.client.luau): chevrons from the feet to the next pad
Config.GUIDE_BUILT = 5 -- always shown in realm 1 until this many buildings stand
Config.GUIDE_IDLE = 20 -- afterwards only after this many seconds standing still
-- the tutorial order (owner 2026-10-23: "should push to do the recruiting building in priority";
-- 2026-10-24: "the meditation center should be also in the first things"): while one of these pads
-- is open, the HUD "Next" arrow and the guide trail lead to the first open one in this order (D82's
-- realm 1 disciple core) before the cheapest pad, and the trail stays on until the core stands
Config.GUIDE_PRIORITY = { "platform", "bridge_fields", "bridge_disciples", "hall", "bridge_dao", "array" }
-- the recruit tutorial (owner 2026-10-24): the first Disciple Hall of a save that never recruited
-- comes with FREE_RECRUITS free recruits, then the trail leads to the Meditation Platform to see the
-- newcomer, done within SEE_DISCIPLE_RANGE studs of its centre (Main income tick, Tips.client)
Config.FREE_RECRUITS = 1
Config.SEE_DISCIPLE_RANGE = 22
-- `pads`: the player's open pad parts (PadId, Cost attributes). Returns the pad to lead to, and
-- whether it is the priority one
function Config.guidePick(pads)
	local byId, best = {}, nil
	for _, p in pads do
		byId[p:GetAttribute("PadId") or ""] = p
		if not best or (p:GetAttribute("Cost") or 0) < (best:GetAttribute("Cost") or 0) then
			best = p
		end
	end
	for _, id in Config.GUIDE_PRIORITY do
		if byId[id] then
			return byId[id], true
		end
	end
	return best, false
end

-- Features
Config.PILL_INTERVAL = 180 -- seconds between pills from the Alchemy Furnace
Config.PILL_DURATION = 60 -- seconds of 2x qi
Config.ORB_INTERVAL = 20 -- seconds between qi orbs from the Qi Gathering Array
Config.ORB_MAX = 3 -- orbs waiting on a peak at most
Config.ORB_VALUE = 15 -- an orb is worth this many seconds of income
Config.ORB_TIP_TIMES = 5 -- the "Walk into it" tip stays for this many orbs (owner 2026-10-24)
Config.REBIRTH_TIP_TIMES = 2 -- the first rebirths get a "Rebirth ready!" bubble and toast (Tips.client, Hud)
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
-- Favorite gift (owner 2026-10-24: "another 10% boost ... for favoriting game", no new sim on his
-- word): FAVORITE_BONUS more qi everywhere, forever, once the player favorites the game from the
-- Sect Gift card. Out of priceRate like the group gift.
Config.FAVORITE_BONUS = 0.1
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
-- over the hub. It opens every 5 minutes (owner 2026-10-24: "every 5 minutes, like it's cool"), a
-- quarter tide cycle off each tide so it never lands on one (tide 240+600k for 90 s, altar
-- 390+300k); stand on it ALONE for
-- ALTAR_HOLD s to claim it (two or more on it pause the timer); Palm Strike pushes, a fall locks
-- you out until the round ends. Rewards are seconds of the player's own income (fair at any
-- realm, no stacking power): the winner ALTAR_WIN_SECONDS + a light aura until the next round (only
-- ALTAR_SOLO_SECONDS if nobody else came to fight), everyone else who stood on it
-- ALTAR_JOIN_SECONDS. Twice the rounds at half the prize each (were 300/60/120 every 10 min), so
-- the altar's qi per hour and the pacing sims are unchanged.
Config.ALTAR_FIRST = Config.TIDE_FIRST + Config.TIDE_INTERVAL / 4 -- s after the server starts
Config.ALTAR_INTERVAL = Config.TIDE_INTERVAL / 2
Config.ALTAR_WARN = 30 -- s of heads-up (walking from a peak to the hub takes ~20 s)
Config.ALTAR_WINDOW = 60 -- s the altar stays open without a claim
Config.ALTAR_HOLD = 20
Config.ALTAR_WIN_SECONDS = 150
Config.ALTAR_JOIN_SECONDS = 30
Config.ALTAR_SOLO_SECONDS = 60
-- The stage (owner 2026-10-23: the built Lei Tai was "so ugly"; "use the bottom of the disciple
-- island, the top needs an existing asset"; picked A of docs/art/mocks/altar_store_arenas.jpg): the
-- free Creator Store "Ancient Chinese Arena" mesh rebuilt by id on the lotus isles' rock islet
-- (Config.SKY_MESH). Its square deck: ALTAR_RADIUS = half its side; the mesh draws, an invisible
-- slab carries the players (open edges).
Config.ALTAR_HEIGHT = 36 -- studs from the hub plaza up to the deck (was 15, then 28: owner "a bit higher")
Config.ALTAR_RADIUS = 11 -- half the deck's side (was a 9 stud circle)
Config.ALTAR_SPRING_X = 15 -- the moon gates stand this far out on the plaza, either side of the cauldron (owner: "more to the center")
-- the arena mesh (asset 17609048910), in its own studs: the deck is DECK_HALF from the middle to an
-- edge and DECK_TOP above the mesh's bottom, its middle OFFSET_X from the mesh's (Studio rays 2026-10-23)
Config.ALTAR_ARENA = {
	mesh = "rbxassetid://17609048713",
	texture = "rbxassetid://17609048840",
	native = Vector3.new(85.338, 35.609, 74.559),
	deckHalf = 27.3,
	deckTop = 7.73,
	offsetX = -1.0,
	-- the four corner poles (x, z) and their tops; they stand past the islet's rim, so a little magic
	-- holds each one up (owner 2026-10-23: "the 4 corner pillars are holding into void")
	poles = { Vector2.new(-41, -24.5), Vector2.new(-41, 24.5), Vector2.new(40, -24.5), Vector2.new(40, 24.5) },
	poleTop = 34,
}
Config.ALTAR_PUSH_COOLDOWN = 2
Config.ALTAR_PUSH_REACH = 10 -- studs in front of the striker
-- owner 2026-10-23 "make sure it pushes enough": ~24 studs sideways (was ~14 at 62 for 0.22 s), with a
-- short ragdoll so the body cannot walk the knock back
Config.ALTAR_PUSH_SPEED = 80 -- knockback, studs/s (sideways), plus a hop
Config.ALTAR_PUSH_TIME = 0.3 -- s the knockback drives the body
Config.ALTAR_RAGDOLL = 0.6 -- s the struck body tumbles (PlatformStand) before it gets up
Config.ALTAR_BRAZIERS = 8 -- rim braziers: they light one by one as the holder's timer runs
-- Playtime gifts, D49 (owner 2026-10-22: "always show the next reward, reset daily, up to 2 h
-- online"): gift i is claimable after GIFT_TIMES[i] seconds of play TODAY (UTC day, summed over
-- every session; the ladder restarts at 00:00 UTC). Each pays GIFT_VALUE[i] seconds of income (no
-- tide, no pill), GIFT_SUMMONS[i] free summons (into the idle chest's summons), GIFT_PILL[i] s of
-- 2x qi and a GIFT_RARITY[i] disciple (owner: "make them interesting": an Elder at 45 min, an
-- Immortal at 2 h). Simmed 2026-10-22 (tools/sim_game.py): every player kind's lives end on the
-- same days as before, within a minute or two of play.
-- the 2 min gift (owner 2026-10-24: "add a 2m online daily qi gift, so they see it faster"): the
-- first claim comes inside the first realm, so a new player learns the ladder on day 1
Config.GIFT_TIMES = { 120, 300, 600, 1200, 1800, 2700, 3600, 5400, 7200 }
-- Red dots (server Dots.luau). The Shop's leads to its free daily gift (owner: "to clean shop one, give
-- a small free daily gift"): SHOP_FREE_SECONDS of income (no tide, no pill), once per UTC day, first
-- offered after DOT_SHOP_FIRST s of play; claiming it is what clears the dot. The Sect Gift's stays lit
-- until the group gift is claimed (owner 2026-10-24: "keep the red dot always until claimed").
Config.DOT_SHOP_FIRST = 120
Config.SHOP_FREE_SECONDS = 300
Config.GIFT_VALUE = { 120, 180, 120, 0, 300, 0, 900, 0, 0 }
Config.GIFT_SUMMONS = { 0, 0, 1, 0, 3, 0, 0, 5, 0 }
Config.GIFT_PILL = { 0, 0, 0, 300, 0, 0, 0, 0, 0 } -- seconds of 2x qi (adds to a running pill)
Config.GIFT_RARITY = { "", "", "", "", "", "Elder", "", "", "Immortal" } -- a disciple of that rarity
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
	founder = 510139726895395, -- Sect Founder: first building
	disciple = 3978846889057343, -- First Disciple
	realm2 = 0, -- Foundation Laid
	realm3 = 145003760584492, -- Golden Core
	streak7 = 4484698797029235, -- Loyal Cultivator: day 7 of the Daily Blessing
	elder = 0, -- Elder's Favour: an Elder or rarer
	realm4 = 0, -- Nascent Soul
	friends = 569770625263835, -- Sect of Friends: a friend joins you in game (not just sharing a server)
	realm8 = 0, -- Mahayana
	reborn = 0, -- Reborn: first reincarnation
}
-- Launch set (owner 2026-10-23: "only 5 free, 2 easy, 2 medium and 1 super hard", then the hard one
-- swapped for a friend joining you): founder, disciple, realm3, streak7, friends. The others stay 0.
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
	-- Flying Swords (owner 2026-10-23, picked "Hover ride, faster each level"; PS99's hoverboards copied
	-- as is): three passes, each a sword to ride (Config.SWORD_RIDE, src/server/SwordRide.luau).
	-- Owning a higher one keeps the lower ones; the HUD's sword button picks which to ride.
	{ key = "swordJade", id = 2053738987, name = "Jade Jian", line = "Fly a sword, x1.5 speed", ride = 1 },
	{ key = "swordHeavenly", id = 2052916966, name = "Heavenly Sword", line = "Fly a sword, x1.75 speed", ride = 2 },
	{ key = "swordCelestial", id = 2055358863, name = "Celestial Crystal Sword", short = "Celestial Sword", line = "Fly a sword, x2 speed", ride = 3 },
}
-- The sword ride (D76; v2 2026-10-23, owner after trying the hover ride: "i cant fly with them? When i
-- jump they got removed? this is bad"): real flight, Adopt Me's flying pets copied. The sword is welded
-- under the feet (the body drawn `lift` studs up by SwordPose.client); SwordFly.client flies it where
-- the camera looks at MOVE.walk x the tier's `speed` (rise and sink at `rise` of that), hovering when
-- idle. Jump rises, it never steps off; only the button, death / reset and the auto-off zones do: within
-- `padRadius` studs of any pad (it never buys anything) and the Heavenly Altar while a round runs.
-- The server keeps a flyer under `ceiling` (world Y: the highest Lotus Isle deck, ~64, + 60), inside
-- `bound` studs of the hub and out of the closed islets of their own peak, and snaps back anyone who
-- moves more than `speedSlack` x the tier's speed for `speedStrikes` checks. No qi.
Config.SWORD_RIDE = {
	lift = 1.2, -- studs the body is drawn over its walking height (the blade's own thickness included)
	length = 9, -- studs, every blade under the rider
	lean = 8, -- degrees the rider leans forward at the root joint
	waistLean = 6, -- and more at the waist (R15): the root lean alone measured ~1.4 degrees in Play
	padRadius = 7,
	rise = 0.6, -- share of the tier speed when rising or sinking
	ceiling = 126, -- world Y
	bound = 540, -- studs from the hub (the peaks sit PLOT_RADIUS 280 out, their islets up to ~230 more)
	speedSlack = 1.5,
	speedStrikes = 3,
	-- `bladeTopOffset`: studs from the blade's box top to where the feet stand (SwordLook BladeTop)
	tiers = {
		{ key = "swordJade", speed = 1.5, color = Color3.fromHex("8FF5D0"), trail = 4537267850, trailLife = 0.45, trailWidth = 1.6, bladeTopOffset = 0 },
		{ key = "swordHeavenly", speed = 1.75, color = Color3.fromHex("FFD34D"), trail = 6480618759, trailLife = 0.6, trailWidth = 2.1, bladeTopOffset = 0 },
		{ key = "swordCelestial", speed = 2, color = Color3.fromHex("9FD8FF"), trail = 94214927232934, trailLife = 0.75, trailWidth = 2.4, bladeTopOffset = -0.4 }, -- the crystal surface mid-blade sits under its box top (the feet stood on the glow),
	},
}
Config.SHOP_PRODUCTS = {
	-- the entry door (owner 2026-10-21, research 2026-10-22_cheap_buys): 5 Robux, once per player, an
	-- Elder plus `qiBonus` more qi forever (kept through every life); offered once by WELCOME
	{ key = "welcome", id = 3721094927, name = "Welcome Pouch", line = "Elder + 10% Qi forever", rarity = "Elder", qiBonus = 0.1, limit = 1, overLimit = "pack1" },
	{ key = "pill", id = 3721095019, name = "Instant Pill", line = "2x Qi for 60 s now" },
	{ key = "pack1", id = 3721095093, name = "Qi Pouch", line = "10 min of income", seconds = 600 },
	{ key = "pack2", id = 3721095259, name = "Qi Chest", line = "1 hour of income", seconds = 3600 },
	{ key = "pack3", id = 3721095401, name = "Qi Vault", line = "6 hours of income", seconds = 21600 },
	-- a disciple of a FIXED rarity (never random, R8); joins like a recruit (takes the weakest seat
	-- when full). Every tier from Elder up is sold (owner, D28), priced by the owner as a ladder.
	-- No buy limit (owner 2026-10-23: "let people buy the disciples as much as they want"). Bought
	-- disciples are never trimmed, so Shop.luau bounds the list and the save instead: it refuses the
	-- prompt when the newcomer could not stay (a full sect of stronger ones, or DISCIPLE_CAP bought ones
	-- already). Every item is on sale at every realm (owner 2026-10-22: "open all products to any
	-- level"); an item may still set `minRealm` (Shop.luau and Shop.client read it), none does.
	{ key = "elder", id = 3721095583, name = "Elder", line = "+150% Qi disciple", rarity = "Elder" },
	{ key = "immortal", id = 3721095692, name = "Immortal", line = "+400% Qi disciple", rarity = "Immortal" },
	{ key = "celestial", id = 3721095787, name = "Celestial", line = "+900% Qi disciple", rarity = "Celestial" },
	{ key = "dao", id = 3721095866, name = "Dao Ancestor", line = "+2,000% Qi disciple", rarity = "Dao Ancestor" },
	{ key = "emperor", id = 3721095940, name = "Heavenly Emperor", line = "+4,500% Qi disciple", rarity = "Heavenly Emperor" },
	{ key = "primordial", id = 3721095995, name = "Primordial", line = "+10,000% Qi disciple", rarity = "Primordial" },
	-- Tide Bell (owner 2026-10-23, Bee Swarm Simulator's Night Bell): a Spirit Tide starts now for the
	-- whole server, the buyer's name on the banner. Repeatable; refused while a tide runs or the altar
	-- is open or about to open (Shop.luau)
	{ key = "tidebell", id = 3721585058, name = "Tide Bell", line = "x2 Qi for the whole server" },
	-- Sect Starter Pack (owner 2026-10-23, card "B night jade"): once per player, one item granting three
	-- things: an Immortal (a bought disciple), `seconds` of income in qi (like the Qi Chest) and `pill` s
	-- of 2x Qi added to boostUntil (like the Instant Pill). Offered once by STARTER_OFFER; `short` = the
-- name on its Shop tile. `overLimit` = what a once-only item pays when bought past its `limit` (a Qi pack)
	{ key = "starter", id = 3721585167, name = "Sect Starter Pack", short = "Starter Pack", line = "Immortal + Qi Chest + 2x Qi", rarity = "Immortal", seconds = 3600, pill = 600, limit = 1, overLimit = "pack2" },
}
Config.PASS_QI_MULT = 2 -- 2x Qi pass: every qi/s, offline and gifts included
-- The Welcome Pouch offer card: once, after a big building (one with a `feature`) from `after` s of
-- play, or after any building from `late` s (owner: "after a big building after 5-10 minutes")
Config.WELCOME = { after = 300, late = 600 }
-- The Sect Starter Pack offer card: once, the first time a building with a `feature` is bought once the
-- Welcome Pouch was bought or its card was shown (declined), at least `after` s of play after that
Config.STARTER_OFFER = { after = 300 }
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
-- Weather marks (owner 2026-10-26 "index whatever you recommend", Bee Swarm Simulator's gifted marks):
-- each index entry has one mark per weather mutation (data.mutIndex), lit the first time that disciple
-- comes in that mutation. Every MARK_STEP marks pays MARK_STEP_SUMMONS free summons; all of them
-- (#RARITIES x #DISCIPLE_LOOKS x #WEATHERS) pay MARK_FULL_BONUS qi forever, kept out of prices like the index
Config.MARK_STEP = 12
Config.MARK_STEP_SUMMONS = 3
Config.MARK_FULL_BONUS = 0.1
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
-- the peak's shop pads stand only from this life on (owner 2026-10-24: a new player left 13 s after a
-- pad's Robux prompt; no paid prompt underfoot before the first rebirth). The HUD shop stays open (D64)
Config.SHOP_PADS_FROM_LIFE = 2
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
-- D44 (kept for the older sims only; pads are priced by PAD_SECONDS below since 2026-10-24)
Config.PRICE_FLOOR_S = 20
Config.PRICE_FLOOR_FROM_LIFE = 2
-- Pads you wait for (owner pick Plan 1 + "your numbers" 2026-10-24; research
-- docs/research/2026-10-24_core_loop_after_10.md, DevForum "price = income x seconds per button"):
-- each open pad costs PAD_SECONDS[realm] seconds of the pad income (Main padRate: the away rate
-- without the 2x Qi pass, the Welcome Pouch, Robux disciples or the rebirth boost; free disciples
-- count), times the rebirth boost the realm needs (Config.rebirthsFor), so only rebirths past that
-- make a realm faster. Prices are set when a pad opens and again after every buy, so a recruit, orbs
-- or a pill in between bring the next pad sooner. Felt waits (qisim, orbs and pills in): realm 1
-- ~10 s, 2-3 ~30 s, 4-7 1-4 min, 8-10 14-25 min (owner: "realm 8-10 may be 20-30m of wait per pad
-- for a full f2p"). Realms past the table use its last entry.
Config.PAD_SECONDS = { 5, 30, 30, 40, 110, 220, 800, 5000, 6000, 7000 } -- realms 2-7 trimmed ~25% (owner pick 2026-10-24: the Main Hall last and paid hires had slowed the climb ~40%); realms 3-4 40/65 -> 30/40 (owner pick 2026-10-25: live rebirth 2 at 62 min in one sitting, target ~35; qisim onesitslow 61 -> 35, long game unchanged)
-- the open pads spread +-PAD_SPREAD around that by catalogue cost (the cheap ones come sooner)
Config.PAD_SPREAD = 0.3
-- the Main Hall is the big step of a realm (owner 2026-10-24: "the main hall price between steps should
-- be way higher, it should always be the last building to get"; the tycoon standard: the main
-- building's next floor is the priciest button of its tier): level lv costs MAINHALL_SECONDS[lv] x a
-- pad's price, above every other open pad (at most 1 + PAD_SPREAD)
Config.MAINHALL_SECONDS = { 1.5, 2, 2.5, 3, 3.5 }
Config.MAINHALL_ABOVE = 1.25 -- and at least this x the dearest other open pad (Main pricePads)
-- a breakthrough keeps the disciple core (owner 2026-10-24: "breakthrough does remove most building
-- but the base of disciples in the center and recruit building + bridges + orb building")
Config.PAD_KEEP = { platform = true, hall = true, quarters1 = true, quarters2 = true, array = true, bridge_fields = true, bridge_dao = true, bridge_disciples = true, bridge_summit = true, lotus1 = true, lotus2 = true, lotus3 = true, lotus4 = true, lotus5 = true, lotus6 = true, lotus7 = true, lotus8 = true }
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
-- Heavenly Weather (owner pick B 2026-10-25, mock docs/art/mocks/2026-10-25_live_events.html; copy Grow a
-- Garden's weather + crop mutations): a server-wide sky event. Every recruit, chest or gift summon rolled
-- while one runs has `chance` to come out with its mutation: x`mult` its bonus (Shiny stacks) and its own
-- index mark (data.mutIndex). The mutation sits on the disciple (data.discMut, "" = none), like Shiny.
-- Paid random item rule (R8): the odds sheet shows every mutation's chance. Bought disciples never mutate.
-- A slot opens every WEATHER_INTERVAL s, half a tide cycle off the tides (tide 240+600k for 90 s, weather
-- 540+600k), and rolls one weather by `weight` (shares of the slots, summing to 1): rain most slots,
-- thunder ~1 in 4, blood moon ~1 in 9, starfall ~1 in 20 (~3 h). `duration` s each, ending before the
-- next altar round (690+600k).
Config.WEATHER_FIRST = Config.TIDE_FIRST + Config.TIDE_INTERVAL / 2 -- s after the server starts
Config.WEATHER_INTERVAL = Config.TIDE_INTERVAL
Config.WEATHER_WARN = 20 -- s of heads-up toast before a slot
Config.WEATHERS = {
	{ key = "rain", name = "Spirit Rain", mut = "Dewy", chance = 0.2, mult = 2, weight = 0.62, duration = 150, color = Color3.fromRGB(111, 183, 255), tint = Color3.fromRGB(64, 156, 255), motion = "ebb" },
	{ key = "thunder", name = "Thunder Tribulation", mut = "Thunderborn", chance = 0.1, mult = 4, weight = 0.22, duration = 120, color = Color3.fromRGB(199, 155, 255), tint = Color3.fromRGB(255, 226, 52), motion = "spark" },
	{ key = "blood", name = "Blood Moon", mut = "Bloodlit", chance = 0.1, mult = 5, weight = 0.11, duration = 150, color = Color3.fromRGB(255, 93, 108), tint = Color3.fromRGB(226, 24, 48), motion = "beat" },
	{ key = "star", name = "Starfall", mut = "Starforged", chance = 0.05, mult = 10, weight = 0.05, duration = 120, color = Color3.fromRGB(159, 243, 255), tint = Color3.fromRGB(255, 110, 220), motion = "rainbow" },
}
-- a save that never saw weather (data.weatherSeen nil) gets a Spirit Rain for its server at
-- WEATHER_NEWCOMER_AT s of its session, unless weather is on or a slot opens within WEATHER_NEWCOMER_GAP s
-- (live 2026-10-25: 18% quit while recruiting at ~3.6 min); at most one such rain a WEATHER_NEWCOMER_GAP
Config.WEATHER_NEWCOMER_AT = 220
Config.WEATHER_NEWCOMER_GAP = 120

function Config.weather(key)
	for _, w in Config.WEATHERS do
		if w.key == key then
			return w
		end
	end
	return nil
end

-- A mutation's own look (owner 2026-10-26 "B but with a different per type": the figure and its card
-- washed in the mutation's colour, each moving its own way so all four tell apart on a phone).
-- `tint` is the mutation's colour (not the sky's `color`: lavender and pale cyan vanished on purple and
-- white robes, Studio check 2026-10-26); `motion` how it moves. At time `t` (s) returns the colour now
-- and a level 0..1 (how strong the wash is now):
--   ebb      Dewy: rises and falls slowly, like water
--   spark    Thunderborn: flickers on and off fast, like a spark
--   beat     Bloodlit: a double heartbeat every 1.2 s
--   rainbow  Starforged: cycles through the rainbow (Pet Simulator 99's Rainbow pets)
function Config.mutLook(w, t)
	if w.motion == "rainbow" then
		return Color3.fromHSV((t * 0.3) % 1, 0.7, 1), 0.8
	elseif w.motion == "spark" then
		local n = math.noise(t * 7, 0.5) -- -1..1, smooth but quick
		-- peaks lower than the others: at full strength the face and robe vanished into a gold statue
		return w.tint:Lerp(Color3.new(1, 1, 1), n > 0.25 and 0.3 or 0), n > -0.15 and 0.67 or 0.2
	elseif w.motion == "beat" then
		local p = (t % 1.2) / 1.2
		local beat = math.max(math.exp(-((p - 0.08) / 0.05) ^ 2), 0.7 * math.exp(-((p - 0.3) / 0.05) ^ 2))
		return w.tint, 0.3 + 0.7 * beat
	end
	return w.tint, 0.5 + 0.5 * math.sin(t * math.pi * 2 / 3)
end

-- the weather whose mutation is `mut` (its name, "Dewy"), nil for none
function Config.mutation(mut)
	if not mut or mut == "" then
		return nil
	end
	for _, w in Config.WEATHERS do
		if w.mut == mut then
			return w
		end
	end
	return nil
end

-- Building palettes cycle with the realm.
Config.PALETTES = {
	{ stone = Color3.fromRGB(150, 150, 145), wood = Color3.fromRGB(120, 80, 50), roof = Color3.fromRGB(90, 60, 45), trim = Color3.fromRGB(190, 170, 120), glow = Color3.fromRGB(120, 220, 255) },
	{ stone = Color3.fromRGB(200, 225, 210), wood = Color3.fromRGB(140, 40, 40), roof = Color3.fromRGB(40, 140, 100), trim = Color3.fromRGB(230, 230, 220), glow = Color3.fromRGB(120, 255, 180) },
	{ stone = Color3.fromRGB(235, 225, 200), wood = Color3.fromRGB(110, 30, 30), roof = Color3.fromRGB(200, 150, 40), trim = Color3.fromRGB(255, 220, 120), glow = Color3.fromRGB(255, 210, 110) },
}

-- Hub rankings (src/server/Ranks.luau): one OrderedDataStore per board (+ one per country)
Config.RANKS = {
	sects = { store = "Ranks1", title = "Greatest Sects", order = 2 }, -- realms climbed * 1000 + lives
	qi = { store = "RanksQi2", title = "Richest Qi", order = 1 }, -- best steady qi/s ever (no pill, tide, friends; RanksQi1 counted them)
	week = { store = "RanksWeek1", title = "This Week", order = 3, weekly = true }, -- seconds played this week
}
-- the week number (weeks start Monday 00:00 UTC; day 0 = 1970-01-01, a Thursday)
function Config.rankWeek(t)
	return math.floor((math.floor((t or os.time()) / 86400) + 3) / 7)
end
Config.RANK_TOP = 10 -- rows on the hub wall
Config.RANK_READ = 100 -- rows read per board and listed on the Rankings screen (GetSortedAsync max)
Config.RANK_FRIENDS = 50 -- friends looked up for the Friends tab (one GetAsync each, cached RANK_REFRESH s)
Config.RANK_WALL_GAP = 5 -- the hub gap (between bridges 5 and 6) where the wall stands
Config.RANK_WALL_R = 52 -- studs from the hub centre: the wall (lions at its ends) clears both bridge walks by 3 studs and its back lanterns stand on the rim (54 left their legs over the drop; 25 on the 44 hub stood on the walks)
-- HUD teleports (owner 2026-10-22: "MY BASE" and "RANKINGS" at the top of the HUD): seconds between two
-- jumps, and how far in front of the ranking wall you land (facing it)
Config.TELEPORT_COOLDOWN = 2 -- s between two teleports on the client (the server allows half: Main)
Config.TELEPORT_VEIL = 0.35 -- s the server waits before the move: the Hud's jade wipe closes in that time
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
-- The top 3 of Greatest Sects as avatars on a podium across the hub from the ranking wall (owner 2026-10-23:
-- "a podium of top 3 with their aura and beads", "a bit larger", "on the opposite border"), each its own
-- avatar (GetHumanoidDescriptionFromUserId, rebuilt only when a place changes hands) playing the idle,
-- in its realm aura and life beads (PlayerAura); an away player's realm is read from its save once per
-- RANK_REFRESH. r = studs from the hub centre (the dais clears both bridge walks by 5+); width, depth = a plinth's; scale = the avatars';
-- glyph = the ground glyph's size over a player's
Config.RANK_PODIUM = { r = 40, width = 7, depth = 5, scale = 1.4, glyph = 0.45 }
-- The hub's ride shop (HubShop.luau, owner 2026-10-24): the gap that holds it, and the Tide Bell's
-- (both stand HUB_SHOP_R from the centre, facing the plaza, clear of the bridge walks)
Config.HUB_SHOP_GAP = 1
Config.HUB_BELL_GAP = 3
Config.HUB_SHOP_R = 38.5
Config.RANK_REFRESH = 300 -- s between store reads (DevForum: a global board needs no faster)
Config.RANK_WRITE_EVERY = 60 -- s between write rounds
Config.RANK_WRITE_GAP = 300 -- s between two saves of one player's scores (leaving saves at once)
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

-- Sect Styles (research docs/research/2026-10-25_rebirth_new_looks.md, mocks
-- docs/art/mocks/2026-10-25_sect_style_*.png; Build Your Backrooms biomes + Clash of Clans levels):
-- every rebirth up to 10, then every 5th, unlocks a whole-sect look so a rebuild never repeats. A style
-- replaces the D53 grade colours (`map`, same keys as SKIN_GRADES), puts ornaments on every top roof
-- ridge (`orn`, SectStyle.luau) and drifts one ambience emitter over the peak (`fx`). The newest is
-- worn on unlock; the Styles page (Reincarnation.client) picks any unlocked one, or Classic (the D53
-- ladder). `swatch` = the tile and the trim on its page tile.
Config.SECT_STYLES = {
	{ id = "snow", ground = { Enum.Material.Snow, hex("F2F6FA") }, name = "Snow Lotus", rebirth = 1, orn = "crystal", ornColor = hex("A8E4FF"), swatch = { hex("CFE3F2"), hex("A8E4FF") },
		-- snow on a winter temple: white roofs over deep lacquer, so the snow reads (pale-on-pale washed out)
		map = { tile = { hex("F4F8FC"), Enum.Material.Snow }, tileDark = hex("C6D6E4"), vermilion = hex("7E2A30"), plaster = hex("F2F4F7"), gold = hex("CFE6FF"), stone = { hex("E3ECF4"), Enum.Material.Marble }, stoneLight = hex("F2F6FA"), timber = hex("4A3A3A"), timberDark = hex("2E2426"), jade = hex("A8E4FF") },
		fx = { color = hex("FFFFFF"), accel = Vector3.new(0.4, -2, 0), size = 0.5 } },
	{ id = "volcano", ground = { Enum.Material.CrackedLava, hex("A8401C") }, name = "Volcano Forge", rebirth = 2, orn = "forge", ornColor = hex("FF6A1A"), swatch = { hex("2F2A2A"), hex("FF6A1A") },
		-- vermilion 4A1610: 7A1F14 read bright red under the place lighting
		map = { tile = hex("2F2A2A"), tileDark = hex("1E1A1A"), vermilion = hex("4A1610"), plaster = { hex("3A3330"), Enum.Material.Basalt }, gold = hex("FF8A2A"), stone = { hex("3B3634"), Enum.Material.Basalt }, stoneLight = hex("4A4441"), timber = hex("2A1E19"), timberDark = hex("1A120E") },
		fx = { color = hex("FF8A2A"), accel = Vector3.new(0, 2.5, 0), size = 0.4, light = 1 } },
	{ id = "sakura", ground = { Enum.Material.Salt, hex("E9B8C8") }, name = "Sakura Spring", rebirth = 3, orn = "blossom", ornColor = hex("FFD6E4"), swatch = { hex("E79AB4"), hex("FFFFFF") },
		map = { tile = hex("E79AB4"), tileDark = hex("C27390"), vermilion = hex("F4EDE6"), plaster = hex("FFFFFF"), gold = hex("F2C9A0"), timber = hex("7A4E3A") },
		fx = { color = hex("FFC4D8"), accel = Vector3.new(0.8, -1.2, 0), size = 0.5 } },
	{ id = "moon", ground = { Enum.Material.Glacier, hex("C9D6EA") }, name = "Moon Palace", rebirth = 4, orn = "crescent", ornColor = hex("E8EEF8"), swatch = { hex("2D3E73"), hex("E8EEF8") },
		map = { tile = hex("2D3E73"), tileDark = hex("1E2A52"), vermilion = hex("E9EEF6"), plaster = { hex("FFFFFF"), Enum.Material.Marble }, gold = hex("D8E2F0"), stone = { hex("E4E9F1"), Enum.Material.Marble }, stoneLight = hex("F2F5F9"), timber = hex("5A6788"), timberDark = hex("323C58") },
		fx = { color = hex("CFE0FF"), accel = Vector3.new(0, 0.4, 0), size = 0.6 } },
	{ id = "thunder", ground = { Enum.Material.Slate, hex("6E7890") }, name = "Thunder Peak", rebirth = 5, orn = "rod", ornColor = hex("B9A8FF"), swatch = { hex("3A3550"), hex("F5D04A") },
		map = { tile = hex("3A3550"), tileDark = hex("272338"), vermilion = hex("4B3C7A"), plaster = { hex("8B8FA0"), Enum.Material.Slate }, gold = hex("F5D04A"), stone = { hex("5C606B"), Enum.Material.Slate }, stoneLight = hex("6E727D") },
		fx = { color = hex("C8B8FF"), accel = Vector3.new(0, 0, 0), size = 0.5, light = 1 } },
	{ id = "dragon", ground = { Enum.Material.Pavement, hex("EEEDE6") }, name = "Dragon Emperor", rebirth = 6, orn = "dragon", ornColor = hex("FFE27A"), swatch = { hex("E0A82E"), hex("A3221B") },
		-- the Forbidden City: imperial yellow glaze, red walls and columns, white marble terraces
		map = { tile = hex("E8B030"), tileDark = hex("B07E18"), vermilion = hex("A3221B"), plaster = hex("B8352B"), gold = { hex("FFD24A"), Enum.Material.Foil }, stone = { hex("F2F2EE"), Enum.Material.Marble }, stoneLight = hex("FFFFFF") },
		fx = { color = hex("FFE07A"), accel = Vector3.new(0, 0.6, 0), size = 0.5 } },
	{ id = "maple", ground = { Enum.Material.Mud, hex("E0922E") }, name = "Autumn Maple", rebirth = 7, orn = "pearl", ornColor = hex("FFB347"), swatch = { hex("C2452D"), hex("FFB347") },
		map = { tile = hex("C2452D"), tileDark = hex("8E2E1E"), vermilion = hex("6B3A22"), plaster = hex("F5E6CC"), gold = hex("FFB347"), timber = hex("4A2C1C") }, -- jade left alone: it is the ponds too (Play check 2026-10-25)
		fx = { color = hex("FF9A3C"), accel = Vector3.new(0.6, -1, 0), size = 0.6 } },
	{ id = "abyss", ground = { Enum.Material.Asphalt, hex("2F6B62") }, name = "Abyssal Jade", rebirth = 8, orn = "pearl", ornColor = hex("7FFFE0"), swatch = { hex("1F5F5B"), hex("7FFFE0") },
		map = { tile = hex("1F5F5B"), tileDark = hex("143F3C"), vermilion = hex("2E7F74"), plaster = { hex("CFEDE6"), Enum.Material.Marble }, gold = hex("9FE8D6"), stone = { hex("8FB8B0"), Enum.Material.Marble }, stoneLight = hex("B4D6CF"), timber = hex("23463F"), timberDark = hex("142B27") },
		fx = { color = hex("7FFFE0"), accel = Vector3.new(0, 0.8, 0), size = 0.5, light = 1 } },
	{ id = "phoenix", ground = { Enum.Material.Sandstone, hex("9E2A22") }, name = "Phoenix Flame", rebirth = 9, orn = "feather", ornColor = hex("FFC24A"), swatch = { hex("B3202A"), hex("FFC24A") },
		map = { tile = hex("B3202A"), tileDark = hex("7E141B"), vermilion = hex("E05A1F"), plaster = hex("FFF1D6"), gold = { hex("FFC24A"), Enum.Material.Foil }, stone = hex("E8D2B0") },
		fx = { color = hex("FFB04A"), accel = Vector3.new(0, 2, 0), size = 0.5, light = 1 } },
	{ id = "cloud", ground = { Enum.Material.Ice, hex("F7F9FC") }, name = "Heavenly Cloud", rebirth = 10, orn = "pearl", ornColor = hex("FFFFFF"), swatch = { hex("F2F6FA"), hex("FFD36A") },
		map = { tile = hex("FFE7A0"), tileDark = hex("E0C070"), vermilion = hex("FFFFFF"), plaster = { hex("FFFFFF"), Enum.Material.Marble }, gold = { hex("FFD36A"), Enum.Material.Foil }, stone = { hex("F4F6F8"), Enum.Material.Marble }, stoneLight = hex("FFFFFF"), timber = hex("E8DCC4"), timberDark = hex("B8A888") },
		fx = { color = hex("FFFFFF"), accel = Vector3.new(0.3, 0.2, 0), size = 1.2 } },
	{ id = "starfall", ground = { Enum.Material.Basalt, hex("1E2240") }, name = "Starfall", rebirth = 15, orn = "star", ornColor = hex("FFFFFF"), swatch = { hex("12142A"), hex("D4DCEE") },
		-- night itself: near-black roofs, dark violet walls, silver trim (Moon Palace is the blue-and-white one)
		map = { tile = hex("12142A"), tileDark = hex("0A0C1C"), vermilion = hex("2A1F4A"), plaster = hex("1E2240"), gold = { hex("D4DCEE"), Enum.Material.Metal }, stone = hex("2A2E48"), stoneLight = hex("3A3F5E"), timber = hex("181A30"), timberDark = hex("0E1020") },
		fx = { color = hex("FFFFFF"), accel = Vector3.new(0, -0.6, 0), size = 0.5, light = 1 } },
	{ id = "goldlotus", ground = { Enum.Material.Limestone, hex("E8C860") }, name = "Golden Lotus", rebirth = 20, orn = "dragon", ornColor = hex("FFE27A"), swatch = { hex("FFD24A"), hex("FFFFFF") },
		-- gold set in white jade, so the shapes read (gold on gold melted together)
		map = { tile = { hex("FFD24A"), Enum.Material.Foil }, tileDark = hex("C8962E"), vermilion = { hex("F2C14E"), Enum.Material.Foil }, plaster = { hex("FFFFFF"), Enum.Material.Marble }, gold = hex("FFF6D8"), stone = { hex("F4F4F0"), Enum.Material.Marble }, stoneLight = hex("FFFFFF"), timber = hex("E8E2D4"), timberDark = hex("B8AE98") },
		fx = { color = hex("FFE07A"), accel = Vector3.new(0, 0.8, 0), size = 0.6, light = 1 } },
}
-- `ground` = the island lawn in that style: a terrain material no other ground uses, and its colour
-- (Terrain colours are per material for the whole place, so each style owns one material)
function Config.sectStyle(id)
	for _, st in Config.SECT_STYLES do
		if st.id == id then
			return st
		end
	end
	return nil
end
-- the style rebirth number `n` unlocks (nil: none at that rebirth)
function Config.styleAt(n)
	for _, st in Config.SECT_STYLES do
		if st.rebirth == n then
			return st
		end
	end
	return nil
end
-- the next style still locked after `rebirths` rebirths (nil: all collected)
function Config.nextStyle(rebirths)
	for _, st in Config.SECT_STYLES do
		if st.rebirth > (rebirths or 0) then
			return st
		end
	end
	return nil
end
-- the style a sect wears: its pick if unlocked ("classic" = the D53 ladder), else the newest unlocked
function Config.wornStyle(choice, rebirths)
	rebirths = rebirths or 0
	if choice == "classic" then
		return nil
	end
	local pick = choice and Config.sectStyle(choice)
	if pick and pick.rebirth <= rebirths then
		return pick
	end
	local newest
	for _, st in Config.SECT_STYLES do
		if st.rebirth <= rebirths then
			newest = st
		end
	end
	return newest
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
	return math.floor(Config.RECRUIT_BASE * Config.costMult(realm) * Config.RECRUIT_POW ^ recruits * Config.startMult(realm))
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

-- the rebirth's leftover recruits (owner pick 2026-10-25, the simulators' Buy Max): qi resets at a
-- rebirth, so the Rebirth button first spends what is over the price on recruits, biggest press
-- first. Returns the presses ({ n, ... }) and how many recruits they make. qisim: players spent ~3 min
-- tapping x1 / x10 here before the first rebirth (live rebirth 1 at 10.2 min, realm 2 done at ~7).
Config.LEFTOVER_MAX_PRESSES = 40
function Config.leftoverRecruits(realm, recruits, spare)
	local presses, total = {}, 0
	for i = #Config.RECRUIT_COUNTS, 1, -1 do
		local n = Config.RECRUIT_COUNTS[i]
		while #presses < Config.LEFTOVER_MAX_PRESSES do
			local cost = Config.recruitBatchCost(realm, recruits, n)
			if cost > spare then
				break
			end
			spare -= cost
			recruits += Config.recruitStep(n)
			total += n
			table.insert(presses, n)
		end
	end
	return presses, total
end

-- how far one press of `n` recruits moves data.realmRecruits: one per recruit
function Config.recruitStep(n)
	return n
end

-- the price of the `rank`-th cheapest (catalogue cost) of `n` open pads, `income` = Main padRate
function Config.padPrice(pad, realm, income, rank, n)
	local f = n > 1 and (1 - Config.PAD_SPREAD) + 2 * Config.PAD_SPREAD * (rank - 1) / (n - 1) or 1
	local lv = tonumber(pad.id:match("^mainhall(%d)$"))
	if lv then
		f = Config.MAINHALL_SECONDS[lv] -- the Main Hall: priced above the spread
	end
	return math.floor(math.max(pad.cost, Config.padSeconds(realm) * f * income) * Config.startMult(realm))
end

-- a pad's price in seconds of the pad income (PAD_SECONDS x the rebirth boost the realm needs)
function Config.padSeconds(realm)
	return Config.PAD_SECONDS[math.min(realm, #Config.PAD_SECONDS)] * Config.rebirthMult(Config.rebirthsFor(realm))
end

-- what a breakthrough leaves standing of `owned` (PAD_KEEP)
function Config.keptAtBreakthrough(owned)
	local kept = {}
	for id in owned do
		if Config.PAD_KEEP[id] then
			kept[id] = true
		end
	end
	return kept
end

-- the old D44 price (the older sims): cost x costMult, or PRICE_FLOOR_S s of `income` from life 2
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
	image = "rbxassetid://117949315010532", -- 35 icons (trophy, bell, three swords added), uploaded 2026-10-23
	cell = 128,
	keys = {
		-- cell 4 (disciple) is unused: Toy draws the disciple atlas figure
		qi = 0, karma = 1, shop = 3, pill = 5, gift = 6, tide = 7,
		hall = 8, goal = 9, x2 = 10, auto = 11, vip = 12, hands = 13, rebirth = 14, like = 15,
		invite = 16, group = 17, palm = 18, chest = 19, altar = 20, pack1 = 21, pack2 = 22, pack3 = 23,
		sworn = 24, seat = 25, isles = 25, foundation = 26, elixir = 27, meditation = 28, echo = 29, trophy = 30,
		bag = 3, -- the shop's qi pouch
		tidebell = 31, -- the Tide Bell's own bell (docs/art/mocks/icons.js, key "bell")
		-- the three Flying Swords (D76); a sword key missing here falls back to Toy's drawn glyph
		swordJade = 32, swordHeavenly = 33, swordCelestial = 34,
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
-- `marks` = the weather marks found (Config.markCount); every one of them adds MARK_FULL_BONUS
function Config.indexMult(index, marks)
	local full = (marks or 0) >= Config.markTotal() and 1 + Config.MARK_FULL_BONUS or 1
	return (1 + Config.INDEX_STAR_BONUS * Config.indexTotalStars(index)) * full
end

-- weather marks: every rarity x look x weather mutation, and how many of a data.mutIndex are lit
function Config.markTotal()
	return #Config.RARITIES * #Config.DISCIPLE_LOOKS * #Config.WEATHERS
end
function Config.markCount(mutIndex)
	local n = 0
	for key in mutIndex or {} do
		local mut = string.match(key, "#(.+)$")
		if Config.mutation(mut) then
			n += 1
		end
	end
	return n
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

-- a disciple's bonus: its rarity's, x SHINY_MULT when Shiny, x its weather mutation's mult (`mut` = "Dewy")
function Config.discBonus(rarityName, shiny, mut)
	local w = Config.mutation(mut)
	return Config.rarity(rarityName).bonus * (shiny and Config.SHINY_MULT or 1) * (w and w.mult or 1)
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
	{ "path_fields", "grove_fields", "vein3", "firelotus1", "gate", "path_dao", "mainhall3", "path_disciples", "quarters1", "grove_dao", "expand1", "lotus1" },
	-- Fire Lotus 2, Bamboo and Training Ground came from realm 2 (owner pick 2026-10-25: first rebirth
	-- ~6-7 min; realm 2 is walk-bound, qisim one sitting 9.8 -> 6.4 min with the leftover recruits)
	{ "firelotus2", "bamboo", "training", "garden2", "grove_disciples", "mainhall4", "tea1", "spring1", "koi", "quarters2", "garden3", "tea2", "expand2", "spring2", "lotus2" },
	{ "bell", "bridge_summit", "pagoda1", "path_summit", "library", "moongate", "jade1", "grove_summit", "pagoda2", "thunder1", "mainhall5", "jade2", "thunder2", "jade3", "lotus3", "lotus4", "lotus5", "lotus6", "lotus7", "lotus8" },
}
local padRealm = {}
for r, ids in Config.REALM_PADS do
	for _, id in ids do
		padRealm[id] = r
	end
end
-- paths and groves wait for DECOR_FROM_REALM (owner pick 2026-10-24: "make realm 1-2 20% faster still,
-- and life 1 too": the start is walk-bound, so it has fewer optional pads to walk to; qisim -17% life 1)
Config.DECOR_FROM_REALM = 3
for _, pad in Config.PADS do -- a pad left out of REALM_PADS opens with the last step, never silently in realm 1
	padRealm[pad.id] = padRealm[pad.id] or #Config.REALM_PADS
	if pad.kind == "path" or pad.kind == "grove" then
		padRealm[pad.id] = math.max(padRealm[pad.id], Config.DECOR_FROM_REALM)
	end
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
-- Owner 2026-10-24: 5 min day and 5 min night ("night is cool").
Config.DAY_SECONDS = 300
Config.NIGHT_SECONDS = 300
Config.NIGHT_FADE = 20
Config.NIGHT = {
	ClockTime = 18.35,
	Brightness = 1.8,
	Ambient = Color3.fromRGB(100, 92, 130),
	OutdoorAmbient = Color3.fromRGB(140, 125, 170),
	ColorShift_Top = Color3.fromRGB(255, 165, 135),
	ExposureCompensation = 0.15,
	atmosphere = { Color = Color3.fromRGB(205, 150, 165), Decay = Color3.fromRGB(75, 85, 145), Glare = 0.1, Haze = 0 },
	color = { TintColor = Color3.fromRGB(235, 228, 255), Brightness = 0, Saturation = 0.05, Contrast = 0.1 },
	bloom = { Threshold = 1.3, Intensity = 0.45 },
	sunRays = { Intensity = 0.1 },
}
-- Sky all round (owner pick A 2026-10-23, mocks docs/art/mocks/2026-10-23_skybox_*): the painted sky pack is flat
-- blue below the horizon, so the side faces are re-authored with their painted top half mirrored underneath and Dn
-- is the Up face mirrored: the sky reads like a still lake reflecting it. Any Atmosphere Haze above 0 paints the
-- whole skybox below the horizon flat teal (blue at night) and hides the mirror, so Haze is 0 by day and night;
-- Density still fades far parts. Main.server sets these at boot (the place keeps the originals, as does
-- ServerStorage.Sky_Original). Faces were cut from the original pack (top halves kept, Up flipped for Dn).
Config.SKY = {
	faces = { Bk = 122552090947091, Dn = 74440462776208, Ft = 74166367579610, Lf = 74262479252409, Rt = 116565553366584 },
	atmosphere = { Density = 0.12, Offset = 0, Haze = 0 },
}
Config.NIGHT_BED = { id = 9112762281, vol = 0.18 } -- Crickets And Cicadas 1: the birds fade out, the crickets in

-- Sect Missions (2026-10-25, copies Pet Simulator 99 ranks: https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99)).
-- A few missions at a time, one from each group (MISSION_GROUPS), a done one pays its stars and a new one
-- takes its slot. Stars fill the rank's reward path (MISSION_RANKS): each reward is paid when the stars
-- reach its `at`, the last one ranks you up. Slots per rank and star tiers follow PS99 (2 slots at rank 1,
-- 3 at ranks 2-4, 4 from rank 5; 2-star missions from rank 1's 3rd mission, 3-star from rank 2, 4-star
-- from rank 5). Rank 1 is a fixed starter line (MISSION_STARTER) aimed at what goes with players coming
-- back (live analysis 2026-10-25: realm 2, the Daily Blessing, the first rebirth). Missions are kept for
-- the whole account (breakthrough and rebirth keep them). Rewards are the timed gifts' kinds: qiSec
-- seconds of income (no tide, no pill), free summons (into the idle chest's summons), pill seconds of
-- 2x qi, a disciple of `rarity`.
Config.MISSIONS_ON = true
Config.MISSION_DAILY_ON = true -- the 3 daily missions and their chest (picks B, C)
Config.MISSION_SLOTS = { 2, 3, 3, 3, 4 } -- by rank, the last entry for every rank after
Config.MISSION_TIER_AT = { [2] = { rank = 1, done = 2 }, [3] = { rank = 2, done = 0 }, [4] = { rank = 5, done = 0 } } -- a tier opens at that rank after `done` missions in it
Config.MISSION_RANKS = {
	{ name = "Sweeper", rewards = { { at = 2, qiSec = 60 }, { at = 4, summons = 1 }, { at = 7, pill = 120 }, { at = 10, qiSec = 120 }, { at = 13, summons = 2, rarity = "Core Disciple" } } },
	{ name = "Novice", rewards = { { at = 3, qiSec = 90 }, { at = 7, summons = 1 }, { at = 11, pill = 180 }, { at = 16, qiSec = 150 }, { at = 20, summons = 2 }, { at = 25, summons = 2, rarity = "Core Disciple" } } },
	{ name = "Acolyte", rewards = { { at = 4, qiSec = 120 }, { at = 9, summons = 2 }, { at = 15, pill = 300 }, { at = 21, qiSec = 180 }, { at = 26, summons = 2 }, { at = 32, summons = 3, rarity = "Elder" } } },
	{ name = "Adept", rewards = { { at = 6, qiSec = 150 }, { at = 13, summons = 2 }, { at = 21, pill = 300 }, { at = 29, qiSec = 240 }, { at = 37, summons = 3 }, { at = 46, summons = 3, rarity = "Elder" } } },
	{ name = "Senior", rewards = { { at = 8, qiSec = 180 }, { at = 18, summons = 2 }, { at = 28, pill = 420 }, { at = 39, qiSec = 300 }, { at = 50, summons = 3 }, { at = 63, summons = 4, rarity = "Immortal" } } },
	{ name = "Deacon", rewards = { { at = 11, qiSec = 240 }, { at = 25, summons = 3 }, { at = 40, pill = 600 }, { at = 55, qiSec = 360 }, { at = 71, summons = 4 }, { at = 89, summons = 4, rarity = "Elder" } } },
	{ name = "Steward", rewards = { { at = 16, qiSec = 300 }, { at = 36, summons = 3 }, { at = 58, pill = 600 }, { at = 80, qiSec = 480 }, { at = 104, summons = 5 }, { at = 131, summons = 5, rarity = "Immortal" } } },
	{ name = "Hall Master", rewards = { { at = 22, qiSec = 360 }, { at = 50, summons = 4 }, { at = 80, pill = 900 }, { at = 112, qiSec = 600 }, { at = 146, summons = 5 }, { at = 182, summons = 6, rarity = "Immortal" } } },
	{ name = "Protector", rewards = { { at = 32, qiSec = 480 }, { at = 70, summons = 4 }, { at = 113, pill = 900 }, { at = 160, qiSec = 720 }, { at = 208, summons = 6 }, { at = 259, summons = 6, rarity = "Celestial" } } },
	{ name = "Sect Master", rewards = { { at = 40, qiSec = 600 }, { at = 88, summons = 5 }, { at = 140, pill = 1200 }, { at = 196, qiSec = 900 }, { at = 256, summons = 6 }, { at = 319, summons = 8, rarity = "Celestial" } } },
}
-- The Relic Hall (owner 2026-10-25: "a building always on showing some relics based on progression of
-- quests"): finishing rank N earns MISSION_RELICS[N], shown in the hall for good (never reset). Rank 1
-- shows the ten as dark silhouettes, so the first relic lands with the first rank up (~7-10 min).
Config.MISSION_RELICS = { "Golden Broom", "Practice Sword", "Incense Burner", "Jade Seal", "Bronze Ding", "Phoenix Fan", "Sect Scroll", "Hall Bell", "Sword in Stone", "Dragon Pearl" }
Config.MISSION_STALE = 900 -- s of play: a mission not started by then is swapped for another

-- Groups: one active mission per group. `need[tier]` is the count, `stars[tier]` its stars, a missing tier
-- is never drawn. `when(d, ctx)` says the group can be drawn now (ctx.others = other players here,
-- ctx.rebirths, ctx.giftLeft, ctx.furnace). `scale` "build" shrinks the count in late realms, where pads wait
-- minutes (D82).
Config.MISSION_GROUPS = {
	orb = { text = "Collect %d qi orbs", need = { 3, 8, 15, 30 }, stars = { 1, 2, 3, 4 } },
	recruit = { text = "Recruit %d disciples", need = { 3, 10, 25, 60 }, stars = { 1, 2, 3, 4 } },
	build = { text = "Build %d buildings", need = { 3, 8, 15, 25 }, stars = { 1, 2, 3, 4 }, scale = "build" },
	breakthrough = { text = "Break through %d time", plural = "Break through %d times", need = { [3] = 1, [4] = 2 }, stars = { [3] = 3, [4] = 4 } },
	altar = { text = "Join a Heavenly Altar fight", need = { [2] = 1 }, stars = { [2] = 2 } },
	gift = { text = "Claim %d free gift", plural = "Claim %d free gifts", need = { 1, 2 }, stars = { 1, 2 }, when = "giftLeft" },
	pill = { text = "Take %d x2 pill", plural = "Take %d x2 pills", need = { 1, 2, 4 }, stars = { 1, 2, 3 }, when = "furnace" },
	bless = { text = "Bless %d sect", plural = "Bless %d sects", need = { [2] = 1, [3] = 2 }, stars = { [2] = 2, [3] = 3 }, when = "others" },
	rebirth = { text = "Rebirth once", need = { [4] = 1 }, stars = { [4] = 4 }, when = "reborn" },
}
-- Rank 1, in order (like Bee Swarm Simulator's first quest giver): each entry is a group, count and stars.
-- "streak" (claim the Daily Blessing) is skipped when today's is already claimed, "rebirth" after a first rebirth.
Config.MISSION_STARTER = {
	{ group = "build", need = 5, stars = 1 },
	{ group = "recruit", need = 3, stars = 1 },
	{ group = "breakthrough", need = 1, stars = 2, text = "Break through to the next realm" },
	{ group = "rebirth", need = 1, stars = 4, text = "Rebirth once" }, -- sits in its slot until the first rebirth (~9 min)
	{ group = "orb", need = 3, stars = 1 },
	{ group = "streak", need = 1, stars = 1, text = "Claim the Daily Blessing" },
	{ group = "build", need = 10, stars = 2 },
	{ group = "gift", need = 1, stars = 1 },
	{ group = "orb", need = 8, stars = 2 },
}
-- Daily (owner pick pending, B): 3 missions a UTC day from these groups, all 3 done opens the daily chest.
Config.MISSION_DAILY = { "orb", "recruit", "build", "gift", "altar", "pill" } -- no bless: a day can start on an empty server
Config.MISSION_DAILY_COUNT = 3
Config.MISSION_DAILY_TIER = 2 -- every daily is drawn at this tier (the nearest one the group has)
Config.MISSION_DAILY_CHEST = { qiSec = 300, summons = 2 }

function Config.missionRank(rank)
	local n = #Config.MISSION_RANKS
	local def = Config.MISSION_RANKS[math.min(rank, n)]
	if rank <= n then
		return def.name, def.rewards
	end
	local roman = { "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
	return def.name .. " " .. (roman[rank - n] or tostring(rank - n + 1)), def.rewards
end

function Config.missionSlots(rank)
	return Config.MISSION_SLOTS[math.min(rank, #Config.MISSION_SLOTS)]
end

-- the count of a group's tier for this save (build missions shrink where pads wait long)
function Config.missionNeed(group, tier, realm)
	local g = Config.MISSION_GROUPS[group]
	local n = g and g.need[tier]
	if not n then
		return nil
	end
	if g.scale == "build" then
		n = math.max(1, math.floor(n * (realm <= 3 and 1 or realm <= 6 and 0.5 or 0.2)))
	end
	return n
end

function Config.missionText(group, n, text)
	if text then
		return text
	end
	local g = Config.MISSION_GROUPS[group]
	if not g then
		return group
	end
	return string.format(n ~= 1 and g.plural or g.text, n)
end

return Config
