-- Breakthrough confirm screen (mock B "Before and after", owner pick 2026-10-22,
-- docs/art/mocks/2026-10-22_breakthrough_confirm.html): stepping on the gold Breakthrough pad (or
-- Heavenly Hands on it) no longer breaks through. The server offers this screen (Notify
-- "breakthroughAsk", the price); it shows this realm and the next, the income boost, the new
-- buildings, the rebirth gate when this realm is one, what resets and what is kept, and one button.
-- Only its Confirm breaks through, and the server checks everything again (R9).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local LOCKED = Color3.fromHex("C9C2D3")
local MUTED = Color3.fromHex("CBBFD6")
local RESET = Color3.fromHex("FF8A7A")
local WHITE = Color3.new(1, 1, 1)

local gui = Instance.new("ScreenGui")
gui.Name = "Breakthrough"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5 -- over the HUD
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = playerGui

local ui = {}
local cost = 0
local busy = false
local spin -- the next realm's turning ring (runs only while the screen is open, R16)

local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice")
	local touch = if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
	if touch then
		return math.clamp(vp.Y / 390, 0.78, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

-- 12.3K, 4.5M ... (the qi counter's style)
local function compact(n)
	local units, i = { "K", "M", "B", "T", "Qa", "Qn" }, 0
	n = math.floor(n)
	while n >= 1000 and i < #units do
		n /= 1000
		i += 1
	end
	if i == 0 then
		return tostring(n)
	end
	return string.format(n < 10 and "%.1f%s" or "%d%s", n, units[i])
end

local function roman(n)
	local out = ""
	for _, p in { { 1000, "M" }, { 900, "CM" }, { 500, "D" }, { 400, "CD" }, { 100, "C" }, { 90, "XC" }, { 50, "L" }, { 40, "XL" }, { 10, "X" }, { 9, "IX" }, { 5, "V" }, { 4, "IV" }, { 1, "I" } } do
		while n >= p[1] do
			out ..= p[2]
			n -= p[1]
		end
	end
	return out
end

local function mult(m)
	return "x" .. (string.format("%.1f", m):gsub("%.0$", ""))
end

local close -- forward

-- a row of icons then a word (the reset / kept strip)
local function iconsLine(parent, keys, word, color, order)
	local row = Toy.frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order })
	Toy.list(row, true, px(3))
	for i, k in keys do
		Toy.icon(row, k, px(20), { LayoutOrder = i })
	end
	text(row, word, px(15), color, { LayoutOrder = #keys + 1 })
	return row
end

-- a realm plate: a round seal with the realm number, its name under it
local function plate(parent, realm, lit, order)
	local col = Toy.frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order })
	Toy.list(col, false, px(6))
	local size = px(96)
	local box = Toy.frame(col, { Size = UDim2.fromOffset(size, size + px(4)), LayoutOrder = 1 })
	local shadow = Toy.frame(box, { Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(0, px(4)), BackgroundTransparency = 0, BackgroundColor3 = Toy.INK })
	Toy.corner(shadow, UDim.new(1, 0))
	local seal = Toy.frame(box, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 0, BackgroundColor3 = WHITE })
	Toy.corner(seal, UDim.new(1, 0))
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = px(4)
	st.Parent = seal
	local g = Instance.new("UIGradient")
	g.Rotation = 60
	g.Color = lit and ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("FFF3B8")), ColorSequenceKeypoint.new(0.55, Color3.fromHex("F3B733")), ColorSequenceKeypoint.new(1, Color3.fromHex("B06A0C")) })
		or ColorSequence.new(Color3.fromHex("8D7FA8"), Color3.fromHex("4A3C5E"))
	g.Parent = seal
	text(seal, roman(realm), px(34), lit and WHITE or MUTED, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	if lit then
		-- a ring of motes turning round the next realm (the mock's dashed ring)
		local ring = Toy.frame(box, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(size / 2, size / 2), Size = UDim2.fromOffset(size + px(30), size + px(30)), ZIndex = 4 })
		for i = 1, 12 do
			local a = math.pi * 2 * i / 12
			local d = Toy.frame(ring, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5 + 0.5 * math.cos(a), 0, 0.5 + 0.5 * math.sin(a), 0), Size = UDim2.fromOffset(px(i % 3 == 0 and 8 or 5), px(i % 3 == 0 and 8 or 5)), BackgroundTransparency = i % 3 == 0 and 0 or 0.25, BackgroundColor3 = Color3.fromHex("FFF0A6"), ZIndex = 4 })
			Toy.corner(d, UDim.new(1, 0))
		end
		ui.ring = ring
	end
	text(col, Config.realmName(realm), px(17), lit and GOLD or MUTED, { LayoutOrder = 2 })
	return col
end

local function refresh()
	if not ui.btn then
		return
	end
	local ready = (player:GetAttribute("Qi") or 0) >= cost
	ui.btn.BackgroundColor3 = ready and JADE or LOCKED
end

