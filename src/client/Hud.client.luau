-- Cultivation Tycoon HUD (mock C, docs/mocks/hud_C_*): no panels, chunky outlined numbers,
-- toy buttons. Icons are drawn from UI shapes (no uploaded images). The layout follows the
-- device: phone sizes from a 390px-tall reference, computer ~1.3x, and it steers around
-- Roblox's own topbar, thumbstick and jump button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sfx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sfx"))

local INK = Color3.fromHex("1B1420")
local JADE = Color3.fromHex("59D39F")
local JADE_LIGHT = Color3.fromHex("C9FFE4")
local GOLD = Color3.fromHex("FFE36B")
local PINK = Color3.fromHex("FFB3A8")
local TIDE = Color3.fromHex("9FD0FF")
local TIDE_LIGHT = Color3.fromHex("CFE6FF")
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

---------------------------------------------------------------------------------------------
-- number formatting
local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
local function short(n)
	n = math.floor(n or 0)
	if n < 1e6 then
		return commas(n)
	end
	local units = { "M", "B", "T", "Qa", "Qi" }
	local v, i = n / 1e6, 1
	while v >= 1000 and i < #units do
		v /= 1000
		i += 1
	end
	local digits = v < 10 and 2 or (v < 100 and 1 or 0)
	local f = 10 ^ digits
	return string.format("%." .. digits .. "f%s", math.floor(v * f) / f, units[i])
end
local function compact(n) -- for small price tags: 3.5K
	n = math.floor(n or 0)
	if n < 1000 then
		return tostring(n)
	end
	local units = { "K", "M", "B", "T", "Qa" }
	local v, i = n / 1000, 1
	while v >= 1000 and i < #units do
		v /= 1000
		i += 1
	end
	local digits = v < 10 and 1 or 0
	local f = 10 ^ digits
	return string.format("%." .. digits .. "f%s", math.floor(v * f) / f, units[i])
end

---------------------------------------------------------------------------------------------
-- device + scale
local S = 1
-- player attribute HudDevice = "pc" / "phone" forces a layout (testing from an emulator)
local function jumpButton()
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	if jump and jump.Visible and jump.AbsoluteSize.X > 0 then
		return jump
	end
	return nil
end
local function isPhone()
	local forced = player:GetAttribute("HudDevice")
	if forced then
		return forced == "phone"
	end
	-- Roblox's own touch controls on screen are the truth (emulators and touch laptops also
	-- report a keyboard, so TouchEnabled/KeyboardEnabled alone guess wrong)
	if jumpButton() then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end
local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	if isPhone() then
		return math.clamp(vp.Y / 390, 0.78, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7) -- 720p -> 1.3, 1080p -> 1.7
end
local function px(v)
	return math.floor(v * S + 0.5)
end

---------------------------------------------------------------------------------------------
-- primitives
local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	for k, v in props or {} do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r
	c.Parent = parent
	return c
end

