-- The HUD language (mock C) as a kit for new screens: outlined chunky text, toy buttons, icons
-- drawn from UI shapes. Same look as Hud.client.luau (which still carries its own copy).
-- Every size goes through Toy.px, so a screen scales with Toy.S (set by the caller).
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sfx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sfx"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Toy = {}
Toy.S = 1
Toy.INK = Color3.fromHex("1B1420")
Toy.FONT = Font.fromEnum(Enum.Font.FredokaOne)

function Toy.px(v)
	return math.floor(v * Toy.S + 0.5)
end
local px = Toy.px

function Toy.frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	for k, v in props or {} do
		f[k] = v
	end
	f.Parent = parent
	return f
end
local frame = Toy.frame

function Toy.corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r
	c.Parent = parent
	return c
end
local corner = Toy.corner

function Toy.list(parent, horizontal, gap, props)
	local l = Instance.new("UIListLayout")
	l.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap or 0)
	for k, v in props or {} do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- outlined chunky text (never cut: it grows with its text, R4)
function Toy.text(parent, str, size, color, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = Toy.FONT
	t.Text = str
	t.TextSize = size
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.AutomaticSize = Enum.AutomaticSize.XY
	t.Size = UDim2.new()
	for k, v in props or {} do
		t[k] = v
	end
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = math.max(1.5, size * 0.11)
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.Parent = t
	t.Parent = parent
	return t
end

-- toy button: solid shadow + outlined face + shine. Returns (holder, button).
function Toy.button(parent, size, color, radius)
	local holder = frame(parent, { Size = size })
	local shadow = frame(holder, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(4)), BackgroundTransparency = 0, BackgroundColor3 = Toy.INK })
	corner(shadow, UDim.new(0, radius))
	local btn = Instance.new("TextButton")
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.Parent = holder
	corner(btn, UDim.new(0, radius))
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = px(3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = btn
	local shine = frame(btn, { Size = UDim2.fromScale(0.8, 0.2), Position = UDim2.fromScale(0.1, 0.1), BackgroundTransparency = 0.62, BackgroundColor3 = Color3.new(1, 1, 1) })
	corner(shine, UDim.new(1, 0))
	local sc = Instance.new("UIScale")
	sc.Parent = holder
	local function to(s, t, style)
		TweenService:Create(sc, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = s }):Play()
	end
	btn.MouseEnter:Connect(function()
		to(1.06, 0.12)
	end)
	btn.MouseButton1Down:Connect(function()
		btn.Position = UDim2.fromOffset(0, px(3))
		to(0.92, 0.06)
	end)
	local function up()
		btn.Position = UDim2.new()
		to(1, 0.35, Enum.EasingStyle.Back)
	end
	btn.MouseButton1Up:Connect(up)
	btn.MouseLeave:Connect(up)
	btn.Activated:Connect(function()
		Sfx.play("click")
	end)
	return holder, btn
end

-- Shapes in a 64-unit icon box; each shape gets a dark outline copy underneath (lower ZIndex) so
-- overlapping fills merge into one outlined silhouette.
local Icon = {}
Icon.__index = Icon
Toy.Icon = Icon
function Icon.new(parent, size, props)
	local box = frame(parent, { Size = UDim2.fromOffset(size, size) })
	for k, v in props or {} do
		box[k] = v
	end
	return setmetatable({ box = box, u = size / 64, ow = math.max(2, size / 64 * 4.5) }, Icon)
end
function Icon:_shape(cx, cy, w, h, color, radius, rot, outline)
	local u = self.u
	local function make(extra, col, z)
		local f = frame(self.box, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx * u, cy * u),
			Size = UDim2.fromOffset(w * u + extra * 2, h * u + extra * 2),
			BackgroundTransparency = 0,
			BackgroundColor3 = col,
			Rotation = rot or 0,
			ZIndex = z,
		})
		if radius then
			corner(f, radius)
		end
		return f
	end
	if outline ~= false then
		make(self.ow, Toy.INK, 1)
	end
	return make(0, color, 2)
end
function Icon:circle(cx, cy, r, color, outline)
	return self:_shape(cx, cy, r * 2, r * 2, color, UDim.new(0.5, 0), 0, outline)
end
function Icon:rect(cx, cy, w, h, color, radius, rot, outline)
	return self:_shape(cx, cy, w, h, color, radius and UDim.new(0, radius * self.u) or nil, rot, outline)
end
function Icon:detail(cx, cy, r, color, transparency) -- un-outlined highlight on top
	local f = self:_shape(cx, cy, r * 2, r * 2, color, UDim.new(0.5, 0), 0, false)
	f.ZIndex = 3
	f.BackgroundTransparency = transparency or 0
	return f
end

-- the qi drop (same drawing as the HUD counter); `s` scales it inside the box, (cx, cy) its centre
function Icon:qi(cx, cy, s)
	s = s or 1
	self:circle(cx, cy + 8 * s, 20 * s, Color3.fromHex("6FD6AE"))
	self:rect(cx, cy - 9 * s, 27 * s, 27 * s, Color3.fromHex("6FD6AE"), 3 * s, 45)
	self:detail(cx + 5 * s, cy + 8 * s, 9 * s, Color3.fromHex("E8FFF4"))
	self:detail(cx - 9 * s, cy + 3 * s, 4 * s, Color3.new(1, 1, 1), 0.2)
end

