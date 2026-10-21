-- Reincarnation screen (docs/research/2026-10-21_reincarnation_design.md): the road to realm 10,
-- the NEXT step, and what a new life keeps and gains. Opened by the HUD's Rebirth button
-- (PlayerGui.ReincOpen, a BindableEvent). Same language as the Shop: no board, toy pieces over a
-- dark veil. The server decides (R9): the button only asks; a second tap confirms.
-- A second page, the Karma Shop (Config.DAO), spends karma on permanent nodes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local px, text = Toy.px, Toy.text
local GOLD = Color3.fromHex("FFE36B")
local JADE = Color3.fromHex("59D39F")
local GREY = Color3.fromHex("8C8296")
local GO = Color3.fromHex("B06BFF")
local CONFIRM = Color3.fromHex("FF8A5C")
local LOCKED = Color3.fromHex("C9C2D3")
local KARMA = Color3.fromHex("D9B8FF")
local TILE = { sworn = "9FD0FF", seat = "FFD36B", foundation = "9FF5C8", elixir = "FFB3A8", meditation = "C9C2FF", echo = "E6C9FF" }
local TILT = { -2, 1.5, -1, 2, -1.5, 1 }

local openEvent = Instance.new("BindableEvent")
openEvent.Name = "ReincOpen"
openEvent.Parent = playerGui

local gui = Instance.new("ScreenGui")
gui.Name = "Reincarnation"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5 -- over the HUD
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = playerGui

local ui = {}
local armedUntil = 0 -- second tap within this time confirms
local busy = false
local page = "road" -- "road" | "karma"

