-- Cultivation Tycoon server: plots, qi income, pads, disciples, breakthrough, saving.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Builders = require(script.Parent:WaitForChild("Builders"))
local Style = require(script.Parent:WaitForChild("Style"))
local SaveStore = require(script.Parent:WaitForChild("SaveStore"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

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

-- Spots that must stay free of trees and boulders: the entrance path, every pad, the Main
-- Hall's largest footprint (level 5 with wings and towers) and the pagoda behind it.
local function keepClear(x, z)
	if math.abs(x) < 10 and z > 0 then
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
	return false
end

local WATERFALL_ANGLE = -1.75 -- back-left rim: clear of the Main Hall towers and the pagoda at every size

-- The peak's ground: island (terrain grass on top), rim trees, waterfall, rope bridge and
-- the entrance archway with the owner's name. Rebuilt whenever the island grows or shrinks.
local function buildGrounds(plot, radius)
	if plot.grounds then
		plot.grounds:Destroy()
	end
	-- clear the old terrain grass (largest island + margin; never reaches the hub or neighbours)
	-- (islands reach at most 1.05 x radius, so 1.05 x max + 6 stays clear of the neighbours at
	-- PLOT_RADIUS 215 and of the hub)
	workspace.Terrain:FillCylinder(plot.frame * CFrame.new(0, -6, 0), 20, Config.ISLAND_RADII[#Config.ISLAND_RADII] * 1.05 + 6, Enum.Material.Air)
	local g = Instance.new("Folder")
	g.Name = "Grounds"
	Style.island(g, plot.frame, radius, 100 + plot.index, keepClear, true)
	-- trees around the rim, wherever nothing is planned
	local n = math.floor(radius / 4)
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2 + 0.13
		local r = radius - 8 - (k % 2) * 3
		local x, z = math.cos(a) * r, math.sin(a) * r
		if not keepClear(x, z) then
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
	-- entrance archway carrying the owner's name
	local sign = Style.archway(g, plot.frame * CFrame.new(0, 0, radius - 1), 11, 10)
	sign.Name = "Sign"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
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
	g.Parent = plot.folder
	plot.grounds = g
	plot.label = label
	plot.radius = radius
end

-- Terrain grass blades grow through anything standing on them (stairs, stone floors), so
-- the ground under a structure turns to packed earth, which has no blades.
-- Only the parts that actually touch the ground are painted (plinths, steps, paths), so a
-- courtyard between buildings keeps its grass.
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
				workspace.Terrain:ReplaceMaterial(region, 4, Enum.Material.LeafyGrass, Enum.Material.Ground)
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
	return { qi = 0, realm = 1, owned = {}, disciples = {}, recruited = 0, last = os.time(), best = 1 }
end

-- The list is kept sorted strongest first; only the first maxDisciples work (the rest are
-- benched, e.g. after a breakthrough resets the Quarters).
local function discipleMult(data)
	local m = 1
	local max = Config.maxDisciples(data.owned)
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

-- `away` = offline qi (and gifts), which never count the live tide or a pill
local function rate(data, away)
	local base = Config.BASE_RATE
	for id in data.owned do
		local pad = Config.padById(id)
		if pad then
			base += pad.income
		end
	end
	local tide = (not away and tideOn()) and Config.TIDE_MULT or 1
	local pill = (not away and boosted(data)) and 2 or 1
	return base * Config.incomeMult(data.realm) * discipleMult(data) * pill * tide
end

local function publish(player)
	local s = sessions[player]
	if not s then
		return
	end
	local d = s.data
	player:SetAttribute("Qi", math.floor(d.qi))
	player:SetAttribute("Rate", rate(d))
	player:SetAttribute("Realm", d.realm)
	player:SetAttribute("RealmName", Config.realmName(d.realm))
	player:SetAttribute("HasHall", d.owned.hall == true)
	player:SetAttribute("RecruitCost", Config.recruitCost(d.realm, d.realmRecruits or 0))
	player:SetAttribute("Disciples", table.concat(d.disciples, ","))
	player:SetAttribute("MaxDisciples", Config.maxDisciples(d.owned))
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
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Realm.Value = d.realm
	end
end

local function ctxFor(s, folder)
	return { folder = folder or s.plot.built, frame = s.plot.frame, pal = Config.PALETTES[(s.data.realm - 1) % #Config.PALETTES + 1] }
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
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") then
			d.Enabled = false
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
	local max = Config.maxDisciples(s.data.owned)
	for slot, name in s.data.disciples do
		if slot > max then
			break -- benched
		end
		Builders.disciple(ctx, slot, Config.rarity(name))
	end
	ctx.folder.Parent = s.plot.built
end

local refreshPads -- forward
local PAD_COLOR = Color3.fromHex("6FB59C") -- jade

local function makePad(player, s, pad, cost, label, income, onBuy)
	-- a carved stone disc with a jade inlay (no neon: the pad is an object, not a light)
	local at = s.plot.frame * CFrame.new(pad.x, 0, pad.z)
	local rim = Style.P(s.plot.built, Vector3.new(0.4, 5.4, 5.4), at * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Style.PAL.stone, nil, Enum.PartType.Cylinder)
	local p = Style.P(s.plot.built, Vector3.new(0.5, 4, 4), at * CFrame.new(0, 0.27, 0) * CFrame.Angles(0, 0, math.pi / 2), PAD_COLOR, nil, Enum.PartType.Cylinder)
	p.CanCollide = false
	p.CanTouch = false
	p.Name = "Pad_" .. (pad.id or "x")
	rim.Name = "PadRim"
	rim.Parent = p -- destroyed together with the pad
	-- the client draws the price card and the preview from these
	p:SetAttribute("Title", label)
	p:SetAttribute("Cost", cost)
	p:SetAttribute("Income", income)
	p:SetAttribute("Feature", pad.feature)
	p:SetAttribute("OwnerId", player.UserId)
	p:SetAttribute("PadId", pad.id)
	buildPreview(s, pad, p)
	-- Buying is a position check in the pad loop below, not .Touched: a foot grazing a thin
	-- pad top fires Touched unreliably, so walking on a pad often did nothing.
	s.padData = s.padData or {}
	s.padData[p] = { cost = cost, onBuy = onBuy }
	return p
end

-- Every 0.1 s: is an owner standing on one of their pads? (horizontal distance + height band)
local PAD_REACH = 2.6 -- the pad top is 4 studs wide
local function checkPads()
	for player, s in sessions do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 and s.padData then
			for part, info in s.padData do
				if not part.Parent then
					s.padData[part] = nil
				elseif not info.busy then
					local d = hrp.Position - part.Position
					if Vector2.new(d.X, d.Z).Magnitude < PAD_REACH and d.Y > -1 and d.Y < 7 then
						if s.data.qi >= info.cost then
							info.busy = true
							s.padData[part] = nil
							s.data.qi -= info.cost
							info.onBuy()
						end
						break -- one pad per player per tick
					end
				end
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
	if s.plot.radius ~= radius then
		buildGrounds(s.plot, radius)
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
						buildGrounds(s.plot, Config.islandRadius(s.data.owned))
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
			s.data.qi = 0
			s.data.pillReady = false
			s.data.pillTimer = 0
			s.data.realmRecruits = 0
			lightning(s)
			rebuild(s)
			refreshPads(player, s)
			publish(player)
			notify:FireAllClients("breakthrough", player.DisplayName, nextName)
		end)
		s.pads.breakthrough.Color = Color3.fromRGB(255, 210, 90)
	end
end

-- Saving (SaveStore holds the session lock) ------------------------------------------
local pendingSaves = 0

-- `release` = the last save of this session (leave or close); later saves are skipped.
local function save(s, release)
	if not store or not s.loaded or s.released then
		return
	end
	if release then
		s.released = true
	end
	s.data.last = os.time()
	local snapshot = deepCopy(s.data) -- the session keeps changing while UpdateAsync yields
	pendingSaves += 1
	SaveStore.save(store, s.userId, s.sessionId, snapshot, release)
	pendingSaves -= 1
end

local function load(player, sessionId)
	local data = nil
	local loaded = true
	if store then
		data, loaded = SaveStore.load(store, player.UserId, sessionId, function()
			return player.Parent ~= nil
		end)
	end
	local d = defaultData()
	if type(data) == "table" then
		for k, v in data do
			d[k] = v
		end
	end
	return d, loaded
end

-- Join / leave -----------------------------------------------------------------------
local function freePlot()
	for _, plot in plots do
		if not plot.owner then
			return plot
		end
	end
	return nil
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

	local plot = freePlot()
	if not plot then
		warn("[Tycoon] no free peak for", player.Name)
		return
	end
	plot.owner = player
	player:SetAttribute("PlotIndex", plot.index) -- clients place their effects with it
	setPlotLabel(plot, player.DisplayName .. "'s Sect")
	local sessionId = SaveStore.newSessionId()
	local data, loaded = load(player, sessionId)
	if not player.Parent then
		plot.owner = nil
		setPlotLabel(plot, "Unclaimed Peak")
		if store and loaded then
			-- hand the lock back untouched (same data, same `last`) so a rejoin is not blocked
			SaveStore.save(store, player.UserId, sessionId, data, true)
		end
		return
	end
	local s = { data = data, plot = plot, pads = {}, loaded = loaded, userId = player.UserId, sessionId = sessionId }
	sessions[player] = s

	-- offline qi
	local away = math.clamp(os.time() - (data.last or os.time()), 0, Config.OFFLINE_CAP)
	local offlineGain = 0
	if away > 60 then
		offlineGain = math.floor(rate(data, true) * away)
		data.qi += offlineGain
		Telemetry.source(player, data, offlineGain, "offline", true)
	end
	data.sessions = (data.sessions or 0) + 1
	s.joinedAt = os.clock()
	s.earned, s.orbEarned = 0, 0
	Telemetry.funnel(player, data)

	rebuild(s)
	refreshPads(player, s)
	publish(player)
	if offlineGain > 0 then
		task.delay(3, function()
			notify:FireClient(player, "offline", offlineGain, away)
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
	if not s then
		return
	end
	sessions[player] = nil
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
	s.plot.owner = nil
	setPlotLabel(s.plot, "Unclaimed Peak")
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

recruitFn.OnServerInvoke = function(player)
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
	local kept = true
	local list = s.data.disciples
	local max = Config.maxDisciples(s.data.owned)
	local function byBonus(a, b)
		return Config.rarity(a).bonus > Config.rarity(b).bonus
	end
	table.sort(list, byBonus)
	if #list < max then
		table.insert(list, r.name)
	elseif r.bonus > Config.rarity(list[max]).bonus then
		-- full: the newcomer takes the weakest working seat (it joins and the list re-sorts)
		table.insert(list, r.name)
	else
		kept = false
	end
	table.sort(list, byBonus)
	-- keep at most as many as the largest possible sect (benched ones beyond the slots)
	local cap = Config.MAX_DISCIPLES + #Config.SLOT_PADS
	while #list > cap do
		table.remove(list)
	end
	buildDisciples(s)
	publish(player)
	Telemetry.custom(player, "Recruit", r.name, Telemetry.realmBucket(s.data.realm), kept and "kept" or "benched")
	Telemetry.funnel(player, s.data)
	s.recruiting = false
	return { ok = true, rarity = r.name, kept = kept }
end

-- Pill (Alchemy Furnace): brewed every PILL_INTERVAL; using it doubles qi/s for PILL_DURATION.
pillFn.OnServerInvoke = function(player)
	local s = sessions[player]
	if not s or not s.data.owned.furnace or not s.data.pillReady then
		return false
	end
	s.data.pillReady = false
	s.data.pillTimer = 0
	s.data.boostUntil = workspace:GetServerTimeNow() + Config.PILL_DURATION
	publish(player)
	Telemetry.custom(player, "Feature", "pill", Telemetry.realmBucket(s.data.realm))
	return true
end

giftFn.OnServerInvoke = function(player)
	local s = sessions[player]
	if not s then
		return nil
	end
	local gi = s.giftIdx or 1
	local at = Config.GIFT_TIMES[gi]
	if not at or (s.playTime or 0) < at then
		return nil
	end
	local gain = math.floor(rate(s.data, true) * Config.GIFT_VALUE[gi])
	s.giftIdx = gi + 1
	s.data.qi += gain
	publish(player)
	print(string.format("[Tycoon] gift %d claimed by %d after %d s", gi, player.UserId, math.floor(s.playTime)))
	return gain
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
	for i = #s.orbs, 1, -1 do
		local orb = s.orbs[i]
		if not orb.Parent then
			table.remove(s.orbs, i)
		elseif (orb.Position - hrp.Position).Magnitude < 4.5 then
			local gain = math.floor(rate(s.data) * Config.ORB_VALUE)
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
			s.data[key] = value
			if key == "orbNow" then
				spawnOrb(s)
			end
			publish(player)
			return true
		end
		return false
	end
	set.Parent = game:GetService("ServerStorage")
end

-- Boot -------------------------------------------------------------------------------
buildHub()
setupLighting()
buildPlots()

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
		local gain = rate(d) * dt
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
		for player, s in sessions do
			Telemetry.source(player, s.data, s.earned or 0, "income")
			Telemetry.source(player, s.data, s.orbEarned or 0, "orb")
			s.earned, s.orbEarned = 0, 0
			task.spawn(save, s)
		end
	end
end