-- outlined chunky text
local function text(parent, str, size, color, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.Text = str
	t.TextSize = size
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.AutomaticSize = Enum.AutomaticSize.XY
	t.Size = UDim2.new()
	for k, v in props or {} do
		t[k] = v
	end
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = math.max(1.5, size * 0.11)
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.Parent = t
	t.Parent = parent
	return t
end

-- Shapes in a 64-unit icon box (like the mock's SVGs). Each shape gets a dark outline copy
-- underneath (lower ZIndex) so overlapping fills merge into one outlined silhouette.
local Icon = {}
Icon.__index = Icon
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
		make(self.ow, INK, 1)
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

local function qiIcon(parent, size, props)
	local ic = Icon.new(parent, size, props)
	ic:circle(32, 40, 20, Color3.fromHex("6FD6AE"))
	ic:rect(32, 23, 27, 27, Color3.fromHex("6FD6AE"), 3, 45)
	ic:detail(37, 40, 9, Color3.fromHex("E8FFF4"))
	ic:detail(23, 35, 4, Color3.new(1, 1, 1), 0.2)
	return ic.box
end

local function discipleIcon(parent, size, robe, props)
	local ic = Icon.new(parent, size, props)
	ic:rect(32, 52, 38, 22, robe or Color3.fromHex("5096FF"), 9)
	ic:circle(32, 12, 7, INK)
	ic:circle(32, 29, 13, Color3.fromHex("F2CFAE"))
	local hair = ic:rect(32, 21, 24, 7, INK, 3, 0, false)
	hair.ZIndex = 3
	local collar = ic:rect(32, 47, 8, 12, Color3.new(1, 1, 1), 2, 0, false)
	collar.ZIndex = 3
	return ic.box
end

-- returns (slot, spinner): the slot sits in the layout, the spinner inside it is what rotates
local function arrowIcon(parent, size, props)
	local slot = frame(parent, { Size = UDim2.fromOffset(size, size) })
	for k, v in props or {} do
		slot[k] = v
	end
	local ic = Icon.new(slot, size)
	ic:rect(24, 32, 30, 14, GOLD, 3)
	ic:rect(42, 32, 26, 26, GOLD, 3, 45)
	return slot, ic.box
end

-- toy button: solid shadow + outlined face + shine. Returns (holder, face, button).
local function toy(parent, size, color, radius)
	local holder = frame(parent, { Size = size })
	local shadow = frame(holder, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(4)), BackgroundTransparency = 0, BackgroundColor3 = INK })
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
	st.Color = INK
	st.Thickness = px(3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = btn
	local shine = frame(btn, { Size = UDim2.new(0.8, 0, 0.2, 0), Position = UDim2.fromScale(0.1, 0.1), BackgroundTransparency = 0.62, BackgroundColor3 = Color3.new(1, 1, 1) })
	corner(shine, UDim.new(1, 0))
	-- feel: hover grows it a touch, press sinks it onto its shadow and squishes, release springs
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

---------------------------------------------------------------------------------------------
-- state
local state = {
	shownQi = player:GetAttribute("Qi") or 0,
	lastQi = player:GetAttribute("Qi") or 0,
	discOpen = false,
}
local ui = {} -- rebuilt on viewport change

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function myPads()
	local list = {}
	local sect = workspace:FindFirstChild("Sect")
	if not sect then
		return list
	end
	for _, peak in sect:GetChildren() do
		local built = peak:FindFirstChild("Built")
		if built then
			for _, p in built:GetChildren() do
				if p.Name:sub(1, 4) == "Pad_" and p:GetAttribute("OwnerId") == player.UserId then
					table.insert(list, p)
				end
			end
		end
	end
	return list
end

---------------------------------------------------------------------------------------------
-- build
local toastLayer
local rebuildAll -- forward
local popGain -- forward (the gift button calls it)
local toast -- forward (it used to live on `ui`, which build() replaces: the recruit button
-- then called a nil toast, errored, and stayed locked after the first recruit)
local function build()
	gui:ClearAllChildren()
	ui = {}
	state.phoneMode = isPhone()
	S = computeScale()
	local root = frame(gui, { Size = UDim2.fromScale(1, 1) })
	ui.root = root

	-- qi counter: top centre
	local counter = frame(root, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, px(8)), AutomaticSize = Enum.AutomaticSize.XY })
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, px(6))
	row.Parent = counter
	qiIcon(counter, px(46), { LayoutOrder = 1 })
	local col = frame(counter, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	local colLayout = Instance.new("UIListLayout")
	colLayout.Padding = UDim.new(0, px(1))
	colLayout.Parent = col
	ui.qi = text(col, short(state.shownQi), px(38), Color3.new(1, 1, 1), { LayoutOrder = 1 })
	ui.rate = text(col, "+0/s", px(16), Color3.fromHex("9FF5C8"), { LayoutOrder = 2 })
	-- Spirit Tide line (mock tycoon_ideas idea 3 A): countdown, then the 2x timer
	ui.tide = text(col, "", px(12), TIDE_LIGHT, { LayoutOrder = 3 })
	ui.counter = counter
	counter.Name = "Counter" -- Juice flies qi drops into it

	-- left column: Disciples (others appear when their features exist)
	local left = frame(root, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, px(12), 0.45, 0), AutomaticSize = Enum.AutomaticSize.XY })
	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, px(10))
	leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	leftLayout.Parent = left
	local dCol = frame(left, { AutomaticSize = Enum.AutomaticSize.XY })
	local dLayout = Instance.new("UIListLayout")
	dLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dLayout.Padding = UDim.new(0, px(2))
	dLayout.Parent = dCol
	local dHolder, dBtn = toy(dCol, UDim2.fromOffset(px(54), px(54)), Color3.fromHex("9FD0FF"), px(14))
	dHolder.LayoutOrder = 1
	discipleIcon(dBtn, px(40), nil, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local badge = frame(dBtn, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -px(2), 0, px(2)), Size = UDim2.fromOffset(px(22), px(22)), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("EE3333"), ZIndex = 5 })
	corner(badge, UDim.new(1, 0))
	local bst = Instance.new("UIStroke")
	bst.Color = INK
	bst.Thickness = px(3)
	bst.Parent = badge
	ui.badge = text(badge, "0", px(13), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 6 })
	ui.badgeFrame = badge
	local dLabel = text(dCol, "Disciples", px(13))
	dLabel.LayoutOrder = 2
	ui.dCol = dCol

	-- Pill (Alchemy Furnace): brewing countdown -> ready (wobbles) -> active 2x timer
	local pCol = frame(left, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	local pLayout2 = Instance.new("UIListLayout")
	pLayout2.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pLayout2.Padding = UDim.new(0, px(2))
	pLayout2.Parent = pCol
	local pHolder, pBtn = toy(pCol, UDim2.fromOffset(px(54), px(54)), Color3.fromHex("FFD36B"), px(14))
	pHolder.LayoutOrder = 1
	local pill = Icon.new(pBtn, px(40), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Rotation = -35 })
	pill:rect(23, 32, 22, 20, Color3.fromHex("E65B4F"), 10)
	pill:rect(41, 32, 22, 20, Color3.fromHex("FFF4DC"), 10)
	pill:detail(20, 27, 3, Color3.new(1, 1, 1), 0.3)
	ui.pillLabel = text(pCol, "Pill", px(13), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	ui.pCol = pCol
	ui.pillHolder = pHolder
	ui.pillBtn = pBtn
	pBtn.Activated:Connect(function()
		if player:GetAttribute("PillReady") then
			local ok, used = pcall(function()
				return remotes.UsePill:InvokeServer()
			end)
			if ok and used then
				toast("Pill swallowed: 2x Qi for 60 s!", GOLD, 2)
			end
		else
			toast("The furnace is still brewing", PINK, 1.2)
		end
	end)
	-- Playtime gift (mock tycoon_ideas idea 2 A): countdown -> ready (wobbles, red dot) -> claim
	local gCol = frame(left, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	local gLayout = Instance.new("UIListLayout")
	gLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gLayout.Padding = UDim.new(0, px(2))
	gLayout.Parent = gCol
	local gHolder, gBtn = toy(gCol, UDim2.fromOffset(px(54), px(54)), Color3.fromHex("FFB3A8"), px(14))
	gHolder.LayoutOrder = 1
	local gift = Icon.new(gBtn, px(40), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	gift:rect(32, 42, 42, 28, Color3.fromHex("E65B4F"), 4)
	gift:rect(32, 25, 50, 12, Color3.fromHex("FF7A6B"), 3)
	gift:rect(32, 37, 8, 38, Color3.fromHex("FFD34D"), nil, 0, false)
	gift:detail(22, 22, 3, Color3.new(1, 1, 1), 0.3)
	local gDot = frame(gBtn, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -px(2), 0, px(2)), Size = UDim2.fromOffset(px(18), px(18)), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("EE3333"), ZIndex = 5 })
	corner(gDot, UDim.new(1, 0))
	local gst = Instance.new("UIStroke")
	gst.Color = INK
	gst.Thickness = px(3)
	gst.Parent = gDot
	ui.giftLabel = text(gCol, "Gift", px(13), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	ui.gCol = gCol
	ui.giftBtn = gBtn
	ui.giftDot = gDot
	gBtn.Activated:Connect(function()
		if (player:GetAttribute("GiftIn") or -1) == 0 then
			local ok, gain = pcall(function()
				return remotes.ClaimGift:InvokeServer()
			end)
			if ok and gain then
				popGain(gain, true)
				toast("Gift  +" .. compact(gain) .. " Qi", GOLD, 2)
			end
		else
			toast("Keep playing: your next gift is on its way", PINK, 1.5)
		end
	end)
	ui.left = left
	ui.dBtn = dBtn

	-- disciples card (opens beside the button)
	local card = frame(root, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, px(80), 0.45, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("FFF4DC"), Visible = state.discOpen })
	corner(card, UDim.new(0, px(14)))
	local cst = Instance.new("UIStroke")
	cst.Color = INK
	cst.Thickness = px(3)
	cst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cst.Parent = card
	local cpad = Instance.new("UIPadding")
	cpad.PaddingTop = UDim.new(0, px(8))
	cpad.PaddingBottom = UDim.new(0, px(10))
	cpad.PaddingLeft = UDim.new(0, px(12))
	cpad.PaddingRight = UDim.new(0, px(12))
	cpad.Parent = card
	local cLayout = Instance.new("UIListLayout")
	cLayout.Padding = UDim.new(0, px(3))
	cLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cLayout.Parent = card
	ui.card = card
	dBtn.Activated:Connect(function()
		state.discOpen = not state.discOpen
		card.Visible = state.discOpen
	end)

	-- realm progress: bottom centre
	local prog = frame(root, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -px(14)), AutomaticSize = Enum.AutomaticSize.XY })
	local pLayout = Instance.new("UIListLayout")
	pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pLayout.Padding = UDim.new(0, px(2))
	pLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pLayout.Parent = prog
	ui.realm = text(prog, "", px(15), Color3.fromHex("FFE9A8"), { LayoutOrder = 1 })
	local barHolder = frame(prog, { Size = UDim2.fromOffset(px(240), px(24)), LayoutOrder = 2 })
	local barShadow = frame(barHolder, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(3)), BackgroundTransparency = 0, BackgroundColor3 = INK })
	corner(barShadow, UDim.new(1, 0))
	local track = frame(barHolder, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("3A2D40"), ClipsDescendants = true })
	corner(track, UDim.new(1, 0))
	local tst = Instance.new("UIStroke")
	tst.Color = INK
	tst.Thickness = px(3)
	tst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tst.Parent = track
	ui.fill = frame(track, { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = JADE })
	corner(ui.fill, UDim.new(1, 0))
	ui.progText = text(track, "", px(14), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	ui.prog = prog

	-- recruit: bottom right (placed by layout())
	local rHolder, rBtn = toy(root, UDim2.fromOffset(px(150), px(56)), Color3.fromHex("B06BFF"), px(14))
	rHolder.AnchorPoint = Vector2.new(1, 1)
	rHolder.Rotation = -2
	local rRow = frame(rBtn, { Size = UDim2.fromScale(1, 1) })
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rl.VerticalAlignment = Enum.VerticalAlignment.Center
	rl.Padding = UDim.new(0, px(6))
	rl.Parent = rRow
	discipleIcon(rRow, px(34), nil, { LayoutOrder = 1 })
	local rText = frame(rRow, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	local rtl = Instance.new("UIListLayout")
	rtl.Padding = UDim.new(0, px(1))
	rtl.Parent = rText
	text(rText, "Recruit", px(20), Color3.new(1, 1, 1), { LayoutOrder = 1 })
	local priceRow = frame(rText, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	local prl = Instance.new("UIListLayout")
	prl.FillDirection = Enum.FillDirection.Horizontal
	prl.VerticalAlignment = Enum.VerticalAlignment.Center
	prl.Padding = UDim.new(0, px(3))
	prl.Parent = priceRow
	qiIcon(priceRow, px(16), { LayoutOrder = 1 })
	ui.recruitCost = text(priceRow, "", px(14), JADE_LIGHT, { LayoutOrder = 2 })
	ui.recruit = rHolder
	ui.recruitBtn = rBtn

	-- next goal: top right, under Roblox's own buttons
	local goal = frame(root, { AnchorPoint = Vector2.new(1, 0), AutomaticSize = Enum.AutomaticSize.XY, Rotation = 2 })
	local gl = Instance.new("UIListLayout")
	gl.FillDirection = Enum.FillDirection.Horizontal
	gl.VerticalAlignment = Enum.VerticalAlignment.Center
	gl.Padding = UDim.new(0, px(6))
	gl.Parent = goal
	local _, spinner = arrowIcon(goal, px(30), { LayoutOrder = 1 })
	ui.arrow = spinner
	local gt = frame(goal, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	local gtl = Instance.new("UIListLayout")
	gtl.Padding = UDim.new(0, px(2))
	gtl.Parent = gt
	ui.goalName = text(gt, "", px(14), Color3.new(1, 1, 1), { LayoutOrder = 1 })
	ui.goalCost = text(gt, "", px(13), PINK, { LayoutOrder = 2 })
	ui.goal = goal

	toastLayer = frame(root, { Size = UDim2.fromScale(1, 1), ZIndex = 20 })
	-- every list follows LayoutOrder (the default sorts by Name, which put the price above "Recruit")
	for _, d in root:GetDescendants() do
		if d:IsA("UIListLayout") then
			d.SortOrder = Enum.SortOrder.LayoutOrder
		end
	end

	rBtn.Activated:Connect(function()
		if state.recruiting then
			return
		end
		state.recruiting = true
		local ok, res = pcall(function()
			return remotes.Recruit:InvokeServer()
		end)
		state.recruiting = false -- always release, whatever happens below
		if ok and res and res.ok then
			local r = Config.rarity(res.rarity)
			local fxEvent = playerGui:FindFirstChild("RecruitFx")
			if fxEvent then
				fxEvent:Fire(res.rarity, res.kept) -- sound + light column on the platform (Juice)
			end
			toast(res.kept and ("New disciple: " .. res.rarity .. "!") or (res.rarity .. " left: your disciples are stronger"), r.color, 2.5)
		elseif ok and res then
			toast(res.reason, PINK, 1.5)
		end
	end)
end

---------------------------------------------------------------------------------------------
-- toasts and the little "+N" that pops off the counter
toast = function(str, color, hold)
	if not toastLayer then
		return
	end
	local t = text(toastLayer, str, px(22), color or Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), ZIndex = 21, TextWrapped = false })
	local sc = Instance.new("UIScale")
	sc.Scale = 0.4
	sc.Parent = t
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Sfx.play("toast")
	task.delay(hold or 2.5, function()
		local st = t:FindFirstChildOfClass("UIStroke")
		TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.27) }):Play()
		if st then
			TweenService:Create(st, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
		task.wait(0.55)
		t:Destroy()
	end)
