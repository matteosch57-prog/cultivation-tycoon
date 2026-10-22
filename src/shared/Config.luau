-- Cultivation Tycoon: all tunable numbers live here (single source of truth).
local Config = {}

Config.PLOT_COUNT = 6
Config.PLOT_RADIUS = 215 -- distance from the hub to each peak centre (room for 90-stud islands)
Config.ISLAND_RADIUS = 62 -- the base disc; expansions add lobes (ISLAND_LOBES)
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
Config.IDLE_CHEST_AT = Vector3.new(10, 0, 44) -- on the peak (frame space): beside the avenue, past the gate
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
-- Leaf-card tree canopies (src/server/Nature.luau, tools/nature_assets.py writes art/meshes/canopy_*.obj).
-- The owner uploads them (R11); empty = not uploaded yet, the old part trees stay. The leaf textures
-- live in src/server/NatureKit.model.json as SurfaceAppearances.
Config.NATURE_MESH = {
	sakura = "rbxassetid://99741618115048",
	ginkgo = "rbxassetid://89967761874874",
	round = "rbxassetid://112145916039641",
	pine = "rbxassetid://91206435364540",
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
-- per reincarnation from how deep that life went; SWORN_BASE best disciples follow into the next life.
-- D37 (owner: "40m is long to hook, 5-10m is good"): the gate is realm 2, so the first new life
-- comes ~10 min in; x1.5 per realm deeper keeps each life a little longer than the last (10, 14,
-- 20 ... ~75 min by life 9, ~4 h by life 14 for 2 x 30 min a day; research 2026-10-21_economy_math).
Config.REINC_REALM = 2
Config.PAST_LIVES_MULT = 1.5
Config.SWORN_BASE = 1
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
	{ key = "sworn", name = "Sworn Bond", line = "+1 disciple follows you", costs = { 10, 30 } },
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
Config.BREAKTHROUGH_COST = 300000 -- realm 1 end income is ~2k/s with no disciples: a 2 to 3 min goal (tools/sim_pacing.py)

-- Pads of one realm. Players CHOOSE: a pad opens once `unlock` buildings are owned (any of
-- them) and its `req` pads (hard dependencies) are owned, which keeps 3 to 5 pads open at once.
-- `feature` = what the building does besides qi/s (shown on its price card).
-- `x`,`z` = pad position in the peak's local frame (+Z faces the hub bridge).
-- The Main Hall (mainhall1..5) is ONE building upgraded in place; each level replaces the last.
-- expand1/expand2 add lobes of land (Config.ISLAND_LOBES) where their districts grow.
-- `district` groups buildings (layout A, owner 2026-10-21, docs/art/mocks/island_layout.html):
-- fields (Spirit Fields, front left), dao (Alchemy and Training, right), disciples (back left),
-- heart (the avenue, plaza, Main Hall and the summit behind it). DISTRICT_BONUS below.
Config.PADS = {
	{ id = "path", name = "Stone Path", cost = 10, income = 1, unlock = 0, req = {}, x = 0, z = 40, district = "heart" },
	{ id = "vein1", name = "Spirit Vein", cost = 25, income = 2, unlock = 0, req = {}, x = -20, z = 24, district = "fields" },
	{ id = "lanterns", name = "Lantern Row", cost = 60, income = 3, unlock = 0, req = {}, x = 10, z = 30, district = "heart" },
	{ id = "mainhall1", name = "Thatched Hut", cost = 90, income = 4, unlock = 1, req = {}, x = 0, z = -30, feature = "Your sect's heart: upgrade it", district = "heart" },
	{ id = "platform", name = "Meditation Platform", cost = 150, income = 4, unlock = 2, req = {}, x = 0, z = 0, feature = "Disciples meditate here", district = "heart" },
	{ id = "garden", name = "Herb Garden", cost = 300, income = 8, unlock = 3, req = {}, x = -36, z = 36, district = "fields" },
	{ id = "vein2", name = "Twin Spirit Vein", cost = 600, income = 14, unlock = 4, req = {}, x = -18, z = 34, district = "fields" },
	{ id = "mainhall2", name = "Sect Hall", cost = 900, income = 20, unlock = 4, req = { "mainhall1" }, x = 0, z = -30, feature = "Main Hall level 2", district = "heart" },
	{ id = "furnace", name = "Alchemy Furnace", cost = 1200, income = 10, unlock = 6, req = {}, x = 26, z = 20, feature = "Brews a 2x Qi pill", district = "dao" },
	{ id = "hall", name = "Disciple Hall", cost = 1500, income = 10, unlock = 6, req = {}, x = -50, z = 0, feature = "Unlocks recruiting", district = "disciples" },
	{ id = "gate", name = "Sect Gate", cost = 2200, income = 25, unlock = 8, req = {}, x = 0, z = 52, district = "heart" },
	{ id = "array", name = "Qi Gathering Array", cost = 3200, income = 30, unlock = 9, req = {}, x = 44, z = -2, feature = "Spawns qi orbs to collect", district = "dao" },
	{ id = "mainhall3", name = "Great Hall", cost = 4500, income = 45, unlock = 9, req = { "mainhall2" }, x = 0, z = -30, feature = "Main Hall level 3", district = "heart" },
	{ id = "quarters1", name = "Disciple Quarters", cost = 5000, income = 5, unlock = 10, req = { "hall", "expand1" }, x = -54, z = -32, feature = "+1 disciple slot", district = "disciples" },
	{ id = "expand1", name = "Expand the Peak", cost = 6000, income = 0, unlock = 11, req = {}, x = -14, z = 8, feature = "Your island grows" },
	{ id = "bamboo", name = "Bamboo Grove", cost = 7500, income = 60, unlock = 12, req = { "expand1" }, x = -84, z = -6, district = "fields" },
	{ id = "training", name = "Training Ground", cost = 8500, income = 60, unlock = 12, req = { "expand1" }, x = 74, z = 8, district = "dao" },
	{ id = "mainhall4", name = "Sect Palace", cost = 11000, income = 100, unlock = 13, req = { "mainhall3" }, x = 0, z = -30, feature = "Main Hall level 4", district = "heart" },
	{ id = "bell", name = "Bell Tower", cost = 12000, income = 90, unlock = 14, req = { "expand2" }, x = 40, z = -74, district = "heart" },
	{ id = "koi", name = "Koi Pond", cost = 13000, income = 90, unlock = 14, req = { "expand1" }, x = -74, z = 14, district = "fields" },
	{ id = "quarters2", name = "Grand Quarters", cost = 15000, income = 10, unlock = 15, req = { "quarters1", "expand1" }, x = -58, z = -62, feature = "+1 disciple slot", district = "disciples" },
	{ id = "expand2", name = "Expand the Peak II", cost = 18000, income = 0, unlock = 16, req = { "expand1" }, x = 14, z = 8, feature = "Your island grows again" },
	{ id = "pagoda1", name = "Pagoda", cost = 21000, income = 150, unlock = 17, req = { "expand2" }, x = 0, z = -60, district = "heart" },
	{ id = "library", name = "Scripture Library", cost = 23000, income = 170, unlock = 18, req = { "expand2" }, x = -26, z = -76, district = "heart" },
	{ id = "moongate", name = "Moon Gate Garden", cost = 24000, income = 170, unlock = 18, req = { "expand2" }, x = 64, z = -26, district = "dao" },
	{ id = "pagoda2", name = "Pagoda Spire", cost = 26000, income = 200, unlock = 19, req = { "pagoda1" }, x = 12, z = -66, district = "heart" },
	{ id = "mainhall5", name = "Celestial Palace", cost = 30000, income = 300, unlock = 20, req = { "mainhall4", "expand2" }, x = 0, z = -30, feature = "Main Hall final level", district = "heart" },
	-- District resources (option C, owner 2026-10-21): more copies and new types. Economy sim
	-- 2026-10-21: incomes halved from the first pass (realm 10 on day 16 regular, day 33 casual; D25 kept).
	{ id = "vein3", name = "Third Spirit Vein", cost = 1800, income = 10, unlock = 7, req = { "vein2" }, x = -30, z = 10, district = "fields" },
	{ id = "firelotus1", name = "Fire Lotus Pond", cost = 2000, income = 12, unlock = 7, req = { "furnace" }, x = 34, z = 40, district = "dao" },
	{ id = "firelotus2", name = "Twin Fire Lotus", cost = 5500, income = 25, unlock = 10, req = { "firelotus1" }, x = 50, z = 14, district = "dao" },
	{ id = "garden2", name = "Second Lotus Garden", cost = 8000, income = 35, unlock = 12, req = { "garden", "expand1" }, x = -40, z = 54, district = "fields" },
	{ id = "tea1", name = "Spirit Tea Terrace", cost = 9500, income = 40, unlock = 13, req = { "expand1" }, x = -57, z = 33, district = "fields" },
	{ id = "spring1", name = "Meditation Spring", cost = 10000, income = 42, unlock = 13, req = { "expand1" }, x = -80, z = -41, district = "disciples" },
	{ id = "garden3", name = "Third Lotus Garden", cost = 12500, income = 50, unlock = 15, req = { "garden2" }, x = -60, z = 48, district = "fields" },
	{ id = "tea2", name = "High Tea Terrace", cost = 14000, income = 55, unlock = 15, req = { "tea1" }, x = -73, z = 31, district = "fields" },
	{ id = "spring2", name = "Twin Spring", cost = 16000, income = 62, unlock = 16, req = { "spring1" }, x = -80, z = -60, district = "disciples" },
	{ id = "jade1", name = "Jade Quarry", cost = 20000, income = 80, unlock = 18, req = { "expand2" }, x = 62, z = 30, district = "dao" },
	{ id = "thunder1", name = "Thunder Crystal", cost = 22000, income = 88, unlock = 19, req = { "expand2" }, x = 58, z = -50, district = "dao" },
	{ id = "jade2", name = "Deep Jade Quarry", cost = 25000, income = 95, unlock = 20, req = { "jade1" }, x = 78, z = 28, district = "dao" },
	{ id = "thunder2", name = "Storm Crystal", cost = 28000, income = 110, unlock = 21, req = { "thunder1" }, x = 74, z = -47, district = "dao" },
	{ id = "jade3", name = "Heart of Jade", cost = 29000, income = 115, unlock = 22, req = { "jade2" }, x = 90, z = -10, district = "dao" },
}
-- The island grows lobe by lobe (owner 2026-10-21: "they go little by little, not full diameter"):
-- the base disc keeps ISLAND_RADIUS, each expansion adds lobes of land beside the district it
-- grows. `exp` = the expansion level that adds it; x, z, r in studs (peak frame). The farthest lobe
-- edge (ISLAND_REACH) stays clear of the neighbours at PLOT_RADIUS 215 (east/west reach about 100; the lobes behind reach ~110, away from every neighbour).
Config.ISLAND_LOBES = {
	{ x = -70, z = 6, r = 34, exp = 1 }, -- Spirit Fields grow west (bamboo, koi)
	{ x = -60, z = -52, r = 30, exp = 1 }, -- the Disciples' corner, back left (quarters, springs)
	{ x = -48, z = 46, r = 26, exp = 1 }, -- the fields' front left (the second and third lotus gardens)
	{ x = 70, z = 8, r = 32, exp = 2 }, -- Alchemy and Training grow east (training ground, jade quarries)
	{ x = 62, z = -30, r = 28, exp = 2 }, -- ... and south-east (moon gate, thunder crystals)
	{ x = 88, z = -10, r = 16, exp = 2 }, -- ... and far east (the Heart of Jade)
	{ x = -26, z = -78, r = 26, exp = 2 }, -- the summit behind the Main Hall (library)
	{ x = 14, z = -80, r = 26, exp = 2 }, -- (pagodas)
	{ x = 40, z = -74, r = 18, exp = 2 }, -- (bell tower; the Celestial Palace's back corners)
}
Config.ISLAND_RADII = { 62, 62, 62 } -- kept for old readers: the base disc no longer grows
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
-- Roads (always there, free): the plaza ring and paths from it into each district; `exp` = the
-- expansion that adds that stretch. The avenue itself is the Stone Path pad.
Config.ROAD_RING = 21
Config.ROADS = {
	{ exp = 0, { -15, 15 }, { -28, 22 }, { -40, 22 } }, -- Spirit Fields
	{ exp = 1, { -40, 22 }, { -62, 22 } },
	{ exp = 0, { 21, 0 }, { 33, -5 } }, -- Alchemy and Training
	{ exp = 2, { 33, -5 }, { 44, -17 }, { 60, -7 } },
	{ exp = 0, { -21, 0 }, { -34, 0 } }, -- the Disciple Hall's door
}
-- District bonus (layout A): each OTHER owned qi building in the same district adds this share
-- to a building's income, so where you build matters. Economy sim 2026-10-21: realm 10 a day
-- sooner, the fast-then-hard steps kept; never above 0.10 (0.20 flattens D25's step).
Config.DISTRICT_BONUS = 0.05
Config.DISTRICT_NAMES = { fields = "Fields", dao = "Alchemy", disciples = "Disciple" }
-- the price card's line for a district building (nil for the heart): "+5% per Fields building"
function Config.districtLine(pad)
	local name = pad.district and Config.DISTRICT_NAMES[pad.district]
	if not name or pad.income <= 0 then
		return nil
	end
	return string.format("+%d%% per %s building", math.floor(Config.DISTRICT_BONUS * 100 + 0.5), name)
end
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
Config.WORKER_MAX = 3
Config.WORKER_BONUS = 0.5 -- simmed (research 2026-10-21_economy_math): ~9% faster climb; above 1.0 eats the hard part
Config.WORKER_COST = { 0.5, 1, 2 }
Config.WORKERS = {
	garden = { name = "Farmer", x = -24, z = 44 },
	vein1 = { name = "Miner", x = -12, z = 22 },
	furnace = { name = "Alchemist", x = 24, z = 37 },
	training = { name = "Fighter", x = 61.6, z = 6.6 },
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
Config.GROUP_ID = 0
Config.GROUP_BONUS = 0.1
-- Heavenly Gift (D36): a brand-new save's intro screen pays this once (the first four buildings,
-- 10 + 25 + 60 + 90, with no wait; Economy check 2026-10-21: realms 2 to 5 move under a minute)
Config.WELCOME_QI = 200
-- Heavenly Altar (owner idea 2026-10-21, mock A docs/art/mocks/altar_A_phone.jpg): king of the hill
-- over the hub. It opens half a tide cycle after each tide (never with one); stand on it ALONE for
-- ALTAR_HOLD s to claim it (two or more on it pause the timer); Palm Strike pushes, a fall locks
-- you out until the round ends. Rewards are seconds of the player's own income (fair at any
-- realm, no stacking power): the winner ALTAR_WIN_SECONDS + a crown until the next round (only
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
-- Playtime gifts: claimable after this many seconds of play in one session (research
-- 2026-10-21_tycoon_study); each pays GIFT_VALUE[i] seconds of income (no tide, no pill)
Config.GIFT_TIMES = { 300, 900, 1800 }
Config.GIFT_VALUE = { 120, 300, 600 }
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
	{ key = "x2", id = 0, name = "2x Qi", line = "Double income forever" },
	{ key = "auto", id = 0, name = "Auto Orbs", line = "Orbs fly to you" },
	{ key = "vip", id = 0, name = "VIP Sect", line = "+1 disciple, gold name" },
}
Config.SHOP_PRODUCTS = {
	{ key = "pill", id = 0, name = "Instant Pill", line = "2x Qi for 60 s now" },
	{ key = "pack1", id = 0, name = "Qi Pouch", line = "10 min of income", seconds = 600 },
	{ key = "pack2", id = 0, name = "Qi Chest", line = "1 hour of income", seconds = 3600 },
	{ key = "pack3", id = 0, name = "Qi Vault", line = "6 hours of income", seconds = 21600 },
	-- a disciple of a FIXED rarity (never random, R8); joins like a recruit (takes the weakest seat
	-- when full). Every tier from Elder up is sold (owner, D28), priced by the owner as a ladder.
	{ key = "elder", id = 0, name = "Elder", line = "+150% Qi disciple", rarity = "Elder", limit = 8 },
	{ key = "immortal", id = 0, name = "Immortal", line = "+400% Qi disciple", rarity = "Immortal", limit = 8 },
	-- `limit` = times one player may buy it: the chase tiers once each, Elder / Immortal one sect's
	-- worth (bought disciples are never trimmed, so this bounds the list and the save); `minRealm` = on sale only from
	-- that realm (bought from the start they would flatten the early climb: economy check, D28)
	{ key = "celestial", id = 0, name = "Celestial", line = "+900% Qi disciple", rarity = "Celestial", limit = 1, minRealm = 3 },
	{ key = "dao", id = 0, name = "Dao Ancestor", line = "+2,000% Qi disciple", rarity = "Dao Ancestor", limit = 1, minRealm = 5 },
	{ key = "emperor", id = 0, name = "Heavenly Emperor", line = "+4,500% Qi disciple", rarity = "Heavenly Emperor", limit = 1, minRealm = 7 },
	{ key = "primordial", id = 0, name = "Primordial", line = "+10,000% Qi disciple", rarity = "Primordial", limit = 1, minRealm = 9 },
}
Config.PASS_QI_MULT = 2 -- 2x Qi pass: every qi/s, offline and gifts included
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
	{ key = "pill", x = 40, z = 22, needs = "furnace" }, -- the furnace brews this pill; beside it (layout A)
	{ key = "auto", x = 32, z = -12, needs = "array" }, -- the orbs come from the Gathering Array, beside it (layout A)
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
Config.RECRUIT_GROWTH = 0.5 -- +50% cost per disciple recruited in THIS realm (restarts at a breakthrough, D25)
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
	return math.floor(Config.RECRUIT_BASE * Config.costMult(realm) * (1 + recruits * Config.RECRUIT_GROWTH))
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

return Config
