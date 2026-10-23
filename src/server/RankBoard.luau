-- The hub's ranking wall (Ranks.luau boards; owner 2026-10-22: "C but way more premium", "3 different
-- rankings", no statues or podiums): a painted gate (free Creator Store mesh, Config.RANK_GATE) holds
-- Greatest Sects, two roofed steles beside it hold Richest Qi and This Week, two stone guardian lions
-- (Config.RANK_LION) and two braziers with real fire (R3: a visible lamp) frame it. Each board lists
-- the top RANK_TOP with head shots, the top 3 in gold, silver and bronze. Redrawn only when a board's
-- rows change (Ranks.changed), never per frame (R16).
local AssetService = game:GetService("AssetService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local Style = require(script.Parent:WaitForChild("Style"))
local Ranks = require(script.Parent:WaitForChild("Ranks"))
local PlayerAura = require(script.Parent:WaitForChild("PlayerAura"))

local RankBoard = {}

local P, PAL = Style.P, Style.PAL
local H = Color3.fromHex
local SLATE = H("2A2D35")
local INK = H("1B1420")
local MEDAL = { H("FFD34D"), H("E6ECF2"), H("E0A060") }
local CREAM = H("FFF1D6")
local JADE = H("9FF5C8")
local PPS = 45 -- SurfaceGui pixels per stud
-- board sizes in studs (owner 2026-10-22: "hard to read, could be bigger"): rows and text scale to fill
-- the face, about 0.7 studs of text, readable on a phone from the RANKINGS teleport spot
local SECTS_W, SECTS_H, SECTS_Y = 15.6, 14, 11 -- the gate board; Y = its centre above the ground
local STELE_W, STELE_H, STELE_X = 10, 12.5, 14 -- the side boards; X = each one's centre off the gate's
local PAD = 16 -- face padding, px
local TOP = 1.15 -- a top 3 row's height over a plain row's

local guis = {} -- [key] = SurfaceGui
local sizes = {} -- [key] = the face's size in px
local heads = {} -- [userId] = head shot content id

local function headOf(userId)
	if heads[userId] == nil then
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		heads[userId] = ok and img or ""
	end
	return heads[userId]
end

local function compact(n)
	n = math.floor(n or 0)
	if n < 1000 then
		return tostring(n)
	end
	local units = { "K", "M", "B", "T", "Qa", "Qi", "Sx" }
	local v, i = n / 1000, 1
	while v >= 1000 and i < #units do
		v /= 1000
		i += 1
	end
	local digits = v < 10 and 1 or 0
	local f = 10 ^ digits
	return string.format("%." .. digits .. "f%s", math.floor(v * f) / f, units[i])
end

local function hours(sec)
	local h, m = sec // 3600, (sec % 3600) // 60
	return h > 0 and string.format("%dh %02dm", h, m) or string.format("%dm", m)
end

local function label(parent, text, x, size, color, align, w)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(x, 0)
	l.Size = w and UDim2.new(0, w, 1, 0) or UDim2.new(1, -x - 10, 1, 0)
	l.FontFace = Toy.FONT
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = math.max(2, size * 0.1)
	st.Parent = l
	l.Parent = parent
	return l
end

-- one board's rows (cleared and redrawn on a change only)
local gens = {} -- [key] = draw count: a draw that yielded behind a newer one stops (no duplicate rows)
local function draw(key, rows)
	local g = guis[key]
	if not g then
		return
	end
	gens[key] = (gens[key] or 0) + 1
	local gen = gens[key]
	for _, r in rows do -- fetch the head shots first (they yield), then build in one go
		headOf(r.userId)
	end
	if gens[key] ~= gen or not g.Parent then
		return
	end
	for _, c in g:GetChildren() do
		if c:IsA("Frame") and c.Name ~= "Title" then
			c:Destroy()
		end
	end
	local px = sizes[key]
	local w = px.X - PAD * 2
	-- a plain row's height: the face less its title and gaps, shared by RANK_TOP rows (top 3 taller)
	local unit = math.floor((px.Y - PAD - g.Title.Size.Y.Offset - 2 * Config.RANK_TOP) / (Config.RANK_TOP + 3 * (TOP - 1)))
	local valueW = math.floor(w * (key == "sects" and 0.42 or 0.3))
	for i, r in rows do
		local top = i <= 3
		local h = top and math.floor(unit * TOP) or unit
		local f = Instance.new("Frame")
		f.LayoutOrder = i
		f.Size = UDim2.new(1, 0, 0, h)
		f.BackgroundColor3 = top and MEDAL[i] or Color3.new(1, 1, 1)
		f.BackgroundTransparency = top and 0.6 or 0.88
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = f
		local size = math.floor(h * 0.68)
		local rankW = math.floor(size * 1.3)
		label(f, tostring(i), 8, size + 2, top and MEDAL[i] or CREAM, nil, rankW)
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromOffset(h - 6, h - 6)
		img.Position = UDim2.fromOffset(8 + rankW, 3)
		img.Image = headOf(r.userId)
		img.Parent = f
		local nameX = 8 + rankW + h + 2
		label(f, r.name, nameX, size, Color3.new(1, 1, 1), nil, w - nameX - valueW - 6)
		local value
		if key == "sects" then
			value = string.format("%d realms · %d %s", r.value, r.extra, r.extra == 1 and "life" or "lives")
		elseif key == "week" then
			value = hours(r.value)
		end
		if key == "qi" then
			local amt = Toy.amount(f, "qi", size - 2, JADE, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0) })
			local t = amt:FindFirstChildWhichIsA("TextLabel", true)
			if t then
				t.Text = compact(r.value) .. "/s"
			end
		else
			label(f, value, 0, size - 2, JADE, Enum.TextXAlignment.Right)
		end
		f.Parent = g
	end
	if #rows == 0 then
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, 40)
		f.LayoutOrder = 1
		label(f, "Be the first sect here", 0, 30, CREAM, Enum.TextXAlignment.Center)
		f.Parent = g
	end