end

popGain = function(amount, big)
	if not ui.counter or amount <= 0 then
		return
	end
	-- the counter bumps every time qi lands (bigger for orbs and grants)
	local bump = ui.counter:FindFirstChild("Bump") or Instance.new("UIScale")
	bump.Name = "Bump"
	bump.Parent = ui.counter
	bump.Scale = big and 1.22 or 1.08
	TweenService:Create(bump, TweenInfo.new(big and 0.5 or 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local abs = ui.counter.AbsolutePosition - ui.root.AbsolutePosition
	local t = text(ui.root, "+" .. compact(amount), px(18), GOLD, {
		Position = UDim2.fromOffset(abs.X + ui.counter.AbsoluteSize.X + px(2), abs.Y + px(4)),
		Rotation = -8,
		ZIndex = 10,
	})
	local st = t:FindFirstChildOfClass("UIStroke")
	TweenService:Create(t, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Position = t.Position - UDim2.fromOffset(0, px(22)), TextTransparency = 1 }):Play()
	if st then
		TweenService:Create(st, TweenInfo.new(0.9), { Transparency = 1 }):Play()
	end
	task.delay(0.95, function()
		t:Destroy()
	end)
end

---------------------------------------------------------------------------------------------
-- layout: place things around Roblox's own controls (called on any change)
local function layout()
	if not ui.root then
		return
	end
	if isPhone() ~= state.phoneMode then
		-- the touch controls appeared or went away (late spawn, touch laptop): resize everything
		task.defer(rebuildAll)
		return
	end
	local inset = GuiService.TopbarInset
	ui.goal.Position = UDim2.new(1, -px(14), 0, inset.Max.Y + px(8))
	local hasHall = player:GetAttribute("HasHall") == true
	local hasFurnace = player:GetAttribute("HasFurnace") == true
	ui.recruit.Visible = hasHall
	ui.dCol.Visible = hasHall
	ui.pCol.Visible = hasFurnace
	local hasGift = (player:GetAttribute("GiftIn") or -1) >= 0
	ui.gCol.Visible = hasGift
	ui.left.Visible = hasHall or hasFurnace or hasGift
	if not hasHall then
		state.discOpen = false
		ui.card.Visible = false
	end
	-- recruit: left of the phone jump button, or above it when the progress bar is in the way
	local jump = player:GetAttribute("HudDevice") ~= "pc" and jumpButton() or nil
	local rootPos = ui.root.AbsolutePosition
	if jump then
		local jx = jump.AbsolutePosition.X - rootPos.X
		local jy = jump.AbsolutePosition.Y - rootPos.Y
		local barRight = ui.prog.AbsolutePosition.X - rootPos.X + ui.prog.AbsoluteSize.X
		local leftOfJump = jx - px(12)
		if leftOfJump - ui.recruit.AbsoluteSize.X < barRight + px(8) then
			ui.recruit.Position = UDim2.fromOffset(jx + jump.AbsoluteSize.X, jy - px(10)) -- above it
		else
			ui.recruit.Position = UDim2.fromOffset(leftOfJump, jy + jump.AbsoluteSize.Y)
		end
	else
		ui.recruit.Position = UDim2.new(1, -px(20), 1, -px(20))
	end
end

---------------------------------------------------------------------------------------------
-- data -> UI
local function refreshStatic()
	if not ui.root then
		return
	end
	ui.rate.Text = "+" .. compact(player:GetAttribute("Rate") or 0) .. "/s"
	ui.realm.Text = player:GetAttribute("RealmName") or ""
	ui.recruitCost.Text = compact(player:GetAttribute("RecruitCost") or 0)
	local raw = player:GetAttribute("Disciples") or ""
	local list = raw == "" and {} or string.split(raw, ",")
	ui.badge.Text = tostring(#list)
	ui.badgeFrame.Visible = #list > 0
	for _, c in ui.card:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local max = player:GetAttribute("MaxDisciples") or Config.MAX_DISCIPLES
	ui.badge.Text = tostring(math.min(#list, max))
	text(ui.card, string.format("Disciples %d/%d", math.min(#list, max), max), px(17), Color3.fromHex("FFE9A8"), { LayoutOrder = 0 })
	if #list == 0 then
		text(ui.card, "Recruit one with the purple button", px(13), Color3.new(1, 1, 1), { LayoutOrder = 1 })
	end
	for i, name in list do
		local r = Config.rarity(name)
		if i > max then
			text(ui.card, string.format("%d resting (build Quarters)", #list - max), px(12), Color3.fromHex("C8C0D0"), { LayoutOrder = i })
			break
		end
		text(ui.card, string.format("%s  +%d%%", name, r.bonus * 100), px(14), r.color, { LayoutOrder = i })
	end
	-- realm progress = buildings owned this realm (published by the server)
	local owned = player:GetAttribute("Built") or 0
	local total = #Config.PADS
	ui.progText.Text = owned >= total and "Ready to break through!" or string.format("%d / %d built", owned, total)
	TweenService:Create(ui.fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(owned / total, 0.04, 1), 1) }):Play()
	ui.fill.BackgroundColor3 = owned >= total and GOLD or JADE
end

rebuildAll = function()
	build()
	refreshStatic()
	task.defer(layout)
end

rebuildAll()
for _, a in { "Rate", "RealmName", "RecruitCost", "Disciples", "Built" } do
	player:GetAttributeChangedSignal(a):Connect(refreshStatic)
end
player:GetAttributeChangedSignal("HasHall"):Connect(function()
	refreshStatic()
	layout()
end)
player:GetAttributeChangedSignal("HasFurnace"):Connect(layout)
player:GetAttributeChangedSignal("GiftIn"):Connect(function()
	if ui.gCol and ((player:GetAttribute("GiftIn") or -1) >= 0) ~= ui.gCol.Visible then
		layout()
	end
end)
player:GetAttributeChangedSignal("MaxDisciples"):Connect(refreshStatic)
player:GetAttributeChangedSignal("Qi"):Connect(function()
	local q = player:GetAttribute("Qi") or 0
	local gain = q - state.lastQi
	state.lastQi = q
	if gain > 0 and gain <= (player:GetAttribute("Rate") or 0) * 1.6 + 1 then
		popGain(gain) -- passive income tick (not a purchase refund or a big grant)
	end
end)

local lastVp = workspace.CurrentCamera.ViewportSize
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	local vp = workspace.CurrentCamera.ViewportSize
	if (vp - lastVp).Magnitude > 8 then
		lastVp = vp
		rebuildAll()
	end
end)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
player:GetAttributeChangedSignal("HudDevice"):Connect(rebuildAll)
playerGui.ChildAdded:Connect(function(c)
	if c.Name == "TouchGui" then
		task.wait(0.5)
		layout()
	end
end)
task.delay(2, layout) -- TouchGui settles a moment after spawn

---------------------------------------------------------------------------------------------
-- per frame: smooth count-up, next-goal arrow, recruit wobble when affordable
local goalAcc = 0
local goalPad
RunService.RenderStepped:Connect(function(dt)
	if not ui.root then
		return
	end
	local target = player:GetAttribute("Qi") or 0
	local diff = target - state.shownQi
	if math.abs(diff) < 1 then
		state.shownQi = target
	else
		state.shownQi += diff * math.min(1, dt * 8)
	end
	ui.qi.Text = short(state.shownQi)

	goalAcc += dt
	if goalAcc > 0.5 then
		goalAcc = 0
		-- Roblox's touch controls appear and resize late (and on rotation): re-place around them
		layout()
		local best
		for _, p in myPads() do
			if not best or (p:GetAttribute("Cost") or 0) < (best:GetAttribute("Cost") or 0) then
				best = p
			end
		end
		goalPad = best
	end
	if goalPad and goalPad.Parent then
		ui.goal.Visible = true
		local cost = goalPad:GetAttribute("Cost") or 0
		ui.goalName.Text = "Next: " .. (goalPad:GetAttribute("Title") or "")
		ui.goalCost.Text = compact(cost) .. " Qi"
		ui.goalCost.TextColor3 = target >= cost and Color3.fromHex("9FF5C8") or PINK
		local cam = workspace.CurrentCamera
		local rel = cam.CFrame:PointToObjectSpace(goalPad.Position)
		ui.arrow.Rotation = math.deg(math.atan2(rel.Z, rel.X)) -- 0 = right, 90 = toward the camera
	else
		ui.goal.Visible = false
	end

	-- Spirit Tide line under the counter; the rate turns tide blue while it runs
	local now = workspace:GetServerTimeNow()
	local tideLeft = (workspace:GetAttribute("TideUntil") or 0) - now
	local tideIn = (workspace:GetAttribute("TideNext") or 0) - now
	local tideText = ""
	if tideLeft > 0 then
		tideText = string.format("2x Spirit Tide %d:%02d", tideLeft // 60, math.floor(tideLeft % 60))
	elseif tideIn > 0 then
		tideText = string.format("Spirit Tide in %d:%02d", tideIn // 60, math.floor(tideIn % 60))
	end
	if ui.tide.Text ~= tideText then
		ui.tide.Text = tideText
		ui.tide.TextColor3 = tideLeft > 0 and TIDE or TIDE_LIGHT
		ui.tide.TextSize = tideLeft > 0 and px(13) or px(12)
		ui.rate.TextColor3 = tideLeft > 0 and TIDE or Color3.fromHex("9FF5C8")
	end

	if ui.gCol.Visible then
		local g = player:GetAttribute("GiftIn") or -1
		ui.giftDot.Visible = g == 0
		if g == 0 then
			ui.giftLabel.Text = "Claim!"
			ui.giftLabel.TextColor3 = GOLD
			ui.giftBtn.Rotation = math.sin(os.clock() * 7) * 6
			ui.giftBtn.BackgroundColor3 = Color3.fromHex("FFD36B")
		else
			ui.giftLabel.Text = string.format("Gift %d:%02d", g // 60, g % 60)
			ui.giftLabel.TextColor3 = Color3.new(1, 1, 1)
			ui.giftBtn.Rotation = 0
			ui.giftBtn.BackgroundColor3 = Color3.fromHex("FFB3A8")
		end
	end

	if ui.pCol.Visible then
		local left = (player:GetAttribute("BoostUntil") or 0) - workspace:GetServerTimeNow()
		if left > 0 then
			ui.pillLabel.Text = string.format("2x %d:%02d", left // 60, math.floor(left % 60))
			ui.pillLabel.TextColor3 = GOLD
			ui.pillBtn.Rotation = 0
			ui.pillBtn.BackgroundColor3 = Color3.fromHex("FFE9A0")
		elseif player:GetAttribute("PillReady") then
			ui.pillLabel.Text = "Use pill!"
			ui.pillLabel.TextColor3 = Color3.new(1, 1, 1)
			ui.pillBtn.Rotation = math.sin(os.clock() * 7) * 6
			ui.pillBtn.BackgroundColor3 = Color3.fromHex("FFD36B")
		else
			local s = player:GetAttribute("PillIn") or 0
			ui.pillLabel.Text = string.format("%d:%02d", s // 60, s % 60)
			ui.pillLabel.TextColor3 = Color3.fromHex("C8C0D0")
			ui.pillBtn.Rotation = 0
			ui.pillBtn.BackgroundColor3 = Color3.fromHex("B8A878")
		end
	end

	if ui.recruit.Visible then
		local can = target >= (player:GetAttribute("RecruitCost") or math.huge)
		ui.recruit.Rotation = can and (-2 + math.sin(os.clock() * 6) * 2.5) or -2
		ui.recruitBtn.BackgroundColor3 = can and Color3.fromHex("B06BFF") or Color3.fromHex("8C72A8")
	end
end)

remotes.Notify.OnClientEvent:Connect(function(kind, a, b)
	if kind == "orb" then
		popGain(a, true)
		toast("Qi orb  +" .. compact(a), Color3.fromHex("9FF5D0"), 1.2)
		return
	elseif kind == "pill" then
		toast("A pill is ready in your furnace!", GOLD, 2.5)
		return
	elseif kind == "expand" then
		toast("Your peak grows! New land to build on", Color3.fromHex("9FF5C8"), 3)
		return
	elseif kind == "tideSoon" then
		toast(string.format("A Spirit Tide rises in %d s", a), Color3.fromHex("9FD0FF"), 3)
		return
	elseif kind == "tide" then
		toast(string.format("Spirit Tide! Every sect earns 2x Qi for %d s", a), Color3.fromHex("9FD0FF"), 4)
		return
	end
	if kind == "built" then
		toast("Built: " .. a, Color3.fromHex("9FF5C8"), 1.6)
	elseif kind == "offline" then
		toast(string.format("Your sect gathered %s Qi while you were away", short(a)), Color3.fromHex("9FD0FF"), 5)
	elseif kind == "breakthrough" then
		toast(a .. " broke through to " .. b .. "!", GOLD, 4)
	end
end)
