-- What's new (owner pick A 2026-10-27, mocks https://claude.ai/artifact/6bSAyz819rRt8F97mGaCGY): after an
-- update, a returning player (a save from before Config.PATCH.id) gets one board with every new thing and a
-- shortcut on each (open its page, or travel there). Shown once: closing it tells the server (PatchSeen,
-- data.patchSeen). Settings reopens it any time through Player.WhatsNewOpen. It waits for any other screen
-- (Shared.Screens), so it never lands on the launch screen or a day-one card.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local Screens = require(Shared:WaitForChild("Screens"))

local PATCH = Config.PATCH
if not PATCH then
	return
end

local px, text, frame, corner = Toy.px, Toy.text, Toy.frame, Toy.corner
local GOLD = Color3.fromHex("FFD34D")
local PANEL = Color3.fromHex("241C2E")
local MUTED = Color3.fromHex("C9BDDA")
local JADE = Color3.fromHex("3FCF9A")

local gui = Instance.new("ScreenGui")
gui.Name = "WhatsNew"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 19
gui.Parent = playerGui

local function scale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice")
	local touch = if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
	if touch then
		return math.clamp(vp.Y / 390, 0.72, 1.1), true
	end
	return math.clamp(vp.Y / 554, 1, 1.7), false
end

local board -- the open board, or nil

-- a shortcut: open that screen through its Player BindableEvent, or travel there (the HUD's Travel)
local function go(item)
	local how = item.go
	if how.travel then
		-- the HUD's jade-wipe teleport (HudSlots.Travel), like the Base chip
		local slots = player:FindFirstChild("HudSlots")
		local ev = slots and slots:FindFirstChild("Travel")
		if ev then
			ev:Fire(how.travel)
		end
		return
	end
	local ev = player:FindFirstChild(how.open)
	if ev then
		ev:Fire(how.arg)
	end
end

local function close()
	if board then
		board:Destroy()
		board = nil
	end
	if (player:GetAttribute("PatchNew") or 0) > 0 then
		remotes.PatchSeen:FireServer()
	end
end

local function open()
	if board then
		return
	end
	local S, phone = scale()
	Toy.S = S
	local vp = workspace.CurrentCamera.ViewportSize
	local w = math.min(vp.X - px(40), px(phone and 460 or 560))
	local dim = Instance.new("TextButton")
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui
	board = dim
	-- the click that opened it (Settings' Open button) can land on this dim too: ignore taps for a moment
	local since = os.clock()
	dim.Activated:Connect(function()
		if os.clock() - since > 0.4 then
			close()
		end
	end)
	local card = Instance.new("TextButton") -- eats taps so the dim behind does not close it
	card.Text = ""
	card.AutoButtonColor = false
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(w, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = PANEL
	card.Parent = dim
	corner(card, UDim.new(0, px(18)))
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = px(4)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = card
	local body = frame(card, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(14)), UDim.new(0, px(14))
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(12)), UDim.new(0, px(14))
	pad.Parent = body
	Toy.list(body, false, px(phone and 6 or 8), { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Top })
	text(body, "What's new!", px(phone and 26 or 32), GOLD, { LayoutOrder = 1 })
	text(body, PATCH.name, px(15), MUTED, { LayoutOrder = 2 })
	local inner = w - px(28)
	local icon = px(phone and 34 or 42)
	for i, item in PATCH.items do
		local row = frame(body, { Size = UDim2.fromOffset(inner, icon + px(12)), BackgroundTransparency = 0.94, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 10 + i })
		corner(row, UDim.new(0, px(12)))
		Toy.icon(row, item.icon, icon, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, px(8), 0.5, 0) })
		local words = frame(row, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, icon + px(16), 0.5, 0), AutomaticSize = Enum.AutomaticSize.XY })
		Toy.list(words, false, px(1), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
		text(words, item.title, px(phone and 15 or 18), Color3.new(1, 1, 1), { LayoutOrder = 1 })
		text(words, item.line, px(phone and 11 or 13), MUTED, { LayoutOrder = 2 })
		local holder, btn = Toy.button(row, UDim2.fromOffset(px(phone and 58 or 70), px(phone and 28 or 32)), JADE, px(10))
		holder.AnchorPoint = Vector2.new(1, 0.5)
		holder.Position = UDim2.new(1, -px(8), 0.5, -px(2))
		text(btn, item.button, px(phone and 14 or 16), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		Toy.feel(btn)
		btn.Activated:Connect(function()
			close()
			go(item)
		end)
	end
	local okH, okB = Toy.button(body, UDim2.fromOffset(px(140), px(phone and 34 or 40)), GOLD, px(12))
	okH.LayoutOrder = 99
	text(okB, "Got it", px(phone and 17 or 20), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	Toy.feel(okB)
	okB.Activated:Connect(close)
	local xh, xb = Toy.button(card, UDim2.fromOffset(px(36), px(36)), Color3.fromHex("FF4D4D"), px(18))
	xh.AnchorPoint = Vector2.new(0.5, 0.5)
	xh.Position = UDim2.new(1, -px(4), 0, px(4))
	xh.ZIndex = 5
	text(xb, "X", px(20), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	Toy.feel(xb)
	xb.Activated:Connect(close)
	remotes.MenuOpened:FireServer("whatsnew") -- analytics Menu
end

-- Settings (and Studio checks) open it through Player.WhatsNewOpen
local openEv = Instance.new("BindableEvent")
openEv.Name = "WhatsNewOpen"
openEv.Parent = player
openEv.Event:Connect(open)

-- once after an update, for a returning save (the server sets PatchNew), when no other screen is up
task.spawn(function()
	if (player:GetAttribute("PatchNew") or 0) == 0 then
		player:GetAttributeChangedSignal("PatchNew"):Wait()
	end
	task.wait(PATCH.delay or 6)
	Screens.waitClear(playerGui, "WhatsNew", 1)
	if (player:GetAttribute("PatchNew") or 0) > 0 then
		open()
	end
end)
