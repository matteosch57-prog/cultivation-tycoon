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

-- a small dark pill (the pull count, the stars)
local function pill(parent, props)
	local f = frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 0.15, BackgroundColor3 = Color3.fromHex("1E1726") })
	for k, v in props or {} do
		f[k] = v
	end
	Toy.corner(f, UDim.new(1, 0))
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(4)), UDim.new(0, px(4))
	pad.Parent = f
	Toy.list(f, true, 0)
	return f
end

-- One entry as a toy card (owner 2026-10-22: "make it sexier, the frames and add the auras"): a solid
-- shadow, a face lit from the top in the rarity's colours, an ink rim, an inner rim in the rarity's
-- colour (gold once all five stars are in), the toy buttons' glass cap, and the disciple in its moving
-- rarity aura (Toy.aura). Never pulled: a slate card, the figure a dark shape and a "?".
local function tile(parent, rarity, look, pulls, order)
	local r = Config.rarity(rarity.name)
	local stars = Config.indexStars(pulls)
	local found = pulls > 0
	local full = stars >= #Config.INDEX_STARS
	local W, H, R = px(54), px(48), px(10)
	local cell = frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order })
	Toy.list(cell, false, px(2))
	local holder = frame(cell, { Size = UDim2.fromOffset(W, H), LayoutOrder = 1 })
	local shadow = frame(holder, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(3)), BackgroundTransparency = 0, BackgroundColor3 = INK })
	Toy.corner(shadow, UDim.new(0, R))
	local face = frame(holder, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true })
	Toy.corner(face, UDim.new(0, R))
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = found and ColorSequence.new(r.color:Lerp(Color3.new(1, 1, 1), 0.62), r.color:Lerp(INK, 0.12)) or ColorSequence.new(Color3.fromHex("4A3F57"), Color3.fromHex("2A2232"))
	grad.Parent = face
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = px(3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = face
	Toy.glass(face, R)
	if found then
		Toy.disciple(face, px(54), rarity.name, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, px(4)), ZIndex = 2 })
	else
		local fig = Toy.disciple(face, px(38), rarity.name, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, px(4)), ZIndex = 2 }, true)
		fig.ImageColor3 = SHAPE -- never pulled: a dark shape
		text(face, "?", px(17), Color3.fromHex("A89BBB"), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), ZIndex = 3 })
	end
	-- the inner rim: the rarity's colour, gold with all five stars
	local rim = frame(face, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -px(5), 1, -px(5)), ZIndex = 5 })
	Toy.corner(rim, UDim.new(0, R - px(3)))
	local rs = Instance.new("UIStroke")
	rs.Color = full and GOLD or (found and r.color:Lerp(Color3.new(1, 1, 1), 0.35) or Color3.fromHex("5E5270"))
	rs.Thickness = full and px(3) or px(2)
	rs.Parent = rim
	if found then
		local c = pill(face, { Position = UDim2.fromOffset(px(3), px(3)), ZIndex = 6 })
		text(c, "x" .. pulls, px(9), Color3.new(1, 1, 1), { ZIndex = 7 })
	end
	local key = Config.indexKey(rarity.name, look)
	if stars > (seen[key] or 0) then
		local tag = frame(holder, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, px(3), 0, px(1)), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("FF4D4D"), Rotation = 8, ZIndex = 8 })
		Toy.corner(tag, UDim.new(0, px(4)))
		local ts = Instance.new("UIStroke")
		ts.Color = INK
		ts.Thickness = px(2)
		ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ts.Parent = tag
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(3)), UDim.new(0, px(3))
		pad.Parent = tag
		text(tag, "NEW", px(9), Color3.new(1, 1, 1), { ZIndex = 9 })
	end
	-- the five stars on a dark pill: lit gold, the rest dim
	local row = pill(cell, { LayoutOrder = 2 })
	if stars > 0 then
		text(row, string.rep("★", stars), px(11), GOLD, { LayoutOrder = 1 })
	end
	if stars < #Config.INDEX_STARS then
		text(row, string.rep("★", #Config.INDEX_STARS - stars), px(11), STAR_OFF, { LayoutOrder = 2 })
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
	Toy.list(body, false, px(5))
	text(body, "Disciple Index", px(28), GOLD, { LayoutOrder = 1, Rotation = -2 })
	text(body, string.format("%d of %d stars · +%s%% qi forever", total, max, string.format("%.2f", (Config.indexMult(index) - 1) * 100):gsub("%.?0+$", "")), px(14), Color3.new(1, 1, 1), { LayoutOrder = 2 })

	local grid = frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	Toy.list(grid, false, px(3))
	-- the head: each rarity's name once any of its looks is found, else ???
	local head = frame(grid, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 0 })
	Toy.list(head, true, px(4))
	frame(head, { Size = UDim2.fromOffset(px(46), px(16)), LayoutOrder = 0 })
	for i, r in Config.RARITIES do
		local found = false
		for _, look in Config.DISCIPLE_LOOKS do
			found = found or (index[Config.indexKey(r.name, look)] or 0) > 0
		end
		local name = string.gsub(r.name, " Disciple$", "")
		name = string.gsub(name, "^Heavenly ", "")
		local cellHead = frame(head, { Size = UDim2.fromOffset(px(54), px(16)), LayoutOrder = i })
		local ribbon = frame(cellHead, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -px(2), 1, 0), BackgroundTransparency = 0, BackgroundColor3 = found and r.color or Color3.fromHex("3A3044") })
		Toy.corner(ribbon, UDim.new(1, 0))
		local rbs = Instance.new("UIStroke")
		rbs.Color = INK
		rbs.Thickness = px(2)
		rbs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rbs.Parent = ribbon
		text(ribbon, found and name or "???", px(#name > 9 and 8 or 10), found and Color3.new(1, 1, 1) or GREY, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	end
	for li, look in Config.DISCIPLE_LOOKS do
		local row = frame(grid, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = li })
		Toy.list(row, true, px(4))
		local lab = frame(row, { Size = UDim2.fromOffset(px(46), px(48)), LayoutOrder = 0 })
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
