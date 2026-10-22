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
local PerfMark = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PerfMark"))
local Toy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Toy"))

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
-- an amount piece for a toast: its currency icon, then the number (R18)
local function amt(currency, n, sign)
	return { icon = currency, text = (sign or "") .. compact(n) }
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

-- the Spirit Tide: a blue wave crest
local function tideIcon(parent, size, props)
	local ic = Icon.new(parent, size, props)
	ic:rect(32, 46, 54, 22, TIDE, 6)
	ic:circle(18, 34, 12, TIDE)
	ic:circle(42, 30, 14, TIDE)
	ic:detail(44, 26, 6, TIDE_LIGHT)
	ic:detail(20, 31, 4, Color3.new(1, 1, 1), 0.2)
	return ic.box
end

-- a little hall (buildings owned, on the realm bar)
local function hallIcon(parent, size, props)
	local ic = Icon.new(parent, size, props)
	ic:rect(32, 42, 38, 24, Color3.fromHex("FFF4DC"), 2)
	ic:rect(32, 22, 54, 14, Color3.fromHex("E65B4F"), 4)
	ic:rect(32, 47, 10, 14, Color3.fromHex("8A5A3C"), 1, 0, false).ZIndex = 3
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

-- toy button: solid shadow + outlined face + glass shine (Toy.glass). Returns (holder, button).
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
	Toy.glass(btn, radius)
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
local goalPad -- the pad the "Next" card names (set per frame; Heavenly Hands builds it)

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
	local tideRow = frame(col, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3, Visible = false })
	local trl = Instance.new("UIListLayout")
	trl.FillDirection = Enum.FillDirection.Horizontal
	trl.VerticalAlignment = Enum.VerticalAlignment.Center
	trl.Padding = UDim.new(0, px(3))
	trl.Parent = tideRow
	tideIcon(tideRow, px(15), { LayoutOrder = 1 })
	ui.tide = text(tideRow, "", px(12), TIDE_LIGHT, { LayoutOrder = 2 })
	ui.tideRow = tideRow
	ui.counter = counter
	counter.Name = "Counter" -- Juice flies qi drops into it

	-- left column: Disciples (others appear when their features exist)
	-- (layout() fits it between Roblox's top bar and the thumbstick: a column too tall for that band
	-- wraps into a second one, so 4 buttons never sit under the Roblox menu on a phone)
	local left = frame(root, { Position = UDim2.fromOffset(px(12), px(60)), Size = UDim2.fromOffset(0, px(300)), AutomaticSize = Enum.AutomaticSize.X })
	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, px(10))
	leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	leftLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	leftLayout.Wraps = true
	leftLayout.Parent = left
	-- Shop (mock shop B, D24): always shown, on top; opens Shop.client's screen
	local sCol = frame(left, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 0 })
	local sLayout = Instance.new("UIListLayout")
	sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sLayout.Padding = UDim.new(0, px(2))
	sLayout.Parent = sCol
	local sHolder, sBtn = toy(sCol, UDim2.fromOffset(px(54), px(54)), Color3.fromHex("FFD36B"), px(14))
	sHolder.LayoutOrder = 1
	local bag = Icon.new(sBtn, px(40), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	bag:rect(32, 15, 18, 9, Color3.fromHex("E65B4F"), 2)
	bag:circle(32, 40, 22, Color3.fromHex("FFD34D"))
	bag:rect(32, 22, 22, 6, Color3.fromHex("E65B4F"), 2)
	qiIcon(sBtn, px(17), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, px(4)) })
	text(sCol, "Shop", px(13), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	sBtn.Activated:Connect(function()
		local ev = playerGui:FindFirstChild("ShopOpen")
		if ev then
			ev:Fire("hud")
		end
	end)
	local dCol = frame(left, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	local dLayout = Instance.new("UIListLayout")
	dLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dLayout.Padding = UDim.new(0, px(2))
	dLayout.Parent = dCol
	local dHolder, dBtn = toy(dCol, UDim2.fromOffset(px(54), px(54)), Color3.fromHex("9FD0FF"), px(14))
	dHolder.LayoutOrder = 1
	discipleIcon(dBtn, px(40), nil, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	-- the label is the count (less text, mock less_text A)
	ui.dLabel = text(dCol, "0", px(13), Color3.new(1, 1, 1), { LayoutOrder = 2 })
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
				toast("2x Qi!", GOLD, 2)
			end
		else
			local s = player:GetAttribute("PillIn") or 0
			toast(string.format("Brewing %d:%02d", s // 60, s % 60), PINK, 1.6)
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
				toast({ amt("qi", gain, "+") }, GOLD, 2)
			end
		else
			local g = math.max(0, player:GetAttribute("GiftIn") or 0)
			toast(string.format("Gift in %d:%02d", g // 60, g % 60), PINK, 1.5)
		end
	end)
	ui.left = left
	ui.dBtn = dBtn

	-- disciples card (opens beside the button)
	-- (no panel, R4: disciples in their rarity colours, 4 to a row, their bonus under each)
	local card = frame(root, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, px(80), 0.45, 0), Size = UDim2.fromOffset(px(4 * 52), 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = state.discOpen })
	local cLayout = Instance.new("UIListLayout")
	cLayout.FillDirection = Enum.FillDirection.Horizontal
	cLayout.Wraps = true
	cLayout.Padding = UDim.new(0, px(4))
	cLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cLayout.Parent = card
	ui.card = card
	dBtn.Activated:Connect(function()
		state.discOpen = not state.discOpen
		card.Visible = state.discOpen
		if state.discOpen then
			remotes.MenuOpened:FireServer("disciples") -- analytics Menu (DATA.md)
		end
	end)

	-- realm progress: bottom centre
	local prog = frame(root, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -px(14)), AutomaticSize = Enum.AutomaticSize.XY })
	local pLayout = Instance.new("UIListLayout")
	pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pLayout.Padding = UDim.new(0, px(2))
	pLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pLayout.Parent = prog
	-- realm name + the Rebirth chip (road to reincarnation: "Rebirth 3/10", opens Reincarnation.client)
	local realmRow = frame(prog, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	local rrLayout = Instance.new("UIListLayout")
	rrLayout.FillDirection = Enum.FillDirection.Horizontal
	rrLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rrLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rrLayout.Padding = UDim.new(0, px(8))
	rrLayout.Parent = realmRow
	ui.realm = text(realmRow, "", px(15), Color3.fromHex("FFE9A8"), { LayoutOrder = 1 })
	local chipHolder, chipBtn = toy(realmRow, UDim2.fromOffset(px(84), px(26)), Color3.fromHex("B06BFF"), px(9))
	chipHolder.LayoutOrder = 2
	local chipRow = frame(chipBtn, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	local crl = Instance.new("UIListLayout")
	crl.FillDirection = Enum.FillDirection.Horizontal
	crl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	crl.VerticalAlignment = Enum.VerticalAlignment.Center
	crl.Padding = UDim.new(0, px(3))
	crl.Parent = chipRow
	Toy.icon(chipRow, "karma", px(18), { LayoutOrder = 1 })
	ui.rebirth = text(chipRow, "", px(13), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	ui.rebirthBtn = chipBtn
	chipBtn.Activated:Connect(function()
		local ev = playerGui:FindFirstChild("ReincOpen")
		if ev then
			ev:Fire()
		end
	end)
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
	local progRow = frame(track, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 3 })
	local prl2 = Instance.new("UIListLayout")
	prl2.FillDirection = Enum.FillDirection.Horizontal
	prl2.VerticalAlignment = Enum.VerticalAlignment.Center
	prl2.Padding = UDim.new(0, px(4))
	prl2.Parent = progRow
	ui.progIcon = hallIcon(progRow, px(17), { LayoutOrder = 1 })
	ui.progText = text(progRow, "", px(14), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	ui.prog = prog

	-- recruit: the formation seal (mock docs/art/mocks/recruit_button_c.gif, owner pick 2026-10-22: "C,
	-- but needs to look as good as your mock"), bottom right, placed by layout(). A round button with
	-- a qi orb charging through the rarity colours inside a turning ring, rays and a glow behind; the
	-- soft pieces are the uploaded aura atlas (Toy.atlasPiece), moved in the frame loop. Still and dim
	-- when a recruit is out of reach.
	local SEAL = px(104)
	local rHolder = frame(root, { AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(SEAL, SEAL + px(44)) })
	local seal = frame(rHolder, { Size = UDim2.fromOffset(SEAL, SEAL) })
	local sealScale = Instance.new("UIScale")
	sealScale.Parent = seal
	local rays = Toy.atlasPiece(seal, "rays12", SEAL * 2.1, SEAL * 2.1, Color3.new(1, 1, 1), 0.4)
	local glow = Toy.atlasPiece(seal, "glow", SEAL * 2, SEAL * 2, JADE, 0)
	local shadow = frame(seal, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(4)), BackgroundTransparency = 0, BackgroundColor3 = INK })
	corner(shadow, UDim.new(0.5, 0))
	local rBtn = Instance.new("TextButton")
	rBtn.Name = "RecruitSeal" -- the recruit reveal's orb starts here
	rBtn.Text = ""
	rBtn.AutoButtonColor = false
	rBtn.Size = UDim2.fromScale(1, 1)
	rBtn.BackgroundColor3 = Color3.fromHex("A070F0")
	rBtn.BorderSizePixel = 0
	rBtn.Parent = seal
	corner(rBtn, UDim.new(0.5, 0))
	local rst = Instance.new("UIStroke")
	rst.Color = INK
	rst.Thickness = px(3)
	rst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rst.Parent = rBtn
	-- the face's soft light (a radial lift from the glow piece) and its glass cap
	Toy.atlasPiece(rBtn, "glow", SEAL * 0.95, SEAL * 0.95, Color3.fromHex("D9B8FF"), 0.35, { Position = UDim2.fromScale(0.5, 0.42) })
	local cap = frame(rBtn, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.05), Size = UDim2.fromScale(0.84, 0.44), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1) })
	corner(cap, UDim.new(0.5, 0))
	local capG = Instance.new("UIGradient")
	capG.Rotation = 90
	capG.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.98) })
	capG.Parent = cap
	local ring = Toy.atlasPiece(rBtn, "ring", SEAL - px(12), SEAL - px(12), Color3.new(1, 1, 1), 0.1)
	-- the orb: a glow, the ball, its highlight, four motes circling
	local ORB = px(44)
	local orbGlow = Toy.atlasPiece(rBtn, "glow", ORB * 1.9, ORB * 1.9, JADE, 0.1)
	local orb = frame(rBtn, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(ORB, ORB), BackgroundTransparency = 0, BackgroundColor3 = JADE })
	corner(orb, UDim.new(0.5, 0))
	local ost = Instance.new("UIStroke")
	ost.Color = INK
	ost.Thickness = px(3)
	ost.Parent = orb
	-- the ball's shading: light from the top left into its colour (the mock's radial sphere)
	orb.BackgroundColor3 = Color3.new(1, 1, 1)
	local orbShade = Instance.new("UIGradient")
	orbShade.Rotation = 50
	orbShade.Parent = orb
	Toy.atlasPiece(orb, "mote", ORB * 0.9, ORB * 0.9, Color3.new(1, 1, 1), 0.55, { Position = UDim2.fromScale(0.42, 0.38) })
	local hi = frame(orb, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.35, 0.3), Size = UDim2.fromScale(0.26, 0.26), BackgroundTransparency = 0.05, BackgroundColor3 = Color3.new(1, 1, 1) })
	corner(hi, UDim.new(0.5, 0))
	local motes = {}
	for i = 1, 4 do
		motes[i] = Toy.atlasPiece(rBtn, "mote", px(10), px(10), Color3.new(1, 1, 1), 0)
	end
	-- "Recruit" and its price under the seal
	local rText = frame(rHolder, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, SEAL + px(2)), AutomaticSize = Enum.AutomaticSize.XY })
	local rtl = Instance.new("UIListLayout")
	rtl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rtl.Padding = UDim.new(0, px(1))
	rtl.SortOrder = Enum.SortOrder.LayoutOrder
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
	ui.seal = { scale = sealScale, rays = rays, glow = glow, ring = ring, orbGlow = orbGlow, orb = orb, shade = orbShade, motes = motes, orbSize = ORB }
	-- press feel, like the toy buttons
	rBtn.MouseButton1Down:Connect(function()
		seal.Position = UDim2.fromOffset(0, px(3))
	end)
	for _, ev in { rBtn.MouseButton1Up, rBtn.MouseLeave } do
		ev:Connect(function()
			seal.Position = UDim2.new()
		end)
	end
	rBtn.Activated:Connect(function()
		Sfx.play("click")
	end)

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
	-- the price shows its qi drop (R18)
	local gcRow = frame(gt, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	local gcl = Instance.new("UIListLayout")
	gcl.FillDirection = Enum.FillDirection.Horizontal
	gcl.VerticalAlignment = Enum.VerticalAlignment.Center
	gcl.Padding = UDim.new(0, px(3))
	gcl.Parent = gcRow
	qiIcon(gcRow, px(15), { LayoutOrder = 1 })
	ui.goalCost = text(gcRow, "", px(13), PINK, { LayoutOrder = 2 })
	ui.goal = goal
	-- Heavenly Hands (Karma Shop): a gold hand that builds the Next pad from anywhere (mock A)
	local hHolder, hBtn = toy(goal, UDim2.fromOffset(px(50), px(42)), Color3.fromHex("FFD34D"), px(12))
	hHolder.LayoutOrder = 3
	hHolder.Visible = false
	Toy.icon(hBtn, "hands", px(32), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	hBtn.Activated:Connect(function()
		local id = goalPad and goalPad.Parent and goalPad:GetAttribute("PadId")
		local ok, done = pcall(function()
			return remotes.HandsBuild:InvokeServer(id)
		end)
		if not (ok and done) then
			Sfx.play("deny")
		end
	end)
	ui.hands = hHolder

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
			-- the orb reveal on screen (RecruitReveal) and the light column on the platform (Juice);
			-- the reveal names the disciple, so no toast
			local fxEvent = playerGui:FindFirstChild("RecruitFx")
			if fxEvent then
				fxEvent:Fire(res.rarity, res.kept)
			end
		elseif ok and res then
			toast(res.reason, PINK, 1.5)
		end
	end)
end

---------------------------------------------------------------------------------------------
-- toasts and the little "+N" that pops off the counter

-- one line of pieces (strings, or amt() pieces) laid out left to right
local function line(parent, pieces, size, color, props)
	local row = frame(parent, { AutomaticSize = Enum.AutomaticSize.XY })
	for k, v in props or {} do
		row[k] = v
	end
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, math.floor(size * 0.18))
	l.Parent = row
	for i, p in type(pieces) == "table" and pieces or { pieces } do
		if type(p) == "table" then
			local cell = frame(row, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = i })
			local cl = Instance.new("UIListLayout")
			cl.FillDirection = Enum.FillDirection.Horizontal
			cl.VerticalAlignment = Enum.VerticalAlignment.Center
			cl.SortOrder = Enum.SortOrder.LayoutOrder
			cl.Padding = UDim.new(0, math.max(1, math.floor(size * 0.08)))
			cl.Parent = cell
			Toy.icon(cell, p.icon, math.floor(size * 1.15), { LayoutOrder = 1, ZIndex = row.ZIndex })
			text(cell, p.text, size, color, { LayoutOrder = 2, ZIndex = row.ZIndex })
		else
			text(row, p, size, color, { LayoutOrder = i, ZIndex = row.ZIndex })
		end
	end
	return row
