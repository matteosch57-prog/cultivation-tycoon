-- The Disciples book (owner 2026-10-23: "grid, but we also have the index, now the recruit page...
-- normalize how we show them and don't have 3 menus doing the same"; mock
-- docs/art/mocks/roster/2026-10-23_disciples_book_tabs.png): one window, three tabs, every disciple
-- drawn as the shared Toy.discipleTile.
--   My Sect: your own disciples, strongest first (the server keeps the list sorted), each with its
--            stars, its qi bonus and where it sits (Platform / Isle n); benched ones last, greyed.
--   Index:   IndexBook's page (Player.BuildIndexTab); closing the book counts it as seen (IndexSeen).
--   Odds:    RecruitOdds' page (Player.BuildOddsTab).
-- Opened by Player.OpenRoster:Fire(tab) ("sect" | "index" | "odds"): the HUD disciples card opens My
-- Sect, its gold Index button the Index tab; the Recruit picker's "%" chip (Player.OpenOdds) the Odds
-- tab (OddsInBook tells RecruitOdds to leave its own window shut).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local px, text, frame = Toy.px, Toy.text, Toy.frame
local GOLD = Color3.fromHex("FFD34D")
local MINT = Color3.fromHex("9FF5C8")
local WHITE = Color3.new(1, 1, 1)
local TAB_ON, TAB_OFF = Color3.fromHex("FFD36A"), Color3.fromHex("5D5068")
local TABS = { { key = "sect", label = "My Sect" }, { key = "index", label = "Index" }, { key = "odds", label = "Odds" } }
local PER_ROW = 10

local gui = Instance.new("ScreenGui")
gui.Name = "Disciples"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5 -- over the HUD, like the Shop and the Index
gui.Enabled = false
gui.Parent = playerGui

