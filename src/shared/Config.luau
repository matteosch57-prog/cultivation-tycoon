-- Cultivation Tycoon: all tunable numbers live here (single source of truth).
local Config = {}

Config.PLOT_COUNT = 6
Config.PLOT_RADIUS = 215 -- distance from the hub to each peak centre (room for 90-stud islands)
Config.ISLAND_RADIUS = 62 -- starting island; grows with expand1/expand2 (ISLAND_RADII)
Config.HUB_RADIUS = 36

Config.BASE_RATE = 1 -- qi/s with nothing built
Config.OFFLINE_CAP = 4 * 3600 -- seconds of offline qi kept
Config.AUTOSAVE = 60
Config.DATASTORE = "CultivationTycoon_v1"
Config.DATA_VERSION = 1 -- save record format; SaveStore.migrate lifts older records to it
Config.SAVE_LEASE = 150 -- s a session lock lives without a refresh (autosave refreshes it)
Config.SAVE_RETRIES = 3 -- DataStore attempts per load/save (backoff 1 s, 2 s)
Config.SAVE_LOCK_WAITS = 6 -- tries to take a lock held by another live session on join
Config.SAVE_LOCK_WAIT = 5 -- s between those tries

-- Phone performance (B01 step 3): small Ball / Cylinder parts become clones of one low-poly mesh
-- (art/meshes, tools/lowpoly_meshes.py, uploaded by the owner). nil = off (plain parts).
Config.LOWPOLY_BALL = "rbxassetid://75794578549559"
Config.LOWPOLY_CYLINDER = "rbxassetid://90367641492097"
Config.LOWPOLY_MAX = 2 -- studs across: bigger balls and cylinders stay true parts

-- Realms: each breakthrough multiplies income and costs.
Config.REALMS = {
	"Qi Condensation",
	"Foundation Establishment",
	"Core Formation",
	"Nascent Soul",
	"Soul Transformation",
}
Config.REALM_INCOME_MULT = 3 -- income x3 per realm
Config.REALM_COST_MULT = 8 -- costs x8 per realm
Config.BREAKTHROUGH_COST = 45000

-- Pads of one realm. Players CHOOSE: a pad opens once `unlock` buildings are owned (any of
-- them) and its `req` pads (hard dependencies) are owned, which keeps 3 to 5 pads open at once.
-- `feature` = what the building does besides qi/s (shown on its price card).
-- `x`,`z` = pad position in the peak's local frame (+Z faces the hub bridge).
-- The Main Hall (mainhall1..5) is ONE building upgraded in place; each level replaces the last.
-- expand1/expand2 grow the island (Config.ISLAND_RADII) and open the outer building spots.
Config.PADS = {
	{ id = "path", name = "Stone Path", cost = 10, income = 1, unlock = 0, req = {}, x = 0, z = 40 },
	{ id = "vein1", name = "Spirit Vein", cost = 25, income = 2, unlock = 0, req = {}, x = -16, z = 24 },
	{ id = "lanterns", name = "Lantern Row", cost = 60, income = 3, unlock = 0, req = {}, x = 10, z = 30 },
	{ id = "mainhall1", name = "Thatched Hut", cost = 90, income = 4, unlock = 1, req = {}, x = 0, z = -30, feature = "Your sect's heart: upgrade it" },
	{ id = "platform", name = "Meditation Platform", cost = 150, income = 4, unlock = 2, req = {}, x = 0, z = 0, feature = "Disciples meditate here" },
	{ id = "garden", name = "Herb Garden", cost = 300, income = 8, unlock = 3, req = {}, x = -28, z = 12 },
	{ id = "vein2", name = "Twin Spirit Vein", cost = 600, income = 14, unlock = 4, req = {}, x = 18, z = 22 },
	{ id = "mainhall2", name = "Sect Hall", cost = 900, income = 20, unlock = 4, req = { "mainhall1" }, x = 0, z = -30, feature = "Main Hall level 2" },
	{ id = "furnace", name = "Alchemy Furnace", cost = 1200, income = 10, unlock = 6, req = {}, x = 30, z = 4, feature = "Brews a 2x Qi pill" },
	{ id = "hall", name = "Disciple Hall", cost = 1500, income = 10, unlock = 6, req = {}, x = -47, z = -4, feature = "Unlocks recruiting" },
	{ id = "gate", name = "Sect Gate", cost = 2200, income = 25, unlock = 8, req = {}, x = 0, z = 52 },
	{ id = "array", name = "Qi Gathering Array", cost = 3200, income = 30, unlock = 9, req = {}, x = 46, z = -22, feature = "Spawns qi orbs to collect" },
	{ id = "mainhall3", name = "Great Hall", cost = 4500, income = 45, unlock = 9, req = { "mainhall2" }, x = 0, z = -30, feature = "Main Hall level 3" },
	{ id = "quarters1", name = "Disciple Quarters", cost = 5000, income = 5, unlock = 10, req = { "hall" }, x = -30, z = 40, feature = "+1 disciple slot" },
	{ id = "expand1", name = "Expand the Peak", cost = 6000, income = 0, unlock = 11, req = {}, x = -14, z = 8, feature = "Your island grows" },
	{ id = "bamboo", name = "Bamboo Grove", cost = 7500, income = 60, unlock = 12, req = { "expand1" }, x = -64, z = 24 },
	{ id = "training", name = "Training Ground", cost = 8500, income = 60, unlock = 12, req = { "expand1" }, x = 62, z = 8 },
	{ id = "mainhall4", name = "Sect Palace", cost = 11000, income = 100, unlock = 13, req = { "mainhall3" }, x = 0, z = -30, feature = "Main Hall level 4" },
	{ id = "bell", name = "Bell Tower", cost = 12000, income = 90, unlock = 14, req = { "expand1" }, x = -52, z = -50 },
	{ id = "koi", name = "Koi Pond", cost = 13000, income = 90, unlock = 14, req = { "expand1" }, x = 52, z = -50 },
	{ id = "quarters2", name = "Grand Quarters", cost = 15000, income = 10, unlock = 15, req = { "quarters1" }, x = 30, z = 40, feature = "+1 disciple slot" },
	{ id = "expand2", name = "Expand the Peak II", cost = 18000, income = 0, unlock = 16, req = { "expand1" }, x = 14, z = 8, feature = "Your island grows again" },
	{ id = "pagoda1", name = "Pagoda", cost = 21000, income = 150, unlock = 17, req = { "expand2" }, x = 0, z = -60 },
	{ id = "library", name = "Scripture Library", cost = 23000, income = 170, unlock = 18, req = { "expand2" }, x = 60, z = 46 },
	{ id = "moongate", name = "Moon Gate Garden", cost = 24000, income = 170, unlock = 18, req = { "expand2" }, x = -60, z = 46 },
	{ id = "pagoda2", name = "Pagoda Spire", cost = 26000, income = 200, unlock = 19, req = { "pagoda1" }, x = 12, z = -66 },
	{ id = "mainhall5", name = "Celestial Palace", cost = 30000, income = 300, unlock = 20, req = { "mainhall4" }, x = 0, z = -30, feature = "Main Hall final level" },
}