local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice")
	local touch = if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
	if touch then
		return math.clamp(vp.Y / 390, 0.78, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

local function commas(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- x3, x27, x2.2K ...
local function mult(m)
	if m < 1000 then
		return "x" .. commas(m)
	end
	local units, i = { "K", "M", "B", "T" }, 0
	while m >= 1000 and i < #units do
		m /= 1000
		i += 1
	end
	return string.format("x%.1f%s", m, units[i])
end

local close -- forward

-- one step of the road: a dot with the realm number
local function dot(parent, order, realm, state)
	local big = state == "now"
	local size = big and px(30) or px(22)
	local color = state == "done" and JADE or (big and GOLD or GREY)
	local d = Toy.frame(parent, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 0, BackgroundColor3 = color, LayoutOrder = order })
	Toy.corner(d, UDim.new(1, 0))
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = px(3)
	st.Parent = d
	text(d, tostring(realm), big and px(15) or px(11), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	return d
end

local function link(parent, order, done)
	local l = Toy.frame(parent, { Size = UDim2.fromOffset(px(10), px(5)), BackgroundTransparency = 0, BackgroundColor3 = done and JADE or Toy.INK, LayoutOrder = order })
	return l
end

-- Karma Shop icons, drawn from shapes in a 64-unit box (Toy.Icon)
local DRAW = {}
function DRAW.sworn(ic)
	for _, x in { 22, 42 } do
		ic:rect(x, 46, 16, 20, Color3.fromHex("5096FF"), 6)
		ic:circle(x, 26, 9, Color3.fromHex("F2CFAE"))
	end
end
function DRAW.seat(ic)
	ic:rect(32, 48, 44, 12, Color3.fromHex("E65B4F"), 6)
	ic:rect(32, 34, 14, 18, Color3.fromHex("9A6BFF"), 6)
	ic:circle(32, 20, 9, Color3.fromHex("F2CFAE"))
end
function DRAW.foundation(ic)
	ic:rect(32, 44, 36, 20, Color3.fromHex("FFF4DC"), 2)
	ic:rect(32, 28, 50, 12, Color3.fromHex("C0392B"), 4)
	ic:rect(32, 47, 10, 14, Color3.fromHex("8A5A3C"), 2)
end
function DRAW.elixir(ic)
	ic:rect(23, 32, 22, 20, Color3.fromHex("E65B4F"), 10)
	ic:rect(41, 32, 22, 20, Color3.fromHex("FFF4DC"), 10)
	ic.box.Rotation = -35
end
function DRAW.meditation(ic)
	ic:circle(30, 32, 20, Color3.fromHex("FFE36B"))
	ic:detail(40, 26, 16, Color3.fromHex(TILE.meditation))
end
function DRAW.echo(ic)
	ic:circle(32, 32, 22, Color3.fromHex("9A6BFF"))
	ic:circle(32, 32, 13, Color3.fromHex("D9B8FF"))
	ic:circle(32, 32, 5, Color3.fromHex("FFFFFF"))
end

local function refreshKarma()
	local have = player:GetAttribute("Karma") or 0
	ui.karma.Text = commas(have) .. " Karma"
	for _, t in ui.tiles do
		local lv = player:GetAttribute("Dao_" .. t.node.key) or 0
		local cost = t.node.costs[lv + 1]
		for i, pip in t.pips do
			pip.BackgroundColor3 = i <= lv and GOLD or Color3.fromHex("3A2D40")
		end
		if not cost then
			t.price.Text = "Max"
			t.button.BackgroundColor3 = LOCKED
		else
			t.price.Text = commas(cost)
			t.button.BackgroundColor3 = have >= cost and JADE or LOCKED
		end
	end
end

local function refresh()
	if not ui.body then
		return
	end
	if page == "karma" then
		refreshKarma()
		return
	end
	local realm = player:GetAttribute("Realm") or 1
	local gate = Config.REINC_REALM
	local built = player:GetAttribute("Built") or 0
	local total = #Config.PADS
	local gain = player:GetAttribute("ReincKarma") or Config.karmaFor(gate, 0)
	local now = player:GetAttribute("PastLives") or 1
	local nextMult = player:GetAttribute("NextPastLives") or now
	local ready = realm >= gate

	-- the road: realms 1..gate (a deeper realm shows as the gate dot plus "+N")
	for _, c in ui.road:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local order = 0
	for r = 1, gate do
		if r > 1 then
			order += 1
			link(ui.road, order, r <= realm)
		end
		order += 1
		local state = (r < realm or (r == gate and realm > gate)) and "done" or (r == realm and "now" or "todo")
		dot(ui.road, order, r, state)
	end
	ui.deeper.Visible = realm > gate
	ui.deeper.Text = "+" .. (realm - gate)

	-- NEXT step: one short line (owner: "too much text")
	if ready then
		ui.next.Text = "NEXT: Reincarnate"
	elseif built >= total then
		ui.next.Text = "NEXT: Break through"
	else
		ui.next.Text = string.format("NEXT: Build %d more", total - built)
	end

	-- what a new life gives: two numbers
	local shownNext = ready and nextMult or math.max(nextMult, Config.pastLivesMult(gate))
	ui.g1.Visible = shownNext > now
	ui.g1.Text = mult(shownNext) .. " Qi"
	ui.g2.Text = "+" .. commas(gain) .. " Karma"

	-- the button
	local armed = os.clock() < armedUntil
	if not ready then
		ui.btn.BackgroundColor3 = LOCKED
		ui.btnLabel.Text = string.format("Reach realm %d", gate)
	elseif armed then
		ui.btn.BackgroundColor3 = CONFIRM
		ui.btnLabel.Text = "Sure? Tap again"
	else
		ui.btn.BackgroundColor3 = GO
		ui.btnLabel.Text = "Reincarnate"
	end
end

local build -- forward
local function goTo(p)
	page = p
	armedUntil = 0
	build()
end

local function head(body, title)
	local h = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1, Rotation = -2 })
	Toy.list(h, true, px(14))
	if page == "karma" then
		local bHolder, bBtn = Toy.button(h, UDim2.fromOffset(px(34), px(34)), JADE, px(10))
		bHolder.LayoutOrder = 0
		text(bBtn, "<", px(20), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		bBtn.Activated:Connect(function()
			goTo("road")
		end)
	end
	text(h, title, px(32), page == "karma" and KARMA or GOLD, { LayoutOrder = 1 })
	local xHolder, xBtn = Toy.button(h, UDim2.fromOffset(px(34), px(34)), Color3.fromHex("FF6B5E"), px(10))
	xHolder.LayoutOrder = 2
	text(xBtn, "X", px(20), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	xBtn.Activated:Connect(function()
		close()
	end)
end

-- the Karma Shop page: one tile per node (icon, name, a short line, level pips, price)
local function buildKarma(body)
	head(body, "Karma Shop")
	ui.karma = text(body, "", px(20), KARMA, { LayoutOrder = 2 })
	ui.tiles = {}
	local rows = {}
	for i = 1, 2 do
		rows[i] = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 + i })
		Toy.list(rows[i], true, px(18), { VerticalAlignment = Enum.VerticalAlignment.Top })
	end
	for i, node in Config.DAO do
		local col = Toy.frame(rows[i <= 3 and 1 or 2], { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = i, Rotation = TILT[i] })
		Toy.list(col, false, px(2))
		local holder, btn = Toy.button(col, UDim2.fromOffset(px(58), px(58)), Color3.fromHex(TILE[node.key] or "C9FFE4"), px(16))
		holder.LayoutOrder = 1
		local ic = Toy.Icon.new(btn, px(44), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		DRAW[node.key](ic)
		text(col, node.name, px(14), Color3.new(1, 1, 1), { LayoutOrder = 2 })
		text(col, node.line, px(11), Color3.fromHex("C9FFE4"), { LayoutOrder = 3 })
		local pipRow = Toy.frame(col, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 4 })
		Toy.list(pipRow, true, px(3))
		local pips = {}
		for l = 1, #node.costs do
			local pip = Toy.frame(pipRow, { Size = UDim2.fromOffset(px(9), px(9)), BackgroundTransparency = 0, LayoutOrder = l })
			Toy.corner(pip, UDim.new(1, 0))
			local st = Instance.new("UIStroke")
			st.Color = Toy.INK
			st.Thickness = px(2)
			st.Parent = pip
			pips[l] = pip
		end
		Toy.frame(col, { Size = UDim2.fromOffset(1, px(3)), LayoutOrder = 5 }) -- the pips clear the button
		local pHolder, pBtn = Toy.button(col, UDim2.fromOffset(px(70), px(26)), JADE, px(9))
		pHolder.LayoutOrder = 6
		local price = text(pBtn, "", px(14), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		local function buy()
			if busy then
				return
			end
			busy = true
			local ok, done = pcall(function()
				return remotes.DaoBuy:InvokeServer(node.key)
			end)
			busy = false
			Sfx.play(ok and done and "buyChime" or "deny")
			refreshKarma()
		end
		btn.Activated:Connect(buy)
		pBtn.Activated:Connect(buy)
		table.insert(ui.tiles, { node = node, pips = pips, price = price, button = pBtn })
	end
end

build = function()
	gui:ClearAllChildren()
	Toy.S = computeScale()
	ui = {}

	local veil = Instance.new("TextButton")
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 0.32
	veil.BorderSizePixel = 0
	veil.Parent = gui
	veil.Activated:Connect(function()
		close()
	end)

	local body = Toy.frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY })
	Toy.list(body, false, px(8))
	ui.body = body
	if page == "karma" then
		buildKarma(body)
		refresh()
		return
	end
	head(body, "Reincarnation")

	local roadRow = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	Toy.list(roadRow, true, px(6))
	ui.road = Toy.frame(roadRow, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	Toy.list(ui.road, true, 0)
	ui.deeper = text(roadRow, "", px(18), GOLD, { LayoutOrder = 2 })

	Toy.frame(body, { Size = UDim2.fromOffset(1, px(4)), LayoutOrder = 5 })
	ui.next = text(body, "", px(24), Color3.new(1, 1, 1), { LayoutOrder = 6 })
	local gains = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 9, Rotation = 1.5 })
	Toy.list(gains, true, px(26))
	ui.g1 = text(gains, "", px(22), GOLD, { LayoutOrder = 1 })
	ui.g2 = text(gains, "", px(22), Color3.fromHex("D9B8FF"), { LayoutOrder = 2 })

	Toy.frame(body, { Size = UDim2.fromOffset(1, px(4)), LayoutOrder = 14 })
	local bHolder, bBtn = Toy.button(body, UDim2.fromOffset(px(230), px(46)), GO, px(14))
	bHolder.LayoutOrder = 15
	ui.btn = bBtn
	ui.btnLabel = text(bBtn, "", px(20), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	bBtn.Activated:Connect(function()
		if busy or (player:GetAttribute("Realm") or 1) < Config.REINC_REALM then
			return
		end
		if os.clock() >= armedUntil then
			armedUntil = os.clock() + 4
			refresh()
			task.delay(4.1, refresh)
			return
		end
		armedUntil = 0
		busy = true
		local ok, res = pcall(function()
			return remotes.Reincarnate:InvokeServer()
		end)
		busy = false
		if ok and res then
			close()
		else
			refresh()
		end
	end)
	-- the Karma Shop: what karma is for
	local kHolder, kBtn = Toy.button(body, UDim2.fromOffset(px(160), px(34)), KARMA, px(11))
	kHolder.LayoutOrder = 16
	kHolder.Rotation = -1.5
	text(kBtn, "Karma Shop", px(16), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	kBtn.Activated:Connect(function()
		goTo("karma")
	end)
	refresh()
end

local function open()
	if gui.Enabled then
		return
	end
	armedUntil = 0
	page = "road"
	build()
	gui.Enabled = true
	Sfx.play("toast")
	local sc = Instance.new("UIScale")
	sc.Scale = 0.85
	sc.Parent = ui.body
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

close = function()
	gui.Enabled = false
end

openEvent.Event:Connect(open)
local watched = { "Realm", "Built", "Karma", "Lives", "ReincKarma", "PastLives", "NextPastLives" }
for _, n in Config.DAO do
	table.insert(watched, "Dao_" .. n.key)
end
for _, a in watched do
	player:GetAttributeChangedSignal(a):Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)
end
