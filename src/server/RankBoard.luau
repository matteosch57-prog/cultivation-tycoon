-- The hub's ranking wall (Ranks.luau boards; owner 2026-10-22: "C but way more premium", "3 different
-- rankings", no statues or podiums): a painted gate (free Creator Store mesh, Config.RANK_GATE) holds
-- Greatest Sects, two roofed steles beside it hold Richest Qi and This Week, two stone guardian lions
-- (Config.RANK_LION) and two braziers with real fire (R3: a visible lamp) frame it. Each board lists
-- the top RANK_TOP with head shots, the top 3 in gold, silver and bronze. Redrawn only when a board's
-- rows change (Ranks.changed), never per frame (R16).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local Style = require(script.Parent:WaitForChild("Style"))
local Ranks = require(script.Parent:WaitForChild("Ranks"))

local RankBoard = {}

local P, PAL = Style.P, Style.PAL
local H = Color3.fromHex
local SLATE = H("2A2D35")
local INK = H("1B1420")
local MEDAL = { H("FFD34D"), H("E6ECF2"), H("E0A060") }
local CREAM = H("FFF1D6")
local JADE = H("9FF5C8")
local PPS = 45 -- SurfaceGui pixels per stud

local guis = {} -- [key] = SurfaceGui
local heads = {} -- [userId] = head shot content id

local function headOf(userId)
	if heads[userId] == nil then
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
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
local function draw(key, rows)
	local g = guis[key]
	if not g then
		return
	end
	for _, c in g:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local big = key == "sects"
	for i, r in rows do
		local top = i <= 3
		local h = top and (big and 46 or 40) or (big and 36 or 32)
		local f = Instance.new("Frame")
		f.LayoutOrder = i
		f.Size = UDim2.new(1, 0, 0, h)
		f.BackgroundColor3 = top and MEDAL[i] or Color3.new(1, 1, 1)
		f.BackgroundTransparency = top and 0.6 or 0.88
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = f
		local size = top and (big and 26 or 22) or (big and 21 or 18)
		label(f, tostring(i), 8, size + 2, top and MEDAL[i] or CREAM, nil, 30)
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromOffset(h - 6, h - 6)
		img.Position = UDim2.fromOffset(38, 3)
		img.Image = headOf(r.userId)
		img.Parent = f
		label(f, r.name, 38 + h, size, Color3.new(1, 1, 1), nil, big and 250 or 170)
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
		label(f, "Be the first sect here", 0, 22, CREAM, Enum.TextXAlignment.Center)
		f.Parent = g
	end
end

-- a slate face with its title; returns the SurfaceGui that holds the rows
local function face(slab, title, big)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = PPS
	g.LightInfluence = 0.2
	g.MaxDistance = Config.RANK_SEE
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 3)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = g
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = g
	local t = Instance.new("Frame")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, big and 52 or 44)
	t.LayoutOrder = 0
	label(t, title, 0, big and 44 or 36, MEDAL[1], Enum.TextXAlignment.Center)
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
		local mp = Instance.new("MeshPart")
		local ok = pcall(function()
			mp.MeshId = part.mesh
		end)
		if ok then
			mp.Anchored = true
			mp.TextureID = part.texture or ""
			mp.Size = part.size * k
			mp.CFrame = cf * (part.at - part.at.Position + part.at.Position * k)
			mp.Parent = m
		else
			mp:Destroy()
		end
	end
	m.Parent = parent
	return m
end

local function brazier(parent, cf)
	P(parent, Vector3.new(2.2, 3, 2.2), cf * CFrame.new(0, 1.5, 0), H("3A2A20"), Enum.Material.Metal)
	local bowl = P(parent, Vector3.new(3.2, 0.8, 3.2), cf * CFrame.new(0, 3.4, 0), PAL.gold, Enum.Material.Metal)
	local coals = P(parent, Vector3.new(2.4, 0.3, 2.4), cf * CFrame.new(0, 3.9, 0), H("FF7A2A"), Enum.Material.Neon)
	coals.CastShadow = false
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Color = H("FF9A3C")
	fire.SecondaryColor = H("FFD34D")
	fire.Parent = bowl
	local light = Instance.new("PointLight")
	light.Color = H("FFB070")
	light.Range = 16
	light.Brightness = 1.8
	light.Shadows = false
	light.Parent = coals
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
	Style.roof(parent, cf * CFrame.new(0, 2.2 + h, 0), w + 2.4, 3.4, { rise = 1.6, over = 0.8 })
	return slab
end

-- `cf` = the wall's centre on the ground, its -Z (the boards' Front face) toward the plaza
function RankBoard.build(parent, cf)
	local m = Instance.new("Model")
	m.Name = "RankWall"
	-- the gate with Greatest Sects in its opening
	mesh(m, Config.RANK_GATE, cf * CFrame.new(0, 0, 0.6) * CFrame.Angles(0, Config.RANK_GATE.yaw or 0, 0), Config.RANK_GATE.height)
	local slab = P(m, Vector3.new(12, 8.4, 0.8), cf * CFrame.new(0, 7.6, 0), SLATE, Enum.Material.Slate)
	slab.Name = "SectsBoard"
	P(m, Vector3.new(12.8, 0.5, 1.2), cf * CFrame.new(0, 12, 0), PAL.gold, Enum.Material.Metal)
	P(m, Vector3.new(12.8, 0.5, 1.2), cf * CFrame.new(0, 3.2, 0), PAL.gold, Enum.Material.Metal)
	guis.sects = face(slab, Config.RANKS.sects.title, true)
	-- the two steles, turned a little toward the plaza
	for _, side in { { key = "qi", x = -13.5, yaw = 0.35 }, { key = "week", x = 13.5, yaw = -0.35 } } do
		local s = stele(m, cf * CFrame.new(side.x, 0, -2) * CFrame.Angles(0, side.yaw, 0), 9, 7.2)
		s.Name = side.key .. "Board"
		guis[side.key] = face(s, Config.RANKS[side.key].title, false)
	end
	-- guardians and fire in front
	for _, sx in { -1, 1 } do
		mesh(m, Config.RANK_LION, cf * CFrame.new(sx * 20, 0, -4) * CFrame.Angles(0, (Config.RANK_LION.yaw or 0) + sx * 0.4, 0), Config.RANK_LION.height)
		brazier(m, cf * CFrame.new(sx * 7.5, 0, -5))
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
	return m
end

return RankBoard