-- island radius by expansion level (0, 1, 2)
Config.ISLAND_RADII = { 62, 76, 90 }
function Config.islandRadius(owned)
	return Config.ISLAND_RADII[1 + (owned.expand1 and 1 or 0) + (owned.expand2 and 1 or 0)]
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

-- Features
Config.PILL_INTERVAL = 180 -- seconds between pills from the Alchemy Furnace
Config.PILL_DURATION = 60 -- seconds of 2x qi
Config.ORB_INTERVAL = 20 -- seconds between qi orbs from the Qi Gathering Array
Config.ORB_MAX = 3 -- orbs waiting on a peak at most
Config.ORB_VALUE = 15 -- an orb is worth this many seconds of income
Config.SLOT_PADS = { "quarters1", "quarters2" } -- each owned one adds a disciple slot

function Config.maxDisciples(owned)
	local n = Config.MAX_DISCIPLES
	for _, id in Config.SLOT_PADS do
		if owned[id] then
			n += 1
		end
	end
	return n
end

-- Disciples: recruited at the Disciple Hall, each adds a % bonus to income.
Config.MAX_DISCIPLES = 5
Config.RECRUIT_BASE = 500
Config.RECRUIT_GROWTH = 0.5 -- +50% cost per disciple ever recruited (this realm-scaled)
Config.RARITIES = {
	{ name = "Outer Disciple", weight = 60, bonus = 0.10, color = Color3.fromRGB(200, 200, 200) },
	{ name = "Inner Disciple", weight = 28, bonus = 0.25, color = Color3.fromRGB(90, 200, 120) },
	{ name = "Core Disciple", weight = 9, bonus = 0.60, color = Color3.fromRGB(80, 150, 255) },
	{ name = "Elder", weight = 2.5, bonus = 1.50, color = Color3.fromRGB(190, 100, 255) },
	{ name = "Immortal", weight = 0.5, bonus = 4.00, color = Color3.fromRGB(255, 200, 60) },
}

-- Building palettes cycle with the realm.
Config.PALETTES = {
	{ stone = Color3.fromRGB(150, 150, 145), wood = Color3.fromRGB(120, 80, 50), roof = Color3.fromRGB(90, 60, 45), trim = Color3.fromRGB(190, 170, 120), glow = Color3.fromRGB(120, 220, 255) },
	{ stone = Color3.fromRGB(200, 225, 210), wood = Color3.fromRGB(140, 40, 40), roof = Color3.fromRGB(40, 140, 100), trim = Color3.fromRGB(230, 230, 220), glow = Color3.fromRGB(120, 255, 180) },
	{ stone = Color3.fromRGB(235, 225, 200), wood = Color3.fromRGB(110, 30, 30), roof = Color3.fromRGB(200, 150, 40), trim = Color3.fromRGB(255, 220, 120), glow = Color3.fromRGB(255, 210, 110) },
}

function Config.realmName(realm)
	return Config.REALMS[math.min(realm, #Config.REALMS)] .. (realm > #Config.REALMS and (" " .. realm) or "")
end

function Config.costMult(realm)
	return Config.REALM_COST_MULT ^ (realm - 1)
end

function Config.incomeMult(realm)
	return Config.REALM_INCOME_MULT ^ (realm - 1)
end

function Config.recruitCost(realm, recruited)
	return math.floor(Config.RECRUIT_BASE * Config.costMult(realm) * (1 + recruited * Config.RECRUIT_GROWTH))
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
