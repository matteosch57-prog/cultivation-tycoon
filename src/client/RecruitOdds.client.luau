-- The recruit odds (R8, Roblox's paid random item rule: qi is sold for Robux, so a recruit shows its
-- odds first) and the pity bars (owner pick "All" 2026-10-23, mock
-- docs/art/mocks/2026-10-23_disciple_roster.html?view=pity, copy Anime Defenders / Anime Vanguards).
-- One row per rarity: its face, name and chance (Config.RARITIES weights, which add up to exactly 100),
-- then one bar per Config.PITY guarantee (the Pity attribute: recruits since that rarity or better),
-- then the Shiny line. The Disciples book's Odds tab fills it (Player.BuildOddsTab); until the book
-- lands, Player.OpenOdds (the "%" chip of the Recruit picker) shows it in its own window.
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
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromHex("FFD34D")
local SOFT = Color3.fromHex("E8E0F0")
local INK = Toy.INK

-- "12.5" / "0.008": a weight as a percent, no trailing zeros
local function pct(w)
	local s = string.format(w >= 1 and "%.2f" or "%.3f", w):gsub("%.?0+$", "")
	return s .. "%"
end

-- the Pity attribute: "Celestial=812;Dao Ancestor=2140" -> { [rarity] = count }
local function readPity()
	local out = {}
	for _, pair in string.split(player:GetAttribute("Pity") or "", ";") do
		local name, n = string.match(pair, "^(.-)=(%d+)$")
		if name then
			out[name] = tonumber(n)
		end
	end
	return out
end

local function commas(n)
	local s = tostring(math.floor(n))
	repeat
		local k
		s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

-- the page into `body`: two columns side by side so it fits a phone's height (Play check 2026-10-23:
-- one column ran off a 749 x 381 screen): the odds on the left, pity and Shiny on the right
local bars = {} -- [rarity] = { fill, label, at }: refreshed when the Pity attribute changes
local function fill(page)
	table.clear(bars)
	local cols = frame(page, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	Toy.list(cols, true, px(18), { VerticalAlignment = Enum.VerticalAlignment.Top })
	local body = frame(cols, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	Toy.list(body, false, px(4))
	local right = frame(cols, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	Toy.list(right, false, px(8))
	local rows = frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	Toy.list(rows, false, px(3), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
	for i, r in Config.RARITIES do
		local row = frame(rows, { Size = UDim2.fromOffset(px(250), px(24)), LayoutOrder = i })
		Toy.disciple(row, px(26), r.name, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5) }, true, Config.DISCIPLE_LOOKS[1])
		text(row, r.name, px(15), r.color, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, px(32), 0.5, 0) })
		text(row, pct(r.weight), px(15), WHITE, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) })
	end
	text(body, "Each is one of 4 disciples of that rarity, equally likely.", px(11), SOFT, { LayoutOrder = 2 })
	body = right
	-- pity: one bar per guarantee
	local counts = readPity()
	for i, p in Config.PITY do
		local r = Config.rarity(p.rarity)
		local box = frame(body, { Size = UDim2.fromOffset(px(230), px(40)), LayoutOrder = i })
		text(box, p.rarity .. " or better by " .. commas(p.at), px(13), r.color, { Position = UDim2.fromOffset(0, 0) })
		local label = text(box, "", px(13), WHITE, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0) })
		local bar = frame(box, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, px(14)), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("110C18"), ClipsDescendants = true })
		Toy.corner(bar, UDim.new(1, 0))
		local bs = Instance.new("UIStroke")
		bs.Color = INK
		bs.Thickness = px(2.5)
		bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bs.Parent = bar
		local f = frame(bar, { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = r.color })
		Toy.corner(f, UDim.new(1, 0))
		bars[p.rarity] = { fill = f, label = label, at = p.at }
	end
	local function refresh()
		local now = readPity()
		for name, b in bars do
			local n = math.min(now[name] or counts[name] or 0, b.at)
			b.fill.Size = UDim2.fromScale(math.max(n / b.at, 0.02), 1)
			b.label.Text = commas(n) .. " / " .. commas(b.at)
		end
	end
	refresh()
	-- Shiny (Pet Simulator 99): on top of any rarity
	local shiny = frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 10 })
	Toy.list(shiny, false, px(1))
	local head = frame(shiny, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	Toy.list(head, true, px(3))
	Toy.atlasPiece(head, "sparkle", px(16), px(16), GOLD, 0, { LayoutOrder = 1 }) -- the font has no ✦
	text(head, "Shiny", px(14), GOLD, { LayoutOrder = 2 })
	text(shiny, string.format("%s of every recruit, x%s qi", pct(Config.SHINY_CHANCE * 100), tostring(Config.SHINY_MULT)), px(13), WHITE, { LayoutOrder = 2 })
	-- Heavenly Weather (Config.WEATHERS): a recruit made while one runs can come out with its mutation
	local wBox = frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 11 })
	Toy.list(wBox, false, px(1), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
	text(wBox, "During weather", px(14), Color3.fromHex("D9C8FF"), { LayoutOrder = 0 })
	local nowKey = (workspace:GetAttribute("WeatherUntil") or 0) > workspace:GetServerTimeNow() and workspace:GetAttribute("Weather")
	for i, w in Config.WEATHERS do
		local line = frame(wBox, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = i })
		Toy.list(line, true, px(4))
		local gem = frame(line, { Size = UDim2.fromOffset(px(9), px(9)), BackgroundTransparency = 0, BackgroundColor3 = w.color, Rotation = 45, LayoutOrder = 1 })
		Toy.corner(gem, UDim.new(0, px(2)))
		local gs = Instance.new("UIStroke")
		gs.Color = INK
		gs.Thickness = px(2)
		gs.Parent = gem
		text(line, string.format("%s: %s %s x%s", w.name, pct(w.chance * 100), w.mut, tostring(w.mult)), px(12), w.key == nowKey and w.color or WHITE, { LayoutOrder = 2 })
		if w.key == nowKey then
			text(line, "now", px(12), GOLD, { LayoutOrder = 3 })
		end
	end
	return refresh
