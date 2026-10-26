-- Sect Missions (2026-10-25, copies Pet Simulator 99 ranks; mock /mnt/project-files/2026-10-25_missions):
-- the tracker beside the HUD's left rail (the rank bar, the active missions, today's next daily) and the
-- rank page (the reward path, every mission, the dailies). Everything comes from the server's "Missions"
-- attribute (Missions.luau, JSON); the server alone counts and pays (R9). A finished mission flies a gold
-- "+N ★" line, a paid reward or a rank up a bigger one (Notify "mission").
-- The tracker is one glass panel (owner pick A 2026-10-26) with a tab that hides it down to the rank badge
-- (MissionsHidden, saved). Config.MISSION_DAILY_ON: the daily row.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local Sfx = require(Shared:WaitForChild("Sfx"))

if not Config.MISSIONS_ON then
	return
end

local px, text, frame, corner = Toy.px, Toy.text, Toy.frame, Toy.corner
local GOLD = Color3.fromHex("FFD34D")
local PANEL = Color3.fromHex("241C2E")
local TRACK = Color3.fromHex("4A3F57")
local MUTED = Color3.fromHex("C9BDDA")
local JADE = Color3.fromHex("3FCF9A")
local DAILY = Color3.fromHex("7FB6FF")
local SUMMON = Color3.fromHex("D9B8FF")
local PILL = Color3.fromHex("FF9A8C")
local QI = Color3.fromHex("8FF0C8")

local gui = Instance.new("ScreenGui")
gui.Name = "Missions"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 17 -- over the HUD, under the Gifts page (18) and the Intro (20)
gui.Parent = playerGui

-- the rank page has its own ScreenGui, empty while closed: the Daily Blessing waits while it has children
-- (Streak.client COVERS)
local pageGui = Instance.new("ScreenGui")
pageGui.Name = "MissionsPage"
pageGui.ResetOnSpawn = false
pageGui.IgnoreGuiInset = true
pageGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pageGui.DisplayOrder = 19
pageGui.Parent = playerGui

local openEvent = Instance.new("BindableEvent")
openEvent.Name = "MissionsOpen"
openEvent.Parent = player -- not PlayerGui: the first LoadCharacter empties it

local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice")
	local touch = if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
	if touch then
		return math.clamp(vp.Y / 390, 0.72, 1.1), true
	end
	return math.clamp(vp.Y / 554, 1, 1.7), false
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function short(n)
	n = math.floor(n or 0)
	local units = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local i = 1
	while n >= 1000 * 10 ^ (3 * (i - 1)) and i < #units do
		i += 1
	end
	local v = n / 10 ^ (3 * (i - 1))
	return (v < 10 and i > 1) and string.format("%.1f%s", v, units[i]) or string.format("%d%s", math.floor(v), units[i])
end