local function build()
	gui:ClearAllChildren()
	Toy.S = computeScale()
	ui = {}
	local realm = player:GetAttribute("Realm") or 1
	local nextRealm = realm + 1

	local veil = Instance.new("TextButton")
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 0.38
	veil.BorderSizePixel = 0
	veil.Parent = gui
	veil.Activated:Connect(function()
		close()
	end)

	local xHolder, xBtn = Toy.button(gui, UDim2.fromOffset(px(40), px(40)), Color3.fromHex("FF6B5E"), px(12))
	xHolder.AnchorPoint = Vector2.new(1, 0)
	xHolder.Position = UDim2.new(1, -px(24), 0, px(24))
	text(xBtn, "X", px(22), WHITE, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	xBtn.Activated:Connect(function()
		close()
	end)

	local body = Toy.frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY })
	Toy.list(body, false, px(12))
	ui.body = body
	text(body, "Breakthrough", px(34), GOLD, { LayoutOrder = 1 })

	-- this realm -> the next one, what it brings between them
	local mid = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	Toy.list(mid, true, px(26))
	plate(mid, realm, false, 1)
	local gains = Toy.frame(mid, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	Toy.list(gains, false, px(8))
	local boost = Toy.frame(gains, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	Toy.list(boost, true, px(6))
	Toy.icon(boost, "qi", px(28), { LayoutOrder = 1 })
	text(boost, "x1", px(22), MUTED, { LayoutOrder = 2 })
	text(boost, "->", px(20), WHITE, { LayoutOrder = 3 })
	text(boost, mult(Config.incomeMult(nextRealm) / Config.incomeMult(realm)), px(32), GOLD, { LayoutOrder = 4 })
	local newPads = 0
	for _, pad in Config.PADS do
		if Config.padRealm(pad) == nextRealm then
			newPads += 1
		end
	end
	if newPads > 0 then
		local row = Toy.frame(gains, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
		Toy.list(row, true, px(5))
		Toy.icon(row, "hall", px(24), { LayoutOrder = 1 })
		text(row, "+" .. newPads .. " new", px(18), JADE, { LayoutOrder = 2 })
	end
	-- a realm gated by rebirths (Config.REBIRTH_REALMS) shows the gate it passed
	local need = Config.rebirthsFor(nextRealm)
	if need > Config.rebirthsFor(realm) then
		local row = Toy.frame(gains, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
		Toy.list(row, true, px(5))
		Toy.icon(row, "rebirth", px(24), { LayoutOrder = 1 })
		local have = player:GetAttribute("Rebirths") or 0
		text(row, math.min(have, need) .. "/" .. need, px(18), have >= need and JADE or RESET, { LayoutOrder = 2 })
	end
	plate(mid, nextRealm, true, 3)

	-- what resets and what is kept, one strip
	local strip = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3, BackgroundTransparency = 0.35, BackgroundColor3 = Toy.INK })
	Toy.corner(strip, UDim.new(0, px(12)))
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(12)), UDim.new(0, px(12))
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(5)), UDim.new(0, px(5))
	pad.Parent = strip
	Toy.list(strip, true, px(18))
	iconsLine(strip, { "qi", "hall" }, "reset", RESET, 1)
	iconsLine(strip, { "disciple", "karma", "rebirth" }, "kept", JADE, 2)

	Toy.frame(body, { Size = UDim2.fromOffset(1, px(2)), LayoutOrder = 4 })
	local bHolder, bBtn = Toy.button(body, UDim2.fromOffset(px(290), px(52)), JADE, px(15))
	bHolder.LayoutOrder = 5
	ui.btn = bBtn
	local label = Toy.frame(bBtn, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 3 })
	Toy.list(label, true, px(10))
	text(label, "Break through", px(23), WHITE, { LayoutOrder = 1, ZIndex = 3 })
	local _, price = Toy.amount(label, "qi", px(23), WHITE, { LayoutOrder = 2 })
	price.Text = compact(cost)
	price.ZIndex = 3
	bBtn.Activated:Connect(function()
		if busy then
			return
		end
		if (player:GetAttribute("Qi") or 0) < cost then
			Sfx.play("deny")
			return
		end
		busy = true
		local ok, done = pcall(function()
			return remotes.Breakthrough:InvokeServer()
		end)
		if ok and done then
			Toy.reward(bBtn) -- busy stays on: the Realm change must not cut the burst short
			task.delay(0.45, close)
		else
			busy = false
			Sfx.play("deny")
			close() -- the offer ran out or the pad changed: step on the pad again
		end
	end)
	refresh()
end

local function open(price)
	if type(price) ~= "number" then
		return
	end
	cost = price
	busy = false
	build()
	gui.Enabled = true
	Sfx.play("toast")
	local sc = Instance.new("UIScale")
	sc.Scale = 0.85
	sc.Parent = ui.body
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if spin then
		spin:Disconnect()
	end
	spin = RunService.RenderStepped:Connect(function(dt)
		if ui.ring and ui.ring.Parent then
			ui.ring.Rotation = (ui.ring.Rotation + dt * 24) % 360
		end
	end)
end

close = function()
	gui.Enabled = false
	busy = false
	if spin then
		spin:Disconnect()
		spin = nil
	end
end

remotes.Notify.OnClientEvent:Connect(function(kind, a)
	if kind == "breakthroughAsk" then
		open(a)
	end
end)
player:GetAttributeChangedSignal("Qi"):Connect(function()
	if gui.Enabled then
		refresh()
	end
end)
player:GetAttributeChangedSignal("Realm"):Connect(function()
	if gui.Enabled and not busy then
		close() -- the realm changed under the screen: its numbers are stale
	end
end)
