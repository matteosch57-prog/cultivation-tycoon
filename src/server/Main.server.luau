-- Cultivation Tycoon server: plots, qi income, pads, disciples, breakthrough, saving.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local GroupService = game:GetService("GroupService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Builders = require(script.Parent:WaitForChild("Builders"))
local Style = require(script.Parent:WaitForChild("Style"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local SaveStore = require(script.Parent:WaitForChild("SaveStore"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Cultivators = require(script.Parent:WaitForChild("Cultivators"))
local Workers = require(script.Parent:WaitForChild("Workers"))
local ServerHealth = require(script.Parent:WaitForChild("ServerHealth"))
local RealmLook = require(script.Parent:WaitForChild("RealmLook"))
local Altar = require(script.Parent:WaitForChild("Altar"))
local Guard = require(script.Parent:WaitForChild("Guard"))

local store = nil
if Config.MOCK_DATASTORE and game:GetService("RunService"):IsStudio() then
	-- Studio mock (both halves of the gate, never the flag alone): no store at all, so every Play
	-- starts as a brand-new player and nothing is saved. Set MOCK_DATASTORE false to test saving.
	print("[Tycoon] Studio mock save: fresh player every Play, nothing saved")
else
	local ok, result = pcall(function()
		-- Studio tests write to their own store so they never touch live saves.
		local suffix = game:GetService("RunService"):IsStudio() and "_studio" or ""
		return DataStoreService:GetDataStore(Config.DATASTORE .. suffix)
	end)
	if ok then
		store = result
	else
		warn("[Tycoon] DataStore unavailable, progress will not save:", result)
	end
end

-- Remotes ----------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local chestFn = Instance.new("RemoteFunction")
chestFn.Name = "ChestSummon" -- the idle chest's free summons (D39)
chestFn.Parent = remotes
local recruitFn = Instance.new("RemoteFunction")
recruitFn.Name = "Recruit"
recruitFn.Parent = remotes
local notify = Instance.new("RemoteEvent")
notify.Name = "Notify"
notify.Parent = remotes
local pillFn = Instance.new("RemoteFunction")
pillFn.Name = "UsePill"
pillFn.Parent = remotes
local giftFn = Instance.new("RemoteFunction")
giftFn.Name = "ClaimGift"
giftFn.Parent = remotes
local reincFn = Instance.new("RemoteFunction")
reincFn.Name = "Reincarnate"
reincFn.Parent = remotes
local daoFn = Instance.new("RemoteFunction")
daoFn.Name = "DaoBuy"
daoFn.Parent = remotes
local handsFn = Instance.new("RemoteFunction")
handsFn.Name = "HandsBuild"
handsFn.Parent = remotes
local groupFn = Instance.new("RemoteFunction")
groupFn.Name = "ClaimGroup"
groupFn.Parent = remotes
local inviteEv = Instance.new("RemoteEvent")
inviteEv.Name = "SocialInvite" -- the client opened Roblox's invite prompt (telemetry only)
inviteEv.Parent = remotes
local welcomeFn = Instance.new("RemoteFunction")
welcomeFn.Name = "ClaimWelcome" -- the intro's GO (D36)
welcomeFn.Parent = remotes
remotes.Parent = ReplicatedStorage

-- World ------------------------------------------------------------------------------
-- The ground the game stands on: terrain grass can only surface at world y = +2 or -2
-- (FillCylinder snaps to the 4-stud grid, measured 2026-10-21), so the hub and peaks sit at 2.
local BASE_Y = 2

local world = Instance.new("Folder")
world.Name = "Sect"
world.Parent = workspace

local function bridgeAngle(i)
	return (i - 1) / Config.PLOT_COUNT * math.pi * 2
end

-- true when (x, z) on the hub lies on a bridge mouth
local function onBridgeMouth(x, z)
	local a = math.atan2(z, x)
	for i = 1, Config.PLOT_COUNT do
		local d = math.abs((a - bridgeAngle(i) + math.pi) % (math.pi * 2) - math.pi)
		if d < 0.45 then
			return true
		end
	end
	return false
end

local function buildHub()
	local folder = Instance.new("Folder")
	folder.Name = "Hub"
	Style.island(folder, CFrame.new(0, BASE_Y, 0), Config.HUB_RADIUS, 31, onBridgeMouth, true)
	-- octagonal plaza with a bronze cauldron at its heart
	local P = Style.P
	local plaza = P(folder, Vector3.new(0.5, 26, 26), CFrame.new(0, BASE_Y + 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2), Style.PAL.stone, nil, Enum.PartType.Cylinder)
	plaza.Name = "Plaza"
	P(folder, Vector3.new(0.6, 22, 22), CFrame.new(0, BASE_Y + 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Style.PAL.stoneLight, nil, Enum.PartType.Cylinder)
	P(folder, Vector3.new(0.7, 9, 9), CFrame.new(0, BASE_Y + 0.35, 0) * CFrame.Angles(0, 0, math.pi / 2), Style.PAL.gold, nil, Enum.PartType.Cylinder)
	Style.cauldron(folder, CFrame.new(0, BASE_Y + 0.7, 0), 1)
	-- no grass blades through the plaza stones
	local plazaRegion = Region3.new(Vector3.new(-16, -8, -16), Vector3.new(16, 8, 16)):ExpandToGrid(4)
	workspace.Terrain:ReplaceMaterial(plazaRegion, 4, Enum.Material.Grass, Enum.Material.Ground)
	workspace.Terrain:ReplaceMaterial(plazaRegion, 4, Enum.Material.LeafyGrass, Enum.Material.Ground)
	-- sakura between the bridge mouths, a lantern at each mouth
	for i = 1, Config.PLOT_COUNT do
		local a = bridgeAngle(i)
		local mid = a + math.pi / Config.PLOT_COUNT
		local r = Config.HUB_RADIUS * 0.72
		if i % 2 == 0 then
			Style.sakura(folder, CFrame.new(math.cos(mid) * r, BASE_Y, math.sin(mid) * r), i)
		else
			Style.pine(folder, CFrame.new(math.cos(mid) * r, BASE_Y, math.sin(mid) * r), i, 12)
		end
		local side = a + 0.32
		local lr = Config.HUB_RADIUS - 5
		Style.lantern(folder, CFrame.new(math.cos(side) * lr, BASE_Y, math.sin(side) * lr), 0.9)
		task.wait()
	end
	folder.Parent = world
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		spawn.CFrame = CFrame.new(0, BASE_Y + 1.2, 9) -- on the plaza, in front of the cauldron
		spawn.Transparency = 1
		spawn.CanCollide = false
		for _, d in spawn:GetChildren() do
			if d:IsA("Decal") then
				d:Destroy()
			end
		end
	end
	local base = workspace:FindFirstChild("Baseplate")
	if base then
		base:Destroy()
	end
end

-- plots[i] = { frame, center, folder, built (Folder), grounds (Folder), label, labelText,
--              radius, owner (Player?) }
local plots = {}

-- direction (peak frame) from the peak centre to its shop island's bridge
local SHOP_DIR = Vector2.new(Config.SHOP_ISLAND_AT.X, Config.SHOP_ISLAND_AT.Z).Unit

local groundRadius = Config.ISLAND_RADIUS -- the island being drawn (buildGrounds sets it first)

-- Spots that must stay free of trees and boulders: the entrance path, the shop bridge's foot, every
-- pad, the Main Hall's largest footprint (level 5 with wings and towers) and the pagoda behind it.
local function keepClear(x, z)
	if math.abs(x) < 10 and z > 0 then
		return true
	end
	local v = Vector2.new(x, z)
	if v:Dot(SHOP_DIR) > 0 and math.abs(v.X * SHOP_DIR.Y - v.Y * SHOP_DIR.X) < 7 then
		return true
	end
	if math.abs(x) < 38 and z > -58 and z < -14 then
		return true
	end
	if math.abs(x) < 12 and z < -56 then
		return true
	end
	for _, pad in Config.PADS do
		if (Vector2.new(x, z) - Vector2.new(pad.x, pad.z)).Magnitude < 16 then -- the biggest buildings reach ~14
			return true
		end
	end
	for _, e in Config.SHOP_PEAK_PADS do -- the shop pads (the entrance ones move with the rim)
		local sx, sz = Config.shopPeakSpot(e, groundRadius)
		if (Vector2.new(x, z) - Vector2.new(sx, sz)).Magnitude < 7 then
			return true
		end
	end
	return false
end

local WATERFALL_ANGLE = 0.55 -- front-right rim, between the shop bridge and the east lobe (layout A keeps it clear of every lobe)

-- is (x, z) on one of these lobes of land?
local function onLobe(lobes, x, z, margin)
	for _, l in lobes do
		if (Vector2.new(x, z) - Vector2.new(l.x, l.z)).Magnitude < l.r + (margin or 0) then
			return true
		end
	end
	return false
end

-- The peak's ground: island (terrain grass on top) with the lobes its expansions added, roads,
-- rim trees, waterfall, rope bridge and the entrance archway with the owner's name. Rebuilt
-- whenever the land changes (an expansion, a breakthrough).
local function buildGrounds(plot, radius, lobes)
	lobes = lobes or {}
	if plot.grounds then
		plot.grounds:Destroy()
	end
	-- clear the old terrain grass (largest island + margin; never reaches the hub or neighbours)
	-- (islands reach at most 1.05 x radius, so 1.05 x max + 6 stays clear of the neighbours at
	-- PLOT_RADIUS 215 and of the hub)
	workspace.Terrain:FillCylinder(plot.frame * CFrame.new(0, -6, 0), 20, Config.ISLAND_RADIUS * 1.05 + 6, Enum.Material.Air)
	for _, l in Config.ISLAND_LOBES do -- every lobe a peak can own (layout A), each with its margin
		workspace.Terrain:FillCylinder(plot.frame * CFrame.new(l.x, -6, l.z), 20, l.r * 1.05 + 4, Enum.Material.Air)
	end
	local g = Instance.new("Folder")
	g.Name = "Grounds"
	groundRadius = radius
	Style.island(g, plot.frame, radius, 100 + plot.index, keepClear, true, lobes)
	-- roads: the plaza ring and the paths into each district this land reaches (Config.ROADS)
	local level = #lobes > 0 and (lobes[#lobes].exp or 0) or 0
	local roads = Instance.new("Folder")
	roads.Name = "Roads"
	Style.road(roads, plot.frame, {}, 5, Config.ROAD_RING)
	for _, r in Config.ROADS do
		if r.exp <= level then
			Style.road(roads, plot.frame, r, 4.5)
		end
	end
	roads.Parent = g
	-- trees around the rim of the base disc and of each lobe, wherever nothing is planned
	local rim = {}
	local n = math.floor(radius / 4)
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2 + 0.13
		local r = radius - 8 - (k % 2) * 3
		table.insert(rim, { math.cos(a) * r, math.sin(a) * r, k })
	end
	for li, l in lobes do
		local ln = math.floor(l.r / 4)
		for k = 0, ln - 1 do
			local a = k / ln * math.pi * 2
			local r = l.r - 6 - (k % 2) * 3
			local x, z = l.x + math.cos(a) * r, l.z + math.sin(a) * r
			if Vector2.new(x, z).Magnitude > radius - 2 then -- only on the new land, not over the base disc
				table.insert(rim, { x, z, li * 20 + k })
			end
		end
	end
	for _, t in rim do
		local x, z, k = t[1], t[2], t[3]
		-- base-rim trees that a lobe now surrounds would stand in the middle of the new land
		local inner = Vector2.new(x, z).Magnitude < radius and onLobe(lobes, x, z, -4)
		if not inner and not keepClear(x, z) then
			if k % 3 == 0 then
				Style.sakura(g, plot.frame * CFrame.new(x, 0, z), plot.index * 50 + k)
			else
				Style.pine(g, plot.frame * CFrame.new(x, 0, z), plot.index * 50 + k, 11 + (k % 4) * 2)
			end
		end
	end
	Style.waterfall(g, plot.frame, radius, WATERFALL_ANGLE)
	-- rope bridge from the hub rim to the peak rim
	local dir = Vector3.new(plot.center.X, 0, plot.center.Z).Unit
	local hubEdge = dir * (Config.HUB_RADIUS - 3) + Vector3.new(0, BASE_Y, 0)
	local peakEdge = plot.center - dir * (radius - 3)
	Style.bridge(g, hubEdge + Vector3.new(0, 0.05, 0), peakEdge + Vector3.new(0, 0.05, 0), 8)
	-- and one from the peak rim to its shop island (Shop.buildIsland)
	local foot = plot.frame * Vector3.new(SHOP_DIR.X * (radius - 3), 0, SHOP_DIR.Y * (radius - 3))
	Style.bridge(g, foot + Vector3.new(0, 0.05, 0), Shop.islandEntry(plot.frame) + Vector3.new(0, 0.05, 0), 6)
	-- entrance archway carrying the owner's name
	local sign = Kit.gate(g, plot.frame * CFrame.new(0, 0, radius - 1), 13, 16) -- taller (owner 2026-10-21)
	sign.Name = "Sign"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- the board's +Z side (Front faced the frame: the name never showed)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Name = "Owner"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.Fantasy
	label.TextColor3 = Color3.fromRGB(255, 225, 150)
	label.Text = plot.labelText or "Unclaimed Peak"
	label.Parent = gui
	if plot.vip then
		-- VIP Sect pass: the owner's name in bright gold with a dark edge
		label.TextColor3 = Color3.fromRGB(255, 205, 50)
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromHex("3A2410")
		st.Thickness = 3
		st.Parent = label
	end
	g.Parent = plot.folder
	plot.grounds = g
	plot.label = label
	plot.radius = radius
	plot.lookKey = nil -- the realm look follows the island's size
	RealmLook.apply(plot)
end

-- Terrain grass blades grow through anything standing on them (stairs, stone floors), so
-- the ground under a structure turns to packed earth, which has no blades.
-- Only the parts that actually touch the ground are painted (plinths, steps, paths), so a
-- courtyard between buildings keeps its grass. Only bladed Grass (the meadow patches) is
-- painted: the LeafyGrass lawn has no blades, and painting it left half the lawn bare earth
-- (each part paints its box snapped OUT to the 4-stud grid; visual check 2026-10-21).
local function paintGround(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local h = part.Size / 2
			local r = part.CFrame - part.Position
			local ex = Vector3.new(
				math.abs(r.XVector.X) * h.X + math.abs(r.YVector.X) * h.Y + math.abs(r.ZVector.X) * h.Z,
				math.abs(r.XVector.Y) * h.X + math.abs(r.YVector.Y) * h.Y + math.abs(r.ZVector.Y) * h.Z,
				math.abs(r.XVector.Z) * h.X + math.abs(r.YVector.Z) * h.Y + math.abs(r.ZVector.Z) * h.Z
			)
			local p = part.Position
			local touches = p.Y - ex.Y < BASE_Y + 1.2
			if touches and (ex.X > 0.8 or ex.Z > 0.8) then
				local region = Region3.new(Vector3.new(p.X - ex.X, BASE_Y - 8, p.Z - ex.Z), Vector3.new(p.X + ex.X, BASE_Y + 4, p.Z + ex.Z)):ExpandToGrid(4)
				workspace.Terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.Ground)
			end
		end
	end
end

local function setPlotLabel(plot, text)
	plot.labelText = text
	if plot.label then
		plot.label.Text = text
	end
end

-- The idle chest on every peak (D39): lacquered wood, gold bands, a jade clasp, and a label that
-- says it fills while you are away. The return screen (IdleChest.client) plays it opening.
local function buildIdleChest(plot)
	local P, PAL = Style.P, Style.PAL
	local m = Instance.new("Model")
	m.Name = "IdleChest"
	local at = Config.IDLE_CHEST_AT
	local cf = plot.frame * CFrame.new(at.X, 0, at.Z) * CFrame.Angles(0, math.rad(-90), 0) -- faces the avenue
	local red, dark = PAL.vermilion, Color3.fromHex("7A2019")
	P(m, Vector3.new(4.4, 0.4, 3.2), cf * CFrame.new(0, 0.2, 0), PAL.stone) -- plinth
	local box = P(m, Vector3.new(4, 2.2, 2.8), cf * CFrame.new(0, 1.5, 0), red, Enum.Material.Wood)
	P(m, Vector3.new(4.1, 0.35, 2.9), cf * CFrame.new(0, 1.9, 0), PAL.gold, Enum.Material.Metal)
	for _, x in { -1.45, 1.45 } do
		P(m, Vector3.new(0.4, 2.3, 2.9), cf * CFrame.new(x, 1.5, 0), PAL.gold, Enum.Material.Metal)
	end
	-- the lid: a low barrel vault (a cylinder half sunk into the box)
	P(m, Vector3.new(3.4, 2.6, 2.6), cf * CFrame.new(0, 2.6, 0), red, Enum.Material.Wood, Enum.PartType.Cylinder)
	P(m, Vector3.new(0.3, 2.7, 2.7), cf * CFrame.new(-1.7, 2.6, 0), dark, Enum.Material.Wood, Enum.PartType.Cylinder)
	P(m, Vector3.new(0.3, 2.7, 2.7), cf * CFrame.new(1.7, 2.6, 0), dark, Enum.Material.Wood, Enum.PartType.Cylinder)
	P(m, Vector3.new(0.9, 1, 0.3), cf * CFrame.new(0, 1.9, -1.5), PAL.jade) -- clasp
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 46)
	bb.StudsOffset = Vector3.new(0, 4.6, 0)
	bb.MaxDistance = 70
	bb.LightInfluence = 0
	bb.Adornee = box
	local function line(text, size, color, y)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, size + 4)
		t.Position = UDim2.fromOffset(0, y)
		t.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		t.Text = text
		t.TextSize = size
		t.TextColor3 = color
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromHex("1B1420")
		st.Thickness = math.max(1.5, size * 0.11)
		st.Parent = t
		t.Parent = bb
	end
	line("Idle Chest", 18, Color3.fromHex("FFE36B"), 0)
	line(string.format("Fills while you're away (up to %d h)", Config.OFFLINE_CAP / 3600), 12, Color3.new(1, 1, 1), 22)
	bb.Parent = m
	m.Parent = plot.folder
end

local function buildPlots()
	for i = 1, Config.PLOT_COUNT do
		local a = (i - 1) / Config.PLOT_COUNT * math.pi * 2
		local center = Vector3.new(math.cos(a) * Config.PLOT_RADIUS, BASE_Y, math.sin(a) * Config.PLOT_RADIUS)
		-- +Z of the frame faces the hub
		local frame = CFrame.lookAt(center, Vector3.new(0, BASE_Y, 0)) * CFrame.Angles(0, math.pi, 0)
		local folder = Instance.new("Folder")
		folder.Name = "Peak" .. i
		local built = Instance.new("Folder")
		built.Name = "Built"
		built.Parent = folder
		local plot = { index = i, frame = frame, center = center, folder = folder, built = built, owner = nil }
		buildGrounds(plot, Config.ISLAND_RADIUS)
		Shop.buildIsland(plot)
		buildIdleChest(plot)
		folder.Parent = world
		plots[i] = plot
		task.wait()
	end
end

local function setupLighting()
	-- Lighting itself is authored in Edit (saved with the place); only the cloud sea is built here.
	-- Terrain grass: a soft stylised green, with Roblox's animated grass blades on
	workspace.Terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromHex("7DAA5C")) -- the island lawn
	workspace.Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromHex("86B35E")) -- meadow patches (tall blades)
	workspace.Terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromHex("A8957A")) -- packed earth under buildings
	pcall(function()
		workspace.Terrain.Decoration = true
	end)
	-- cumulus sea below the peaks, plus a few banks drifting between them for depth
	-- soft particle clouds (few and big: each is ~35 live particles, mind phone overdraw)
	local sea = Style.cloudSea(world, Vector3.new(0, -95, 0), 140, 650, 18, 3)
	for i = 1, Config.PLOT_COUNT do
		local a = (i - 0.5) / Config.PLOT_COUNT * math.pi * 2
		local r = Config.PLOT_RADIUS * 0.8
		Style.softCloud(sea, CFrame.new(math.cos(a) * r, -50 - (i % 3) * 8, math.sin(a) * r) * CFrame.Angles(0, -a, 0), 70 + (i % 2) * 25, 300 + i)
	end
end

-- Player state -----------------------------------------------------------------------
-- sessions[player] = { data, plot, pads = { [id] = Part }, recruiting }
local sessions = {}

local function deepCopy(t)
	local c = {}
	for k, v in t do
		c[k] = if type(v) == "table" then deepCopy(v) else v
	end
	return c
end

local function defaultData()
	-- lives/karma/soulPeak/lifeStart: reincarnation (lifeStart = playSec when this life began)
	-- workers = { [building id] = workers hired there } (Config.WORKERS)
	return { qi = 0, realm = 1, owned = {}, disciples = {}, recruited = 0, last = os.time(), best = 1, lives = 1, karma = 0, soulPeak = 0, lifeStart = 0, dao = {}, workers = {} }
end

-- The list is kept sorted strongest first; only the first maxDisciples work (the rest are
-- benched, e.g. after a breakthrough resets the Quarters). `s.passes` = game passes owned (Shop).
-- Karma Shop node level (0 = not bought)
local function dao(d, key)
	return (d.dao or {})[key] or 0
end

local function maxDisciples(s)
	return Config.maxDisciples(s.data.owned, s.passes and s.passes.vip) + dao(s.data, "seat")
end

-- karma a reincarnation would pay now (Soul Echo included); only a life deeper than every one
-- before pays (D37: a reset at the same depth takes minutes, so it must not be a karma faucet)
local function karmaGain(d, share)
	if d.realm <= (d.soulPeak or 0) then
		return 0
	end
	return math.floor(Config.karmaFor(math.max(d.realm, Config.REINC_REALM), share) * (1 + Config.DAO_ECHO * dao(d, "echo")))
end

local function discipleMult(s)
	local data = s.data
	local m = 1
	local max = maxDisciples(s)
	for i, name in data.disciples do
		if i > max then
			break
		end
		m += Config.rarity(name).bonus
	end
	return m
end

local function boosted(data)
	return (data.boostUntil or 0) > workspace:GetServerTimeNow()
end

-- Spirit Tide: a server-wide event, every peak on the server earns TIDE_MULT x while it lasts
local function tideOn()
	return (workspace:GetAttribute("TideUntil") or 0) > workspace:GetServerTimeNow()
end

-- Friends here (D35): [player] = { [other player] = true } for Roblox friends on this server, checked
-- once at join, in memory only; a friend counts while their session exists
local friendsOf = {}

local function friendCount(s)
	local n = 0
	for other in friendsOf[s.player] or {} do
		if sessions[other] then
			n += 1
		end
	end
	return math.min(n, Config.FRIEND_MAX)
end

-- `away` = offline qi (and gifts), which never count the live tide, a pill or friends; the 2x Qi
-- pass counts everywhere
local function rate(s, away)
	local data = s.data
	local base = Config.BASE_RATE
	for id in data.owned do
		local pad = Config.padById(id)
		if pad then
			base += pad.income * (1 + Config.WORKER_BONUS * ((data.workers or {})[id] or 0)) * Config.districtMult(data.owned, pad)
		end
	end
	local tide = (not away and tideOn()) and Config.TIDE_MULT or 1
	local pill = (not away and boosted(data)) and 2 or 1
	local pass = (s.passes and s.passes.x2) and Config.PASS_QI_MULT or 1
	local past = Config.pastLivesMult(data.soulPeak)
	local friends = away and 1 or 1 + Config.FRIEND_STEP * friendCount(s)
	local group = (s.inGroup and data.groupClaimed) and 1 + Config.GROUP_BONUS or 1
	return base * Config.incomeMult(data.realm) * discipleMult(s) * pill * tide * pass * past * friends * group
end

-- share of this realm's pads owned (0..1)
local function builtShare(d)
	local n = 0
	for _, pad in Config.PADS do
		if d.owned[pad.id] then
			n += 1
		end
	end
	return n / #Config.PADS
end

local function publish(player)
	local s = sessions[player]
	if not s then
		return
	end
	local d = s.data
	player:SetAttribute("Qi", math.floor(d.qi))
	player:SetAttribute("Rate", rate(s))
	player:SetAttribute("AwayRate", rate(s, true)) -- what a Qi pack or a gift pays per second
	local friends = friendCount(s)
	player:SetAttribute("FriendsHere", friends)
	local ids = {}
	for other in friendsOf[player] or {} do
		if sessions[other] and #ids < Config.FRIEND_MAX then
			table.insert(ids, other.UserId)
		end
	end
	player:SetAttribute("FriendIds", table.concat(ids, ",")) -- head shots on the HUD card
	player:SetAttribute("GroupBonus", (s.inGroup and d.groupClaimed) == true)
	player:SetAttribute("WelcomeQi", d.welcomed == false and Config.WELCOME_QI or 0) -- > 0: show the intro
	s.friendsPeak = math.max(s.friendsPeak or 0, friends)
	player:SetAttribute("Realm", d.realm)
	player:SetAttribute("RealmName", Config.realmName(d.realm))
	player:SetAttribute("HasHall", d.owned.hall == true)
	player:SetAttribute("RecruitCost", Config.recruitCost(d.realm, d.realmRecruits or 0))
	player:SetAttribute("Disciples", table.concat(d.disciples, ","))
	local pulled = {}
	for name in d.pulled or {} do
		table.insert(pulled, name)
	end
	player:SetAttribute("Pulled", table.concat(pulled, ","))
	player:SetAttribute("MaxDisciples", maxDisciples(s))
	player:SetAttribute("HasFurnace", d.owned.furnace == true)
	player:SetAttribute("PillReady", d.pillReady == true)
	player:SetAttribute("PillIn", d.owned.furnace and math.max(0, math.ceil(Config.PILL_INTERVAL - (d.pillTimer or 0))) or 0)
	player:SetAttribute("BoostUntil", d.boostUntil or 0)
	-- playtime gifts: GiftIn = seconds to the next one (0 = ready), -1 = all claimed this session
	local gi = s.giftIdx or 1
	local at = Config.GIFT_TIMES[gi]
	player:SetAttribute("GiftIn", at and math.max(0, math.ceil(at - (s.playTime or 0))) or -1)
	local built = 0
	for _, pad in Config.PADS do
		if d.owned[pad.id] then
			built += 1
		end
	end
	player:SetAttribute("Built", built)
	-- reincarnation: what a new life would keep and gain (the screen previews it)
	player:SetAttribute("Lives", d.lives or 1)
	player:SetAttribute("Karma", d.karma or 0)
	player:SetAttribute("SoulPeak", d.soulPeak or 0)
	player:SetAttribute("PastLives", Config.pastLivesMult(d.soulPeak))
	player:SetAttribute("NextPastLives", Config.pastLivesMult(math.max(d.soulPeak or 0, d.realm)))
	player:SetAttribute("ReincKarma", karmaGain(d, d.realm >= Config.REINC_REALM and built / #Config.PADS or 0))
	for _, n in Config.DAO do
		player:SetAttribute("Dao_" .. n.key, dao(d, n.key))
	end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Realm.Value = d.realm
	end
end

local function ctxFor(s, folder)
	return { folder = folder or s.plot.built, frame = s.plot.frame, pal = Config.PALETTES[(s.data.realm - 1) % #Config.PALETTES + 1], sect = s.plot.labelText }
end

-- Build one pad's structure into its own Model (so clients can animate or preview it whole).
-- The model is filled while unparented and parented once at the end (one replication).
local function buildModel(s, pad, attrs)
	local m = Instance.new("Model")
	m.Name = pad.id
	for k, v in attrs or {} do
		m:SetAttribute(k, v)
	end
	Builders[pad.id](ctxFor(s, m), pad)
	return m
end

-- A hidden copy of the building for the client's proximity preview: invisible to everyone
-- (the owner's client fades it in locally), no collisions, no lights or effects.
local function buildPreview(s, pad, parent)
	if not Builders[pad.id] then
		return
	end
	local m = buildModel(s, pad)
	m.Name = "Preview"
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("SurfaceGui") then
			d.Enabled = false -- (a SurfaceGui draws even on an invisible part: the name boards)
		end
	end
	m.Parent = parent
end

local function buildDisciples(s)
	local old = s.plot.built:FindFirstChild("Disciples")
	if old then
		old:Destroy()
	end
	if not s.data.owned.platform then
		return
	end
	local ctx = ctxFor(s)
	ctx.folder = Instance.new("Folder")
	ctx.folder.Name = "Disciples"
	local max = maxDisciples(s)
	for slot, name in s.data.disciples do
		if slot > max then
			break -- benched
		end
		Builders.disciple(ctx, slot, Config.rarity(name))
	end
	ctx.folder.Parent = s.plot.built
end

-- the hired workers at their buildings (Workers.luau); rebuilt whole, like the disciples
local function buildWorkers(s)
	local old = s.plot.built:FindFirstChild("Workers")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Workers"
	for id, n in s.data.workers or {} do
		local pad = Config.padById(id)
		if pad and s.data.owned[id] then
			for k = 1, math.min(n, Config.WORKER_MAX) do
				Workers.build(folder, s.plot.frame, pad, k, { s.plot.built, workspace.Terrain })
			end
		end
	end
	folder.Parent = s.plot.built
end

local refreshPads -- forward
local PAD_COLOR = Color3.fromHex("6FB59C") -- jade

local function makePad(player, s, pad, cost, label, income, onBuy, kind)
	-- An invisible anchor: every client draws the pad itself (Build.client, tag "StepPad").
	local at = s.plot.frame * CFrame.new(pad.x, 0, pad.z)
	local p = Style.P(s.plot.built, Vector3.new(0.5, 4, 4), at * CFrame.new(0, 0.27, 0) * CFrame.Angles(0, 0, math.pi / 2), PAD_COLOR, nil, Enum.PartType.Cylinder)
	p.Transparency = 1
	p.CastShadow = false
	p.CanCollide = false
	p.CanTouch = false
	p.Name = "Pad_" .. (pad.id or "x")
	p:SetAttribute("PadKind", kind or "build")
	CollectionService:AddTag(p, "StepPad")
	-- the client draws the price card and the preview from these
	p:SetAttribute("Title", label)
	p:SetAttribute("Cost", cost)
	p:SetAttribute("Income", income)
	p:SetAttribute("Feature", pad.feature or Config.districtLine(pad)) -- what it does, or its district bonus
	p:SetAttribute("OwnerId", player.UserId)
	p:SetAttribute("PadId", pad.id)
	buildPreview(s, pad, p)
	-- Buying is a position check in the pad loop below, not .Touched: a foot grazing a thin
	-- pad top fires Touched unreliably, so walking on a pad often did nothing.
	s.padData = s.padData or {}
	s.padData[p] = { cost = cost, onBuy = onBuy }
	return p
end

-- the one place a pad is paid for (standing on it, or Heavenly Hands)
local function buyPad(s, part, info)
	info.busy = true
	s.padData[part] = nil
	s.data.qi -= info.cost
	info.onBuy()
end

-- Every 0.1 s: is an owner standing on one of their pads? (horizontal distance + height band)
local PAD_REACH = 2.6 -- the pad top is 4 studs wide
local function checkPads()
	for player, s in sessions do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 and s.padData then
			-- After a buy, every pad waits until the player stands on none of them: the step-out
			-- move (or a new pad spawning underfoot) once landed on the next pad and chained 5 buys.
			local onAny = false
			for part, info in s.padData do
				if not part.Parent then
					s.padData[part] = nil
				elseif not info.busy then
					local d = hrp.Position - part.Position
					if Vector2.new(d.X, d.Z).Magnitude < PAD_REACH and d.Y > -1 and d.Y < 7 then
						onAny = true
						if s.padHold then
							break
						end
						if s.data.qi >= info.cost then
							s.padHold = true
							buyPad(s, part, info)
						end
						break -- one pad per player per tick
					end
				end
			end
			if not onAny then
				s.padHold = nil
			end
		end
	end
end

local function lightning(s)
	local top = s.plot.frame * CFrame.new(0, 0, 0)
	local pos = top.Position + Vector3.new(0, 1, 0)
	local last = pos + Vector3.new(0, 220, 0)
	local rng = Random.new()
	for i = 1, 12 do
		local nextPos = pos + Vector3.new(rng:NextNumber(-8, 8), 220 * (1 - i / 12), rng:NextNumber(-8, 8))
		if i == 12 then
			nextPos = pos
		end
		local b = Instance.new("Part")
		b.Anchored = true
		b.CanCollide = false
		b.Material = Enum.Material.Neon
		b.Color = Color3.fromRGB(190, 200, 255)
		local len = (nextPos - last).Magnitude
		b.Size = Vector3.new(1.2, 1.2, len)
		b.CFrame = CFrame.lookAt((last + nextPos) / 2, nextPos)
		b.Parent = world
		game:GetService("Debris"):AddItem(b, 0.6)
		last = nextPos
	end
	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide = false
	flash.Transparency = 1
	flash.Position = pos + Vector3.new(0, 10, 0)
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 8
	light.Color = Color3.fromRGB(200, 210, 255)
	light.Parent = flash
	flash.Parent = world
	game:GetService("Debris"):AddItem(flash, 0.5)
end

local function rebuild(s)
	s.plot.built:ClearAllChildren()
	s.pads = {}
	-- the island's size follows the expansions owned (a breakthrough shrinks it back)
	local radius = Config.islandRadius(s.data.owned)
	local level = Config.expansionLevel(s.data.owned)
	s.plot.realm = s.data.realm
	if s.plot.radius ~= radius or s.plot.landLevel ~= level then
		s.plot.landLevel = level
		buildGrounds(s.plot, radius, Config.islandLobes(s.data.owned))
	else
		RealmLook.apply(s.plot) -- what this realm shows around the peak (nothing below REALM_LOOK_FROM)
	end
	local hallLevel = Config.mainHallLevel(s.data.owned)
	for _, pad in Config.PADS do
		local lv = tonumber(pad.id:match("^mainhall(%d)$"))
		-- only the highest Main Hall level stands
		if s.data.owned[pad.id] and (not lv or lv == hallLevel) then
			local m = buildModel(s, pad)
			m.Parent = s.plot.built
			paintGround(m)
		end
	end
	buildDisciples(s)
	buildWorkers(s)
end

refreshPads = function(player, s)
	-- only add and remove what changed (rebuilding every pad made all cards and beacons flicker)
	local mult = Config.costMult(s.data.realm)
	local wanted = {}
	local all = true
	local ownedCount = 0
	for _ in s.data.owned do
		ownedCount += 1
	end
	for _, pad in Config.PADS do
		if not s.data.owned[pad.id] then
			all = false
			local ready = ownedCount >= (pad.unlock or 0)
			for _, r in pad.req do
				if not s.data.owned[r] then
					ready = false
				end
			end
			wanted[pad.id] = ready
		end
	end
	if all then
		wanted.breakthrough = true
	end
	-- a hire pad beside every owned building that takes workers, until it has WORKER_MAX
	for id in Config.WORKERS do
		if s.data.owned[id] and ((s.data.workers or {})[id] or 0) < Config.WORKER_MAX then
			wanted["hire_" .. id] = true
		end
	end
	for id, p in s.pads do
		if not wanted[id] or not p.Parent then
			p:Destroy()
			s.pads[id] = nil
		end
	end
	for _, pad in Config.PADS do
		if not s.data.owned[pad.id] then
			local ready = wanted[pad.id]
			if ready and not s.pads[pad.id] then
				local cost = math.floor(pad.cost * mult)
				local income = pad.income * Config.incomeMult(s.data.realm)
				s.pads[pad.id] = makePad(player, s, pad, cost, pad.name, income, function()
					s.data.owned[pad.id] = true
					Telemetry.sink(player, s.data, cost, pad.id)
					Telemetry.funnel(player, s.data)
					-- BuiltAt tells clients to play the assemble animation for this model
					-- a Main Hall level replaces the one before it
					local lv = tonumber(pad.id:match("^mainhall(%d)$"))
					if lv and lv > 1 then
						local prev = s.plot.built:FindFirstChild("mainhall" .. (lv - 1))
						if prev then
							prev:Destroy()
						end
					end
					-- an expansion grows the island under the player's feet
					if pad.id == "expand1" or pad.id == "expand2" then
						s.plot.landLevel = Config.expansionLevel(s.data.owned)
						buildGrounds(s.plot, Config.islandRadius(s.data.owned), Config.islandLobes(s.data.owned))
						notify:FireClient(player, "expand")
					end
					local m = buildModel(s, pad, { BuiltAt = workspace:GetServerTimeNow() })
					m.Parent = s.plot.built
					paintGround(m)
					-- never leave the buyer standing inside what they just built: step them out front
					local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if hrp and m:FindFirstChildWhichIsA("BasePart", true) then -- (expansions build nothing)
						local bcf, bsize = m:GetBoundingBox()
						local lp = bcf:PointToObjectSpace(hrp.Position)
						if math.abs(lp.X) < bsize.X / 2 + 1 and math.abs(lp.Z) < bsize.Z / 2 + 1 and lp.Y < bsize.Y / 2 then
							local out = -s.plot.frame.LookVector -- the frame's +Z (toward the bridge)
							local reach = math.max(bsize.X, bsize.Z) / 2 + 3
							hrp.CFrame = CFrame.new(bcf.Position.X, hrp.Position.Y + 1, bcf.Position.Z) + out * reach
						end
					end
					if pad.id == "platform" then
						buildDisciples(s)
					end
					refreshPads(player, s)
					publish(player)
					notify:FireClient(player, "built", pad.name)
				end)
			end
		end
	end
	for id, spec in Config.WORKERS do
		local key = "hire_" .. id
		local pad = Config.padById(id)
		if wanted[key] and pad and not s.pads[key] then
			local n = ((s.data.workers or {})[id] or 0) + 1
			local cost = Config.workerCost(pad, n, s.data.realm)
			local income = pad.income * Config.incomeMult(s.data.realm) * Config.WORKER_BONUS
			local p = makePad(player, s, { id = key, x = spec.x, z = spec.z }, cost, spec.name, income, function()
				s.data.workers = s.data.workers or {}
				s.data.workers[id] = n
				Telemetry.sink(player, s.data, cost, key)
				-- the next hire costs more: a fresh pad (its card shows one more dot)
				if s.pads[key] then
					s.pads[key]:Destroy()
					s.pads[key] = nil
				end
				local folder = s.plot.built:FindFirstChild("Workers")
				if folder then
					Workers.build(folder, s.plot.frame, pad, n, { s.plot.built, workspace.Terrain })
				else
					buildWorkers(s)
				end
				refreshPads(player, s)
				publish(player)
			end, "hire")
			p.Name = "Hire_" .. id -- not "Pad_": the HUD goal and the guide trail lead to buildings only
			p:SetAttribute("Hired", n - 1)
			p:SetAttribute("HireMax", Config.WORKER_MAX)
			s.pads[key] = p
		end
	end
	if all and not s.pads.breakthrough then
		local cost = math.floor(Config.BREAKTHROUGH_COST * mult)
		local nextName = Config.realmName(s.data.realm + 1)
		local bt = { id = "breakthrough", x = 0, z = 14 }
		s.pads.breakthrough = makePad(player, s, bt, cost, "Breakthrough: " .. nextName, 0, function()
			Telemetry.sink(player, s.data, cost, "breakthrough")
			s.data.realm += 1
			s.data.best = math.max(s.data.best or 1, s.data.realm)
			Telemetry.realm(player, s.data.realm)
			Telemetry.funnel(player, s.data)
			s.data.owned = {}
			s.data.workers = {}
			s.data.qi = 0
			s.data.pillReady = false
			s.data.pillTimer = 0
			s.data.realmRecruits = 0
			lightning(s)
			rebuild(s)
			refreshPads(player, s)
			publish(player)
			notify:FireAllClients("breakthrough", player.DisplayName, nextName)
			local line = Config.realmLookLine(s.data.realm)
			if line then
				notify:FireClient(player, "realmLook", line)
			end
		end, "breakthrough")
		s.pads.breakthrough.Color = Color3.fromRGB(255, 210, 90)
	end
	Shop.refreshPeak(s) -- the shop items that stand where they act (passes at the entrance, pill, orbs)
end

-- Saving (SaveStore holds the session lock) ------------------------------------------
local pendingSaves = 0

-- One save in flight per player (Gladiator R5): a second UpdateAsync on the same key would queue
-- behind the first and spend budget for nothing. `release` = the last save of this session (leave
-- or close); later saves are skipped. `urgent` (a receipt) waits its turn and writes; a plain
-- autosave is skipped while another save of this player is in flight (that one is just as fresh).
-- Returns true when the write landed.
local function save(s, release, urgent)
	if not store or not s.loaded or s.released then
		return false
	end
	if s.saving and not release and not urgent then
		return false
	end
	pendingSaves += 1 -- counted while it waits too, so BindToClose waits for it
	while s.saving do
		task.wait(0.1)
	end
	if s.released then
		pendingSaves -= 1
		return false
	end
	if release then
		s.released = true
	end
	s.saving = true
	s.data.last = os.time()
	local snapshot = deepCopy(s.data) -- the session keeps changing while UpdateAsync yields
	local ok, landed = pcall(SaveStore.save, store, s.userId, s.sessionId, snapshot, release)
	s.saving = false
	pendingSaves -= 1
	return ok and landed
end

-- Additive backfill: a key the save lacks takes its default (nested tables too), a stored value is
-- never replaced or retyped. Maps where a missing key means "not owned" default to {} so nothing
-- is invented in them.
local function backfill(d, default)
	for k, v in default do
		if d[k] == nil then
			d[k] = if type(v) == "table" then deepCopy(v) else v
		elseif type(v) == "table" and type(d[k]) == "table" then
			backfill(d[k], v)
		end
	end
	return d
end

local function load(player, sessionId)
	local data, loaded, reason = nil, true, nil
	if store then
		data, loaded, reason = SaveStore.load(store, player.UserId, sessionId, function()
			return player.Parent ~= nil
		end)
	end
	local d = if type(data) == "table" then backfill(data, defaultData()) else defaultData()
	return d, loaded, reason
end

-- A join whose save could not be loaded is asked to rejoin, never played without saving (Gladiator
-- R5: fail closed; progress made in such a session would be lost).
local KICK_TEXT = {
	locked = "Your sect is still open on another server. Please rejoin in a minute.",
	newer = "This server is out of date. Please rejoin to get a new one.",
	error = "We could not load your sect right now. Please rejoin.",
}

-- Join / leave -----------------------------------------------------------------------
-- a free peak beside a friend's when there is one (D35), else the first free peak; second value =
-- placed next to a friend
local function freePlot(friends)
	for _, plot in plots do
		if plot.owner and friends[plot.owner] then
			for _, step in { 1, -1 } do
				local side = plots[(plot.index - 1 + step) % Config.PLOT_COUNT + 1]
				if not side.owner then
					return side, true
				end
			end
		end
	end
	for _, plot in plots do
		if not plot.owner then
			return plot, false
		end
	end
	return nil, false
end

-- the Roblox friends of `player` on this server, both ways; yields (one web call per other player)
local function findFriends(player)
	local mine = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, yes = pcall(player.IsFriendsWith, player, other.UserId)
			if ok and yes then
				mine[other] = true
			end
		end
	end
	if not player.Parent then
		return mine
	end
	for other, theirs in friendsOf do
		if theirs[player] then
			mine[other] = true -- found us while our own check was still running
		end
	end
	friendsOf[player] = mine
	for other in mine do
		if friendsOf[other] then
			friendsOf[other][player] = true
		end
	end
	return mine
end

-- after a friend's session starts or ends, their friends' rates change
local function publishFriends(player)
	for other in friendsOf[player] or {} do
		if sessions[other] then
			publish(other)
		end
	end
end

local function placeOnPeak(player)
	local s = sessions[player]
	local char = player.Character
	if s and char then
		char:PivotTo(s.plot.frame * CFrame.new(0, 4, (s.plot.radius or Config.ISLAND_RADIUS) - 8))
	end
end

local function onJoin(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local realm = Instance.new("IntValue")
	realm.Name = "Realm"
	realm.Parent = ls
	ls.Parent = player

	local friends = findFriends(player)
	if not player.Parent then
		return
	end
	local plot, nextDoor = freePlot(friends)
	if not plot then
		warn("[Tycoon] no free peak for", player.Name)
		return
	end
	if nextDoor then
		Telemetry.custom(player, "Social", "next_door")
	end
	plot.owner = player
	player:SetAttribute("PlotIndex", plot.index) -- clients place their effects with it
	setPlotLabel(plot, player.DisplayName .. "'s Sect")
	local sessionId = SaveStore.newSessionId()
	local data, loaded, reason = load(player, sessionId)
	if store and not loaded and player.Parent then
		plot.owner = nil
		setPlotLabel(plot, "Unclaimed Peak")
		Telemetry.custom(player, "SaveIssue", reason or "error")
		player:Kick(KICK_TEXT[reason] or KICK_TEXT.error)
		return
	end
	if not player.Parent then
		plot.owner = nil
		setPlotLabel(plot, "Unclaimed Peak")
		if store and loaded then
			-- hand the lock back untouched (same data, same `last`) so a rejoin is not blocked
			SaveStore.save(store, player.UserId, sessionId, data, true)
		end
		return
	end
	local s = { data = data, plot = plot, pads = {}, loaded = loaded, userId = player.UserId, sessionId = sessionId, player = player }
	sessions[player] = s
	Shop.onJoin(player, s) -- yields for the pass checks
	if Config.GROUP_ID > 0 then
		local okG, member = pcall(player.IsInGroup, player, Config.GROUP_ID) -- yields; before the offline qi
		s.inGroup = okG and member == true
	end
	if not player.Parent then
		return -- onLeave already ran (it found the session) and saved
	end
	if plot.vip then
		plot.radius = nil -- rebuild() below redraws the grounds with the gold arch
	end

	-- Heavenly Gift (D36): only a save that never joined before gets it; a save from before the gift
	-- existed counts as already welcomed. Stamped once, so it can never be paid twice.
	if data.welcomed == nil then
		data.welcomed = (data.sessions or 0) > 0
	end

	-- offline qi
	local away = math.clamp(os.time() - (data.last or os.time()), 0, Config.OFFLINE_CAP + Config.DAO_OFFLINE_SECONDS * dao(data, "meditation"))
	local offlineGain = 0
	if away > 60 then
		offlineGain = math.floor(rate(s, true) * away * Config.OFFLINE_RATE)
		data.qi += offlineGain
		Telemetry.source(player, data, offlineGain, "offline", true)
	end
	-- idle chest: a free summon per CHEST_SUMMON_EVERY s away; unopened ones wait (capped)
	local newSummons = math.floor(away / Config.CHEST_SUMMON_EVERY)
	data.chestSummons = math.min((data.chestSummons or 0) + newSummons, Config.CHEST_SUMMON_MAX)
	player:SetAttribute("ChestSummons", data.chestSummons)
	if away > 60 then
		Telemetry.custom(player, "IdleChest", Telemetry.hourBucket(away), tostring(data.chestSummons), Telemetry.realmBucket(data.realm))
	end
	data.sessions = (data.sessions or 0) + 1
	s.joinedAt = os.clock()
	s.earned, s.orbEarned = 0, 0
	Telemetry.funnel(player, data)

	rebuild(s)
	refreshPads(player, s)
	publish(player)
	publishFriends(player)
	if offlineGain > 0 or data.chestSummons > 0 then
		task.delay(3, function()
			-- the return screen (IdleChest.client): the chest bursts, then the summons wait to be tapped
			notify:FireClient(player, "idleChest", offlineGain, away, data.chestSummons)
		end)
	end
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		placeOnPeak(player)
	end)
	if player.Character then
		placeOnPeak(player)
	end
end

local function onLeave(player)
	local s = sessions[player]
	local friends = friendsOf[player] or {}
	friendsOf[player] = nil
	for other in friends do
		if friendsOf[other] then
			friendsOf[other][player] = nil
		end
	end
	if not s then
		return
	end
	sessions[player] = nil
	for other in friends do
		if sessions[other] then
			publish(other)
		end
	end
	if (s.friendsPeak or 0) > 0 then
		Telemetry.custom(player, "Social", "friends_here", tostring(s.friendsPeak), Telemetry.minuteBucket(os.clock() - (s.joinedAt or os.clock())))
	end
	local built = 0
	for id in s.data.owned do
		if Config.padById(id) then
			built += 1
		end
	end
	Telemetry.source(player, s.data, s.earned or 0, "income")
	Telemetry.source(player, s.data, s.orbEarned or 0, "orb")
	Telemetry.custom(player, "SessionEnd", Telemetry.builtBucket(built), Telemetry.minuteBucket(os.clock() - (s.joinedAt or os.clock())), s.data.sessions == 1 and "first" or "return")
	save(s, true)
	s.plot.built:ClearAllChildren()
	Shop.clearPeak(s.plot)
	s.plot.owner = nil
	s.plot.vip = nil
	setPlotLabel(s.plot, "Unclaimed Peak")
	s.plot.realm = nil
	s.plot.landLevel = 0
	buildGrounds(s.plot, Config.ISLAND_RADIUS) -- back to a fresh peak for the next owner
end

-- Recruit ----------------------------------------------------------------------------
local function roll()
	local total = 0
	for _, r in Config.RARITIES do
		total += r.weight
	end
	local x = Random.new():NextNumber(0, total)
	for _, r in Config.RARITIES do
		x -= r.weight
		if x <= 0 then
			return r
		end
	end
	return Config.RARITIES[1]
end

local function byBonus(a, b)
	return Config.rarity(a).bonus > Config.rarity(b).bonus
end

-- Seat a new disciple (a recruit, or one bought in the Shop). Returns true when it works a seat;
-- false = the sect is full of stronger ones and it left (`force` keeps it on the bench instead).
local function addDisciple(s, name, force)
	local list = s.data.disciples
	local max = maxDisciples(s)
	table.sort(list, byBonus)
	local kept = #list < max or Config.rarity(name).bonus > Config.rarity(list[max]).bonus
	if kept or force then
		-- full: the newcomer takes the weakest working seat (it joins and the list re-sorts)
		table.insert(list, name)
	end
	table.sort(list, byBonus)
	-- keep at most as many as the largest possible sect (benched ones beyond the slots), dropping
	-- the weakest UNBOUGHT one: a disciple paid for with Robux (data.boughtDisciples) never leaves,
	-- even if that leaves the list over the cap
	local paid = table.clone(s.data.boughtDisciples or {})
	local keep = {}
	for i, name in list do -- strongest first: the bought copies are the strongest of their name
		if (paid[name] or 0) > 0 then
			paid[name] -= 1
			keep[i] = true
		end
	end
	for i = #list, 1, -1 do
		if #list <= Config.DISCIPLE_CAP then
			break
		end
		if not keep[i] then
			table.remove(list, i)
		end
	end
	buildDisciples(s)
	return kept
end

-- one free summon from the idle chest: the same roll and seating as a recruit, no qi
chestFn.OnServerInvoke = function(player)
	if not Guard.allow(player, "ChestSummon") then
		return nil -- over its call budget (Guard)
	end
	local s = sessions[player]
	if not s or s.recruiting or (s.data.chestSummons or 0) <= 0 then
		return nil
	end
	s.recruiting = true
	s.data.chestSummons -= 1
	player:SetAttribute("ChestSummons", s.data.chestSummons)
	local r = roll()
	local kept = addDisciple(s, r.name)
	-- a rolled rarity keeps its "first pulled" mark, as with a recruit
	s.data.pulled = s.data.pulled or {}
	s.data.pulled[r.name] = true
	publish(player)
	Telemetry.custom(player, "Recruit", r.name, Telemetry.realmBucket(s.data.realm), kept and "kept" or "benched")
	s.recruiting = false
	return { rarity = r.name, kept = kept, left = s.data.chestSummons }
end

recruitFn.OnServerInvoke = function(player)
	if not Guard.allow(player, "Recruit") then
		return nil -- over its call budget (Guard)
	end
	local s = sessions[player]
	if not s or s.recruiting then
		return nil
	end
	if not s.data.owned.hall then
		return { ok = false, reason = "Build the Disciple Hall first" }
	end
	local cost = Config.recruitCost(s.data.realm, s.data.realmRecruits or 0)
	if s.data.qi < cost then
		return { ok = false, reason = "Not enough Qi" }
	end
	s.recruiting = true
	s.data.qi -= cost
	s.data.recruited += 1 -- lifetime (telemetry)
	s.data.realmRecruits = (s.data.realmRecruits or 0) + 1 -- prices the next roll; reset at a breakthrough
	Telemetry.sink(player, s.data, cost, "recruit")
	local r = roll()
	local kept = addDisciple(s, r.name)
	publish(player)
	Telemetry.custom(player, "Recruit", r.name, Telemetry.realmBucket(s.data.realm), kept and "kept" or "benched")
	-- a rarity rolled at least once keeps a "first pulled" mark (the Shop also sells it, D28)
	s.data.pulled = s.data.pulled or {}
	if not s.data.pulled[r.name] then
		s.data.pulled[r.name] = true
		publish(player)
	end
	Telemetry.funnel(player, s.data)
	s.recruiting = false
	return { ok = true, rarity = r.name, kept = kept }
end

-- Pill (Alchemy Furnace): brewed every PILL_INTERVAL; using it doubles qi/s for PILL_DURATION.
pillFn.OnServerInvoke = function(player)
	if not Guard.allow(player, "UsePill") then
		return nil -- over its call budget (Guard)
	end
	local s = sessions[player]
	if not s or not s.data.owned.furnace or not s.data.pillReady then
		return false
	end
	s.data.pillReady = false
	s.data.pillTimer = 0
	s.data.boostUntil = workspace:GetServerTimeNow() + Config.PILL_DURATION + Config.DAO_PILL_SECONDS * dao(s.data, "elixir")
	publish(player)
	Telemetry.custom(player, "Feature", "pill", Telemetry.realmBucket(s.data.realm))
	return true
end

giftFn.OnServerInvoke = function(player)
	if not Guard.allow(player, "ClaimGift") then
		return nil -- over its call budget (Guard)
	end
	local s = sessions[player]
	if not s then
		return nil
	end
	local gi = s.giftIdx or 1
	local at = Config.GIFT_TIMES[gi]
	if not at or (s.playTime or 0) < at then
		return nil
	end
	local gain = math.floor(rate(s, true) * Config.GIFT_VALUE[gi])
	s.giftIdx = gi + 1
	s.data.qi += gain
	publish(player)
	print(string.format("[Tycoon] gift %d claimed by %d after %d s", gi, player.UserId, math.floor(s.playTime)))
	return gain
end

-- Group gift (D35): the card asks for a like, then the group join, then Claim. Only the group is
-- checked or paid (a like has no API and rewarding one breaks Roblox rules). A fresh check, since
-- IsInGroup is cached for the whole session.
groupFn.OnServerInvoke = function(player)
	if not Guard.allow(player, "ClaimGroup") then
		return nil -- over its call budget (Guard)
	end
	local s = sessions[player]
	if not s or Config.GROUP_ID <= 0 then
		return nil
	end
	if s.data.groupClaimed and s.inGroup then
		return "claimed"
	end
	local now = os.clock()
	if now - (s.groupAskAt or 0) < 3 then
		return nil
	end
	s.groupAskAt = now
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if not ok then
		warn("[Tycoon] group check failed")
		return "error"
	end
	for _, g in groups do
		if g.Id == Config.GROUP_ID then
			s.inGroup = true
			local first = not s.data.groupClaimed
			s.data.groupClaimed = true
			publish(player)
			if first then
				Telemetry.custom(player, "Social", "group_claim", "", Telemetry.minuteBucket(s.data.playSec or 0))
			end
			return "claimed"
		end
	end
	return "notMember"
end

-- Heavenly Gift (D36): paid once per save, on the intro's GO
welcomeFn.OnServerInvoke = function(player)
	if not Guard.allow(player, "ClaimWelcome") then
		return nil -- over its call budget (Guard)
	end
	local s = sessions[player]
	if not s or s.data.welcomed ~= false then
		return nil
	end
	s.data.welcomed = true
	local gain = Config.WELCOME_QI
	s.data.qi += gain
	Telemetry.source(player, s.data, gain, "welcome")
	publish(player)
	return gain
end

inviteEv.OnServerEvent:Connect(function(player)
	if not Guard.allow(player, "SocialInvite") then
		return -- over its call budget (Guard)
	end
	local s = sessions[player]
	if not s or os.clock() - (s.inviteAt or 0) < 10 then
		return
	end
	s.inviteAt = os.clock()
	Telemetry.custom(player, "Social", "invite", tostring(friendCount(s)))
end)

-- Reincarnation: the ONE function every caller goes through, so the gate lives here. A new life
-- lands at realm 1, below the REINC_REALM gate, so it can never be repeated for free.
local function reincarnate(player, s)
	local d = s.data
	if d.realm < Config.REINC_REALM then
		return nil
	end
	local gained = karmaGain(d, builtShare(d))
	local lifeSec = (d.playSec or 0) - (d.lifeStart or 0)
	Telemetry.custom(player, "Reincarnate", Telemetry.lifeBucket(d.lives or 1), Telemetry.deepBucket(d.realm), Telemetry.hourBucket(lifeSec))
	print(string.format("[Tycoon] %d reincarnated: life %d ended at realm %d, +%d karma", player.UserId, d.lives or 1, d.realm, gained))
	d.karma = (d.karma or 0) + gained
	d.soulPeak = math.max(d.soulPeak or 0, d.realm)
	d.lives = (d.lives or 1) + 1
	d.lifeStart = d.playSec or 0
	d.realm = 1 -- always below the REINC_REALM gate (D37 removed the Rebirth Gate node)
	d.owned = {}
	d.workers = {}
	if dao(d, "foundation") > 0 then
		-- Old Foundations: the new life starts with every building of its landing realm (skips the walk)
		for _, pad in Config.PADS do
			d.owned[pad.id] = true
		end
	end
	d.qi = 0
	d.pillReady = false
	d.pillTimer = 0
	d.boostUntil = 0
	d.realmRecruits = 0
	-- disciples bought in the Shop are permanent (data.boughtDisciples = { [rarity] = count }) and
	-- do not use a sworn seat; then the SWORN_BASE strongest of the rest follow (list is sorted)
	local bought = table.clone(d.boughtDisciples or {}) -- counted down as they are found in the list
	local kept, sworn = {}, 0
	for _, name in d.disciples do
		if (bought[name] or 0) > 0 then
			bought[name] -= 1
			table.insert(kept, name)
		elseif sworn < Config.SWORN_BASE + dao(d, "sworn") then
			sworn += 1
			table.insert(kept, name)
		end
	end
	d.disciples = kept
	lightning(s)
	rebuild(s)
	refreshPads(player, s)
	publish(player)
	task.spawn(save, s, false, true)
	notify:FireAllClients("reincarnate", player.DisplayName, d.lives)
	return { karma = gained, lives = d.lives, pastLives = Config.pastLivesMult(d.soulPeak) }
end

-- Karma Shop: buy the next level of one node (server checks the price and the cap, R9)
daoFn.OnServerInvoke = function(player, key)
	if not Guard.allow(player, "DaoBuy") then
		return nil -- over its call budget (Guard)
	end
	local s = sessions[player]
	local node = type(key) == "string" and Config.daoNode(key)
	if not s or not node then
		return false
	end
	local d = s.data
	d.dao = d.dao or {}
	local lv = d.dao[key] or 0
	local cost = node.costs[lv + 1]
	if not cost or (d.karma or 0) < cost then
		return false
	end
	d.karma -= cost
	d.dao[key] = lv + 1
	if key == "seat" then
		buildDisciples(s) -- a benched disciple takes the new seat
	end
	publish(player)
	Telemetry.custom(player, "KarmaShop", key, lv + 1, Telemetry.lifeBucket(d.lives or 1))
	return true
end

-- Heavenly Hands (Karma Shop): build one of your open pads from anywhere. The client names the pad
-- its HUD "Next" card shows; the server checks the node, the owner, the price and a cooldown (R9).
handsFn.OnServerInvoke = function(player, padId)
	if not Guard.allow(player, "HandsBuild") then
		return nil -- over its call budget (Guard)
	end
	local s = sessions[player]
	if not s or type(padId) ~= "string" or #padId > 32 or dao(s.data, "hands") <= 0 then
		return false
	end
	local now = os.clock()
	if now < (s.handsAt or 0) then
		return false
	end
	s.handsAt = now + Config.HANDS_COOLDOWN
	local part = s.pads and s.pads[padId]
	local info = part and s.padData and s.padData[part]
	if not info or info.busy or s.data.qi < info.cost then
		return false
	end
	buyPad(s, part, info)
	return true
end

reincFn.OnServerInvoke = function(player)
	if not Guard.allow(player, "Reincarnate") then
		return nil -- over its call budget (Guard)
	end
	local s = sessions[player]
	if not s or s.reincBusy then
		return nil
	end
	s.reincBusy = true
	local ok, res = pcall(reincarnate, player, s)
	s.reincBusy = false
	if not ok then
		warn("[Tycoon] reincarnation failed")
		print("[Tycoon] reincarnation error:", res)
		return nil
	end
	return res
end

-- Qi orbs (Qi Gathering Array): open grass spots in the peak's local frame
local ORB_SPOTS = {
	Vector2.new(-7, 16), Vector2.new(7, 16), Vector2.new(-42, 26), Vector2.new(42, 24),
	Vector2.new(-14, -12), Vector2.new(14, -12), Vector2.new(-18, 48), Vector2.new(18, 48),
}
local function spawnOrb(s)
	s.orbs = s.orbs or {}
	for i = #s.orbs, 1, -1 do
		if not s.orbs[i].Parent then
			table.remove(s.orbs, i)
		end
	end
	if #s.orbs >= Config.ORB_MAX then
		return
	end
	local free = {}
	for _, spot in ORB_SPOTS do
		local taken = false
		for _, o in s.orbs do
			if o:GetAttribute("Spot") == spot.X * 1000 + spot.Y then
				taken = true
			end
		end
		if not taken then
			table.insert(free, spot)
		end
	end
	if #free == 0 then
		return
	end
	local spot = free[math.random(#free)]
	local orb = Instance.new("Part")
	orb.Name = "QiOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(2.2, 2.2, 2.2)
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.CastShadow = false
	orb.Material = Enum.Material.Neon -- the orb is a glowing object holding its own light
	orb.Color = Color3.fromHex("9FF5D0")
	orb.CFrame = s.plot.frame * CFrame.new(spot.X, 3.2, spot.Y)
	orb:SetAttribute("Spot", spot.X * 1000 + spot.Y)
	orb:SetAttribute("Age", os.clock()) -- Auto Orbs waits a moment so the orb is seen first
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("6FB59C")
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = orb
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(Color3.fromHex("E8FFF4"))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.3, 0)
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.Lifetime = NumberRange.new(0.8, 1.2)
	sparkle.Rate = 8
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = orb
	orb.Parent = s.plot.built
	table.insert(s.orbs, orb)
end

local function checkOrbs(player, s, hrp)
	if not s.orbs then
		return
	end
	-- Auto Orbs pass: while the owner stands on their own peak, every orb flies to them
	local flat = hrp.Position - s.plot.center
	local auto = s.passes and s.passes.auto and Vector2.new(flat.X, flat.Z).Magnitude < (s.plot.radius or Config.ISLAND_RADIUS) + 4
	for i = #s.orbs, 1, -1 do
		local orb = s.orbs[i]
		if not orb.Parent then
			table.remove(s.orbs, i)
		elseif (orb.Position - hrp.Position).Magnitude < 4.5 or (auto and os.clock() - (orb:GetAttribute("Age") or 0) > 1.5) then
			local gain = math.floor(rate(s) * Config.ORB_VALUE)
			s.data.qi += gain
			s.orbEarned = (s.orbEarned or 0) + gain
			Telemetry.custom(player, "Feature", "orb", Telemetry.realmBucket(s.data.realm))
			notify:FireClient(player, "orb", gain, orb.Position)
			orb:Destroy()
			table.remove(s.orbs, i)
			publish(player)
		end
	end
end

-- Studio-only test hook: ServerStorage.DebugGrant:Invoke(player, qi) adds qi.
if game:GetService("RunService"):IsStudio() then
	local grant = Instance.new("BindableFunction")
	grant.Name = "DebugGrant"
	grant.OnInvoke = function(player, amount)
		local s = sessions[player]
		if s then
			s.data.qi += amount
			publish(player)
			return s.data.qi
		end
		return nil
	end
	grant.Parent = game:GetService("ServerStorage")
	-- ServerStorage.DebugReset:Invoke(player) wipes the (Studio-only) save back to a new player
	local reset = Instance.new("BindableFunction")
	reset.Name = "DebugReset"
	reset.OnInvoke = function(player)
		local s = sessions[player]
		if s then
			s.data = defaultData()
			rebuild(s)
			refreshPads(player, s)
			publish(player)
			return true
		end
		return false
	end
	reset.Parent = game:GetService("ServerStorage")
	-- ServerStorage.DebugSet:Invoke(player, key, value) sets one save field (pill timers etc.)
	local set = Instance.new("BindableFunction")
	set.Name = "DebugSet"
	set.OnInvoke = function(player, key, value)
		local s = sessions[player]
		if s then
			if key == "pass" then
				Shop.debugPass(player, s, value) -- DebugSet:Invoke(player, "pass", "x2")
				return true
			end
			if key == "friend" then
				-- DebugSet:Invoke(player, "friend", other) counts `other` as a friend here (Studio test
				-- players are never Roblox friends; `other` may be `player` itself in a solo Play)
				friendsOf[player] = friendsOf[player] or {}
				friendsOf[player][value] = true
				friendsOf[value] = friendsOf[value] or {}
				friendsOf[value][player] = true
				publish(player)
				if sessions[value] then
					publish(value)
				end
				return true
			end
			if key == "altar" then
				Altar.debugOpen() -- DebugSet:Invoke(player, "altar") opens a Heavenly Altar round now
				return true
			end
			s.data[key] = value
			if key == "orbNow" then
				spawnOrb(s)
			elseif key == "owned" or key == "workers" then
				rebuild(s) -- DebugSet:Invoke(player, "workers", { garden = 3 })
				refreshPads(player, s)
			end
			if key == "realm" or key == "owned" then
				rebuild(s) -- DebugSet:Invoke(player, "realm", 9) shows that realm's look (RealmLook)
				refreshPads(player, s)
			end
			publish(player)
			return true
		end
		return false
	end
	set.Parent = game:GetService("ServerStorage")
end

-- Shop: a pass bought or found on join changes what this session earns or shows
local function passChanged(player, s, key)
	if key == "vip" then
		s.plot.vip = true
		buildGrounds(s.plot, Config.islandRadius(s.data.owned), Config.islandLobes(s.data.owned)) -- redraws the arch in gold
		buildDisciples(s) -- the extra slot seats a benched disciple
	end
	publish(player)
end

-- Boot -------------------------------------------------------------------------------
buildHub()
Altar.init({
	sessions = sessions,
	rate = rate,
	publish = publish,
	notify = notify,
	remotes = remotes,
	telemetry = Telemetry,
	style = Style,
	baseY = BASE_Y,
}, world)
Shop.init({
	sessions = sessions,
	rate = rate,
	publish = publish,
	save = function(s) -- a receipt: waits for any save in flight, then writes (urgent)
		return save(s, false, true)
	end,
	canSave = function()
		return store ~= nil
	end,
	notify = notify,
	passChanged = passChanged,
	addDisciple = function(s, name)
		local kept = addDisciple(s, name, true) -- paid for: never turned away
		publish(s.player)
		return kept
	end,
	remotes = remotes,
	style = Style,
	kit = Kit,
	styleP = Style.P,
	palette = Style.PAL,
	cultivators = Cultivators,
})
setupLighting()
buildPlots()

ServerHealth.start()
Players.PlayerAdded:Connect(onJoin)
Players.PlayerRemoving:Connect(onLeave)
for _, p in Players:GetPlayers() do
	task.spawn(onJoin, p)
end

game:BindToClose(function()
	for _, s in sessions do
		task.spawn(save, s, true)
	end
	-- leave saves started by PlayerRemoving count too; Roblox allows ~30 s here
	local deadline = os.clock() + 25
	while pendingSaves > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		local ok, err = pcall(checkPads)
		if not ok then
			warn("[Tycoon] pad check failed:", err)
		end
		for player, s in sessions do
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				checkOrbs(player, s, hrp)
			end
		end
	end
end)

-- Spirit Tide schedule: TideNext / TideUntil are Workspace attributes (server time) so clients
-- can draw it; a heads-up goes out TIDE_WARN s before it starts
local tideWarned = false
workspace:SetAttribute("TideNext", workspace:GetServerTimeNow() + Config.TIDE_FIRST)
local function tideTick()
	local now = workspace:GetServerTimeNow()
	local nextAt = workspace:GetAttribute("TideNext")
	if not tideWarned and now >= nextAt - Config.TIDE_WARN then
		tideWarned = true
		notify:FireAllClients("tideSoon", math.max(1, math.ceil(nextAt - now)))
	end
	if now >= nextAt then
		tideWarned = false
		workspace:SetAttribute("TideUntil", now + Config.TIDE_DURATION)
		workspace:SetAttribute("TideNext", now + Config.TIDE_INTERVAL)
		notify:FireAllClients("tide", Config.TIDE_DURATION)
		local n = 0
		for _ in sessions do
			n += 1
		end
		print(string.format("[Tycoon] spirit tide started, %d players", n))
	end
end

-- income tick + autosave
local sinceSave = 0
while true do
	local dt = task.wait(1)
	sinceSave += dt
	local okTide, tideErr = pcall(tideTick)
	if not okTide then
		warn("[Tycoon] spirit tide tick failed:", tideErr)
	end
	for player, s in sessions do
		local d = s.data
		local gain = rate(s) * dt
		d.qi += gain
		s.earned = (s.earned or 0) + gain
		s.playTime = (s.playTime or 0) + dt
		d.playSec = (d.playSec or 0) + dt
		-- Alchemy Furnace brews a pill while none is waiting
		if d.owned.furnace and not d.pillReady then
			d.pillTimer = (d.pillTimer or 0) + dt
			if d.pillTimer >= Config.PILL_INTERVAL then
				d.pillReady = true
				notify:FireClient(player, "pill")
			end
		end
		-- Qi Gathering Array drops an orb every ORB_INTERVAL
		if d.owned.array then
			s.orbTimer = (s.orbTimer or 0) + dt
			if s.orbTimer >= Config.ORB_INTERVAL then
				s.orbTimer = 0
				spawnOrb(s)
			end
		end
		publish(player)
	end
	if sinceSave >= Config.AUTOSAVE then
		sinceSave = 0
		local due = {}
		for player, s in sessions do
			Telemetry.source(player, s.data, s.earned or 0, "income")
			Telemetry.source(player, s.data, s.orbEarned or 0, "orb")
			s.earned, s.orbEarned = 0, 0
			table.insert(due, s)
		end
		-- staggered, and only with budget: player saves never starve leave saves and receipts
		task.spawn(function()
			for _, s in due do
				local waited = 0
				while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync) < Config.SAVE_MIN_BUDGET and waited < 10 do
					task.wait(1)
					waited += 1
				end
				task.spawn(save, s)
				task.wait(Config.SAVE_STAGGER)
			end
		end)
	end
end
