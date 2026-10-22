-- The disciple index (D60, owner pick B + C 2026-10-22, mock docs/art/mocks/disciple_index_B.png with the
-- stars of disciple_index_C.png): one tile per rarity and look (9 x 4), a dark shape until pulled, its
-- pulls in the corner and five stars under it (Config.INDEX_STARS). The foot shows the stars, the qi
-- they add (INDEX_STAR_BONUS each, forever) and the next summons step. Opened from the HUD disciples
-- card (PlayerGui.IndexOpen); the server alone counts (data.index, published as the Index attribute).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local px, text, frame = Toy.px, Toy.text, Toy.frame
local GOLD = Color3.fromHex("FFD34D")
local GREY = Color3.fromHex("9A8FA8")
local DARK = Color3.fromHex("3A3044")
local SHAPE = Color3.fromHex("241C2C")
local STAR_OFF = Color3.fromHex("4A3F55")
local JADE = Color3.fromHex("59D39F")
local INK = Toy.INK

local openEvent = Instance.new("BindableEvent")
openEvent.Name = "IndexOpen"
openEvent.Parent = playerGui

local gui = Instance.new("ScreenGui")
gui.Name = "Index"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5 -- over the HUD, like the Shop
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

-- the Index attribute: "Elder|lotus=3;Core Disciple|sword=12" -> { [key] = pulls }
local function readIndex()
	local out = {}
	for _, pair in string.split(player:GetAttribute("Index") or "", ";") do
		local key, n = string.match(pair, "^(.-)=(%d+)$")
		if key then
			out[key] = tonumber(n)
		end
	end
	return out
end

local seen = {} -- stars per entry at the last close: a tile with more since says NEW
local close