end

-- fades everything a line drew (text, outlines, icon shapes) over `t` seconds
local function fadeOut(root, t)
	local info = TweenInfo.new(t)
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		end
	end
end

-- toast(pieces, color, hold): a string, or a list of strings and amt() pieces
toast = function(pieces, color, hold)
	if not toastLayer then
		return
	end
	local t = line(toastLayer, pieces, px(22), color or Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), ZIndex = 21 })
	local sc = Instance.new("UIScale")
	sc.Scale = 0.4
	sc.Parent = t
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Sfx.play("toast")
	task.delay(hold or 2.5, function()
		TweenService:Create(t, TweenInfo.new(0.5), { Position = UDim2.fromScale(0.5, 0.27) }):Play()
		fadeOut(t, 0.5)
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
	local t = line(ui.root, { amt("qi", amount, "+") }, px(18), GOLD, {
		Position = UDim2.fromOffset(abs.X + ui.counter.AbsoluteSize.X + px(2), abs.Y + px(4)),
		Rotation = -8,
		ZIndex = 10,
	})
	TweenService:Create(t, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Position = t.Position - UDim2.fromOffset(0, px(22)) }):Play()
	fadeOut(t, 0.9)
	task.delay(0.95, function()
		t:Destroy()
	end)
end

---------------------------------------------------------------------------------------------
-- layout: place things around Roblox's own controls (called on any change)
-- a full-screen screen (Shop, Reincarnation) is open: the HUD steps aside (toasts stay), so nothing
-- peeks out from under that screen's veil or under its title on a phone (phone check 2026-10-21)
local MODALS = { "Shop", "Reincarnation", "WelcomeOffer" }
local function modalOpen()
	for _, name in MODALS do
		local g = playerGui:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then
			return true
		end
	end
	return false
