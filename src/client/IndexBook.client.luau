-- The disciple index (D60, owner pick B + C 2026-10-22, mock docs/art/mocks/disciple_index_B.png with the
-- stars of disciple_index_C.png): one tile per rarity and look (9 x 4), a dark shape until pulled, its
-- pulls in the corner and its star row under it (Config.INDEX_STARS, Toy.stars). The foot shows the stars, the qi
-- they add (INDEX_STAR_BONUS each, forever) and the next summons step. Opened from the HUD disciples
-- card (Player.IndexOpen); the server alone counts (data.index, published as the Index attribute).
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
local JADE = Color3.fromHex("59D39F")
local WHITE = Color3.new(1, 1, 1)
local INK = Toy.INK

local openEvent = Instance.new("BindableEvent")
openEvent.Name = "IndexOpen"
openEvent.Parent = player -- not PlayerGui: the first LoadCharacter (Main onJoin) empties it, live joins spawn after this runs

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

-- the ShinyIndex attribute: "Elder|lotus;Core Disciple|sword" -> { [key] = true } (found Shiny)
local function readShiny()
	local out = {}
	for _, key in string.split(player:GetAttribute("ShinyIndex") or "", ";") do
		if key ~= "" then
			out[key] = true
		end
	end
	return out
end

-- the MutIndex attribute: "Elder|lotus#Dewy;..." -> { [key] = { "Dewy", ... } } (weather mutations found),
-- strongest first
local function readMut()
	local out = {}
	for _, pair in string.split(player:GetAttribute("MutIndex") or "", ";") do
		local key, mut = string.match(pair, "^(.-)#(.+)$")
		if key and Config.mutation(mut) then
			out[key] = out[key] or {}
			table.insert(out[key], mut)
		end
	end
	for _, list in out do
		table.sort(list, function(a, b)
			return Config.mutation(a).mult > Config.mutation(b).mult
		end)
	end
	return out
end

-- the MutIndex keys as a set, for Config.markCount (every weather mark found: MARK_FULL_BONUS qi)
local function readMarks()
	local out = {}
	for _, pair in string.split(player:GetAttribute("MutIndex") or "", ";") do
		if pair ~= "" then
			out[pair] = true
		end
	end
	return out
end

local seen = {} -- stars per entry at the last close: a tile with more since says NEW
local close
local nameLine -- the foot line: the star rule, then the tapped disciple's name (named disciples, 2026-10-23)
local shinyFound = {}
local mutFound = {}
local marksOf

-- the weather marks of one entry: { [mutation] = true }
marksOf = function(key)
	local out = {}
	for _, mut in mutFound[key] or {} do
		out[mut] = true
	end
	return out
end

-- One entry: the shared disciple tile (Toy.discipleTile, the same card as My Sect and the recruit
-- reveal), its pulls in the corner and its star row under it. Tap: its name under the grid.
local function tile(parent, rarity, look, pulls, order)
	local key = Config.indexKey(rarity.name, look)
	local stars = Config.indexStars(pulls)
	local _, tap = Toy.discipleTile(parent, px(54), rarity.name, look, {
		found = pulls > 0,
		shiny = shinyFound[key],
		marks = marksOf(key),
		stars = stars,
		count = pulls,
		new = stars > (seen[key] or 0),
		order = order,
	})
	tap.Activated:Connect(function()
		if nameLine and pulls > 0 then
			nameLine.Text = (shinyFound[key] and "Shiny " or "") .. Config.discipleName(rarity.name, look) .. " · " .. rarity.name .. (mutFound[key] and " · " .. table.concat(mutFound[key], ", ") or "")
			nameLine.TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.25)
			nameLine.TextSize = px(15)
		end
	end)
end