-- the karma orb (reincarnation currency): a purple orb with a light swirl; same box rules as qi
function Icon:karma(cx, cy, s)
	s = s or 1
	self:circle(cx, cy, 22 * s, Color3.fromHex("9A6BFF"))
	self:detail(cx + 4 * s, cy + 3 * s, 12 * s, Color3.fromHex("D9B8FF"))
	self:detail(cx + 7 * s, cy + 5 * s, 5 * s, Color3.fromHex("9A6BFF"))
	self:detail(cx - 9 * s, cy - 9 * s, 4 * s, Color3.new(1, 1, 1), 0.15)
end

-- Item icons for the shop (one drawing per key). Every currency has one: "qi", "karma" (R4 owner
-- rule: an amount of a currency always shows its icon)
local ICONS = {}
function ICONS.qi(ic)
	ic:qi(32, 34, 0.95)
end
function ICONS.karma(ic)
	ic:karma(32, 32, 1.1)
end
function ICONS.x2(ic)
	ic:qi(26, 28, 0.85)
	return "2x"
end
function ICONS.auto(ic)
	ic:circle(10, 16, 5, Color3.fromHex("9FF5D0"))
	ic:circle(14, 48, 6, Color3.fromHex("9FF5D0"))
	ic:circle(21, 31, 7, Color3.fromHex("9FF5D0"))
	ic:circle(43, 32, 17, Color3.fromHex("9FF5D0"))
	ic:detail(37, 26, 6, Color3.new(1, 1, 1), 0.15)
end
function ICONS.vip(ic)
	local gold = Color3.fromHex("FFD34D")
	ic:rect(32, 38, 46, 22, gold, 3)
	ic:rect(12, 22, 14, 14, gold, 2, 45)
	ic:rect(32, 16, 16, 16, gold, 2, 45)
	ic:rect(52, 22, 14, 14, gold, 2, 45)
	ic:rect(32, 51, 50, 10, Color3.fromHex("FFB02E"), 3)
	ic:circle(32, 36, 5, Color3.fromHex("59D39F"))
	ic:detail(17, 32, 3, Color3.new(1, 1, 1), 0.3)
end
function ICONS.pill(ic)
	ic:rect(23, 32, 22, 20, Color3.fromHex("E65B4F"), 10)
	ic:rect(41, 32, 22, 20, Color3.fromHex("FFF4DC"), 10)
	ic:detail(20, 27, 3, Color3.new(1, 1, 1), 0.3)
	ic.box.Rotation = -35
end
local PACKS = { pack1 = 1, pack2 = 3, pack3 = 6 }
local PACK_AT = { { 32, 40, 0.62 }, { 18, 44, 0.5 }, { 46, 44, 0.5 }, { 25, 24, 0.44 }, { 40, 22, 0.44 }, { 32, 12, 0.38 } }
local function pack(n)
	return function(ic)
		for i = n, 1, -1 do
			local a = PACK_AT[i]
			ic:qi(a[1], a[2], a[3])
		end
	end
end
for key, n in PACKS do
	ICONS[key] = pack(n)
end
function ICONS.bag(ic)
	ic:rect(32, 15, 18, 9, Color3.fromHex("E65B4F"), 2)
	ic:circle(32, 40, 22, Color3.fromHex("FFD34D"))
	ic:rect(32, 22, 22, 6, Color3.fromHex("E65B4F"), 2)
	ic:qi(32, 39, 0.42)
	ic:detail(18, 36, 3, Color3.new(1, 1, 1), 0.3)
end

-- a disciple in a robe of `robe` (the HUD's disciple drawing)
local function disciple(ic, robe)
	ic:rect(32, 52, 38, 22, robe, 9)
	ic:circle(32, 12, 7, Toy.INK)
	ic:circle(32, 29, 13, Color3.fromHex("F2CFAE"))
	ic:rect(32, 21, 24, 7, Toy.INK, 3, 0, false).ZIndex = 3
	ic:rect(32, 47, 8, 12, Color3.new(1, 1, 1), 2, 0, false).ZIndex = 3
end

-- Currency marks (owner rule: every price or amount shows its currency's icon)
function Toy.qiIcon(parent, size, props)
	return Toy.icon(parent, "qi", size, props) -- the shared currency drawing (ICONS.qi)
end
function Toy.robuxIcon(parent, size, props)
	local ic = Icon.new(parent, size, props)
	ic:rect(32, 32, 46, 46, Color3.new(1, 1, 1), 13)
	ic:rect(32, 32, 18, 18, Toy.INK, 3, 0, false).ZIndex = 3
	return ic.box
end

-- An amount with its currency icon in front: returns (row, label). `currency` = "qi" | "robux"
function Toy.amount(parent, currency, size, color, props)
	local row = Toy.frame(parent, { AutomaticSize = Enum.AutomaticSize.XY })
	for k, v in props or {} do
		row[k] = v
	end
	Toy.list(row, true, math.max(2, math.floor(size * 0.2)))
	local icon = (currency == "qi" and Toy.qiIcon or Toy.robuxIcon)(row, math.floor(size * 1.15), { LayoutOrder = 1 })
	icon.Name = "Currency"
	local label = Toy.text(row, "", size, color, { LayoutOrder = 2 })
	return row, label
end

-- Draws icon `key` in a size x size box; returns the box. A shop item with a `rarity` draws that
-- disciple in its rarity colour.
function Toy.icon(parent, key, size, props)
	local ic = Icon.new(parent, size, props)
	local item = Config.shopItem(key)
	if item and item.rarity then
		disciple(ic, Config.rarity(item.rarity).color)
		return ic.box
	end
	local badge = ICONS[key] and ICONS[key](ic)
	if badge then
		Toy.text(ic.box, badge, math.floor(size * 0.36), Color3.fromHex("FFE36B"), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.72, 0.8), ZIndex = 4 })
	end
	return ic.box
end

return Toy