local function tile(parent, rarity, look, pulls, order)
	local r = Config.rarity(rarity.name)
	local stars = Config.indexStars(pulls)
	local cell = frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order })
	Toy.list(cell, false, px(1))
	local box = frame(cell, { Size = UDim2.fromOffset(px(52), px(42)), BackgroundTransparency = 0, BackgroundColor3 = pulls > 0 and r.color:Lerp(Color3.new(1, 1, 1), 0.72) or DARK, ClipsDescendants = true, LayoutOrder = 1 })
	Toy.corner(box, UDim.new(0, px(9)))
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = px(2)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = box
	local fig = Toy.disciple(box, px(40), rarity.name, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, px(3)), ZIndex = 2 }, true)
	if pulls == 0 then
		fig.ImageColor3 = SHAPE -- never pulled: a dark shape
	end
	if pulls > 0 then
		text(box, "x" .. pulls, px(10), Color3.new(1, 1, 1), { Position = UDim2.fromOffset(px(3), px(1)), ZIndex = 3 })
	end
	local key = Config.indexKey(rarity.name, look)
	if stars > (seen[key] or 0) then
		local tag = frame(box, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -px(2), 0, px(2)), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("FF5A5A"), ZIndex = 4 })
		Toy.corner(tag, UDim.new(0, px(4)))
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(2)), UDim.new(0, px(2))
		pad.Parent = tag
		text(tag, "NEW", px(8), Color3.new(1, 1, 1), { ZIndex = 5 })
	end
	-- the five stars: lit gold, the rest dark
	local row = frame(cell, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	Toy.list(row, true, 0)
	if stars > 0 then
		text(row, string.rep("★", stars), px(10), GOLD, { LayoutOrder = 1 })
	end
	if stars < #Config.INDEX_STARS then
		text(row, string.rep("★", #Config.INDEX_STARS - stars), px(10), STAR_OFF, { LayoutOrder = 2 })
	end
	local sc = Instance.new("UIScale")
	sc.Name = "Pop"
	sc.Parent = cell
end

local function build()
	gui:ClearAllChildren()
	Toy.S = computeScale()
	local index = readIndex()
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

	local total = Config.indexTotalStars(index)
	local max = #Config.RARITIES * #Config.DISCIPLE_LOOKS * #Config.INDEX_STARS
	local body = frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), AutomaticSize = Enum.AutomaticSize.XY })
	Toy.list(body, false, px(6))
	text(body, "Disciple Index", px(30), GOLD, { LayoutOrder = 1, Rotation = -2 })
	text(body, string.format("%d of %d stars · +%s%% qi forever", total, max, string.format("%.2f", (Config.indexMult(index) - 1) * 100):gsub("%.?0+$", "")), px(14), Color3.new(1, 1, 1), { LayoutOrder = 2 })

	local grid = frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	Toy.list(grid, false, px(3))
	-- the head: each rarity's name once any of its looks is found, else ???
	local head = frame(grid, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 0 })
	Toy.list(head, true, px(4))
	frame(head, { Size = UDim2.fromOffset(px(46), px(12)), LayoutOrder = 0 })
	for i, r in Config.RARITIES do
		local found = false
		for _, look in Config.DISCIPLE_LOOKS do
			found = found or (index[Config.indexKey(r.name, look)] or 0) > 0
		end
		local name = string.gsub(r.name, " Disciple$", "")
		name = string.gsub(name, "^Heavenly ", "")
		local cellHead = frame(head, { Size = UDim2.fromOffset(px(52), px(14)), LayoutOrder = i })
		text(cellHead, found and name or "???", px(#name > 9 and 9 or 11), found and r.color or GREY, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	end
	for li, look in Config.DISCIPLE_LOOKS do
		local row = frame(grid, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = li })
		Toy.list(row, true, px(4))
		local lab = frame(row, { Size = UDim2.fromOffset(px(46), px(42)), LayoutOrder = 0 })
		text(lab, Config.LOOK_NAMES[look], px(13), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -px(2), 0.4, 0) })
		for i, r in Config.RARITIES do
			tile(row, r, look, index[Config.indexKey(r.name, look)] or 0, i)
		end
	end

	-- the foot: progress to the next summons step
	local step = Config.INDEX_STEP_STARS
	local nextAt = (total // step + 1) * step
	local bar = frame(body, { Size = UDim2.fromOffset(px(420), px(20)), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("2B2033"), ClipsDescendants = true, LayoutOrder = 4 })
	Toy.corner(bar, UDim.new(1, 0))
	local bs = Instance.new("UIStroke")
	bs.Color = INK
	bs.Thickness = px(3)
	bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bs.Parent = bar
	local fill = frame(bar, { Size = UDim2.fromScale(math.clamp((total % step) / step, 0.03, 1), 1), BackgroundTransparency = 0, BackgroundColor3 = JADE })
	Toy.corner(fill, UDim.new(1, 0))
	local barText = total >= max and "Every star found!" or string.format("%d / %d stars · then +%d free summons", total, math.min(nextAt, max), Config.INDEX_STEP_SUMMONS)
	text(bar, barText, px(13), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	local starsAt = {}
	for _, at in Config.INDEX_STARS do
		table.insert(starsAt, tostring(at))
	end
	text(body, "A star at " .. table.concat(starsAt, ", ") .. " pulls of a disciple in one look", px(12), Color3.fromHex("E8E0F0"), { LayoutOrder = 5 })

	-- close: the big X top right, as on the Shop
	local xHolder, xBtn = Toy.button(gui, UDim2.fromOffset(px(44), px(44)), Color3.fromHex("FF6B5E"), px(12))
	xHolder.AnchorPoint = Vector2.new(1, 0)
	xHolder.Position = UDim2.new(1, -px(22), 0, px(16) + GuiService:GetGuiInset().Y)
	xHolder.ZIndex = 2
	text(xBtn, "X", px(24), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	xBtn.Activated:Connect(function()
		close()
	end)
end

-- tiles spring in one after another (as the Shop's)
local function pop()
	local i = 0
	for _, d in gui:GetDescendants() do
		if d:IsA("UIScale") and d.Name == "Pop" then
			i += 1
			d.Scale = 0.3
			TweenService:Create(d, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, math.min(i, 40) * 0.012), { Scale = 1 }):Play()
		end
	end
end

local function open()
	if gui.Enabled then
		return
	end
	build()
	gui.Enabled = true
	pop()
	Sfx.play("toast")
	remotes.MenuOpened:FireServer("index") -- analytics Menu (DATA.md)
end

close = function()
	gui.Enabled = false
	-- what was looked at is no longer NEW
	for key, pulls in readIndex() do
		seen[key] = Config.indexStars(pulls)
	end
	player:SetAttribute("IndexNew", false) -- the HUD's dot (local)
end

-- a star gained since the last look lights the HUD's dot (local attribute IndexNew)
local function starsNow()
	return Config.indexTotalStars(readIndex())
end
local lastStars = starsNow()
for key, pulls in readIndex() do
	seen[key] = Config.indexStars(pulls) -- the book starts seen on join
end
player:GetAttributeChangedSignal("Index"):Connect(function()
	local n = starsNow()
	if n > lastStars and not gui.Enabled then
		player:SetAttribute("IndexNew", true)
	end
	lastStars = n
	if gui.Enabled then
		build()
	end
end)

openEvent.Event:Connect(open)