end

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
	-- left buttons: the band under the top bar and above the thumbstick (bottom-left on a phone)
	local rootScale = ui.root:FindFirstChildOfClass("UIScale") -- (a phone check scales the root)
	local rootH = ui.root.AbsoluteSize.Y / (rootScale and rootScale.Scale or 1)
	local top = inset.Max.Y + px(8)
	local bottom = state.phoneMode and rootH * 0.72 or rootH - px(24)
	ui.left.Position = UDim2.fromOffset(px(12), top)
	ui.left.Size = UDim2.fromOffset(0, math.max(px(80), bottom - top))
	ui.card.Position = UDim2.new(0, px(12) + ui.left.AbsoluteSize.X / (rootScale and rootScale.Scale or 1) + px(12), 0.45, 0)
	local hasHall = player:GetAttribute("HasHall") == true
	local hasFurnace = player:GetAttribute("HasFurnace") == true
	ui.dCol.Visible = hasHall
	ui.pCol.Visible = hasFurnace
	local hasGift = (player:GetAttribute("GiftIn") or -1) >= 0
	ui.gCol.Visible = hasGift
	local modal = modalOpen()
	state.modal = modal
	ui.recruit.Visible = hasHall and not modal
	ui.prog.Visible = not modal
	ui.counter.Visible = not modal
	ui.left.Visible = not modal -- the Shop button is always there otherwise
	ui.card.Visible = state.discOpen and hasHall and not modal
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
	local realmNow = player:GetAttribute("Realm") or 1
	-- a new life pays once this one goes deeper than every life before (D37)
	local target = math.max(Config.REINC_REALM, (player:GetAttribute("SoulPeak") or 0) + 1)
	ui.rebirth.Text = realmNow >= target and "Rebirth!" or string.format("%d/%d", realmNow, target)
	ui.recruitCost.Text = compact(player:GetAttribute("RecruitCost") or 0)
	local raw = player:GetAttribute("Disciples") or ""
	local list = raw == "" and {} or string.split(raw, ",")
	local pulledRaw = player:GetAttribute("Pulled") or ""
	local pulled = pulledRaw == "" and {} or string.split(pulledRaw, ",")
	for _, c in ui.card:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	local max = player:GetAttribute("MaxDisciples") or Config.MAX_DISCIPLES
	ui.dLabel.Text = string.format("%d/%d", math.min(#list, max), max)
	for i, name in list do
		local r = Config.rarity(name)
		if i > max then
			-- the rest wait for more Quarters: one grey "+N"
			text(ui.card, "+" .. (#list - max), px(16), Color3.fromHex("C8C0D0"), { LayoutOrder = i })
			break
		end
		local cell = frame(ui.card, { Size = UDim2.fromOffset(px(48), 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i })
		local cl = Instance.new("UIListLayout")
		cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		cl.SortOrder = Enum.SortOrder.LayoutOrder
		cl.Parent = cell
		local face = Toy.disciple(cell, px(46), name, { LayoutOrder = 1 }) -- its rarity's look and moving aura
		-- a sold rarity the player also rolled carries its "first pulled" mark: a gold dot
		if table.find(pulled, name) and Config.shopItem(Config.shopKeyOf(name)) then
			local dot = frame(face, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.8, 0.2), Size = UDim2.fromOffset(px(10), px(10)), BackgroundTransparency = 0, BackgroundColor3 = GOLD, ZIndex = 5 })
			corner(dot, UDim.new(1, 0))
			local ds = Instance.new("UIStroke")
			ds.Color = INK
			ds.Thickness = px(2)
			ds.Parent = dot
		end
		text(cell, string.format("+%d%%", r.bonus * 100), px(11), r.color, { LayoutOrder = 2 })
	end
	-- realm progress = buildings owned this realm (published by the server)
	local owned = player:GetAttribute("Built") or 0
	local total = #Config.PADS
	ui.progIcon.Visible = owned < total
	ui.progText.Text = owned >= total and "Break through!" or string.format("%d/%d", owned, total)
	TweenService:Create(ui.fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(owned / total, 0.04, 1), 1) }):Play()
	ui.fill.BackgroundColor3 = owned >= total and GOLD or JADE
end

rebuildAll = function()
	build()
	refreshStatic()
	task.defer(layout)
end

rebuildAll()
for _, a in { "Rate", "RealmName", "RecruitCost", "Disciples", "Built", "Pulled" } do
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
local function watchModal(g)
	if table.find(MODALS, g.Name) and g:IsA("ScreenGui") then
		g:GetPropertyChangedSignal("Enabled"):Connect(layout)
	end
end
for _, g in playerGui:GetChildren() do
	watchModal(g)
end
playerGui.ChildAdded:Connect(watchModal)
playerGui.ChildAdded:Connect(function(c)
	if c.Name == "TouchGui" then
		task.wait(0.5)
		layout()
	end
end)
task.delay(2, layout) -- TouchGui settles a moment after spawn

-- a property write only when the value changed (R16 rule 4: a write can redraw the GUI)
local function put(obj, prop, value)
	if obj[prop] ~= value then
		obj[prop] = value
	end
end

---------------------------------------------------------------------------------------------
-- per frame: smooth count-up, next-goal arrow, recruit wobble when affordable
local goalAcc = 0
RunService.RenderStepped:Connect(function(dt)
	if not ui.root then
		return
	end
	local t0 = PerfMark.begin()
	local target = player:GetAttribute("Qi") or 0
	local diff = target - state.shownQi
	if math.abs(diff) < 1 then
		state.shownQi = target
	else
		state.shownQi += diff * math.min(1, dt * 8)
	end
	put(ui.qi, "Text", short(state.shownQi))

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
		put(ui.goal, "Visible", not state.modal)
		local cost = goalPad:GetAttribute("Cost") or 0
		local title = goalPad:GetAttribute("Title") or ""
		put(ui.goalName, "Text", title:match("^(.-):") or title) -- "Breakthrough: X" says just Breakthrough
		put(ui.goalCost, "Text", compact(cost))
		put(ui.goalCost, "TextColor3", target >= cost and Color3.fromHex("9FF5C8") or PINK)
		put(ui.hands, "Visible", (player:GetAttribute("Dao_hands") or 0) > 0)
		local cam = workspace.CurrentCamera
		local rel = cam.CFrame:PointToObjectSpace(goalPad.Position)
		put(ui.arrow, "Rotation", math.deg(math.atan2(rel.Z, rel.X))) -- 0 = right, 90 = toward the camera
	else
		put(ui.goal, "Visible", false)
	end

	-- Spirit Tide line under the counter; the rate turns tide blue while it runs
	local now = workspace:GetServerTimeNow()
	local tideLeft = (workspace:GetAttribute("TideUntil") or 0) - now
	local tideIn = (workspace:GetAttribute("TideNext") or 0) - now
	local tideText = ""
	if tideLeft > 0 then
		tideText = string.format("2x %d:%02d", tideLeft // 60, math.floor(tideLeft % 60))
	elseif tideIn > 0 then
		tideText = string.format("%d:%02d", tideIn // 60, math.floor(tideIn % 60))
	end
	if ui.tide.Text ~= tideText then
		put(ui.tide, "Text", tideText)
		put(ui.tideRow, "Visible", tideText ~= "")
		put(ui.tide, "TextColor3", tideLeft > 0 and TIDE or TIDE_LIGHT)
		put(ui.tide, "TextSize", tideLeft > 0 and px(13) or px(12))
		put(ui.rate, "TextColor3", tideLeft > 0 and TIDE or Color3.fromHex("9FF5C8"))
	end

	-- the Rebirth chip wobbles gold once a new life is open
	if (player:GetAttribute("Realm") or 1) >= math.max(Config.REINC_REALM, (player:GetAttribute("SoulPeak") or 0) + 1) then
		ui.rebirthBtn.Rotation = math.sin(os.clock() * 6) * 4
		ui.rebirthBtn.BackgroundColor3 = GOLD
	else
		ui.rebirthBtn.Rotation = 0
		ui.rebirthBtn.BackgroundColor3 = Color3.fromHex("B06BFF")
	end

	if ui.gCol.Visible then
		local g = player:GetAttribute("GiftIn") or -1
		put(ui.giftDot, "Visible", g == 0)
		if g == 0 then
			put(ui.giftLabel, "Text", "Claim!")
			put(ui.giftLabel, "TextColor3", GOLD)
			put(ui.giftBtn, "Rotation", math.sin(os.clock() * 7) * 6)
			put(ui.giftBtn, "BackgroundColor3", Color3.fromHex("FFD36B"))
		else
			put(ui.giftLabel, "Text", string.format("%d:%02d", g // 60, g % 60))
			put(ui.giftLabel, "TextColor3", Color3.new(1, 1, 1))
			put(ui.giftBtn, "Rotation", 0)
			put(ui.giftBtn, "BackgroundColor3", Color3.fromHex("FFB3A8"))
		end
	end

	if ui.pCol.Visible then
		local left = (player:GetAttribute("BoostUntil") or 0) - workspace:GetServerTimeNow()
		if left > 0 then
			put(ui.pillLabel, "Text", string.format("2x %d:%02d", left // 60, math.floor(left % 60)))
			put(ui.pillLabel, "TextColor3", GOLD)
			put(ui.pillBtn, "Rotation", 0)
			put(ui.pillBtn, "BackgroundColor3", Color3.fromHex("FFE9A0"))
		elseif player:GetAttribute("PillReady") then
			put(ui.pillLabel, "Text", "Use!")
			put(ui.pillLabel, "TextColor3", Color3.new(1, 1, 1))
			put(ui.pillBtn, "Rotation", math.sin(os.clock() * 7) * 6)
			put(ui.pillBtn, "BackgroundColor3", Color3.fromHex("FFD36B"))
		else
			local s = player:GetAttribute("PillIn") or 0
			put(ui.pillLabel, "Text", string.format("%d:%02d", s // 60, s % 60))
			put(ui.pillLabel, "TextColor3", Color3.fromHex("C8C0D0"))
			put(ui.pillBtn, "Rotation", 0)
			put(ui.pillBtn, "BackgroundColor3", Color3.fromHex("B8A878"))
		end
	end

	if ui.recruit.Visible then
		-- the Recruit seal: while a recruit is affordable the orb charges through the first five
		-- rarity colours (a step every 0.6 s), the ring and rays turn and it breathes; else still, dim
		local can = target >= (player:GetAttribute("RecruitCost") or math.huge)
		local sl = ui.seal
		local t = os.clock()
		put(ui.recruitBtn, "BackgroundColor3", can and Color3.fromHex("A070F0") or Color3.fromHex("8C72A8"))
		put(sl.rays, "Visible", can)
		put(sl.glow, "Visible", can)
		put(sl.orbGlow, "Visible", can)
		if can then
			local col = Config.RARITIES[math.floor(t / 0.6) % 5 + 1].color
			if sl.col ~= col then
				sl.col = col
				sl.shade.Color = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.55), col)
			end
			put(sl.glow, "ImageColor3", col)
			put(sl.orbGlow, "ImageColor3", col)
			sl.rays.Rotation = t * 30
			sl.ring.Rotation = t * 60
			sl.scale.Scale = 1 + 0.06 * math.sin(t * math.pi * 2.4)
			for i, m in sl.motes do
				local a = t * math.pi * 4 / 3 + i * math.pi / 2
				m.Visible = true
				m.Position = UDim2.new(0.5, math.cos(a) * sl.orbSize * 0.72, 0.5, math.sin(a) * sl.orbSize * 0.72)
			end
		else
			if sl.col ~= false then
				sl.col = false
				sl.shade.Color = ColorSequence.new(Color3.fromHex("D8D2E2"), Color3.fromHex("A8A0B8"))
			end
			put(sl.scale, "Scale", 1)
			for _, m in sl.motes do
				put(m, "Visible", false)
			end
		end
	end
	PerfMark.finish("hud", t0)
end)

remotes.Notify.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "orb" then
		popGain(a, true)
		toast({ amt("qi", a, "+") }, Color3.fromHex("9FF5D0"), 1.2)
		return
	elseif kind == "pill" then
		toast("Pill ready!", GOLD, 2.5)
		return
	elseif kind == "expand" then
		toast("More land!", Color3.fromHex("9FF5C8"), 3)
		return
	elseif kind == "tideSoon" then
		toast(string.format("Spirit Tide in %ds", a), Color3.fromHex("9FD0FF"), 3)
		return
	elseif kind == "shopPass" then
		toast(a .. " is yours!", GOLD, 3)
		return
	elseif kind == "shopQi" then
		popGain(a, true)
		toast({ b, amt("qi", a, "+") }, GOLD, 2.5)
		return
	elseif kind == "shopPill" then
		toast("2x Qi!", GOLD, 2.5)
		return
	elseif kind == "shopWelcome" then
		-- after the recruit reveal of its disciple: the forever bonus (`c` = 0.1)
		task.delay(Config.revealBurst(a) + Config.REVEAL.hold + 1, function()
			toast({ "+" .. math.floor((c or 0) * 100 + 0.5) .. "%", { icon = "qi", text = "forever!" } }, GOLD, 3)
		end)
		return
	elseif kind == "shopDisciple" then
		toast(a .. (b and "!" or " (resting)"), Config.rarity(a).color, 3)
		return
	elseif kind == "shopGate" then
		toast(a .. " opens at " .. b, PINK, 2.5)
		return
	elseif kind == "shopLimit" then
		toast("Already yours", Color3.fromHex("9FF5C8"), 2)
		return
	elseif kind == "shopFull" then
		toast("Sect full", PINK, 2)
		return
	elseif kind == "shopOwned" then
		toast("Already yours", Color3.fromHex("9FF5C8"), 1.6)
		return
	elseif kind == "realmLook" then
		toast(a, GOLD, 4) -- what this realm changed on the peak (Config.realmLookLine)
		return
	elseif kind == "tide" then
		toast("Spirit Tide! 2x Qi", Color3.fromHex("9FD0FF"), 4)
		return
	end
	if kind == "built" then
		toast(a .. "!", Color3.fromHex("9FF5C8"), 1.6)
	elseif kind == "offline" then
		toast({ "Away", { icon = "qi", text = "+" .. short(a) } }, Color3.fromHex("9FD0FF"), 5)
	elseif kind == "breakthrough" then
		toast(a == player.DisplayName and (b .. "!") or (a .. ": " .. b .. "!"), GOLD, 4)
	elseif kind == "reincarnate" then
		toast(a == player.DisplayName and string.format("Life %d!", b) or string.format("%s: life %d!", a, b), Color3.fromHex("D9B8FF"), 4)
	end
end)