local function clock(s)
	s = math.max(0, math.ceil(s))
	return s >= 3600 and string.format("%dh %02dm", s // 3600, (s % 3600) // 60) or string.format("%dm", math.max(1, s // 60))
end

local function state()
	local raw = player:GetAttribute("Missions")
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local ok, m = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and m or nil
end

-- a rounded dark panel
local function panel(parent, props, color, transp)
	local f = frame(parent, { BackgroundTransparency = transp or 0.1, BackgroundColor3 = color or PANEL })
	for k, v in props or {} do
		f[k] = v
	end
	corner(f, UDim.new(0, px(10)))
	return f
end

-- a progress bar: returns the bar and its fill
local function bar(parent, h, fillColor, order)
	local b = frame(parent, { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 0, BackgroundColor3 = TRACK, LayoutOrder = order or 9 })
	corner(b, UDim.new(1, 0))
	local f = frame(b, { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = fillColor })
	corner(f, UDim.new(1, 0))
	return b, f
end

local function stars(parent, n, size, props)
	return text(parent, string.rep("★", n), size, GOLD, props)
end

-- one mission row: stars, its words, the count, a bar under (daily = a blue edge and a jade bar)
local function missionRow(parent, x, w, size, order, daily)
	local done = x.n >= x.need
	local row = panel(parent, { Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, done and Color3.fromHex("173A2E") or PANEL, 0.15)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(daily and 10 or 8)), UDim.new(0, px(8))
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(4)), UDim.new(0, px(6))
	pad.Parent = row
	Toy.list(row, false, px(3), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
	if daily or done then -- a daily wears a blue rim, a finished mission a jade one
		local rim = Instance.new("UIStroke")
		rim.Color = done and JADE or DAILY
		rim.Thickness = px(2)
		rim.Parent = row
	end
	local line = frame(row, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 })
	Toy.list(line, true, px(6), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
	stars(line, x.stars, size - px(1), { LayoutOrder = 1 })
	text(line, x.text, size, Color3.new(1, 1, 1), { LayoutOrder = 2 })
	if x.need > 1 then
		text(line, string.format("%d/%d", math.min(x.n, x.need), x.need), size - px(2), done and QI or MUTED, { LayoutOrder = 3 })
	end
	local _, fill = bar(row, px(6), daily and JADE or GOLD, 2)
	fill.Size = UDim2.fromScale(math.clamp(x.n / math.max(1, x.need), 0, 1), 1)
	return row
end

-- what a reward pays, as one short line and its colour
local function rewardWords(r)
	if r.rarity then
		return r.rarity, Config.rarity(r.rarity).color
	elseif (r.pill or 0) > 0 then
		return string.format("2x Qi %d min", r.pill // 60), PILL
	elseif (r.summons or 0) > 0 then
		return string.format("%d summon%s", r.summons, r.summons > 1 and "s" or ""), SUMMON
	end
	return "+" .. short((player:GetAttribute("AwayRate") or 0) * (r.qiSec or 0)) .. " qi", QI
end

local function rewardIcon(parent, r, size, props)
	if r.rarity then
		return Toy.disciple(parent, size, r.rarity, props)
	elseif (r.pill or 0) > 0 then
		return Toy.icon(parent, "pill", size, props)
	elseif (r.summons or 0) > 0 then
		return Toy.icon(parent, "disciple", size, props)
	end
	return Toy.qiIcon(parent, size, props)
end

---------------------------------------------------------------------------- the tracker
local tracker -- the frame beside the left rail
local page -- the open rank page, or nil
local drawPage, drawTracker

local function leftRail()
	local slots = player:FindFirstChild("HudSlots")
	local left = slots and slots:FindFirstChild("Left")
	return left and left.Value
end

local function place()
	if not tracker then
		return
	end
	local rail = leftRail()
	local S = Toy.S
	if rail and rail.Parent then
		-- AbsolutePosition (the rail's, the chat's) is measured under the Roblox top bar, this gui starts above
		-- it (IgnoreGuiInset): without the origin the panel sat one top bar too high, behind the Roblox menus
		local origin = gui.AbsolutePosition
		local x = rail.AbsolutePosition.X - origin.X + rail.AbsoluteSize.X + px(10)
		local y = rail.AbsolutePosition.Y - origin.Y + px(4)
		-- Roblox's chat window (and its input bar) sit top-left over game GUI: start under them
		for _, cls in { "ChatWindowConfiguration", "ChatInputBarConfiguration" } do
			local c = TextChatService:FindFirstChildOfClass(cls)
			if c and c.Enabled and c.AbsoluteSize.Y > 0 and c.AbsolutePosition.X - origin.X + c.AbsoluteSize.X > x then
				y = math.max(y, c.AbsolutePosition.Y - origin.Y + c.AbsoluteSize.Y + px(10))
			end
		end
		tracker.Position = UDim2.fromOffset(x, y)
		tracker.Visible = rail.Visible and rail.Parent.Visible ~= false and page == nil -- hidden under a full screen (the HUD hides its rail)
	else
		tracker.Position = UDim2.fromOffset(px(110) * S, px(140))
	end
end

-- the icon of a mission's group (the HUD's icon sheet)
local GROUP_ICON = { build = "hall", recruit = "disciple", orb = "qi", gift = "gift", pill = "pill", altar = "altar", bless = "like", breakthrough = "goal", rebirth = "rebirth", streak = "chest" }

-- a chevron drawn from two bars (the font has no arrow glyph): points left when `open`
local function chevron(parent, size, open)
	local box = frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size), ZIndex = 4 })
	for k, rot in { 45, -45 } do
		local b = frame(box, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, (k == 1 and -1 or 1) * size * 0.18),
			Size = UDim2.fromOffset(size * 0.55, math.max(3, size * 0.16)),
			Rotation = open and -rot or rot,
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromHex("E8E0F0"),
			ZIndex = 4,
		})
		corner(b, UDim.new(1, 0))
	end
	return box
end