local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice")
	local touch = if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
	if touch then
		return math.clamp(vp.Y / 390, 0.72, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

local function commas(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function split(attr, sep)
	local raw = player:GetAttribute(attr) or ""
	return raw == "" and {} or string.split(raw, sep)
end

-- "Elder|lotus=3;..." -> { [key] = pulls }
local function readIndex()
	local out = {}
	for _, pair in split("Index", ";") do
		local key, n = string.match(pair, "^(.-)=(%d+)$")
		if key then
			out[key] = tonumber(n)
		end
	end
	return out
end

-- how many seats the Floating Lotus Isles hold on this player's peak (the rest are the platform's)
local function isleSeats()
	local peak = workspace:FindFirstChild("Sect") and workspace.Sect:FindFirstChild("Peak" .. tostring(player:GetAttribute("PlotIndex")))
	local built = peak and peak:FindFirstChild("Built")
	local n = 0
	for _, pad in Config.PADS do
		if pad.kind == "isle" and built and built:FindFirstChild(pad.id) then
			n += pad.seats or 4
		end
	end
	return n
end

local current = "sect"
local ui = {}
local close

-- My Sect: every disciple as the shared tile, strongest first, benched last
local function fillSect(body)
	for _, c in body:GetChildren() do
		c:Destroy()
	end
	local names, looks, shiny = split("Disciples", ","), split("DiscLooks", ","), split("DiscShiny", ",")
	local pulls = readIndex()
	local max = player:GetAttribute("MaxDisciples") or Config.MAX_DISCIPLES
	local onPlatform = max - isleSeats()
	local working, total = math.min(#names, max), 0
	for i = 1, working do
		local own = looks[i] and pulls[Config.indexKey(names[i], looks[i])]
		total += Config.discBonus(names[i], shiny[i] == "1") * Config.discipleStarMult(own)
	end
	Toy.list(body, false, px(6), { VerticalAlignment = Enum.VerticalAlignment.Top })
	text(body, string.format("%d / %d seats · +%s%% Qi · the strongest %d meditate on the platform", working, max, commas(math.floor(total * 100 + 0.5)), math.min(onPlatform, working)), px(14), WHITE, { LayoutOrder = 1 })
	local grid = frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(px(58), px(92))
	layout.CellPadding = UDim2.fromOffset(px(6), px(4))
	-- as many columns as the page holds (10 tiles are wider than a 667 px phone's book: the edges were cut)
	local room = body.AbsoluteSize.X - px(6) * 2 -- the scroll bar
	local fit = if room > 0 then (room + px(6)) // (px(58) + px(6)) else PER_ROW
	layout.FillDirectionMaxCells = math.clamp(fit, 4, PER_ROW)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for i, name in names do
		local look = looks[i]
		local key = look and Config.indexKey(name, look)
		local isShiny = shiny[i] == "1"
		local benched = i > max
		local tag = benched and "Bench" or (i <= onPlatform and "Platform" or ("Isle " .. ((i - onPlatform - 1) // 4 + 1)))
		local slot = frame(grid, { LayoutOrder = i })
		local cell, tap = Toy.discipleTile(slot, px(54), name, look, {
			shiny = isShiny,
			stars = Config.indexStars(key and pulls[key] or 0),
			tag = tag,
		})
		local bonus = math.floor(Config.discBonus(name, isShiny) * Config.discipleStarMult(key and pulls[key]) * 100 + 0.5)
		text(cell, "+" .. bonus .. "%", px(11), benched and Color3.fromHex("9A8FA8") or Config.rarity(name).color, { LayoutOrder = 50 })
		if benched then
			for _, d in cell:GetDescendants() do
				if d:IsA("GuiObject") then
					d.BackgroundTransparency = math.max(d.BackgroundTransparency, 0.45)
					if d:IsA("ImageLabel") then
						d.ImageTransparency = math.max(d.ImageTransparency, 0.45)
					end
				end
			end
		end
		tap.Activated:Connect(function()
			if ui.nameLine then
				ui.nameLine.Text = (isShiny and "Shiny " or "") .. Config.discipleName(name, look) .. " · " .. name .. " · " .. tag
				ui.nameLine.TextColor3 = Config.rarity(name).color:Lerp(WHITE, 0.25)
			end
		end)
	end
	if #names > max then
		text(body, string.format("Benched: %d · build more Lotus Isles for seats", #names - max), px(13), Color3.fromHex("C8C0D0"), { LayoutOrder = 3 })
	end
	ui.nameLine = text(body, "Tap a disciple to see its name", px(13), MINT, { LayoutOrder = 4 })
end

local function showTab(key)
	current = key
	for k, b in ui.tabs do
		b.btn.BackgroundColor3 = k == key and TAB_ON or TAB_OFF
	end
	local body = ui.body
	for _, c in body:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	ui.nameLine = nil
	local page = frame(body, { AutomaticSize = Enum.AutomaticSize.XY })
	if key == "sect" then
		fillSect(page)
	else
		local fn = player:FindFirstChild(key == "index" and "BuildIndexTab" or "BuildOddsTab")
		if fn then
			fn:Invoke(page)
		else
			text(page, "Loading...", px(14), WHITE)
		end
	end
	ui.scroll.CanvasPosition = Vector2.zero
end

close = function()
	if not gui.Enabled then
		return
	end
	gui.Enabled = false
	local seen = player:FindFirstChild("IndexSeen")
	if seen then
		seen:Fire() -- what the book showed counts as seen (IndexBook's NEW marks)
	end
end

local function open(tab)
	gui:ClearAllChildren()
	Toy.S = computeScale()
	local veil = Instance.new("TextButton")
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 0.32
	veil.BorderSizePixel = 0
	veil.Parent = gui
	veil.Activated:Connect(close)
	-- one column inside the safe area: the tab strip and the title on top, the scrolling page under
	-- them (absolute placement let the tabs cover the page's first row on a phone)
	local inset = GuiService:GetGuiInset().Y
	local book = frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, px(10) + inset),
		Size = UDim2.new(1, -px(120), 1, -(px(20) + inset)),
	})
	local head = frame(book, { Size = UDim2.new(1, 0, 0, px(48)) })
	text(head, "Disciples", px(28), GOLD, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -px(60), 0.5, 0), Rotation = -2 }) -- right of the tabs, clear of the X
	local strip = frame(head, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), AutomaticSize = Enum.AutomaticSize.XY })
	Toy.list(strip, true, px(8))
	ui.tabs = {}
	for i, t in TABS do
		local holder, btn = Toy.button(strip, UDim2.fromOffset(px(92), px(38)), TAB_OFF, px(12))
		holder.LayoutOrder = i
		text(btn, t.label, px(16), WHITE, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		btn.Activated:Connect(function()
			if current ~= t.key then
				Sfx.play("toast")
				showTab(t.key)
			end
		end)
		ui.tabs[t.key] = { holder = holder, btn = btn }
	end
	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(0, px(56))
	scroll.Size = UDim2.new(1, 0, 1, -px(56))
	scroll.BackgroundColor3 = Color3.fromHex("2F2538")
	scroll.BackgroundTransparency = 0.2
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = px(6)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = book
	Toy.corner(scroll, UDim.new(0, px(16)))
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = px(3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(10)), UDim.new(0, px(10))
	pad.Parent = scroll
	Toy.list(scroll, false, 0, { VerticalAlignment = Enum.VerticalAlignment.Top }) -- Toy.list centres: a tall page spilled off the top
	ui.scroll, ui.body = scroll, scroll
	local xHolder, xBtn = Toy.button(gui, UDim2.fromOffset(px(44), px(44)), Color3.fromHex("FF6B5E"), px(12))
	xHolder.AnchorPoint = Vector2.new(1, 0)
	xHolder.Position = UDim2.new(1, -px(14), 0, px(12) + inset)
	xHolder.ZIndex = 2
	text(xBtn, "X", px(24), WHITE, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	xBtn.Activated:Connect(close)
	gui.Enabled = true
	showTab(tab or "sect")
	Sfx.play("toast")
end

local openEvent = Instance.new("BindableEvent")
openEvent.Name = "OpenRoster"
openEvent.Parent = player -- not PlayerGui: the first spawn empties it (R19)
openEvent.Event:Connect(function(tab)
	open(tab)
end)

-- the Recruit picker's odds chip opens the book on Odds (RecruitOdds keeps its own window shut)
player:SetAttribute("OddsInBook", true)
local oddsEvent = player:WaitForChild("OpenOdds", 30)
if oddsEvent then
	oddsEvent.Event:Connect(function()
		open("odds")
	end)
end

-- My Sect follows the disciples while it is open (a recruit, a new isle, a new star)
for _, a in { "Disciples", "DiscLooks", "DiscShiny", "Index", "MaxDisciples" } do
	player:GetAttributeChangedSignal(a):Connect(function()
		if gui.Enabled and current == "sect" then
			showTab("sect")
		end
	end)
end
