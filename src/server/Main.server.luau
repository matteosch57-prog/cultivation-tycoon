-- Cultivation Tycoon server: plots, qi income, pads, disciples, breakthrough, saving.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local GroupService = game:GetService("GroupService")
local HttpService = game:GetService("HttpService")

Players.CharacterAutoLoads = false -- first thing: onJoin spawns each avatar on its peak (watchDeath)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Builders = require(script.Parent:WaitForChild("Builders"))
local Style = require(script.Parent:WaitForChild("Style"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local SaveStore = require(script.Parent:WaitForChild("SaveStore"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local SwordRide = require(script.Parent:WaitForChild("SwordRide"))
local Dots = require(script.Parent:WaitForChild("Dots"))
local Cultivators = require(script.Parent:WaitForChild("Cultivators"))
local Workers = require(script.Parent:WaitForChild("Workers"))
local ServerHealth = require(script.Parent:WaitForChild("ServerHealth"))
local RealmLook = require(script.Parent:WaitForChild("RealmLook"))
local Skin = require(script.Parent:WaitForChild("Skin"))
local Ranks = require(script.Parent:WaitForChild("Ranks"))
local RankBoard = require(script.Parent:WaitForChild("RankBoard"))
local HubShop = require(script.Parent:WaitForChild("HubShop"))
local Portals = require(script.Parent:WaitForChild("Portals"))
local Altar = require(script.Parent:WaitForChild("Altar"))
local ChestModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ChestModel"))
local Guard = require(script.Parent:WaitForChild("Guard"))
local Journal = require(script.Parent:WaitForChild("Journal"))
local Bless = require(script.Parent:WaitForChild("Bless"))
local Missions = require(script.Parent:WaitForChild("Missions"))
local Badges = require(script.Parent:WaitForChild("Badges"))
local PlayerAura = require(script.Parent:WaitForChild("PlayerAura"))

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
local streakFn = Instance.new("RemoteFunction")
streakFn.Name = "ClaimStreak" -- the Daily Blessing card's Claim (D58)
streakFn.Parent = remotes
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
local favoriteFn = Instance.new("RemoteFunction")
favoriteFn.Name = "ClaimFavorite" -- the Sect Gift card's Favorite, after Roblox's favorite prompt succeeded
favoriteFn.Parent = remotes
local inviteEv = Instance.new("RemoteEvent")
inviteEv.Name = "SocialInvite" -- the client opened Roblox's invite prompt (telemetry only)
inviteEv.Parent = remotes
local welcomeFn = Instance.new("RemoteFunction")
welcomeFn.Name = "ClaimWelcome" -- the intro's GO (D36)
welcomeFn.Parent = remotes
local teleportEv = Instance.new("RemoteEvent")
teleportEv.Name = "Teleport" -- the HUD's Base / Ranks buttons ("home", "ranks"), the incense button ("shrine"), the altar "!" ("altar") and the portals ("isle<i>", "hub")
teleportEv.Parent = remotes
local breakthroughFn = Instance.new("RemoteFunction")
breakthroughFn.Name = "Breakthrough" -- the breakthrough screen's Confirm (the pad only opens the screen)
breakthroughFn.Parent = remotes
local settingsEv = Instance.new("RemoteEvent")
settingsEv.Name = "SaveSettings" -- the Settings page (Settings.client) sends its values when it closes
settingsEv.Parent = remotes
local rankingsFn = Instance.new("RemoteFunction")
rankingsFn.Name = "Rankings" -- the Rankings screen asks for one board: Global, Country or Friends (Ranks.fetch)
rankingsFn.Parent = remotes
local perfEv = Instance.new("RemoteEvent")
perfEv.Name = "PerfReport" -- fps of one zone window and the scene load around the camera (PerfReport.client)
perfEv.Parent = remotes
remotes.Parent = ReplicatedStorage

-- World ------------------------------------------------------------------------------
-- The ground the game stands on: terrain grass can only surface at world y = +2 or -2
-- (FillCylinder snaps to the 4-stud grid, measured 2026-10-21), so the hub and peaks sit at 2.
local BASE_Y = 2

local world = Instance.new("Folder")
world.Name = "Sect"
world.Parent = workspace

local rankStand -- where the Ranks teleport lands (set when the hub is built)
-- hubPortals[i] = { at = Vector3, label, pad, arrive = CFrame }: the hub's portal to island i and
-- where you land coming back from island i (Portals.luau)
local hubPortals = {}

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
		if i == Config.RANK_WALL_GAP then
			-- the ranking wall stands here instead of a tree (RankBoard)
			local at = Vector3.new(math.cos(mid) * Config.RANK_WALL_R, BASE_Y, math.sin(mid) * Config.RANK_WALL_R)
			RankBoard.build(folder, CFrame.lookAt(at, Vector3.new(0, BASE_Y, 0)))
			-- the Ranks teleport lands in front of the wall, facing it
			local front = at + (Vector3.new(0, BASE_Y, 0) - at).Unit * Config.TELEPORT_RANK_FRONT
			rankStand = CFrame.lookAt(front + Vector3.new(0, 4, 0), at + Vector3.new(0, 4, 0))
		elseif i == (Config.RANK_WALL_GAP + Config.PLOT_COUNT / 2 - 1) % Config.PLOT_COUNT + 1 then
			-- the top 3 podium stands across the hub from the wall, facing the plaza (RankBoard.podium)
			local at = Vector3.new(math.cos(mid) * Config.RANK_PODIUM.r, BASE_Y, math.sin(mid) * Config.RANK_PODIUM.r)
			RankBoard.podium(folder, CFrame.lookAt(at, Vector3.new(0, BASE_Y, 0)))
		elseif i == Config.HUB_SHOP_GAP or i == Config.HUB_BELL_GAP then
			-- the ride shop and the Tide Bell (HubShop): where every player passes
			local at = Vector3.new(math.cos(mid) * Config.HUB_SHOP_R, BASE_Y, math.sin(mid) * Config.HUB_SHOP_R)
			local cf = CFrame.lookAt(at, Vector3.new(0, BASE_Y, 0))
			if i == Config.HUB_SHOP_GAP then
				HubShop.swords(folder, cf)
			else
				HubShop.bell(folder, cf)
			end
		elseif i % 2 == 0 then
			Style.sakura(folder, CFrame.new(math.cos(mid) * r, BASE_Y, math.sin(mid) * r), i)
		else
			Style.pine(folder, CFrame.new(math.cos(mid) * r, BASE_Y, math.sin(mid) * r), i, 12)
		end
		local side = a + 0.32
		local lr = Config.HUB_RADIUS - 5
		-- not within 60 degrees of the ranking wall: one stood behind it, the next one inside its right
		-- guardian lion (audit Play sweep 2026-10-22); the wall carries its own lanterns
		local wallMid = bridgeAngle(Config.RANK_WALL_GAP) + math.pi / Config.PLOT_COUNT
		local fromWall = math.abs((side - wallMid + math.pi) % (math.pi * 2) - math.pi)
		if fromWall > math.pi / 3 then
			Style.lantern(folder, CFrame.new(math.cos(side) * lr, BASE_Y, math.sin(side) * lr), 0.9)
		end
		-- the portal to this bridge's island stands beside its mouth, facing the plaza: on the side
		-- without the lantern, unless the ranking wall is there (that bridge's lantern is skipped)
		local toWall = (wallMid - a + math.pi) % (math.pi * 2) - math.pi
		local pa = (toWall < 0 and toWall > -math.pi / 3) and a + 0.26 or a - 0.26
		local pr = Config.HUB_RADIUS - 6
		local at = Vector3.new(math.cos(pa) * pr, BASE_Y, math.sin(pa) * pr)
		local label, pad = Portals.pad(folder, CFrame.lookAt(at, Vector3.new(0, BASE_Y, 0)) * CFrame.Angles(0, math.pi, 0), "isle" .. i, "Unclaimed Peak", { column = true })
		Portals.setOpen(label, pad, false, "Unclaimed Peak")
		local back = Vector3.new(math.cos(a), 0, math.sin(a)) * (Config.HUB_RADIUS - 14) + Vector3.new(0, BASE_Y + 4, 0)
		hubPortals[i] = { at = at, label = label, pad = pad, arrive = CFrame.lookAt(back, Vector3.new(0, BASE_Y + 4, 0)) }
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
	for _, at in { Config.IDLE_CHEST_AT, Config.IDLE_CHEST_PAD } do -- the idle chest and its green pad
		if (Vector2.new(x, z) - Vector2.new(at.X, at.Z)).Magnitude < 7 then
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

-- the owner's name on an entrance sign (the archway's board, or the Sect Gate's once built)
local function nameBoard(plot, sign)
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
	return label
end

-- the land's state (expansion level + which islets are open): the grounds redraw when it changes
local function landKey(owned)
	local key = tostring(Config.expansionLevel(owned))
	for _, name in Config.ISLET_ORDER do
		key ..= Config.isletOpen(owned, name) and "1" or "0"
	end
	return key .. (owned.gate and "g" or "") -- the Sect Gate replaces the entrance archway
end

-- The peak's ground (Sky Islets, owner pick B 2026-10-22): the home island and every district
-- islet (terrain grass on top) with the lobes their expansions added; an islet whose bridge is not
-- built yet is dry ground. No roads and no trees by default: those are pads (Config.PADS kind
-- path / grove, Builders). Plus the waterfall, the hub bridge, the shop bridge and the entrance
-- archway with the owner's name. Rebuilt whenever the land changes (a bridge, an expansion, a
-- breakthrough).
local function buildGrounds(plot, owned)
	owned = owned or {}
	local radius = Config.ISLAND_RADIUS
	if plot.grounds then
		plot.grounds:Destroy()
	end
	-- clear the old terrain grass: every islet and lobe a peak can own, each with its margin (islands
	-- reach at most 1.05 x their radius; Config.ISLETS keeps 13+ studs to the neighbours)
	for _, i in Config.ISLETS do
		workspace.Terrain:FillCylinder(plot.frame * CFrame.new(i.x, -6, i.z), 20, i.r * 1.05 + 6, Enum.Material.Air)
	end
	for _, l in Config.ISLAND_LOBES do
		workspace.Terrain:FillCylinder(plot.frame * CFrame.new(l.x, -6, l.z), 20, l.r * 1.05 + 4, Enum.Material.Air)
	end
	local g = Instance.new("Folder")
	g.Name = "Grounds"
	groundRadius = radius
	local lobes = Config.islandLobes(owned)
	for k, name in Config.ISLET_ORDER do
		local i = Config.ISLETS[name]
		local extra = {}
		for _, l in lobes do
			if l.islet == name then
				table.insert(extra, { x = l.x - i.x, z = l.z - i.z, r = l.r })
			end
		end
		local clear = function(x, z)
			return keepClear(x + i.x, z + i.z)
		end
		local seed = 100 + plot.index + (k - 1) * 17 -- the heart keeps the old island's seed
		Style.island(g, plot.frame * CFrame.new(i.x, 0, i.z), i.r, seed, clear, true, extra, not Config.isletOpen(owned, name))
	end
	Style.waterfall(g, plot.frame, radius, WATERFALL_ANGLE)
	-- rope bridge from the hub rim to the peak rim
	local dir = Vector3.new(plot.center.X, 0, plot.center.Z).Unit
	local hubEdge = dir * (Config.HUB_RADIUS - 3) + Vector3.new(0, BASE_Y, 0)
	local peakEdge = plot.center - dir * (radius - 3)
	Style.bridge(g, hubEdge + Vector3.new(0, 0.05, 0), peakEdge + Vector3.new(0, 0.05, 0), 8)
	-- the portal back to the hub, left of the bridge head past the VIP pad and the incense shrine,
	-- facing into the island (Portals.luau)
	plot.portalAt = plot.frame * Vector3.new(-27, 0, radius - 12)
	Portals.pad(g, plot.frame * CFrame.new(-27, 0, radius - 12) * CFrame.Angles(0, math.pi, 0), "hub", "Sect Hub")
	-- and one from the peak rim to its shop island (Shop.buildIsland)
	local foot = plot.frame * Vector3.new(SHOP_DIR.X * (radius - 3), 0, SHOP_DIR.Y * (radius - 3))
	Style.bridge(g, foot + Vector3.new(0, 0.05, 0), Shop.islandEntry(plot.frame) + Vector3.new(0, 0.05, 0), 6)
	-- entrance archway carrying the owner's name, until the Sect Gate pad replaces it with the grand
	-- gate on the same spot (owner 2026-10-22: "there's already a gate, when we build it it's twice
	-- the same"; Builders.gate, attachName)
	if not owned.gate then
		local sign = Kit.gate(g, plot.frame * CFrame.new(0, 0, radius - 1), 13, 16) -- taller (owner 2026-10-21)
		sign.Name = "Sign"
		plot.label = nameBoard(plot, sign)
	end
	g.Parent = plot.folder
	plot.grounds = g
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
	local hp = hubPortals[plot.index]
	if hp then
		Portals.setOpen(hp.label, hp.pad, plot.owner ~= nil, text)
	end
end

-- The idle chest on every peak (D39): lacquered wood, gold bands, a jade clasp, and a label that
-- says it fills while you are away. The return screen (IdleChest.client) plays it opening.
local function buildIdleChest(plot)
	local P, PAL = Style.P, Style.PAL
	local m = Instance.new("Model")
	m.Name = "IdleChest"
	local at = Config.IDLE_CHEST_AT
	local cf = plot.frame * CFrame.new(at.X, 0, at.Z) * CFrame.Angles(0, math.rad(90), 0) -- front (lock) faces the avenue (-X)
	P(m, Vector3.new(5.2, 0.4, 3.9), cf * CFrame.new(0, 0.2, 0), PAL.stone) -- plinth
	local chest = ChestModel.build(m, cf * CFrame.new(0, 0.4, 0))
	local box = chest:FindFirstChild("Body")
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
	plot.chest = m -- shown by showIdleChest once the owner's disciples can meditate
end

-- The idle chest stands only once the Meditation Platform does (owner 2026-10-22: the chest comes
-- with the disciples who pray there; before it there is nobody to work while you are away)
local function showIdleChest(plot, on)
	if plot.chest then
		plot.chest.Parent = if on then plot.folder else nil
	end
end

-- the save has its idle chest: the Meditation Platform stands and the first CHEST_AFTER_RECRUITS
-- recruits are done (owner 2026-10-24: "idle chest should be given AFTER the first 3 recruits"); a
-- save that already had it keeps it
local function hasIdleChest(d)
	return d.owned.platform == true and ((d.recruited or 0) >= Config.CHEST_AFTER_RECRUITS or d.chestStarter == true or (d.tips and d.tips.chest) == true)
end

-- Free summons (a gift, the Daily Blessing, an index step) go into the idle chest's pool and open
-- at once: the summon screen (IdleChest.client, mode "summons") shows their balls a moment later.
-- Owner 2026-10-24: "free summons don't actually give free summons": they waited unseen for the
-- next join's return screen
local function giveSummons(s, n)
	local d = s.data
	d.chestSummons = (d.chestSummons or 0) + n
	s.player:SetAttribute("ChestSummons", d.chestSummons)
	task.delay(1.5, function()
		if s.player.Parent and (d.chestSummons or 0) > 0 then
			notify:FireClient(s.player, "idleChest", 0, 0, d.chestSummons, "summons")
		end
	end)
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
		buildGrounds(plot, {})
		Shop.buildIsland(plot)
		buildIdleChest(plot)
		Bless.build(plot) -- the incense shrine visitors bless (Bless.luau)
		folder.Parent = world
		plots[i] = plot
		task.wait()
	end
end

local function setupLighting()
	-- Lighting itself is authored in Edit (saved with the place); only the cloud sea is built here, plus the
	-- sky-all-round faces and haze (Config.SKY), set before any client reads the day values (DayNight.client).
	local Lighting = game:GetService("Lighting")
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky and Config.SKY.faces then
		for face, id in Config.SKY.faces do
			sky["Skybox" .. face] = "rbxassetid://" .. id
		end
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		for prop, v in Config.SKY.atmosphere do
			atmosphere[prop] = v
		end
	end
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
	return { qi = 0, realm = 1, owned = {}, disciples = {}, recruited = 0, last = os.time(), best = 1, climbed = 0, peakRate = 0, peakSteady = 0, week = 0, weekSec = 0, lives = 1, karma = 0, soulPeak = 0, lifeStart = 0, dao = {}, workers = {} }
end

-- Each disciple keeps the look it was rolled with (D60): data.discLooks[i] goes with data.disciples[i]
-- (a parallel list, so every reader of the rarity list stays as it is). An old save, or a list
-- another path changed, is padded with the look its place used to give.
local function discLooks(d)
	d.discLooks = d.discLooks or {}
	local looks = Config.DISCIPLE_LOOKS
	for i = #d.discLooks + 1, #d.disciples do
		d.discLooks[i] = looks[(i - 1) % #looks + 1]
	end
	for i = #d.discLooks, #d.disciples + 1, -1 do
		d.discLooks[i] = nil
	end
	return d.discLooks
end

-- Shiny (2026-10-23, Pet Simulator 99's Shiny pets): data.discShiny[i] = true when data.disciples[i]
-- is Shiny (another parallel list like discLooks; an old save has none: all false)
local function discShiny(d)
	d.discShiny = d.discShiny or {}
	for i = #d.discShiny + 1, #d.disciples do
		d.discShiny[i] = false
	end
	for i = #d.discShiny, #d.disciples + 1, -1 do
		d.discShiny[i] = nil
	end
	return d.discShiny
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

-- rebirths done so far (a save counts lives; life 1 = no rebirth yet)
local function rebirths(d)
	return (d.lives or 1) - 1
end

-- karma the next rebirth pays (Muscle Legends' gems: a step more each rebirth; Soul Echo included)
local function karmaGain(d)
	return math.floor(Config.rebirthKarma(rebirths(d)) * (1 + Config.DAO_ECHO * dao(d, "echo")))
end

-- Each working disciple adds its rarity's bonus, raised by its own index stars (owner 2026-10-22:
-- "stars should count on their performance too"; Config.discipleStarMult). `price` leaves the stars
-- out, like the index's sect-wide boost (priceRate).
local function discipleMult(s, price)
	local data = s.data
	local m = 1
	local max = maxDisciples(s)
	local looks = discLooks(data)
	local shiny = discShiny(data)
	for i, name in data.disciples do
		if i > max then
			break
		end
		local bonus = Config.discBonus(name, shiny[i])
		if not price then
			bonus *= Config.discipleStarMult((data.index or {})[Config.indexKey(name, looks[i])])
		end
		m += bonus
	end
	return m
end

local function boosted(data)
	return (data.boostUntil or 0) > workspace:GetServerTimeNow()
end

-- Spirit Tide: a server-wide event, every peak on the server earns TIDE_MULT x while it lasts
-- Start (or lengthen) a Spirit Tide now: TIDE_DURATION more seconds on top of any tide still running,
-- so a tide that lands inside another never eats the time left. TideNext (the schedule) is untouched.
-- `by` = the player who rang the Tide Bell (their name goes on everyone's banner), nil = the schedule.
local function startTide(by)
	local now = workspace:GetServerTimeNow()
	workspace:SetAttribute("TideUntil", math.max(workspace:GetAttribute("TideUntil") or 0, now) + Config.TIDE_DURATION)
	notify:FireAllClients("tide", Config.TIDE_DURATION, by and by.DisplayName or nil)
end

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
	local past = Config.rebirthMult(rebirths(data))
	local friends = away and 1 or 1 + Config.FRIEND_STEP * friendCount(s)
	local group = (s.inGroup and data.groupClaimed) and 1 + Config.GROUP_BONUS or 1
	local favorite = data.favoriteClaimed and 1 + Config.FAVORITE_BONUS or 1
	local welcome = 1 + (data.qiBonus or 0) -- Welcome Pouch: +10% forever (Shop)
	local harmony = Config.harmonyMult(data.owned) -- paths and groves (Sky Islets)
	local index = Config.indexMult(data.index) -- the disciple index's stars (D60)
	return base * Config.incomeMult(data.realm) * discipleMult(s) * pill * tide * pass * past * friends * group * favorite * welcome * harmony * index
end

-- The income prices are measured against (the D44 floor, the D48 breakthrough): the buildings, the
-- realm and the disciples. Not a pill, the tide, friends, the group, the favorite gift, the rebirth boost, Harmony (D67:
-- inside it the floor ate most of its +20%), the index (nor a disciple's own stars) or a paid multiplier (2x Qi pass, Welcome
-- Pouch), so those make every goal come sooner instead of raising its price with the income. (Leaving the disciples out too made lives 4x faster: sim 2026-10-22.)
local function priceRate(s)
	local data = s.data
	local base = Config.BASE_RATE
	for id in data.owned do
		local pad = Config.padById(id)
		if pad then
			base += pad.income * (1 + Config.WORKER_BONUS * ((data.workers or {})[id] or 0)) * Config.districtMult(data.owned, pad)
		end
	end
	return base * Config.incomeMult(data.realm) * discipleMult(s, true)
end

-- The income pad prices are measured against (Config.PAD_SECONDS): the away rate (no pill, tide or
-- friends) without anything paid for (2x Qi pass, Welcome Pouch, Robux disciples) and without the
-- rebirth boost. Free disciples count (owner 2026-10-24: "free disciples should be taken in account").
local function padRate(s)
	local data = s.data
	local r = rate(s, true)
	if s.passes and s.passes.x2 then
		r /= Config.PASS_QI_MULT
	end
	r /= 1 + (data.qiBonus or 0)
	if data.favoriteClaimed then
		r /= 1 + Config.FAVORITE_BONUS -- the favorite gift never raises a price (out of priceRate too)
	end
	r /= Config.rebirthMult(rebirths(data))
	local dm = discipleMult(s)
	local paid = 0
	for name, n in data.boughtDisciples or {} do
		paid += Config.discBonus(name) * n
	end
	return r / dm * math.max(1, dm - paid)
end

-- s.padPrice[id] for every open pad in `ids` that has none yet: ranked by catalogue cost among all
-- of them (Config.padPrice). Cleared after every buy, so the next prices follow the new income.
local function pricePads(s, ids)
	s.padPrice = s.padPrice or {}
	local open = {}
	for _, id in ids do
		table.insert(open, Config.padById(id))
	end
	table.sort(open, function(a, b)
		if a.cost ~= b.cost then
			return a.cost < b.cost
		end
		return a.id < b.id
	end)
	local income
	for i, pad in open do
		if not s.padPrice[pad.id] then
			income = income or padRate(s)
			s.padPrice[pad.id] = Config.padPrice(pad, s.data.realm, income, i, #open)
		end
	end
	-- the Main Hall stays the dearest open pad, also where catalogue floors win (realm 1: a Furnace
	-- at 1,200 above a Sect Hall at 900)
	local top = 0
	for _, pad in open do
		if not pad.id:match("^mainhall") then
			top = math.max(top, s.padPrice[pad.id])
		end
	end
	for _, pad in open do
		if pad.id:match("^mainhall") then
			s.padPrice[pad.id] = math.max(s.padPrice[pad.id], math.floor(top * Config.MAINHALL_ABOVE))
		end
	end
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
	-- the open pads' prices (pricePads; set again after a buy)
	for id, part in s.pads or {} do
		local pad = Config.padById(id) or (id:match("^hire_") and true)
		local info = s.padData and s.padData[part]
		local cost = s.padPrice and s.padPrice[id]
		if pad and info and cost and not info.busy then
			if cost ~= info.cost then
				info.cost = cost
				part:SetAttribute("Cost", cost)
			end
		end
	end
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
	player:SetAttribute("FavoriteBonus", d.favoriteClaimed == true)
	player:SetAttribute("WelcomeQi", d.welcomed == false and Config.WELCOME_QI or 0) -- > 0: show the intro (never since the gift is paid on join)
	s.friendsPeak = math.max(s.friendsPeak or 0, friends)
	player:SetAttribute("Realm", d.realm)
	player:SetAttribute("RealmName", Config.realmName(d.realm))
	player:SetAttribute("HasHall", d.owned.hall == true)
	player:SetAttribute("RecruitCost", Config.recruitCost(d.realm, d.realmRecruits or 0))
	player:SetAttribute("RealmRecruits", d.realmRecruits or 0) -- the HUD prices x10 / x50 from it
	player:SetAttribute("Disciples", table.concat(d.disciples, ","))
	local pulled = {}
	for name in d.pulled or {} do
		table.insert(pulled, name)
	end
	player:SetAttribute("Pulled", table.concat(pulled, ","))
	-- the disciple index (D60): "key=pulls;..." for the Index page, and each seated disciple's look
	local idx = {}
	for key, count in d.index or {} do
		table.insert(idx, key .. "=" .. count)
	end
	player:SetAttribute("Index", table.concat(idx, ";"))
	player:SetAttribute("DiscLooks", table.concat(discLooks(d), ","))
	-- Shiny: each seated disciple's mark ("1" / "0") and the index entries found Shiny ("key;key")
	local shinyMarks, shinyKeys = {}, {}
	for i, on in discShiny(d) do
		shinyMarks[i] = on and "1" or "0"
	end
	for key in d.shinyIndex or {} do
		table.insert(shinyKeys, key)
	end
	player:SetAttribute("DiscShiny", table.concat(shinyMarks, ","))
	player:SetAttribute("ShinyIndex", table.concat(shinyKeys, ";"))
	-- pity: recruits since each guarantee's rarity or better ("Celestial=812;Dao Ancestor=2140")
	local pity = {}
	for _, p in Config.PITY do
		table.insert(pity, p.rarity .. "=" .. ((d.pity or {})[p.rarity] or 0))
	end
	player:SetAttribute("Pity", table.concat(pity, ";"))
	player:SetAttribute("MaxDisciples", maxDisciples(s))
	player:SetAttribute("HasFurnace", d.owned.furnace == true)
	player:SetAttribute("PillReady", d.pillReady == true)
	local tips = {}
	for key in d.tips or {} do
		table.insert(tips, key)
	end
	player:SetAttribute("Tips", table.concat(tips, ",")) -- first-time tips already done (Tips.client)
	player:SetAttribute("FreeRecruits", d.freeRecruits or 0) -- the recruit tutorial (Tips.client, Hud)
	player:SetAttribute("SeeDisciple", d.seeDisciple == true)
	player:SetAttribute("PillIn", d.owned.furnace and math.max(0, math.ceil(Config.PILL_INTERVAL - (d.pillTimer or 0))) or 0)
	player:SetAttribute("BoostUntil", d.boostUntil or 0)
	-- playtime gifts (D49, daily): GiftIn = seconds to the next one (0 = ready), -1 = all claimed
	-- today; GiftNext / GiftQi / GiftSummons = what it pays; GiftResetIn = seconds to 00:00 UTC
	local gi = d.giftIdx or 1
	local at = Config.GIFT_TIMES[gi]
	player:SetAttribute("GiftIn", at and math.max(0, math.ceil(at - (d.giftPlay or 0))) or -1)
	player:SetAttribute("GiftNext", at and gi or 0)
	player:SetAttribute("GiftQi", at and math.floor(rate(s, true) * Config.GIFT_VALUE[gi]) or 0)
	player:SetAttribute("GiftSummons", at and Config.GIFT_SUMMONS[gi] or 0)
	player:SetAttribute("GiftPill", at and Config.GIFT_PILL[gi] or 0)
	player:SetAttribute("GiftPlay", math.floor(d.giftPlay or 0)) -- seconds played today (the Free Gifts page's timers)
	player:SetAttribute("GiftRarity", at and Config.GIFT_RARITY[gi] ~= "" and Config.GIFT_RARITY[gi] or nil)
	player:SetAttribute("GiftResetIn", (Config.giftDay() + 1) * 86400 - os.time())
	local built = 0
	for _, pad in Config.PADS do
		if d.owned[pad.id] and Config.neededForBreakthrough(pad) and Config.padOpen(pad, d.realm) then
			built += 1
		end
	end
	player:SetAttribute("Built", built)
	-- rebirth: the price, the boost now and after, the karma it pays (the screen previews it)
	player:SetAttribute("Lives", d.lives or 1)
	player:SetAttribute("Karma", d.karma or 0)
	player:SetAttribute("Rebirths", rebirths(d))
	player:SetAttribute("RebirthPrice", Config.rebirthPrice(rebirths(d)))
	player:SetAttribute("RebirthOpen", Config.rebirthOpen(d.realm, rebirths(d), d.owned)) -- the next realm waits for a rebirth
	local needKind, needN = Config.rebirthNeed(d.realm, rebirths(d), d.owned) -- what a closed rebirth waits for
	player:SetAttribute("RebirthNeed", needKind and (needKind .. ":" .. needN) or "")
	player:SetAttribute("RebirthMult", Config.rebirthMult(rebirths(d)))
	player:SetAttribute("NextRebirthMult", Config.rebirthMult(rebirths(d) + 1))
	player:SetAttribute("RebirthKarma", karmaGain(d))
	-- the next realm waits for more rebirths (their gyms): the HUD and the screen say so
	player:SetAttribute("RealmNeedsRebirths", Config.rebirthsFor(d.realm + 1))
	Dots.publish(player, s) -- which red dots are lit (Dots.luau)
	for _, n in Config.DAO do
		player:SetAttribute("Dao_" .. n.key, dao(d, n.key))
	end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Realm.Value = d.realm
		ls.Lives.Value = d.lives or 1
	end
	-- Daily Blessing (D58): StreakDay = the ladder day shown (the next to claim, or today's once
	-- claimed), StreakReady = today's claim is open, StreakGot = disciple days already paid
	local st = d.streak or {}
	local ready = st.last ~= Config.giftDay()
	local day = st.day or 1
	player:SetAttribute("StreakReady", ready)
	player:SetAttribute("StreakDay", ready and day or ((day - 2) % #Config.STREAK) + 1)
	local got = {}
	for k in st.got or {} do
		table.insert(got, tostring(k))
	end
	player:SetAttribute("StreakGot", table.concat(got, ","))
	Badges.check(player, s)
end

local function ctxFor(s, folder)
	return { folder = folder or s.plot.built, frame = s.plot.frame, pal = Config.PALETTES[(s.data.realm - 1) % #Config.PALETTES + 1], sect = s.plot.labelText }
end

-- Build one pad's structure into its own Model (so clients can animate or preview it whole).
-- The model is filled while unparented and parented once at the end (one replication).
-- the Sect Gate carries the owner's name (it replaced the entrance archway): put the name board on it
local function attachName(s, m)
	local sign = m.Name == "gate" and m:FindFirstChild("Sign", true)
	if sign then
		s.plot.label = nameBoard(s.plot, sign)
	end
end

local function buildModel(s, pad, attrs)
	local m = Instance.new("Model")
	m.Name = pad.id
	-- arrives on clients whole (streaming is on): a Default model arrived as ~10% of its parts, so the
	-- build-in swirled those few, the rest popped in colliding and shoved the buyer, and a preview
	-- held only the parts that had streamed in when its pad appeared (D71)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for k, v in attrs or {} do
		m:SetAttribute(k, v)
	end
	Builders[pad.id](ctxFor(s, m), pad)
	Skin.apply(m, s.data.realm, s.data.lives) -- the realm / life grade (Config.skinFor)
	Skin.scale(m, pad, s.data.lives, s.plot.frame) -- the Main Hall grows each life
	return m
end

-- A hidden copy of the building for the client's proximity preview: invisible to everyone
-- (the owner's client fades it in locally as a pale glow), no collisions, no lights or effects.
-- Every pad with a builder gets one (bridges, paths and groves too); an expansion, which builds
-- nothing, previews the lobes of land it adds as flat discs.
local function buildPreview(s, pad, parent)
	if not Builders[pad.id] then
		return
	end
	local m = buildModel(s, pad)
	m.Name = "Preview"
	local level = pad.id == "expand1" and 1 or pad.id == "expand2" and 2 or nil
	for _, l in level and Config.ISLAND_LOBES or {} do
		if l.exp == level then
			local disc = Style.P(m, Vector3.new(0.4, l.r * 2, l.r * 2), s.plot.frame * CFrame.new(l.x, 0.4, l.z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromHex("6FB59C"), nil, Enum.PartType.Cylinder)
			disc.Name = "Lobe"
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("SurfaceGui") then
			d.Enabled = false -- (a SurfaceGui draws even on an invisible part: the name boards)
		elseif d:IsA("Decal") then -- (Texture too) a painted face would show through the glow
			d.Transparency = 1
		end
	end
	m.Parent = parent
end

-- `newcomer`: the name of a disciple who just joined; its seat walks it in (Cultivators arrival).
-- Seats are kept: a disciple who still works stays on its cushion untouched, and only the seats
-- whose disciple changed are rebuilt (owner 2026-10-22: a recruit rebuilt the whole platform and
-- every figure popped out and back in). So the seat order is not the strength order: a newcomer
-- takes a free seat, or the seat of the one it pushed to the bench.
-- a Shiny disciple's seat: the Shiny attribute (DiscipleInspect's card) and a few white sparkles
-- drifting off it (built-in texture, low rate: the client's aura range switches emitters off far away)
-- Shiny in the 3D world (owner pick C "Glint ring", mock tools/mock_shiny.luau, made bolder and gold
-- after the Studio captures 2026-10-23 so it beats every rarity's own aura): gold glints rise from a
-- ring around the cushion, and a gold star bursts over the head every 1.6 s. Live check 10:00: the
-- additive glow washed the gold out over purple auras, so the glints blend mostly normally (low
-- LightEmission keeps them gold), draw in front (ZOffset), are bigger, and a warm light marks the seat.
-- Recheck 10:03: the light lit the whole deck (now a short range at the cushion) and the burst hid in
-- the aura's circle behind the head (now higher, bigger and drawn in front of it)
local SHINY_GOLD = Color3.fromHex("FFD34D")
local SHINY_WARM = Color3.fromRGB(255, 244, 196)
local function shinySparkle(m)
	m:SetAttribute("Shiny", true)
	local at = m:FindFirstChild("Cushion") or m.PrimaryPart
	if not at then
		return
	end
	local ring = Instance.new("Part")
	ring.Name = "ShinyRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Transparency = 1
	ring.Size = Vector3.new(4.6, 0.2, 4.6)
	ring.CFrame = CFrame.new(at.Position) * CFrame.new(0, 0.4, 0)
	ring.Parent = m
	local function emitter(parent, props)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.LightEmission = 0.25
		e.LightInfluence = 0
		e.Brightness = 3
		e.ZOffset = 1.5
		for k, v in props do
			e[k] = v
		end
		e.Parent = parent
		return e
	end
	emitter(ring, {
		Name = "ShinySparkle",
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top,
		Rate = 34,
		Lifetime = NumberRange.new(1.3, 1.8),
		Speed = NumberRange.new(2, 3),
		SpreadAngle = Vector2.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(SHINY_GOLD),
	})
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 6.6, 0)
	top.Parent = ring
	local burst = emitter(top, {
		Name = "ShinyBurst",
		Rate = 0,
		Lifetime = NumberRange.new(0.7, 1.1),
		Speed = NumberRange.new(3.5, 6),
		ZOffset = 4,
		Brightness = 1.5, -- v4 shot: 22 big sparks at full brightness summed into one white ball
		-- final shot: the sparks start tiny and grow once spread out, so their spawn point is no round flash
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.25, 0.9), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(SHINY_WARM, SHINY_GOLD),
	})
	-- a thin gold outline that breathes (from look B, recheck 10:11: the burst alone hid in the auras);
	-- only the seated figure, and Shiny is 1 in 100, so few Highlights ever exist at once
	task.spawn(function()
		local avatar = m:WaitForChild("Avatar", 10) -- Cultivators.build adds the figure a moment later
		if not avatar or not m.Parent then
			return
		end
		local h = Instance.new("Highlight")
		h.Name = "ShinyOutline"
		h.Adornee = avatar
		h.FillColor = SHINY_GOLD
		h.FillTransparency = 0.9
		h.OutlineColor = SHINY_GOLD
		h.OutlineTransparency = 0.1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = m
		game:GetService("TweenService"):Create(h, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { OutlineTransparency = 0.55 }):Play()
	end)
	local light = Instance.new("PointLight")
	light.Name = "ShinyLight"
	light.Color = SHINY_GOLD
	light.Brightness = 2
	light.Range = 3.5 -- this seat only: a longer reach gilds the neighbours too
	light.Parent = ring
	task.spawn(function()
		task.wait(math.random() * 2) -- Shiny neighbours don't burst in step
		while burst.Parent and m.Parent do
			burst:Emit(12)
			task.wait(1.6)
		end
	end)
end

local function buildDisciples(s, newcomer)
	local folder = s.plot.built:FindFirstChild("Disciples")
	if not s.data.owned.platform then
		if folder then
			folder:Destroy()
		end
		return
	end
	local fresh = folder == nil
	if fresh then
		folder = Instance.new("Folder")
		folder.Name = "Disciples"
	end
	local ctx = ctxFor(s)
	ctx.folder = folder
	-- the Floating Lotus Isles' seats are the last ones (4 each, in pad order): the strongest always
	-- sit on the platform (owner 2026-10-23: "the stronger disciples should be on bottom always"),
	-- the rest on the isles; slot > onPlatform sits on isle (slot - onPlatform - 1) // 4 + 1
	local max = maxDisciples(s)
	local onPlatform = max
	for _, pad in Config.PADS do
		if pad.kind == "isle" and s.data.owned[pad.id] then
			onPlatform -= (pad.seats or 4)
		end
	end
	ctx.platformSeats = onPlatform -- Builders.disciple spaces a crowded ring evenly
	-- the ring's spacing changed (8 or fewer seats vs 9+): every seat moves, so every figure is reseated
	local was = folder:GetAttribute("PlatformSeats")
	if was ~= onPlatform and (math.max(was or 0, onPlatform) > 8) then
		folder:ClearAllChildren()
	end
	folder:SetAttribute("PlatformSeats", onPlatform)
	local function onIsle(slot)
		return slot > onPlatform
	end
	-- the working disciples (strongest first), counted by rarity and look ("Elder|lotus", D60) and by
	-- where they sit: the top onPlatform on the platform, the others on the isles
	-- (a Shiny one counts apart, "Elder|lotus#s": its seat carries the Shiny attribute and sparkles)
	local want = { [false] = {}, [true] = {} }
	local looks = discLooks(s.data)
	local shinies = discShiny(s.data)
	local function seatKey(i)
		return Config.indexKey(s.data.disciples[i], looks[i]) .. (shinies[i] and "#s" or "")
	end
	for slot in s.data.disciples do
		if slot > max then
			break -- benched
		end
		local key = seatKey(slot)
		local w = want[onIsle(slot)]
		w[key] = (w[key] or 0) + 1
	end
	-- keep every seated figure whose disciple still works in the same place (platform or isles); clear
	-- the rest: a newcomer stronger than the platform's weakest swaps the two, nobody else moves
	local taken = {}
	for _, m in folder:GetChildren() do
		local slot = tonumber(m.Name:match("^Disciple(%d+)$"))
		local key = m:GetAttribute("Disciple") and m:GetAttribute("Disciple") .. (m:GetAttribute("Shiny") and "#s" or "")
		local w = slot and want[onIsle(slot)]
		if slot and slot <= max and key and (w[key] or 0) > 0 and not taken[slot] then
			w[key] -= 1
			taken[slot] = true
		else
			m:Destroy()
		end
	end
	local function seatAt(slot, rarity, arrive, look)
		if onIsle(slot) then
			local n = slot - onPlatform - 1
			return Builders.disciple(ctx, slot, rarity, arrive, look, n // 4 + 1, n % 4 + 1)
		end
		return Builders.disciple(ctx, slot, rarity, arrive, look)
	end
	-- the others take the free seats of their place, strongest first; `newcomer` is a rarity|look key
	for _, isle in { false, true } do
		local w = want[isle]
		local slot = isle and onPlatform + 1 or 1
		for i, name in s.data.disciples do
			local key = seatKey(i)
			if (w[key] or 0) > 0 then
				while taken[slot] do
					slot += 1
				end
				w[key] -= 1
				taken[slot] = true
				local base = Config.indexKey(name, looks[i])
				local arrive = base == newcomer
				if arrive then
					newcomer = nil -- only one seat walks in, the first with that key
				end
				local m = seatAt(slot, Config.rarity(name), arrive, looks[i])
				m:SetAttribute("Disciple", base)
				if shinies[i] then
					shinySparkle(m)
				end
			end
		end
	end
	if fresh then
		folder.Parent = s.plot.built
	end
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
	p:SetAttribute("Feature", pad.feature) -- what a feature building does (the card adds +Qi/s from Income)
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
	local ok, err = pcall(info.onBuy)
	if not ok then
		-- the pad is gone and paid: offer the next pads anyway, or the player waits for a rejoin
		warn("[Tycoon] pad build failed:", err)
		pcall(refreshPads, s.player, s)
		publish(s.player)
	end
end

-- The breakthrough pad (and Heavenly Hands on it) only opens the confirm screen: the reset happens
-- on its Confirm (breakthroughFn), which the server takes only within BREAKTHROUGH_ASK_SECONDS of
-- this offer.
local function offerBreakthrough(player, s, info)
	s.btAskUntil = os.clock() + Config.BREAKTHROUGH_ASK_SECONDS
	notify:FireClient(player, "breakthroughAsk", info.cost)
end

-- Every 0.1 s: is an owner standing on one of their pads? (horizontal distance + height band)
local PAD_REACH = 2.6 -- the pad top is 4 studs wide
local function checkPads()
	for player, s in sessions do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		-- a sword rider never buys (D76): the ride switches off near pads, and a pad ignores a rider
		if hrp and hum and hum.Health > 0 and s.padData and not player:GetAttribute("Riding") then
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
						if info.confirm then
							s.padHold = true -- once per step on: closing the screen on the pad does not reopen it
							offerBreakthrough(player, s, info)
						elseif s.data.qi >= info.cost then
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
	local land = landKey(s.data.owned)
	s.plot.realm = s.data.realm
	if s.plot.radius == nil or s.plot.landKey ~= land then
		s.plot.landKey = land
		buildGrounds(s.plot, s.data.owned)
	else
		RealmLook.apply(s.plot) -- what this realm shows around the peak (nothing below REALM_LOOK_FROM)
	end
	local hallLevel = Config.mainHallLevel(s.data.owned)
	for _, pad in Config.PADS do
		local lv = tonumber(pad.id:match("^mainhall(%d)$"))
		-- only the highest Main Hall level stands
		if s.data.owned[pad.id] and (not lv or lv == hallLevel) then
			local m = buildModel(s, pad)
			Skin.extras(m, pad, s.data.realm, s.data.lives, s.plot.frame)
			m.Parent = s.plot.built
			paintGround(m)
			attachName(s, m)
		end
	end
	buildDisciples(s)
	buildWorkers(s)
	showIdleChest(s.plot, hasIdleChest(s.data))
end

-- the idle chest arrives (hasIdleChest: after the platform and the first recruits) with the starter
-- chest: full, opened from its green pad (a new save only: a save from before the tips, or one that
-- had it, knows the chest). The caller refreshes the pads
local function giveIdleChest(s)
	if not hasIdleChest(s.data) then
		return
	end
	showIdleChest(s.plot, true)
	if not s.data.chestStarter and not (s.data.tips and s.data.tips.chest) then
		s.data.chestStarter = true
		s.data.chestQi = (s.data.chestQi or 0) + Config.CHEST_STARTER_QI
		s.data.chestSummons = math.max(s.data.chestSummons or 0, Config.CHEST_STARTER_SUMMONS)
		s.player:SetAttribute("ChestSummons", s.data.chestSummons)
		s.chestShown = false
	end
end

refreshPads = function(player, s)
	-- only add and remove what changed (rebuilding every pad made all cards and beacons flicker)
	local wanted = {}
	local all = true
	local ownedCount = 0
	for _ in s.data.owned do
		ownedCount += 1
	end
	for _, pad in Config.PADS do
		-- a Lotus Isle pad waits for its karma node (Config.DAO "isles")
		local locked = pad.kind == "isle" and dao(s.data, "isles") < (pad.karma or 1)
		if not s.data.owned[pad.id] and Config.padOpen(pad, s.data.realm) and not locked then -- D48: the island opens with the realms
			if Config.neededForBreakthrough(pad) then -- paths and groves are optional (DECOR_OPTIONAL)
				all = false
			end
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
	local ready = {}
	for _, pad in Config.PADS do
		if wanted[pad.id] then
			table.insert(ready, pad.id)
		end
	end
	pricePads(s, ready)
	-- the idle chest's green pad: while it holds something the player has not been shown yet (and
	-- only once the chest stands, with the Meditation Platform)
	if hasIdleChest(s.data) and ((s.data.chestQi or 0) > 0 or (s.data.chestSummons or 0) > 0) and not s.chestShown then
		wanted.chest = true
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
				local cost = s.padPrice[pad.id]
				local income = pad.income * Config.incomeMult(s.data.realm)
				local part
				part = makePad(player, s, pad, cost, pad.name, income, function()
					s.data.owned[pad.id] = true
					s.padPrice = nil -- every open pad is priced again from the new income
					Telemetry.sink(player, s.data, part:GetAttribute("Cost") or cost, pad.id)
					Telemetry.custom(player, "Build", pad.id, Telemetry.realmBucket(s.data.realm), Telemetry.minuteBucket(s.data.playSec or 0))
					Telemetry.funnel(player, s.data)
					task.defer(Missions.bump, player, "build", 1) -- after the pad's own state is set
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
					-- (a bridge turns its islet from dry ground to grass)
					if landKey(s.data.owned) ~= s.plot.landKey then
						s.plot.landKey = landKey(s.data.owned)
						buildGrounds(s.plot, s.data.owned)
						if pad.id == "expand1" or pad.id == "expand2" then
							notify:FireClient(player, "expand")
						end
					end
					local m = buildModel(s, pad, { BuiltAt = workspace:GetServerTimeNow(), BuyerId = player.UserId })
					Skin.extras(m, pad, s.data.realm, s.data.lives, s.plot.frame) -- lanterns and motes (not on previews)
					m.Parent = s.plot.built
					paintGround(m)
					attachName(s, m)
					-- the buyer is never moved (owner 2026-10-22): pieces that land on them let them
					-- through on their client until they step out (Build.client passThrough, BuyerId)
					if pad.id:match("^lotus%d$") then
						buildDisciples(s) -- benched disciples take the isle's new seats
					end
					if pad.id == "platform" then
						buildDisciples(s)
						giveIdleChest(s)
					end
					-- the recruit tutorial (owner 2026-10-24): a new save's first Disciple Hall comes with a
					-- free recruit (Tips.client points at the Recruit button), then the trail leads to the
					-- Meditation Platform to see the newcomer (data.seeDisciple, the income tick)
					if pad.id == "hall" and (s.data.recruited or 0) == 0 and not (s.data.tips and s.data.tips.recruit) then
						s.data.freeRecruits = math.max(s.data.freeRecruits or 0, Config.FREE_RECRUITS)
					end
					refreshPads(player, s)
					publish(player)
					notify:FireClient(player, "built", pad.name)
					Shop.maybeWelcome(player, s, pad)
					Shop.maybeStarter(player, s, pad)
				end)
				s.pads[pad.id] = part
			end
		end
	end
	if wanted.chest and not s.pads.chest then
		local at = Config.IDLE_CHEST_PAD
		local p = makePad(player, s, { id = "chest", x = at.X, z = at.Z, feature = "Fills while you're away" }, 0, "Idle Chest", 0, function()
			s.chestShown = true
			s.data.tips = s.data.tips or {}
			s.data.tips.chest = true
			local gain = s.data.chestQi or 0
			s.data.chestQi = 0
			if gain > 0 then
				s.data.qi += gain
				Telemetry.source(player, s.data, gain, "chest")
			end
			if s.pads.chest then
				s.pads.chest:Destroy()
				s.pads.chest = nil
			end
			refreshPads(player, s)
			publish(player)
			notify:FireClient(player, "idleChest", gain, 0, s.data.chestSummons or 0, "chest")
		end, "build")
		p.Name = "Chest" -- not "Pad_": the HUD goal and the guide trail lead to buildings only
		p:SetAttribute("FreeText", "Open!")
		s.pads.chest = p
	end
	for id, spec in Config.WORKERS do
		local key = "hire_" .. id
		local pad = Config.padById(id)
		local n = ((s.data.workers or {})[id] or 0) + 1
		if wanted[key] and pad and not s.padPrice[key] then
			-- priced like the pads, from the pad income, and again after every buy (publish sets it)
			s.padPrice[key] = Config.workerCost(pad, n, s.data.realm, padRate(s))
		end
		if wanted[key] and pad and not s.pads[key] then
			local cost = s.padPrice[key]
			local income = pad.income * Config.incomeMult(s.data.realm) * Config.WORKER_BONUS
			local part
			part = makePad(player, s, { id = key, x = spec.x, z = spec.z }, cost, spec.name, income, function()
				s.data.workers = s.data.workers or {}
				s.data.workers[id] = n
				s.padPrice = nil
				Telemetry.sink(player, s.data, part:GetAttribute("Cost") or cost, key)
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
			part.Name = "Hire_" .. id -- not "Pad_": the HUD goal and the guide trail lead to buildings only
			part:SetAttribute("Hired", n - 1)
			part:SetAttribute("HireMax", Config.WORKER_MAX)
			s.pads[key] = part
		end
	end
	-- the next realm opens only with enough rebirths (Config.REBIRTH_REALMS, Muscle Legends' gyms)
	if all and not s.pads.breakthrough and rebirths(s.data) >= Config.rebirthsFor(s.data.realm + 1) then
		local cost = math.floor(priceRate(s) * Config.BREAKTHROUGH_SECONDS) -- D48
		local nextName = Config.realmName(s.data.realm + 1)
		local bt = { id = "breakthrough", x = 0, z = 14 }
		s.pads.breakthrough = makePad(player, s, bt, cost, "Breakthrough: " .. nextName, 0, function()
			Telemetry.sink(player, s.data, cost, "breakthrough")
			s.data.realm += 1
			s.data.best = math.max(s.data.best or 1, s.data.realm)
			s.data.climbed = (s.data.climbed or 0) + 1 -- the ranking score: only a real breakthrough counts
			Ranks.submit(player, s.data)
			Ranks.touch()
			Telemetry.realm(player, s.data.realm)
			Telemetry.funnel(player, s.data)
			task.defer(Missions.bump, player, "breakthrough", 1) -- after the realm change is done
			s.data.owned = Config.keptAtBreakthrough(s.data.owned) -- the disciple core stays (PAD_KEEP)
			s.data.workers = {}
			s.padPrice = nil
			s.data.qi = 0
			s.data.pillReady = false
			s.data.pillTimer = 0
			s.data.realmRecruits = 0
			lightning(s)
			rebuild(s)
			local startQi = math.floor(padRate(s) * Config.BREAKTHROUGH_START_SECONDS) -- the new realm's first pads at once
			s.data.qi = startQi
			Telemetry.source(player, s.data, startQi, "breakthrough")
			refreshPads(player, s)
			publish(player)
			notify:FireAllClients("breakthrough", player.DisplayName, nextName)
			local line = Config.realmLookLine(s.data.realm)
			if line then
				notify:FireClient(player, "realmLook", line)
			end
		end, "breakthrough")
		s.pads.breakthrough.Color = Color3.fromRGB(255, 210, 90)
		s.padData[s.pads.breakthrough].confirm = true
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
		end, function()
			player:SetAttribute("SaveWait", true) -- the loading screen says why it waits (Launch.client)
		end)
		player:SetAttribute("SaveWait", nil)
	end
	if type(data) == "table" and data.climbed == nil then
		data.climbed = math.max(0, (data.best or 1) - 1) -- saves from before the ranking: their deepest climb
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
-- the player's Settings page values (data.settings), for Settings.client to apply
local function publishSettings(player, data)
	local ok, json = pcall(HttpService.JSONEncode, HttpService, data.settings or {})
	if ok and player.Parent then
		player:SetAttribute("Settings", json)
	end
end

local function publishFriends(player)
	for other in friendsOf[player] or {} do
		if sessions[other] then
			publish(other)
		end
	end
end

-- turn the player's camera to look where its avatar was just placed (SpawnFacing.client): the follow
-- camera keeps its old direction through a PivotTo (owner 2026-10-24: a new player looked at the
-- bridge first, "hard to understand what to do")
local function faceCamera(player, cf)
	player:SetAttribute("FaceAt", cf.Position)
	player:SetAttribute("FaceLook", cf.LookVector)
	player:SetAttribute("FaceTurn", (player:GetAttribute("FaceTurn") or 0) + 1)
end

-- on the peak's hub-side rim, facing into the island
local function peakStand(plot)
	return plot.frame * CFrame.new(0, 4, (plot.radius or Config.ISLAND_RADIUS) - 8)
end

local function placeOnPeak(player)
	local s = sessions[player]
	local char = player.Character
	if s and char then
		local at = peakStand(s.plot)
		char:PivotTo(at)
		faceCamera(player, at)
	end
end

-- CharacterAutoLoads is off (set before any join) so nobody appears on the hub first: onJoin makes
-- the first avatar once the peak is built; a death respawns after RespawnTime as Roblox would.
local function watchDeath(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	hum.Died:Connect(function()
		task.wait(Players.RespawnTime)
		if player.Parent and player.Character == char then
			player:LoadCharacter()
		end
	end)
end

-- a fall off the islands (owner 2026-10-24: "make the respawn faster when falling"): the floaty fall
-- took ~10 s to reach the kill height, then RespawnTime; below Config.VOID_Y the avatar is set back on
-- its peak at once, facing in, with no death (Obby and simulator games do the same)
task.spawn(function()
	while true do
		task.wait(0.2)
		for player in sessions do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp.Position.Y < Config.VOID_Y then
				hrp.AssemblyLinearVelocity = Vector3.zero
				placeOnPeak(player)
			end
		end
	end
end)

local function onJoin(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local realm = Instance.new("IntValue")
	realm.Name = "Realm"
	realm.Parent = ls
	local lives = Instance.new("IntValue")
	lives.Name = "Lives"
	lives.Value = 1
	lives.Parent = ls
	ls.Parent = player

	local friends = findFriends(player)
	if not player.Parent then
		return
	end
	-- a friend joined someone already playing: their Sect of Friends badge (Badges.luau `friends`;
	-- owner 2026-10-23: a friend joining you, not just inviting or landing on a friend's server)
	for other in friends do
		if sessions[other] then
			sessions[other].friendJoined = true
		end
	end
	local plot, nextDoor = freePlot(friends)
	if not plot then
		warn("[Tycoon] no free peak for", player.Name)
		player.CharacterAdded:Connect(function(char)
			watchDeath(player, char)
		end)
		player:LoadCharacter() -- on the hub: still a body to walk with
		player:SetAttribute("PeakReady", true)
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
	-- Sky Islets (2026-10-22): a save from before the islets owns buildings that now stand on an
	-- islet; it gets that islet's bridge (and the ones leading to it) free, or it could not reach them
	for _, pad in Config.PADS do
		local name = Config.isletOf(pad)
		if data.owned[pad.id] and pad.kind ~= "bridge" then
			while Config.ISLETS[name].bridge do
				data.owned[Config.ISLETS[name].bridge] = true
				name = Config.ISLETS[name].from
			end
		end
	end
	for id, n in data.workers or {} do -- WORKER_MAX went from 3 to 2 (owner 2026-10-22)
		data.workers[id] = math.min(n, Config.WORKER_MAX)
	end
	-- the disciple index (D60): a save from before it starts its book with the disciples it has
	if not data.index then
		data.index = {}
		local looks = discLooks(data)
		for i, name in data.disciples do
			local key = Config.indexKey(name, looks[i])
			data.index[key] = (data.index[key] or 0) + 1
		end
		data.indexSteps = Config.indexTotalStars(data.index) // Config.INDEX_STEP_STARS
	end
	-- Daily Blessing: disciple days were stored as numeric keys ({[2] = true}), a sparse table no
	-- DataStore write accepts; they are string keys now
	if data.streak and data.streak.got then
		local got = {}
		for k, v in data.streak.got do
			got[tostring(k)] = v
		end
		data.streak.got = got
	end
	-- read before anything can save: a save (autosave, a receipt) stamps `last` with now
	local lastSeen = data.last
	local s = { data = data, plot = plot, pads = {}, loaded = loaded, userId = player.UserId, sessionId = sessionId, player = player }
	sessions[player] = s
	Ranks.submit(player, s.data)
	Ranks.touch()
	Bless.refresh(plot) -- the shrine shows this owner's blessings
	Bless.mark(player, s)
	Missions.refresh(player, s) -- Sect Missions: top up the slots and today's dailies
	Journal.attach(player, data) -- the player's own action journal (docs/design/DATA.md)
	Shop.onJoin(player, s) -- yields for the pass checks
	SwordRide.onJoin(player, s)
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
	-- paid here on join, no GO to press (owner 2026-10-24, after new players left on the intro: "remove
	-- the go and just make them start with qi"); NewSave lets the client hold its day-one cards back
	if data.welcomed == false then
		data.welcomed = true
		data.qi += Config.WELCOME_QI
		Telemetry.source(player, data, Config.WELCOME_QI, "welcome")
		player:SetAttribute("NewSave", true)
	end
	-- first-time tips (D50): a new save gets each once; a save from before them knows the game
	if data.tips == nil then
		data.tips = data.welcomed and { orb = true, pill = true, chest = true, recruit = true } or {}
	end
	-- the starter idle chest is filled when it arrives (giveIdleChest: the Meditation Platform and the
	-- first recruits): the chest stands only from then
	local hasChest = hasIdleChest(data)

	-- offline qi
	local away = math.clamp(os.time() - (lastSeen or os.time()), 0, Config.OFFLINE_CAP + Config.DAO_OFFLINE_SECONDS * dao(data, "meditation"))
	local offlineGain = 0
	if away > 60 then
		offlineGain = math.floor(rate(s, true) * away * Config.OFFLINE_RATE)
		data.qi += offlineGain
		Telemetry.source(player, data, offlineGain, "offline", true)
	end
	-- idle chest: a free summon per CHEST_SUMMON_EVERY s away; unopened ones wait (capped). No chest
	-- yet (no Meditation Platform): no summons fill it
	local newSummons = if hasChest then math.floor(away / Config.CHEST_SUMMON_EVERY) else 0
	-- the cap holds the time away only: gift / blessing / index summons still waiting are kept
	newSummons = math.clamp(Config.CHEST_SUMMON_MAX - (data.chestSummons or 0), 0, newSummons)
	data.chestSummons = (data.chestSummons or 0) + newSummons
	player:SetAttribute("ChestSummons", data.chestSummons)
	if away > 60 then
		Telemetry.custom(player, "IdleChest", Telemetry.hourBucket(away), tostring(data.chestSummons), Telemetry.realmBucket(data.realm))
	end
	-- a returning player sees the return screen (before the pads are drawn: no chest pad then);
	-- starter qi still waiting in the chest is paid with it. Without the chest the offline qi is
	-- still paid, just with no screen
	local showChest = hasChest and (offlineGain > 0 or data.chestSummons > 0 or (data.chestQi or 0) > 0)
	if showChest then
		s.chestShown = true
		if (data.chestQi or 0) > 0 then
			offlineGain += data.chestQi
			data.qi += data.chestQi
			Telemetry.source(player, data, data.chestQi, "chest")
			data.chestQi = 0
		end
	end
	data.sessions = (data.sessions or 0) + 1
	s.joinedAt = os.clock()
	s.earned, s.orbEarned = 0, 0
	Telemetry.funnel(player, data)

	rebuild(s)
	refreshPads(player, s)
	publish(player)
	publishFriends(player)
	publishSettings(player, data)
	s.ready = true -- receipts wait for this (Shop processReceipt): passes known, peak built
	if not showChest and (data.chestSummons or 0) > 0 then
		giveSummons(s, 0) -- free summons from before the chest (a gift): they open now
	end
	if showChest then
		task.delay(3, function()
			-- the return screen (IdleChest.client): the chest bursts, then the summons wait to be tapped
			-- also kept on the player: a slow phone whose IdleChest script connects after this fire
			-- still pulls it (IdleChest.client reads ReturnChest once at start)
			if player.Parent then
				player:SetAttribute("ReturnChest", string.format("%.0f,%.0f,%.0f", offlineGain, away, data.chestSummons or 0))
			end
			notify:FireClient(player, "idleChest", offlineGain, away, data.chestSummons)
		end)
	end
	-- the first avatar is made only now, straight on the peak (no hub stop, no teleport); the
	-- client's loading screen (src/first/Launch.client) covers the wait and reads PeakReady
	player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		placeOnPeak(player)
		watchDeath(player, char)
	end)
	pcall(player.RequestStreamAroundAsync, player, peakStand(s.plot).Position, 5)
	if player.Parent and not player.Character then
		player:LoadCharacter()
	elseif player.Character then
		placeOnPeak(player)
	end
	player:SetAttribute("PeakReady", true)
end

local function onLeave(player)
	Badges.leave(player)
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
	Ranks.leave(player, s.data)
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
	-- why they left: stuck waiting for qi, lost with things to buy, or idle (journal closes its line)
	local sinceBuy, afkShare = Journal.detach(player, built)
	local afford = 0
	for _, info in s.padData or {} do
		if not info.busy and s.data.qi >= info.cost then
			afford += 1
		end
	end
	Telemetry.custom(
		player,
		"LeaveState",
		Telemetry.minuteBucket(sinceBuy),
		afford >= 3 and "3+" or tostring(afford),
		afkShare >= 0.5 and "afk50plus" or (afkShare >= 0.1 and "afk10_50" or "afk0_10")
	)
	save(s, true)
	s.plot.built:ClearAllChildren()
	Shop.clearPeak(s.plot)
	showIdleChest(s.plot, false)
	s.plot.owner = nil
	s.plot.vip = nil
	setPlotLabel(s.plot, "Unclaimed Peak")
	s.plot.realm = nil
	s.plot.landKey = nil
	buildGrounds(s.plot, {}) -- back to a fresh peak for the next owner
	Bless.refresh(s.plot) -- a cold shrine for the next owner
end

-- Recruit ----------------------------------------------------------------------------
local rng = Random.new()

-- one roll for `d` (a save): the weights (the shown odds, R8), then pity (Config.PITY: `at` rolls in a
-- row without that rarity or better gives it), then Shiny (Config.SHINY_CHANCE). Returns the rarity
-- and whether it is Shiny.
local function roll(d)
	local total = 0
	for _, r in Config.RARITIES do
		total += r.weight
	end
	local x = rng:NextNumber(0, total)
	local pick = 1
	for i, r in Config.RARITIES do
		x -= r.weight
		if x <= 0 then
			pick = i
			break
		end
	end
	d.pity = d.pity or {}
	for _, p in Config.PITY do
		local tier = Config.rarityIndex(p.rarity)
		d.pity[p.rarity] = (d.pity[p.rarity] or 0) + 1
		if pick < tier and d.pity[p.rarity] >= p.at then
			pick = tier
		end
		if pick >= tier then
			d.pity[p.rarity] = 0
		end
	end
	return Config.RARITIES[pick], rng:NextNumber() < Config.SHINY_CHANCE
end

-- strongest first: { name, look, shiny } entries by their bonus (Shiny counts)
local function byBonus(a, b)
	return Config.discBonus(a[1], a[3]) > Config.discBonus(b[1], b[3])
end

-- The disciple index (D60): one more pull of `name` in `look`; a new star can reach a summons step
-- (Config.INDEX_STEP_STARS), paid at once as free summons. Returns the entry's stars before / after.
local function indexAdd(s, name, look)
	local d = s.data
	d.index = d.index or {}
	local key = Config.indexKey(name, look)
	local before = Config.indexStars(d.index[key])
	d.index[key] = (d.index[key] or 0) + 1
	local after = Config.indexStars(d.index[key])
	if after > before then
		local steps = Config.indexTotalStars(d.index) // Config.INDEX_STEP_STARS
		if steps > (d.indexSteps or 0) then
			local n = (steps - (d.indexSteps or 0)) * Config.INDEX_STEP_SUMMONS
			d.indexSteps = steps
			giveSummons(s, n)
			notify:FireClient(s.player, "indexStep", Config.INDEX_STEP_SUMMONS)
		end
	end
	return before, after
end

-- Seat a new disciple (a recruit, or one bought in the Shop) in `look` (rolled when missing) and count
-- it in the index. Returns kept (true when it works a seat; false = the sect is full of stronger ones
-- and it left, `force` keeps it on the bench instead), its look, its index stars after, and whether
-- this pull lit a new star.
local function addDisciple(s, name, force, noBuild, look, shiny)
	local d = s.data
	look = look or Config.DISCIPLE_LOOKS[math.random(#Config.DISCIPLE_LOOKS)]
	shiny = shiny == true
	local looks = discLooks(d)
	local shinies = discShiny(d)
	local list = {}
	for i, n in d.disciples do
		list[i] = { n, looks[i], shinies[i] }
	end
	local max = maxDisciples(s)
	table.sort(list, byBonus)
	local kept = #list < max or Config.discBonus(name, shiny) > Config.discBonus(list[max][1], list[max][3])
	if kept or force then
		-- full: the newcomer takes the weakest working seat (it joins and the list re-sorts)
		table.insert(list, { name, look, shiny })
	end
	table.sort(list, byBonus)
	-- keep at most as many as the largest possible sect (benched ones beyond the slots), dropping
	-- the weakest UNBOUGHT one: a disciple paid for with Robux (data.boughtDisciples) never leaves,
	-- even if that leaves the list over the cap
	local paid = table.clone(d.boughtDisciples or {})
	local keep = {}
	for pass = 1, 2 do -- a bought one is never Shiny: mark plain copies first, then any (old saves)
		for i, e in list do -- strongest first: the bought copies are the strongest plain ones of their name
			if not keep[i] and (paid[e[1]] or 0) > 0 and (pass == 2 or not e[3]) then
				paid[e[1]] -= 1
				keep[i] = true
			end
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
	table.clear(d.disciples)
	table.clear(looks)
	table.clear(shinies)
	for i, e in list do
		d.disciples[i], looks[i], shinies[i] = e[1], e[2], e[3] == true
	end
	local starsBefore, stars = indexAdd(s, name, look)
	if shiny then
		d.shinyIndex = d.shinyIndex or {}
		d.shinyIndex[Config.indexKey(name, look)] = true
	end
	if not noBuild then -- a multi-recruit rebuilds once at the end
		buildDisciples(s, kept and Config.indexKey(name, look) or nil)
	end
	return kept, look, stars, stars > starsBefore
end

-- A recruit or chest summon that errors half way must not leave `s.recruiting` set: the player could
-- never recruit again this session (Reincarnate guards its busy flag the same way)
local function clearsBusy(what, fn)
	return function(player, ...)
		local ok, res = pcall(fn, player, ...)
		if ok then
			return res
		end
		local s = sessions[player]
		if s then
			s.recruiting = false
		end
		warn("[Tycoon] recruit failed") -- constant text: the Error Report groups by string
		print("[Tycoon] " .. what .. " error:", res)
		return nil
	end
end

-- free summons from the idle chest: the same roll and seating as a recruit, no qi. `count` of them
-- at once (1 when missing, at most CHEST_BATCH): a tapped ball opens one, Collect opens all that are
-- left in ONE call, so a fast Collect can never outrun the Guard budget or the busy flag and drop
-- some (owner 2026-10-22: "claiming fast gives no disciples"). nil = busy or over budget (the
-- client retries); an empty `results` = nothing left.
local CHEST_BATCH = 50
chestFn.OnServerInvoke = clearsBusy("chest summon", function(player, count)
	if not Guard.allow(player, "ChestSummon") then
		return nil -- over its call budget (Guard)
	end
	local s = sessions[player]
	if not s or s.recruiting then
		return nil
	end
	local want = math.min(if type(count) == "number" and count == count then math.floor(count) else 1, CHEST_BATCH, s.data.chestSummons or 0)
	if want <= 0 then
		return { results = {}, left = s.data.chestSummons or 0 }
	end
	s.recruiting = true
	s.data.chestSummons -= want
	player:SetAttribute("ChestSummons", s.data.chestSummons)
	s.data.pulled = s.data.pulled or {}
	local results, rolled, bestKey, bestBonus = {}, {}, nil, -1
	for _ = 1, want do
		local r, shiny = roll(s.data)
		local kept, look, stars, newStar = addDisciple(s, r.name, false, true, nil, shiny)
		table.insert(results, { rarity = r.name, kept = kept, look = look, stars = stars, newStar = newStar, shiny = shiny })
		-- a rolled rarity keeps its "first pulled" mark, as with a recruit
		s.data.pulled[r.name] = true
		local bonus = Config.discBonus(r.name, shiny)
		if kept and bonus > bestBonus then
			bestKey, bestBonus = Config.indexKey(r.name, look), bonus
		end
		local key = r.name .. "|" .. (kept and "kept" or "benched")
		rolled[key] = (rolled[key] or 0) + 1
	end
	for key, n in rolled do
		local rarity, fate = string.match(key, "^(.-)|(%a+)$")
		Telemetry.customValue(player, "Recruit", n, rarity, Telemetry.realmBucket(s.data.realm), fate)
	end
	buildDisciples(s, bestKey) -- once: the best newcomer walks to its seat
	publish(player)
	s.recruiting = false
	Missions.bump(player, "recruit", #results)
	return { results = results, left = s.data.chestSummons }
end)

-- Recruit `count` disciples (Config.RECRUIT_COUNTS; 1 when missing), all or nothing: the press pays
-- Config.recruitBatchCost once and moves realmRecruits by Config.recruitStep (both Economy's rules)
recruitFn.OnServerInvoke = clearsBusy("recruit", function(player, count)
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
	local want = 1
	for _, n in Config.RECRUIT_COUNTS do
		if count == n then
			want = n
		end
	end
	-- the tutorial's free recruit (FREE_RECRUITS with the first Disciple Hall): one, at no qi, and it
	-- does not raise the next price
	local free = (s.data.freeRecruits or 0) > 0
	if free then
		want = 1
	end
	local cost = free and 0 or Config.recruitBatchCost(s.data.realm, s.data.realmRecruits or 0, want)
	if s.data.qi < cost then
		return { ok = false, reason = "Not enough Qi" }
	end
	s.recruiting = true
	s.data.recruited += want -- lifetime (telemetry)
	if free then
		s.data.freeRecruits -= 1
		s.data.tips = s.data.tips or {}
		s.data.tips.recruit = true
		s.data.seeDisciple = s.data.owned.platform == true -- next: walk to the platform to see it
	else
		s.data.qi -= cost
		s.data.realmRecruits = (s.data.realmRecruits or 0) + Config.recruitStep(want) -- prices the next press; reset at a breakthrough
		Telemetry.sink(player, s.data, cost, "recruit")
	end
	local results, best, bestLook, bestShiny, bestKept, bestKeptBonus, bestKeptKey = {}, nil, nil, false, false, -1, nil
	local rolled = {} -- ["rarity|kept"] = count: one Recruit event per outcome, not one per roll (an
	-- x50 alone was a quarter of the server's minute analytics budget, Telemetry `spend`)
	s.data.pulled = s.data.pulled or {}
	for _ = 1, want do
		local r, shiny = roll(s.data)
		local kept, look, stars, newStar = addDisciple(s, r.name, false, true, nil, shiny)
		table.insert(results, { rarity = r.name, kept = kept, look = look, stars = stars, newStar = newStar, shiny = shiny })
		local bonus = Config.discBonus(r.name, shiny)
		if not best or bonus > Config.discBonus(best, bestShiny) then
			best, bestLook, bestShiny = r.name, look, shiny
		end
		if kept and bonus > bestKeptBonus then
			bestKept, bestKeptBonus, bestKeptKey = true, bonus, Config.indexKey(r.name, look)
		end
		local key = r.name .. "|" .. (kept and "kept" or "benched")
		rolled[key] = (rolled[key] or 0) + 1
		-- a rarity rolled at least once keeps a "first pulled" mark (the Shop also sells it, D28)
		s.data.pulled[r.name] = true
	end
	for key, n in rolled do
		local rarity, fate = string.match(key, "^(.-)|(%a+)$")
		Telemetry.customValue(player, "Recruit", n, rarity, Telemetry.realmBucket(s.data.realm), fate)
	end
	buildDisciples(s, bestKeptKey) -- once, only the best newcomer arrives with its entrance
	if s.data.recruited >= Config.CHEST_AFTER_RECRUITS and s.data.recruited - want < Config.CHEST_AFTER_RECRUITS then
		giveIdleChest(s) -- the first recruits are done: the idle chest arrives, full (its green pad)
		refreshPads(player, s)
	end
	publish(player)
	Telemetry.funnel(player, s.data)
	s.recruiting = false
	Missions.bump(player, "recruit", want)
	return { ok = true, rarity = best, look = bestLook, shiny = bestShiny, kept = bestKept, results = results }
end)

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
	s.data.tips = s.data.tips or {}
	s.data.tips.pill = true
	-- a pill adds to one still running (a gift's 2x Qi pill, D49, is not cut short)
	s.data.boostUntil = math.max(workspace:GetServerTimeNow(), s.data.boostUntil or 0) + Config.PILL_DURATION + Config.DAO_PILL_SECONDS * dao(s.data, "elixir")
	publish(player)
	Telemetry.custom(player, "Feature", "pill", Telemetry.realmBucket(s.data.realm))
	Missions.bump(player, "pill", 1)
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
	local d = s.data
	local gi = d.giftIdx or 1
	local at = Config.GIFT_TIMES[gi]
	if not at or (d.giftPlay or 0) < at then
		return nil
	end
	local gain = math.floor(rate(s, true) * Config.GIFT_VALUE[gi])
	local summons = Config.GIFT_SUMMONS[gi] or 0
	local pill = Config.GIFT_PILL[gi] or 0
	local rarity = Config.GIFT_RARITY[gi] ~= "" and Config.GIFT_RARITY[gi] or nil
	d.giftIdx = gi + 1
	d.qi += gain
	if summons > 0 then
		giveSummons(s, summons)
	end
	if pill > 0 then -- a 2x Qi pill: adds to one already running
		d.boostUntil = math.max(workspace:GetServerTimeNow(), d.boostUntil or 0) + pill
	end
	if rarity then
		addDisciple(s, rarity, true) -- a gift: never turned away
	end
	Telemetry.source(player, d, gain, "gift", true)
	Telemetry.custom(player, "Feature", "gift", Telemetry.realmBucket(d.realm))
	publish(player)
	task.defer(Missions.bump, player, "gift", 1)
	print(string.format("[Tycoon] gift %d claimed by %d after %d s today", gi, player.UserId, math.floor(d.giftPlay or 0)))
	return { qi = gain, summons = summons, pill = pill, rarity = rarity }
end

-- Daily Blessing (D58): one claim per UTC day; the ladder only moves on a claim, so a missed day
-- pauses it. A disciple day pays its disciple once per save, then `again`.
streakFn.OnServerInvoke = function(player)
	if not Guard.allow(player, "ClaimStreak") then
		return nil -- over its call budget (Guard)
	end
	local s = sessions[player]
	if not s then
		return nil
	end
	local d = s.data
	d.streak = d.streak or { day = 1, total = 0, got = {} }
	local st = d.streak
	local today = Config.giftDay()
	if st.last == today then
		return nil
	end
	local day = st.day or 1
	local step = Config.STREAK[day] or Config.STREAK[1]
	st.got = st.got or {}
	local pay = (step.rarity and st.got[tostring(day)]) and step.again or step
	local gain = math.floor(rate(s, true) * (pay.qiSec or 0))
	local summons = pay.summons or 0
	local rarity = pay.rarity
	st.last, st.total = today, (st.total or 0) + 1
	st.day = day % #Config.STREAK + 1
	if step.rarity then
		st.got[tostring(day)] = true -- a string key: DataStore rejects a sparse numeric table
	end
	d.qi += gain
	if gain > 0 then
		Telemetry.source(player, d, gain, "streak", true)
	end
	if summons > 0 then
		giveSummons(s, summons)
	end
	if rarity then
		addDisciple(s, rarity, true) -- a gift: never turned away
	end
	Telemetry.custom(player, "Feature", "streak", Telemetry.realmBucket(d.realm))
	publish(player)
	task.defer(Missions.bump, player, "streak", 1)
	return { day = day, qi = gain, summons = summons, rarity = rarity }
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

-- Favorite gift (owner 2026-10-24): the card opens Roblox's own favorite prompt and asks here once it
-- reports Success. Roblox has no server check for a favorite (AvatarEditorService answers only on the
-- client, behind its own inventory prompt), so this one trusts the ask: once per save, +10% qi.
favoriteFn.OnServerInvoke = function(player)
	if not Guard.allow(player, "ClaimFavorite") then
		return nil -- over its call budget (Guard)
	end
	local s = sessions[player]
	if not s then
		return nil
	end
	if not s.data.favoriteClaimed then
		s.data.favoriteClaimed = true
		publish(player)
		Telemetry.custom(player, "Social", "favorite_claim", "", Telemetry.minuteBucket(s.data.playSec or 0))
	end
	return "claimed"
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

-- the Settings page (Settings.client): volumes, the music track and three switches, kept in the
-- save (data.settings) and published as the Settings attribute (JSON) for the client to apply on join
perfEv.OnServerEvent:Connect(function(player, t)
	if Guard.allow(player, "PerfReport") then
		Telemetry.clientPerf(player, t)
	end
end)

settingsEv.OnServerEvent:Connect(function(player, t)
	if not Guard.allow(player, "SaveSettings") or type(t) ~= "table" then
		return
	end
	local s = sessions[player]
	if not s or not s.data then
		return
	end
	local clean = {}
	for _, key in { "music", "sfx", "amb" } do
		local v = tonumber(t[key])
		if v and v == v then
			clean[key] = math.round(math.clamp(v, 0, 1) * 20) / 20
		end
	end
	local track = tonumber(t.track)
	if track and track == math.floor(track) and track >= 0 and track <= 9 then
		clean.track = track
	end
	for _, key in { "haptic", "auras", "clouds" } do
		if type(t[key]) == "boolean" then
			clean[key] = t[key]
		end
	end
	s.data.settings = clean
	publishSettings(player, s.data)
end)

-- the Rankings screen (Ranks.client): a board's top RANK_READ for one scope, and your own row
rankingsFn.OnServerInvoke = function(player, key, scope)
	if not Guard.allow(player, "Rankings") or type(key) ~= "string" or not Config.RANKS[key] then
		return nil
	end
	if scope ~= "global" and scope ~= "country" and scope ~= "friends" then
		return nil
	end
	return Ranks.fetch(player, key, scope)
end

-- HUD teleports: the server picks the spot (R9), the client only names where. The client asks the
-- moment you step on a portal or tap a chip (Hud teleportTo) and the move waits TELEPORT_VEIL s, till
-- the jade wipe has closed: asking only after the wipe, a walker (MOVE.walk 30.8 studs/s) or a flyer
-- had already crossed the portal and the "you stand on it" check refused (2026-10-24, "arena tp doesnt
-- work sometimes"). The server's own gap is half the client's cooldown, so a client that waited its
-- full cooldown is never refused by network jitter.
local TRAVEL_NEAR = 14 -- studs from a portal a request may come from (hub portals stand ~28 apart)
local function travel(player, s, cf, face)
	s.teleportAt = os.clock()
	local char = player.Character
	task.delay(Config.TELEPORT_VEIL, function()
		local hum = char and char.Parent and player.Character == char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return
		end
		-- a rider keeps the sword: the speed cap starts again from the landing spot (it used to pull a
		-- rider back to where the teleport began)
		SwordRide.moved(player)
		char:PivotTo(cf)
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero -- a fall or a flight's speed does not carry over
			root.AssemblyAngularVelocity = Vector3.zero
		end
		if face then
			faceCamera(player, cf)
		end
		player:SetAttribute("Travelled", (player:GetAttribute("Travelled") or 0) + 1) -- Hud opens the wipe
	end)
end

teleportEv.OnServerEvent:Connect(function(player, where)
	if not Guard.allow(player, "Teleport") then
		return
	end
	local s = sessions[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not s or not hum or not root or hum.Health <= 0 or os.clock() - (s.teleportAt or 0) < Config.TELEPORT_COOLDOWN / 2 then
		return
	end
	local altarOpen = (workspace:GetAttribute("AltarUntil") or 0) > workspace:GetServerTimeNow()
	local top = workspace:GetAttribute("AltarTop")
	local p = root.Position
	if where == "home" then
		if s.plot then
			travel(player, s, peakStand(s.plot), true)
		end
	elseif where == "ranks" and rankStand then
		travel(player, s, rankStand, true)
	elseif where == "altar" and altarOpen and top then
		-- the altar "!" (Altar.client, last 30 s of a round): straight onto the deck's near edge, facing
		-- the middle (owner 2026-10-24: "clicking on it should tp once ON the arena"); a player already
		-- out this round gets the plaza beside the moon gate on their side instead
		local sx = p.X < top.X and -1 or 1
		local at, look
		if player:GetAttribute("AltarOut") then
			at = Vector3.new(top.X + sx * (Config.ALTAR_SPRING_X + 5), BASE_Y + 3, top.Z - 2)
			look = Vector3.new(top.X, BASE_Y + 3, top.Z - 2)
		else
			at = Vector3.new(top.X + sx * (Config.ALTAR_RADIUS - 3), top.Y + 3, top.Z)
			look = Vector3.new(top.X, top.Y + 3, top.Z)
		end
		travel(player, s, CFrame.lookAt(at, look))
	elseif where == "altarGate" and altarOpen and top then
		-- a moon gate under the altar (Altar.luau, D79): only from a gate's doorway and only for a player
		-- still in the round; lands on the deck's near edge, facing the middle
		local sx = p.X < top.X and -1 or 1
		local gate = Vector3.new(top.X + sx * Config.ALTAR_SPRING_X, BASE_Y, top.Z - 2)
		if not player:GetAttribute("AltarOut") and Vector2.new(p.X - gate.X, p.Z - gate.Z).Magnitude < 10 and math.abs(p.Y - BASE_Y) < 8 then
			local at = Vector3.new(top.X + sx * (Config.ALTAR_RADIUS - 3), top.Y + 3, top.Z)
			travel(player, s, CFrame.lookAt(at, Vector3.new(top.X, top.Y + 3, top.Z)))
		end
	elseif where == "shrine" then
		-- the HUD's incense button (Incense.client): in front of the nearest shrine this player can
		-- still bless today (Bless.target checks the day's limits)
		local plot = Bless.target(player, s, p)
		if plot then
			travel(player, s, Bless.standAt(plot), true)
		end
	elseif type(where) == "string" then
		-- a portal (Portals.luau): only from beside it, to a claimed island or the hub
		local function near(at)
			return at and Vector2.new(p.X - at.X, p.Z - at.Z).Magnitude < TRAVEL_NEAR and math.abs(p.Y - at.Y) < 12
		end
		local i = tonumber(where:match("^isle(%d)$"))
		local hp = i and hubPortals[i]
		if hp and plots[i] and plots[i].owner and near(hp.at) then
			travel(player, s, peakStand(plots[i]), true)
		elseif where == "hub" then
			for k, plot in plots do
				if near(plot.portalAt) and hubPortals[k] then
					travel(player, s, hubPortals[k].arrive)
					break
				end
			end
		end
	end
end)

-- Rebirth (Muscle Legends' rebirth): the ONE function every caller goes through, so the price lives
-- here. It costs qi, the price rises a step every rebirth, and qi goes to 0, so a repeat needs the
-- whole price earned again.
local function reincarnate(player, s)
	local d = s.data
	local price = Config.rebirthPrice(rebirths(d))
	if (d.qi or 0) < price or not Config.rebirthOpen(d.realm, rebirths(d), d.owned) then
		return nil
	end
	local gained = karmaGain(d)
	local lifeSec = (d.playSec or 0) - (d.lifeStart or 0)
	d.qi -= price
	Telemetry.sink(player, d, price, "rebirth")
	Telemetry.custom(player, "Reincarnate", Telemetry.lifeBucket(d.lives or 1), Telemetry.deepBucket(d.realm), Telemetry.hourBucket(lifeSec))
	print(string.format("[Tycoon] %d rebirth: life %d ended at realm %d, +%d karma", player.UserId, d.lives or 1, d.realm, gained))
	d.karma = (d.karma or 0) + gained
	Telemetry.karma(player, d, true, gained, "rebirth")
	d.soulPeak = math.max(d.soulPeak or 0, d.realm) -- kept for the record only (nothing reads it for power)
	d.lives = (d.lives or 1) + 1
	d.lifeStart = d.playSec or 0
	Ranks.submit(player, d)
	Ranks.touch()
	-- back to realm 1 with its pads built (D56: no 10-min rebuild of the first realm)
	d.realm = 1
	d.owned = {}
	d.workers = {}
	s.padPrice = nil
	for _, pad in Config.PADS do
		if Config.padOpen(pad, d.realm) then
			d.owned[pad.id] = true
		end
	end
	d.qi = 0
	d.pillReady = false
	d.pillTimer = 0
	d.boostUntil = 0
	d.realmRecruits = 0
	-- every disciple is kept (their pets, D44)
	lightning(s)
	rebuild(s)
	refreshPads(player, s)
	publish(player)
	task.spawn(save, s, false, true)
	notify:FireAllClients("reincarnate", player.DisplayName, d.lives)
	task.defer(Missions.bump, player, "rebirth", 1)
	return { karma = gained, lives = d.lives, mult = Config.rebirthMult(rebirths(d)) }
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
	Telemetry.karma(player, d, false, cost, key)
	if key == "seat" then
		buildDisciples(s) -- a benched disciple takes the new seat
	elseif key == "isles" then
		refreshPads(player, s) -- the Lotus Isle pads open now
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
	if info.confirm then
		offerBreakthrough(player, s, info) -- the breakthrough still waits for its Confirm
		return true
	end
	buyPad(s, part, info)
	Telemetry.custom(player, "Feature", "hands", Telemetry.realmBucket(s.data.realm))
	return true
end

-- The breakthrough screen's Confirm. The client only asks (R9): the server took an offer from the pad
-- or Heavenly Hands, and checks the pad, the price and the rebirth gate again.
breakthroughFn.OnServerInvoke = function(player)
	if not Guard.allow(player, "Breakthrough") then
		return nil -- over its call budget (Guard)
	end
	local s = sessions[player]
	local part = s and s.pads and s.pads.breakthrough
	local info = part and s.padData and s.padData[part]
	if not info or info.busy or not info.confirm or os.clock() > (s.btAskUntil or 0) then
		return false
	end
	if s.data.qi < info.cost or rebirths(s.data) < Config.rebirthsFor(s.data.realm + 1) then
		return false
	end
	s.btAskUntil = nil
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
	local lp = s.plot.frame:PointToObjectSpace(hrp.Position)
	local _, off = Config.isletAt(lp.X, lp.Z) -- on any of the peak's islets (Sky Islets)
	local auto = s.passes and s.passes.auto and off < 4
	for i = #s.orbs, 1, -1 do
		local orb = s.orbs[i]
		if not orb.Parent then
			table.remove(s.orbs, i)
		elseif (orb.Position - hrp.Position).Magnitude < 4.5 or (auto and os.clock() - (orb:GetAttribute("Age") or 0) > 1.5) then
			local walked = (orb.Position - hrp.Position).Magnitude < 4.5
			local gain = math.floor(rate(s) * Config.ORB_VALUE)
			s.data.qi += gain
			s.orbEarned = (s.orbEarned or 0) + gain
			Telemetry.custom(player, "Feature", "orb", Telemetry.realmBucket(s.data.realm))
			task.defer(Missions.bump, player, "orb", 1)
			s.data.tips = s.data.tips or {}
			if not s.data.tips.orb and walked then
				-- the tip stays for the first few orbs walked into (Config.ORB_TIP_TIMES; the Auto Orbs
				-- pass pulls them in after 1.5 s, which does not count)
				s.data.orbTips = (s.data.orbTips or 0) + 1
				if s.data.orbTips >= Config.ORB_TIP_TIMES then
					s.data.tips.orb = true
					s.data.orbTips = nil
				end
			end
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
			if key == "nopass" then
				-- DebugSet:Invoke(player, "nopass") plays on as a player with no pass (Shop.debugNoPasses)
				Shop.debugNoPasses(player, s)
				s.plot.vip = nil
				buildGrounds(s.plot, s.data.owned) -- the arch back to plain
				buildDisciples(s) -- VIP's extra seat goes
				publish(player)
				return true
			end
			if key == "ride" then
				SwordRide.debugRide(player, value) -- DebugSet:Invoke(player, "ride", "swordJade") rides (pass first); false steps off
				return true
			end
			if key == "buy" then
				-- DebugSet:Invoke(player, "buy", "starter") runs a product's prompt checks and grants it
				-- as its receipt would (no purchase); false = refused
				return Shop.debugBuy(player, s, value)
			end
			if key == "offers" then
				-- DebugSet:Invoke(player, "offers") runs the after-build offers as if a building with a
				-- `feature` had just been bought (the Welcome Pouch, then the Starter Pack card)
				Shop.maybeWelcome(player, s, { feature = true })
				Shop.maybeStarter(player, s, { feature = true })
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
			if key == "realm" or key == "lives" or key == "owned" then
				rebuild(s) -- DebugSet:Invoke(player, "realm", 9) shows that realm's look (RealmLook) and skin
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
		buildGrounds(s.plot, s.data.owned) -- redraws the arch in gold
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
SwordRide.init({ sessions = sessions, notify = notify, remotes = remotes })
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
	dotSeen = Dots.seen, -- a menu was opened: its red dot is followed
	freeReady = Dots.freeReady, -- the Shop's free daily gift can be claimed
	addDisciple = function(s, name)
		local kept = addDisciple(s, name, true) -- paid for: never turned away
		publish(s.player)
		return kept
	end,
	tideBell = function(player)
		-- the altar never shares the sky with a tide (owner 2026-10-23): a bell paid for while a round
		-- runs or is about to open rings right after that round closes
		task.spawn(function()
			local function altarBusy()
				local now = workspace:GetServerTimeNow()
				return (workspace:GetAttribute("AltarUntil") or 0) > now or (workspace:GetAttribute("AltarNext") or math.huge) - now <= Config.ALTAR_WARN
			end
			while altarBusy() do
				task.wait(1)
			end
			startTide(player)
			print(string.format("[Tycoon] spirit tide rung by %d (Tide Bell)", player.UserId))
		end)
	end,
	remotes = remotes,
	style = Style,
	kit = Kit,
	styleP = Style.P,
	palette = Style.PAL,
	cultivators = Cultivators,
})
Bless.init({
	sessions = sessions,
	plots = plots,
	rate = rate,
	publish = publish,
	notify = notify,
	telemetry = Telemetry,
	style = Style,
	palette = Style.PAL,
	kit = Kit,
})
Missions.init({
	sessions = sessions,
	rate = rate,
	publish = publish,
	notify = notify,
	telemetry = Telemetry,
	giveSummons = giveSummons,
	addDisciple = addDisciple,
	-- what a mission draw may ask for right now (Missions allowed())
	ctx = function(player, s)
		local d = s.data
		local others = false
		for p in sessions do
			if p ~= player then
				others = true
			end
		end
		return {
			others = others,
			giftLeft = Config.GIFT_TIMES[d.giftIdx or 1] ~= nil,
			furnace = d.owned.furnace == true,
			reborn = rebirths(d) >= 1,
			streakReady = (d.streak or {}).last ~= Config.giftDay(),
			canBreak = not Config.rebirthOpen(d.realm, rebirths(d), d.owned),
		}
	end,
})
setupLighting()
buildPlots()

-- which build this server runs: a bug report or an Error Report spike is matched to a publish by
-- this line (the [SRVHEALTH] lines carry the same job prefix)
print(string.format("[Tycoon] server start: place version %d, job %s", game.PlaceVersion, string.sub(tostring(game.JobId), 1, 8)))
ServerHealth.start()
Players.PlayerAdded:Connect(onJoin)
Players.PlayerRemoving:Connect(onLeave)
Ranks.start()
PlayerAura.start()
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
				local okOrb, orbErr = pcall(checkOrbs, player, s, hrp) -- an error here would stop pad buying for all
				if not okOrb then
					warn("[Tycoon] orb check failed:", orbErr)
				end
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
		workspace:SetAttribute("TideNext", now + Config.TIDE_INTERVAL)
		startTide()
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
		-- one player's error must not stop this loop: it pays everyone's qi and runs every autosave
		local okTick, tickErr = pcall(function()
			local d = s.data
			local gain = rate(s) * dt
			d.qi += gain
			s.earned = (s.earned or 0) + gain
			s.playTime = (s.playTime or 0) + dt
			d.playSec = (d.playSec or 0) + dt
			-- daily gifts (D49): play time today; a new UTC day restarts the ladder
			local today = Config.giftDay()
			if d.giftDay ~= today then
				d.giftDay, d.giftPlay, d.giftIdx = today, 0, 1
			end
			d.giftPlay = (d.giftPlay or 0) + dt
			-- hub rankings: this week's play time and the best rate ever, reported every RANK_TICK s
			local week = Config.rankWeek()
			if d.week ~= week then
				d.week, d.weekSec = week, 0
			end
			d.weekSec = (d.weekSec or 0) + dt
			d.peakRate = math.max(d.peakRate or 0, gain / math.max(dt, 1e-3))
			d.peakSteady = math.max(d.peakSteady or 0, rate(s, true)) -- Richest Qi: no pill, tide or friends (owner 2026-10-23)
			s.rankIn = (s.rankIn or 0) - dt
			if s.rankIn <= 0 then
				s.rankIn = Config.RANK_TICK
				Ranks.submit(player, d)
			end
			Journal.tick(player, player.Character and player.Character:FindFirstChild("HumanoidRootPart"), dt)
			-- Alchemy Furnace brews a pill while none is waiting
			if d.owned.furnace and not d.pillReady then
				d.pillTimer = (d.pillTimer or 0) + dt
				if d.pillTimer >= Config.PILL_INTERVAL then
					d.pillReady = true
					notify:FireClient(player, "pill")
				end
			end
			-- the recruit tutorial's last step: done once the player stands at the Meditation Platform
			if d.seeDisciple then
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local off = hrp and s.plot.frame:PointToObjectSpace(hrp.Position)
				if not d.owned.platform or (off and Vector2.new(off.X, off.Z).Magnitude < Config.SEE_DISCIPLE_RANGE) then
					d.seeDisciple = nil
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
		end)
		if not okTick then
			warn("[Tycoon] income tick failed:", tickErr)
		end
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