local hidden = false -- the player's choice (MissionsHidden, saved by the server)
local dotOn = false -- a mission finished while hidden: the badge's red dot

local function setHidden(v)
	hidden = v
	if not v then
		dotOn = false
	end
	local ev = remotes:FindFirstChild("MissionsHide")
	if ev then
		ev:FireServer(v)
	end
end

-- the gold rank badge (a button)
local function rankBadge(parent, rank, size, order)
	local b = Instance.new("TextButton")
	b.Text = ""
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = Color3.fromHex("F0B400")
	b.LayoutOrder = order or 0
	b.Parent = parent
	corner(b, UDim.new(1, 0))
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromHex("FFF0A0"), Color3.fromHex("E09A00"))
	g.Rotation = 90
	g.Parent = b
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = math.max(2, size * 0.09)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = b
	text(b, tostring(rank), math.floor(size * 0.55), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	return b
end

-- the small square tab that hides or shows the list
local function hideTab(parent, size, open, order)
	local t = Instance.new("TextButton")
	t.Text = ""
	t.AutoButtonColor = false
	t.Size = UDim2.fromOffset(size, size)
	t.BackgroundColor3 = Color3.new(1, 1, 1)
	t.BackgroundTransparency = 0.88
	t.LayoutOrder = order or 9
	t.Parent = parent
	corner(t, UDim.new(0, math.floor(size * 0.3)))
	chevron(t, math.floor(size * 0.55), open)
	Toy.feel(t)
	t.Activated:Connect(function()
		setHidden(open)
		drawTracker()
	end)
	return t
end

-- one row of the glass panel: the group's icon, the words and stars, the count on the right, a slim bar
local function panelRow(parent, x, w, size, order, daily)
	local row = frame(parent, { Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order })
	local icon = px(size * 2)
	local well = frame(row, { Size = UDim2.fromOffset(icon, icon), BackgroundTransparency = 0, BackgroundColor3 = daily and Color3.fromHex("2B4466") or Color3.fromHex("3A2F48") })
	corner(well, UDim.new(1, 0))
	local ws = Instance.new("UIStroke")
	ws.Color = Toy.INK
	ws.Thickness = px(2)
	ws.Parent = well
	Toy.icon(well, GROUP_ICON[x.g] or "goal", icon - px(8), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	local col = frame(row, { Position = UDim2.fromOffset(icon + px(8), 0), Size = UDim2.new(1, -(icon + px(8)), 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	Toy.list(col, false, px(3), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
	local top = frame(col, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 })
	local words = frame(top, { AutomaticSize = Enum.AutomaticSize.XY })
	Toy.list(words, true, px(4), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
	if daily then
		text(words, "Daily ·", size, DAILY, { LayoutOrder = 0 })
	end
	text(words, x.text, size, Color3.new(1, 1, 1), { LayoutOrder = 1 })
	stars(words, x.stars, size - px(3), { LayoutOrder = 2 })
	if x.need > 1 then
		text(top, string.format("%d/%d", math.min(x.n, x.need), x.need), size - px(2), MUTED, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, px(1)) })
	end
	local _, fill = bar(col, px(6), daily and JADE or GOLD, 2)
	fill.Parent.BackgroundColor3 = Color3.new(0, 0, 0)
	fill.Parent.BackgroundTransparency = 0.55
	fill.Size = UDim2.fromScale(math.clamp(x.n / math.max(1, x.need), 0, 1), 1)
	return row
end

function drawTracker()
	local S, phone = computeScale()
	Toy.S = S
	if tracker then
		tracker:Destroy()
		tracker = nil
	end
	local m = state()
	if not m then
		return
	end
	local size = phone and px(12) or px(15)
	local badgeSize = px(phone and 26 or 30)
	tracker = frame(gui, { Name = "Tracker", AutomaticSize = Enum.AutomaticSize.XY })
	if hidden then
		-- hidden: the rank badge (opens the page, red dot when a mission finished) and the tab to show
		Toy.list(tracker, true, px(8), { VerticalAlignment = Enum.VerticalAlignment.Center })
		local b = rankBadge(tracker, m.rank, px(phone and 40 or 46), 1)
		Toy.feel(b)
		b.Activated:Connect(function()
			drawPage(true)
		end)
		Toy.dot(b, px(16), { Visible = dotOn })
		local holder = frame(tracker, { AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 0.15, BackgroundColor3 = PANEL, LayoutOrder = 2 })
		corner(holder, UDim.new(0, px(10)))
		hideTab(holder, px(30), false)
		place()
		return
	end
	local w = phone and px(250) or px(320)
	-- one glass panel (owner pick A 2026-10-26: Pet Sim 99 / Bee Swarm quest list), a hard ink shadow under it
	local shadow = frame(tracker, { Position = UDim2.fromOffset(0, px(4)), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Toy.INK })
	corner(shadow, UDim.new(0, px(16)))
	local card = Instance.new("TextButton")
	card.Text = ""
	card.AutoButtonColor = false
	card.Size = UDim2.fromOffset(w, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromHex("2A2036")
	card.BackgroundTransparency = 0.08
	card.Selectable = false -- a gamepad selects the hide tab, not the whole card (Play check)
	card.Parent = tracker
	corner(card, UDim.new(0, px(16)))
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("B9AEC8"))
	grad.Rotation = 90
	grad.Parent = card
	local cs = Instance.new("UIStroke")
	cs.Color = Toy.INK
	cs.Thickness = px(3)
	cs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cs.Parent = card
	card.Activated:Connect(function()
		drawPage(true)
	end)
	shadow.Size = UDim2.fromOffset(w, 0)
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		shadow.Size = UDim2.fromOffset(w, card.AbsoluteSize.Y)
	end)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(10)), UDim.new(0, px(10))
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(7)), UDim.new(0, px(10))
	pad.Parent = card
	Toy.list(card, false, px(8), { HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top })
	local inner = w - px(20)
	-- header: badge, rank name, stars of the rank, the hide tab
	local head = frame(card, { Size = UDim2.fromOffset(inner, badgeSize), LayoutOrder = 0 })
	local left = frame(head, { AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromScale(0, 1) })
	Toy.list(left, true, px(8), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
	rankBadge(left, m.rank, badgeSize, 1).Activated:Connect(function()
		drawPage(true)
	end)
	text(left, m.name, size + px(3), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	local right = frame(head, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1) })
	Toy.list(right, true, px(8), { HorizontalAlignment = Enum.HorizontalAlignment.Right })
	text(right, string.format("★ %d/%d", m.stars, m.path[#m.path].at), size + px(1), GOLD, { LayoutOrder = 1 })
	hideTab(right, badgeSize, true, 2)
	local line = frame(card, { Size = UDim2.fromOffset(inner, px(2)), BackgroundTransparency = 0.88, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 1 })
	line.Name = "Divider"
	for i, x in m.slots do
		panelRow(card, x, inner, size, 1 + i)
	end
	if Config.MISSION_DAILY_ON and #m.daily > 0 then
		local nextD
		for _, x in m.daily do
			if x.n < x.need then
				nextD = x
				break
			end
		end
		if nextD then
			panelRow(card, nextD, inner, size, 20, true)
		else
			text(card, m.chest and "Daily chest claimed · new in " .. clock(m.resetIn) or "Daily done", size - px(1), QI, { LayoutOrder = 20 })
		end
	end
	place()
end

---------------------------------------------------------------------------- the rank page
drawPage = function(open)
	if page then
		page:Destroy()
		page = nil
	end
	if not open then
		place()
		return
	end
	local m = state()
	if not m then
		return
	end
	local S, phone = computeScale()
	Toy.S = S
	local vp = workspace.CurrentCamera.ViewportSize
	local w = math.min(vp.X - px(40), px(phone and 620 or 760))
	local dim = Instance.new("TextButton")
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = pageGui
	page = dim
	dim.Activated:Connect(function()
		drawPage(false)
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
	st.Color = GOLD
	st.Thickness = px(4)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = card
	-- the content in its own list, so the close button can sit on the card's corner
	local body = frame(card, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(16)), UDim.new(0, px(16))
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(12)), UDim.new(0, px(14))
	pad.Parent = body
	Toy.list(body, false, px(10), { HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top })
	-- title
	local title = frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	Toy.list(title, true, px(10))
	local badge = frame(title, { Size = UDim2.fromOffset(px(32), px(32)), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("F0B400"), LayoutOrder = 1 })
	corner(badge, UDim.new(1, 0))
	text(badge, tostring(m.rank), px(18), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	text(title, m.name, px(24), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	local nextName = Config.missionRank(m.rank + 1)
	text(title, string.format("★ %d of %d to %s", m.stars, m.path[#m.path].at, nextName), px(15), MUTED, { LayoutOrder = 3 })
	-- close
	local xh, xb = Toy.button(card, UDim2.fromOffset(px(36), px(36)), Color3.fromHex("FF4D4D"), px(18))
	xh.AnchorPoint = Vector2.new(0.5, 0.5)
	xh.Position = UDim2.new(1, -px(4), 0, px(4))
	xh.ZIndex = 5
	text(xb, "X", px(20), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	Toy.feel(xb)
	xb.Activated:Connect(function()
		drawPage(false)
	end)
	-- the reward path: nodes along a gold line, ticked when paid, the next one ringed
	local pathH = px(phone and 96 or 112)
	local path = frame(body, { Size = UDim2.new(1, 0, 0, pathH), LayoutOrder = 2 })
	local lineY = px(phone and 30 or 36)
	local _, fill = bar(path, px(10), GOLD)
	fill.Parent.Position = UDim2.fromOffset(0, lineY - px(5))
	local n = #m.path
	local total = m.path[n].at
	fill.Size = UDim2.fromScale(math.clamp(m.stars / total, 0, 1), 1)
	local node = px(phone and 50 or 60)
	for i, r in m.path do
		local x = r.at / total
		local cell = frame(path, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(x, -(x * node) + node / 2, 0, lineY - node / 2), Size = UDim2.fromOffset(node + px(20), 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2 })
		Toy.list(cell, false, px(1), { VerticalAlignment = Enum.VerticalAlignment.Top })
		local got, isNext, last = i <= m.paid, i == m.paid + 1, i == n
		local box = frame(cell, { Size = UDim2.fromOffset(node, node), BackgroundTransparency = 0, BackgroundColor3 = got and Color3.fromHex("1F3B31") or last and Color3.fromHex("3A2650") or Color3.fromHex("352A44"), LayoutOrder = 1, ZIndex = 2 })
		corner(box, UDim.new(0, px(12)))
		local bs = Instance.new("UIStroke")
		bs.Color = got and JADE or isNext and GOLD or last and Color3.fromHex("C77DFF") or Color3.fromHex("5D4F70")
		bs.Thickness = px(3)
		bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bs.Parent = box
		rewardIcon(box, r, node - px(18), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		if got then
			-- paid: a jade dot on the corner (FredokaOne has no tick glyph)
			local tick = frame(box, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -px(2), 0, px(2)), Size = UDim2.fromOffset(px(18), px(18)), BackgroundTransparency = 0, BackgroundColor3 = JADE, ZIndex = 4 })
			corner(tick, UDim.new(1, 0))
			local ts = Instance.new("UIStroke")
			ts.Color = Toy.INK
			ts.Thickness = px(2)
			ts.Parent = tick
		end
		local words, color = rewardWords(r)
		text(cell, "★" .. r.at, px(13), GOLD, { LayoutOrder = 2, ZIndex = 2 })
		local relic = last and Config.MISSION_RELICS and Config.MISSION_RELICS[m.rank]
		if last then
			-- the last node gets wider lines (Play check: its words wrapped in four), the relic on its own
			cell.Size = UDim2.fromOffset(node + px(90), 0)
			cell.Position -= UDim2.fromOffset(px(10), 0)
			text(cell, words .. " + rank up", px(11), color, { LayoutOrder = 3, ZIndex = 2 })
			if relic then
				text(cell, "+ Relic: " .. relic, px(11), GOLD, { LayoutOrder = 4, ZIndex = 2 })
			end
		else
			text(cell, words, px(11), color, { LayoutOrder = 3, ZIndex = 2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromOffset(node + px(20), 0) })
		end
	end
	-- missions and dailies side by side
	local cols = frame(body, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 })
	Toy.list(cols, true, px(14), { VerticalAlignment = Enum.VerticalAlignment.Top, HorizontalAlignment = Enum.HorizontalAlignment.Left })
	local daily = Config.MISSION_DAILY_ON and #m.daily > 0
	local cw = daily and (w - px(32) - px(14)) / 2 or (w - px(32))
	local function column(order, head, list, isDaily)
		local col = frame(cols, { Size = UDim2.fromOffset(cw, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order })
		Toy.list(col, false, px(6), { HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top })
		text(col, head, px(15), isDaily and DAILY or MUTED, { LayoutOrder = 0 })
		for i, x in list do
			missionRow(col, x, cw, px(14), i, isDaily)
		end
		return col
	end
	column(1, "Missions", m.slots, false)
	if daily then
		local col = column(2, string.format("Daily · new in %s", clock(m.resetIn)), m.daily, true)
		local c = m.chestReward
		local words = string.format("All 3: chest with +%s qi and %d summons", short((player:GetAttribute("AwayRate") or 0) * (c.qiSec or 0)), c.summons or 0)
		text(col, m.chest and "Daily chest claimed" or words, px(13), m.chest and QI or GOLD, { LayoutOrder = 10, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromOffset(cw, 0) })
	end
	Sfx.play("click")
	place()
end

---------------------------------------------------------------------------- toasts
local onMission
local toastY = 0 -- under the HUD's "built" toast (y 0.3): the 5th build and its mission land together
-- full screens a toast waits for (Play check: the free summons chest opened under the mission toasts)
local WAIT_FOR = { "IdleChest", "RecruitReveal" }
local function busyScreen()
	for _, name in WAIT_FOR do
		local g = playerGui:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled and #g:GetChildren() > 0 then
			return true
		end
	end
	return false
end

local function toast(str, color, big)
	local waited = 0
	while busyScreen() and waited < 30 do
		task.wait(0.5)
		waited += 0.5
	end
	local S = computeScale()
	Toy.S = S
	local t = text(gui, str, px(big and 30 or 22), color or GOLD, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.38, toastY), TextTransparency = 1 })
	toastY += px(big and 40 or 30)
	local sc = Instance.new("UIScale")
	sc.Scale = 0.6
	sc.Parent = t
	tween(t, 0.2, { TextTransparency = 0 })
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(big and 3 or 2.2, function()
		tween(t, 0.4, { TextTransparency = 1, Position = t.Position - UDim2.fromOffset(0, px(20)) })
		local stroke = t:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, 0.4, { Transparency = 1 })
		end
		task.wait(0.45)
		t:Destroy()
		toastY = math.max(0, toastY - px(big and 40 or 30))
	end)
end

remotes:WaitForChild("Notify").OnClientEvent:Connect(function(kind, ...)
	if kind == "mission" then
		task.spawn(onMission, ...) -- its toasts may wait for a full screen to close
	end
end)
function onMission(finished, paid, chest)
	if hidden and #(finished or {}) > 0 then
		dotOn = true -- the hidden list's badge shows a red dot until it is opened again
		drawTracker()
	end
	for _, f in finished or {} do
		toast(string.format("+%d ★ · %s", f.stars, f.text), f.daily and DAILY or GOLD)
	end
	Sfx.play("buyChime")
	for _, r in paid or {} do
		local pieces = {}
		if (r.qi or 0) > 0 then
			table.insert(pieces, "+" .. short(r.qi) .. " qi")
		end
		if (r.summons or 0) > 0 then
			table.insert(pieces, string.format("%d summon%s", r.summons, r.summons > 1 and "s" or ""))
		end
		if (r.pill or 0) > 0 then
			table.insert(pieces, string.format("2x Qi %d min", r.pill // 60))
		end
		if r.rarity then
			table.insert(pieces, r.rarity)
		end
		if r.rankUp then
			toast("Rank up! " .. r.rankUp, GOLD, true)
			Sfx.play("gong")
		end
		toast("Reward: " .. table.concat(pieces, " · "), QI)
	end
	if chest then
		toast(string.format("Daily chest: +%s qi · %d summons", short(chest.qi), chest.summons or 0), DAILY, true)
	end
end

---------------------------------------------------------------------------- wiring
hidden = player:GetAttribute("MissionsHidden") == true
player:GetAttributeChangedSignal("MissionsHidden"):Connect(function()
	local v = player:GetAttribute("MissionsHidden") == true
	if v ~= hidden then
		hidden = v
		drawTracker()
	end
end)
player:GetAttributeChangedSignal("Missions"):Connect(function()
	drawTracker()
	if page then
		drawPage(true)
	end
end)
openEvent.Event:Connect(function()
	drawPage(true)
end)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	task.defer(drawTracker)
end)
task.spawn(function()
	local slots = player:WaitForChild("HudSlots", 30)
	local rebuilt = slots and slots:FindFirstChild("Rebuilt")
	if rebuilt then
		rebuilt.Event:Connect(function()
			task.defer(drawTracker)
		end)
	end
	drawTracker()
	-- the rail moves when the HUD lays itself out again: follow it
	while true do
		task.wait(1)
		place()
	end
end)