end

-- a slate face with its title; returns the SurfaceGui that holds the rows
local function face(key, slab, title, big)
	sizes[key] = Vector2.new(slab.Size.X, slab.Size.Y) * PPS
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = PPS
	g.LightInfluence = 0.2
	g.MaxDistance = Config.RANK_SEE
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = g
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = g
	local t = Instance.new("Frame")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, big and 70 or 58)
	t.LayoutOrder = 0
	label(t, title, 0, big and 58 or 46, MEDAL[1], Enum.TextXAlignment.Center)
	t.Parent = g
	g.Parent = slab
	return g
end

-- a free Creator Store model rebuilt from its meshes (Config entry { parts = { { mesh, texture, size,
-- at = CFrame from the model's bottom centre } }, size = whole model, height = studs tall wanted, yaw })
local function mesh(parent, def, cf, height)
	if not def.parts or #def.parts == 0 then
		return nil
	end
	local k = height / def.size.Y
	local m = Instance.new("Model")
	m.Name = def.name or "Prop"
	for _, part in def.parts do
		local p
		if part.mesh then
			local ok, mp = pcall(AssetService.CreateMeshPartAsync, AssetService, part.mesh, {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Automatic,
			})
			if ok and mp then
				p = mp
				p.TextureID = part.texture or ""
			else
				warn("[Tycoon][ranks] event=prop_mesh_failed")
			end
		else
			p = Instance.new("Part")
		end
		if p then
			p.Anchored = true
			p.Size = part.size * k
			p.CFrame = cf * (part.at - part.at.Position + part.at.Position * k)
			if part.color then
				p.Color = Color3.fromHex(part.color)
			end
			if part.material then
				p.Material = Enum.Material[part.material]
			end
			if p.Size.Magnitude < 3 then
				p.CastShadow = false
			end
			p.Parent = m
		end
	end
	m.Parent = parent
	return m
end

local function flame(parent, at, size, range)
	local holder = P(parent, Vector3.new(0.4, 0.4, 0.4), at, H("FF7A2A"))
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanQuery = false
	local fire = Instance.new("Fire")
	fire.Size = size
	fire.Heat = 6
	fire.Color = H("FF9A3C")
	fire.SecondaryColor = H("FFD34D")
	fire.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = H("FFB070")
	light.Range = range
	light.Brightness = 2
	light.Shadows = false
	light.Parent = holder
end

-- a bronze ding (free mesh, Config.RANK_DING) burning on a stone step; plain bowl if it fails to load
local function brazier(parent, cf)
	local d = Config.RANK_DING
	P(parent, Vector3.new(d.height * 1.3, 0.5, d.height * 1.3), cf * CFrame.new(0, 0.25, 0), PAL.stone)
	local m = mesh(parent, d, cf * CFrame.new(0, 0.5, 0), d.height)
	if not m or not m:FindFirstChildWhichIsA("BasePart") then
		P(parent, Vector3.new(2, 0.6, 2), cf * CFrame.new(0, 1.8, 0), PAL.gold, Enum.Material.Metal)
	end
	flame(parent, cf * CFrame.new(0, 0.6 + d.height * 1.05, 0), d.height * 1.2, 18)
end

-- a pagoda-roofed lantern (free mesh, Config.RANK_LANTERN) with a real light in its glowing box
local function lantern(parent, cf)
	local d = Config.RANK_LANTERN
	local m = mesh(parent, d, cf, d.height)
	if not m or not m:FindFirstChildWhichIsA("BasePart") then
		return
	end
	local holder = P(parent, Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(0, d.height * d.glowAt, 0), H("FFB070"))
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanQuery = false
	local light = Instance.new("PointLight")
	light.Color = H("FFB070")
	light.Range = 14
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = holder
end

-- a roofed stele (a smaller board beside the gate)
local function stele(parent, cf, w, h)
	P(parent, Vector3.new(w + 2.4, 1, 3.2), cf * CFrame.new(0, 0.5, 0), PAL.stone)
	P(parent, Vector3.new(w + 1.2, 0.6, 2.6), cf * CFrame.new(0, 1.3, 0), PAL.stoneLight)
	local slab = P(parent, Vector3.new(w, h, 0.8), cf * CFrame.new(0, 1.6 + h / 2, 0), SLATE, Enum.Material.Slate)
	for _, sx in { -1, 1 } do
		P(parent, Vector3.new(0.9, h + 0.8, 1.4), cf * CFrame.new(sx * (w / 2 + 0.45), 1.6 + h / 2, 0), PAL.vermilion)
	end
	P(parent, Vector3.new(w + 1.6, 0.4, 1.4), cf * CFrame.new(0, 1.8 + h, 0), PAL.gold, Enum.Material.Metal)
	P(parent, Vector3.new(w + 3, 0.6, 3), cf * CFrame.new(0, 2.3 + h, 0), PAL.tile)
	P(parent, Vector3.new(w + 1.8, 0.7, 2.2), cf * CFrame.new(0, 2.9 + h, 0), PAL.tile)
	P(parent, Vector3.new(w + 0.4, 0.4, 0.8), cf * CFrame.new(0, 3.45 + h, 0), PAL.gold, Enum.Material.Metal)
	return slab
end

-- The podium: the top 3 of Greatest Sects as avatars in their own aura and beads (Config.RANK_PODIUM).
-- The standard of simulator leaderboards (statues of the top players by the board): the avatar from
-- GetHumanoidDescriptionFromUserId, built once when a place changes hands; the aura follows the realm
-- (a player here: its attribute; away: its save, read once per RANK_REFRESH) and the lives on the board.
local IDLE = "rbxassetid://507766666" -- the R15 idle
local saves = nil -- the game's save store (none in the Studio mock)
if not (Config.MOCK_DATASTORE and RunService:IsStudio()) then
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, Config.DATASTORE .. (RunService:IsStudio() and "_studio" or ""))
	saves = ok and result or nil
end
local realms = {} -- [userId] = { realm, at } read from an away player's save
local looks = {} -- [userId] = HumanoidDescription

-- the realm `r`'s player is in now (1 when unknown: no realm aura, beads only)
local function realmOf(r)
	if r.realm then -- Studio debug rows (Ranks.debugRows) carry their own
		return r.realm
	end
	local plr = Players:GetPlayerByUserId(r.userId)
	if plr and plr:GetAttribute("Realm") then
		return plr:GetAttribute("Realm")
	end
	local c = realms[r.userId]
	if c and os.clock() - c.at < Config.RANK_REFRESH then
		return c.realm
	end
	if not saves or DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync) < Config.RANK_MIN_BUDGET then
		return c and c.realm or 1
	end
	local ok, rec = pcall(saves.GetAsync, saves, "u" .. r.userId)
	local d = ok and type(rec) == "table" and (rec.data or (rec.v == nil and rec)) or nil
	local realm = type(d) == "table" and tonumber(d.realm) or (c and c.realm) or 1
	realms[r.userId] = { realm = realm, at = os.clock() }
	return realm
end

local function livesOf(r)
	local plr = Players:GetPlayerByUserId(r.userId)
	return plr and plr:GetAttribute("Lives") or r.extra or 1
end

-- `userId`'s avatar as a still R15 model, feet at the origin, facing -Z
local function avatar(userId)
	if not looks[userId] then
		local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
		looks[userId] = ok and desc or nil
	end
	local desc = looks[userId] or Instance.new("HumanoidDescription")
	local ok, m = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	if not ok then
		ok, m = pcall(Players.CreateHumanoidModelFromDescription, Players, Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
		if not ok then
			return nil
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.EvaluateStateMachine = false
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
		end
	end
	m.PrimaryPart.Anchored = true
	return m
end

-- cast `m` in metal of `color`: no clothes, face or textures (style "statue")
local function cast(m, color)
	for _, d in m:GetDescendants() do
		if d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("Decal") then
			d:Destroy()
		elseif d:IsA("MeshPart") then
			d.TextureID = ""
			d.Color = color
			d.Material = Enum.Material.Foil
		elseif d:IsA("BasePart") then
			d.Color = color
			d.Material = Enum.Material.Foil
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		end
	end
	local bc = m:FindFirstChildOfClass("BodyColors")
	if bc then
		bc:Destroy()
	end
end

-- the plaque on a plinth's front: rank, name, realms and lives
local function plaque(part)
	local g = Instance.new("SurfaceGui")
	g.Name = "Plaque"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = PPS
	g.LightInfluence = 0.2
	g.MaxDistance = Config.RANK_SEE
	local h = part.Size.Y * PPS
	local name = Instance.new("Frame")
	name.Name = "Line1"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, math.floor(h * 0.42))
	name.Position = UDim2.fromOffset(0, math.floor(h * 0.12))
	name.Parent = g
	local sub = name:Clone()
	sub.Name = "Line2"
	sub.Size = UDim2.new(1, 0, 0, math.floor(h * 0.3))
	sub.Position = UDim2.fromOffset(0, math.floor(h * 0.56))
	sub.Parent = g
	g.Parent = part
	return g
end

local function setPlaque(g, i, r)
	if not g then
		return
	end
	local line1, line2 = g:FindFirstChild("Line1"), g:FindFirstChild("Line2")
	line1:ClearAllChildren()
	line2:ClearAllChildren()
	local size = math.min(48, math.floor(line1.Size.Y.Offset * 0.8))
	label(line1, r and (i .. "  " .. r.name) or tostring(i), 0, size, MEDAL[i], Enum.TextXAlignment.Center)
	if r then
		local n = r.extra or 1
		label(line2, string.format("%d realms · %d %s", r.value or 0, n, n == 1 and "life" or "lives"), 0, math.floor(size * 0.7), JADE, Enum.TextXAlignment.Center)
	end
end

local podium = {} -- [i] = { at = CFrame of the feet, scale, plaque, userId, realm, lives, model, gen }

local function place(i, r)
	local slot = podium[i]
	if not slot then
		return
	end
	setPlaque(slot.plaque, i, r)
	local id = r and r.userId or nil
	if id == slot.userId and slot.model then
		local realm, lives = realmOf(r), livesOf(r)
		if realm ~= slot.realm or lives ~= slot.lives then
			slot.realm, slot.lives = realm, lives
			PlayerAura.build(slot.model, realm, lives - 1, Config.RANK_PODIUM.glyph * slot.scale)
		end
		return
	end
	slot.gen += 1
	local gen = slot.gen
	slot.userId = id
	if slot.model then
		slot.model:Destroy()
		slot.model = nil
	end
	if not r then
		return
	end
	local m = avatar(id)
	local realm, lives = realmOf(r), livesOf(r)
	if not m or slot.gen ~= gen then
		if m then
			m:Destroy()
		end
		return
	end
	m.Name = "Top" .. i
	if slot.scale ~= 1 then
		m:ScaleTo(slot.scale)
	end
	local hrp, hum = m.PrimaryPart, m:FindFirstChildOfClass("Humanoid")
	m:PivotTo(slot.at * CFrame.new(0, hrp.Size.Y / 2 + hum.HipHeight, 0))
	if Config.RANK_PODIUM.style == "statue" then
		cast(m, MEDAL[i])
	end
	m.Parent = slot.parent
	if Config.RANK_PODIUM.style ~= "statue" then
		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = hum
		end
		local a = Instance.new("Animation")
		a.AnimationId = IDLE
		local ok, track = pcall(animator.LoadAnimation, animator, a)
		if ok then
			track.Looped = true
			track:Play()
		end
	end
	slot.model, slot.realm, slot.lives = m, realm, lives
	PlayerAura.build(m, realm, lives - 1, Config.RANK_PODIUM.glyph * slot.scale)
end

-- one pass at a time (avatars yield); a change during a pass is placed right after it
local placing, want = false, nil
local function placeAll(rows)
	want = rows
	if placing then
		return
	end
	placing = true
	while want do
		local list = want
		want = nil
		for i = 1, 3 do
			local ok, err = pcall(place, i, list[i])
			if not ok then
				warn("[Tycoon][ranks] event=podium_failed", err)
			end
		end
	end
	placing = false
end

-- a stone dais in front of the gate (styles "steps" and "statue"): 2-1-3, the winner highest
local DAIS = { { x = 0, h = 2.1 }, { x = -3.7, h = 1.5 }, { x = 3.7, h = 1 } }
local DAIS_Z, DAIS_W, DAIS_D = -4.8, 3.4, 3.2
local function dais(parent, cf)
	local base = cf * CFrame.new(0, 0, DAIS_Z)
	P(parent, Vector3.new(DAIS_W * 3 + 1.4, 0.3, DAIS_D + 1), base * CFrame.new(0, 0.15, 0), PAL.stone)
	for i, d in DAIS do
		local block = P(parent, Vector3.new(DAIS_W, d.h, DAIS_D), base * CFrame.new(d.x, 0.3 + d.h / 2, 0), PAL.stoneLight)
		block.Name = "Place" .. i
		P(parent, Vector3.new(DAIS_W + 0.2, 0.2, DAIS_D + 0.2), base * CFrame.new(d.x, 0.3 + d.h + 0.1, 0), MEDAL[i], Enum.Material.Metal)
		podium[i] = { at = base * CFrame.new(d.x, 0.5 + d.h, 0), scale = 1, plaque = plaque(block), gen = 0, parent = parent }
	end
end

-- the winner on the gate's board, second and third on the steles' roofs (style "roof")
local function roofs(parent, cf, steles)
	local k = Config.RANK_PODIUM.roofScale
	local top = cf * CFrame.new(0, SECTS_Y + SECTS_H / 2 + 0.5, -0.9)
	P(parent, Vector3.new(0.4, 2.8, 2.8), top * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), MEDAL[1], Enum.Material.Metal, Enum.PartType.Cylinder)
	podium[1] = { at = top * CFrame.new(0, 0.4, 0), scale = k, gen = 0, parent = parent }
	for i, s in { [2] = steles.qi, [3] = steles.week } do
		local at = s * CFrame.new(0, 3.65 + STELE_H, 0)
		P(parent, Vector3.new(0.4, 2.8, 2.8), at * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), MEDAL[i], Enum.Material.Metal, Enum.PartType.Cylinder)
		podium[i] = { at = at * CFrame.new(0, 0.4, 0), scale = k, gen = 0, parent = parent }
	end