end

local refreshNow -- the page on screen's refresh (window or tab)
player:GetAttributeChangedSignal("Pity"):Connect(function()
	if refreshNow then
		refreshNow()
	end
end)

-- the Disciples book's Odds tab: fills `parent` (cleared first); the book sets Toy.S before it asks
local buildTab = Instance.new("BindableFunction")
buildTab.Name = "BuildOddsTab"
buildTab.Parent = player -- not PlayerGui (R19)
buildTab.OnInvoke = function(parent)
	for _, c in parent:GetChildren() do
		c:Destroy()
	end
	Toy.list(parent, false, px(6))
	refreshNow = fill(parent)
	return true
end

-- the window (until the Disciples book replaces it)
local gui = Instance.new("ScreenGui")
gui.Name = "RecruitOdds"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5
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

local function close()
	gui.Enabled = false
	refreshNow = nil
end

local function open()
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
	local body = frame(gui, { Active = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY })
	Toy.list(body, false, px(6))
	text(body, "Recruit Odds", px(24), GOLD, { LayoutOrder = 0, Rotation = -2 })
	refreshNow = fill(body)
	local xHolder, xBtn = Toy.button(gui, UDim2.fromOffset(px(44), px(44)), Color3.fromHex("FF6B5E"), px(12))
	xHolder.AnchorPoint = Vector2.new(1, 0)
	xHolder.Position = UDim2.new(1, -px(22), 0, px(16) + GuiService:GetGuiInset().Y)
	xHolder.ZIndex = 2
	text(xBtn, "X", px(24), WHITE, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	xBtn.Activated:Connect(close)
	gui.Enabled = true
	Sfx.play("toast")
end

local openEvent = Instance.new("BindableEvent")
openEvent.Name = "OpenOdds"
openEvent.Parent = player -- not PlayerGui (R19)
openEvent.Event:Connect(function()
	-- the Disciples book, once it exists, opens on its Odds tab instead (it takes Player.OpenOdds over
	-- by setting the OddsInBook attribute)
	if not player:GetAttribute("OddsInBook") then
		open()
	end
end)