-- the Index page into `body` (a vertical list): the stars line, the grid, the tapped name, the
-- summons bar and the star rule. The Disciples book's Index tab (Player.BuildIndexTab) and this
-- script's own window both fill it.
local function fill(body)
	local index = readIndex()
	shinyFound = readShiny()
	mutFound = readMut()
	local total = Config.indexTotalStars(index)
	local max = #Config.RARITIES * #Config.DISCIPLE_LOOKS * #Config.INDEX_STARS
	text(body, string.format("%d of %d stars · +%s%% qi forever", total, max, string.format("%.2f", (Config.indexMult(index, Config.markCount(readMarks())) - 1) * 100):gsub("%.?0+$", "")), px(14), Color3.new(1, 1, 1), { LayoutOrder = 2 })

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
		text(ribbon, found and name or "???", px(#name > 9 and 9 or 10), found and Color3.new(1, 1, 1) or GREY, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
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

	-- the foot, side by side (a phone has no height to spare): progress to the next summons step of the
	-- stars, and of the weather marks (all of them: MARK_FULL_BONUS qi forever)
	local foot = frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 5 })
	Toy.list(foot, true, px(8))
	local function bar(order, frac, color, str)
		local b = frame(foot, { Size = UDim2.fromOffset(px(280), px(20)), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("2B2033"), ClipsDescendants = true, LayoutOrder = order })
		Toy.corner(b, UDim.new(1, 0))
		local bs = Instance.new("UIStroke")
		bs.Color = INK
		bs.Thickness = px(3)
		bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bs.Parent = b
		local f = frame(b, { Size = UDim2.fromScale(math.clamp(frac, 0.03, 1), 1), BackgroundTransparency = 0, BackgroundColor3 = color })
		Toy.corner(f, UDim.new(1, 0))
		local t = text(b, str, px(13), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -px(10), 1, 0), TextScaled = true })
		local lim = Instance.new("UITextSizeConstraint")
		lim.MaxTextSize = px(13)
		lim.Parent = t
		return f
	end
	local step = Config.INDEX_STEP_STARS
	local nextAt = (total // step + 1) * step
	bar(1, (total % step) / step, JADE, total >= max and "Every star found!" or string.format("%d / %d stars · then +%d free summons", total, math.min(nextAt, max), Config.INDEX_STEP_SUMMONS))
	local marks, allMarks = 0, Config.markTotal()
	for _, list in mutFound do
		marks += #list
	end
	local mstep = Config.MARK_STEP
	local mf = bar(2, marks >= allMarks and 1 or (marks % mstep) / mstep, WHITE, marks >= allMarks and string.format("Every weather mark! +%d%% qi forever", math.floor(Config.MARK_FULL_BONUS * 100 + 0.5))
		or string.format("%d / %d weather marks · then +%d free summons", marks, math.min((marks // mstep + 1) * mstep, allMarks), Config.MARK_STEP_SUMMONS))
	local mg = Instance.new("UIGradient") -- the four mutation colours along the fill
	local keys = {}
	for i, w in Config.WEATHERS do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#Config.WEATHERS - 1), w.tint))
	end
	mg.Color = ColorSequence.new(keys)
	mg.Parent = mf
	-- "A star at 1, 3, 10, 30, 100 pulls of a disciple in one look, then red stars to 1000, blue to 5000"
	local n, starsAt, later = Config.STAR_ROW, {}, {}
	for i, at in Config.INDEX_STARS do
		if i <= n then
			table.insert(starsAt, tostring(at))
		elseif i % n == 0 then
			table.insert(later, string.format("%s to %d", ({ "", "red stars", "blue" })[i // n] or "more", at))
		end
	end
	local line = "A star at " .. table.concat(starsAt, ", ") .. " pulls of a disciple in one look"
	if #later > 0 then
		line ..= ", then " .. table.concat(later, ", ")
	end
	-- one line for both (a phone has no height to spare): the rule until a tile is tapped
	nameLine = text(body, line, px(12), Color3.fromHex("E8E0F0"), { LayoutOrder = 6 })
end

-- the window (until the Disciples book replaces it): veil, title, the page, the X
local function build()
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
	veil.Activated:Connect(function()
		close()
	end)
	local body = frame(gui, { Active = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), AutomaticSize = Enum.AutomaticSize.XY })
	Toy.list(body, false, px(5))
	text(body, "Disciple Index", px(28), GOLD, { LayoutOrder = 1, Rotation = -2 })
	fill(body)

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

-- the Disciples book's Index tab: fills `parent` (cleared first) with the page; returns true. The book
-- sets Toy.S before it asks. What it shows counts as seen when the book closes (Player.IndexSeen).
local buildTab = Instance.new("BindableFunction")
buildTab.Name = "BuildIndexTab"
buildTab.Parent = player -- not PlayerGui (R19)
buildTab.OnInvoke = function(parent)
	for _, c in parent:GetChildren() do
		c:Destroy()
	end
	Toy.list(parent, false, px(5))
	fill(parent)
	return true
end
local seenEvent = Instance.new("BindableEvent")
seenEvent.Name = "IndexSeen"
seenEvent.Parent = player
seenEvent.Event:Connect(close)