end

-- `cf` = the wall's centre on the ground, its -Z (the boards' Front face) toward the plaza
function RankBoard.build(parent, cf)
	local m = Instance.new("Model")
	m.Name = "RankWall"
	-- the gate with Greatest Sects in its opening
	mesh(m, Config.RANK_GATE, cf * CFrame.new(0, 0, 0.6) * CFrame.Angles(0, Config.RANK_GATE.yaw or 0, 0), Config.RANK_GATE.height)
	local slab = P(m, Vector3.new(SECTS_W, SECTS_H, 0.8), cf * CFrame.new(0, SECTS_Y, 0), SLATE, Enum.Material.Slate)
	slab.Name = "SectsBoard"
	for _, sy in { -1, 1 } do
		P(m, Vector3.new(SECTS_W + 0.8, 0.5, 1.2), cf * CFrame.new(0, SECTS_Y + sy * (SECTS_H / 2 + 0.25), 0), PAL.gold, Enum.Material.Metal)
	end
	guis.sects = face("sects", slab, Config.RANKS.sects.title, true)
	-- the two steles, turned a little toward the plaza
	local steles = {}
	for _, side in { { key = "qi", x = -STELE_X, yaw = 0.35 }, { key = "week", x = STELE_X, yaw = -0.35 } } do
		steles[side.key] = cf * CFrame.new(side.x, 0, -2.5) * CFrame.Angles(0, side.yaw, 0)
		local s = stele(m, steles[side.key], STELE_W, STELE_H)
		s.Name = side.key .. "Board"
		guis[side.key] = face(side.key, s, Config.RANKS[side.key].title, false)
	end
	-- guardians and fire in front, spaced for the bigger boards: braziers between the boards (their
	-- flames clear the text from the RANKINGS spot), lanterns behind the steles off the bridge posts
	-- (a dais in front of the gate pushes them out to its sides)
	local onDais = Config.RANK_PODIUM.style ~= "roof"
	if onDais then
		dais(m, cf)
	else
		roofs(m, cf, steles)
	end
	for _, sx in { -1, 1 } do
		mesh(m, Config.RANK_LION, cf * CFrame.new(sx * 22, 0, -5) * CFrame.Angles(0, (Config.RANK_LION.yaw or 0) + sx * 0.4, 0), Config.RANK_LION.height)
		brazier(m, cf * CFrame.new(sx * (onDais and 8.4 or 6), 0, -6))
		lantern(m, cf * CFrame.new(sx * 16.5, 0, 4))
	end
	m.Parent = parent
	for key, rows in Ranks.top do
		draw(key, rows)
	end
	for key in Config.RANKS do
		if not Ranks.top[key] then
			draw(key, {})
		end
	end
	Ranks.changed:Connect(draw)
	-- the podium follows Greatest Sects; between changes it checks the realms and lives of its three
	Ranks.changed:Connect(function(key, rows)
		if key == "sects" then
			task.spawn(placeAll, rows)
		end
	end)
	task.spawn(function()
		placeAll(Ranks.top.sects or {})
		while m.Parent do
			task.wait(Config.RANK_TICK)
			placeAll(Ranks.top.sects or {})
		end
	end)
	return m
end

return RankBoard
