-- Sect Missions (2026-10-25, copies Pet Simulator 99 ranks; mock /mnt/project-files/2026-10-25_missions):
-- the tracker beside the HUD's left rail (the rank bar, the active missions, today's next daily) and the
-- rank page (the reward path, every mission, the dailies). Everything comes from the server's "Missions"
-- attribute (Missions.luau, JSON); the server alone counts and pays (R9). A finished mission flies a gold
-- "+N ★" line, a paid reward or a rank up a bigger one (Notify "mission").
-- Config.MISSION_HUD: "list" = the tracker (picks A and B), "button" = a Missions button and the nearest
-- mission only (pick C). Config.MISSION_DAILY_ON: the daily row (B, C).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

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

-- the rank header: a gold badge with the number, the name, the stars to the next reward, the bar
local function rankHeader(parent, m, w, size, order)
	local head = Instance.new("TextButton")
	head.Text = ""
	head.AutoButtonColor = false
	head.BackgroundColor3 = PANEL
	head.BackgroundTransparency = 0.05
	head.Size = UDim2.fromOffset(w, 0)
	head.AutomaticSize = Enum.AutomaticSize.Y
	head.LayoutOrder = order or 0
	head.Parent = parent
	corner(head, UDim.new(0, px(12)))
	local st = Instance.new("UIStroke")
	st.Color = GOLD
	st.Thickness = px(3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = head
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(8)), UDim.new(0, px(8))
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(4)), UDim.new(0, px(6))
	pad.Parent = head
	Toy.list(head, false, px(3), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
	local line = frame(head, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 })
	Toy.list(line, true, px(6), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
	local badge = frame(line, { Size = UDim2.fromOffset(px(22), px(22)), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("F0B400"), LayoutOrder = 1 })
	corner(badge, UDim.new(1, 0))
	text(badge, tostring(m.rank), px(13), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	text(line, m.name, size + px(1), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	local nextR = m.path[m.paid + 1]
	local goal = nextR and nextR.at or m.stars
	text(line, string.format("★ %d/%d", m.stars, m.path[#m.path].at), size, GOLD, { LayoutOrder = 3 })
	local _, fill = bar(head, px(8), GOLD, 2)
	local prev = m.paid > 0 and m.path[m.paid].at or 0
	fill.Size = UDim2.fromScale(math.clamp((m.stars - prev) / math.max(1, goal - prev), 0, 1), 1)
	return head
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
local drawPage

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
		local x = rail.AbsolutePosition.X + rail.AbsoluteSize.X + px(10)
		local y = rail.AbsolutePosition.Y + px(4)
		tracker.Position = UDim2.fromOffset(x, y)
		tracker.Visible = rail.Visible and rail.Parent.Visible ~= false and page == nil -- hidden under a full screen (the HUD hides its rail)
	else
		tracker.Position = UDim2.fromOffset(px(110) * S, px(140))
	end
end

local function drawTracker()
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
	local w = phone and px(210) or px(250)
	local size = phone and px(12) or px(14)
	tracker = frame(gui, { Name = "Tracker", AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromOffset(w, 0) })
	Toy.list(tracker, false, px(5), { HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top })
	if Config.MISSION_HUD == "button" then
		-- pick C: the Missions button and only the nearest mission beside it
		local row = frame(tracker, { AutomaticSize = Enum.AutomaticSize.XY })
		Toy.list(row, true, px(8))
		local holder, btn = Toy.button(row, UDim2.fromOffset(px(44), px(44)), GOLD, px(22))
		holder.LayoutOrder = 1
		Toy.icon(btn, "goal", px(30), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		Toy.feel(btn)
		btn.Activated:Connect(function()
			drawPage(true)
		end)
		local best
		for _, x in m.slots do
			if not best or x.n / x.need > best.n / best.need then
				best = x
			end
		end
		if best then
			missionRow(row, best, w - px(52), size, 2)
		end
	else
		local head = rankHeader(tracker, m, w, size, 0)
		Toy.feel(head)
		head.Activated:Connect(function()
			drawPage(true)
		end)
		for i, x in m.slots do
			missionRow(tracker, x, w, size, i)
		end
		if Config.MISSION_DAILY_ON and #m.daily > 0 then
			local left, nextD = 0, nil
			for _, x in m.daily do
				if x.n < x.need then
					left += 1
					nextD = nextD or x
				end
			end
			local dh = panel(tracker, { Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 20 }, Color3.fromHex("1D2F4A"), 0.1)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(8)), UDim.new(0, px(8))
			pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(2)), UDim.new(0, px(2))
			pad.Parent = dh
			Toy.list(dh, true, px(6), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
			Toy.icon(dh, "chest", size + px(4), { LayoutOrder = 1 })
			text(dh, string.format("Daily %d/%d", #m.daily - left, #m.daily), size - px(1), DAILY, { LayoutOrder = 2 })
			text(dh, m.chest and "Chest claimed" or ("new in " .. clock(m.resetIn)), size - px(2), MUTED, { LayoutOrder = 3 })
			if nextD then
				missionRow(tracker, nextD, w, size, 21, true)
			end
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
	dim.Parent = gui
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
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(16)), UDim.new(0, px(16))
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(12)), UDim.new(0, px(14))
	pad.Parent = card
	Toy.list(card, false, px(10), { HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top })
	-- title
	local title = frame(card, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	Toy.list(title, true, px(10))
	local badge = frame(title, { Size = UDim2.fromOffset(px(32), px(32)), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("F0B400"), LayoutOrder = 1 })
	corner(badge, UDim.new(1, 0))
	text(badge, tostring(m.rank), px(18), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	text(title, m.name, px(24), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	local nextName = Config.missionRank(m.rank + 1)
	text(title, string.format("★ %d of %d to %s", m.stars, m.path[#m.path].at, nextName), px(15), MUTED, { LayoutOrder = 3 })
	-- close
	local xh, xb = Toy.button(card, UDim2.fromOffset(px(36), px(36)), Color3.fromHex("FF4D4D"), px(18))
	xh.Parent = dim -- on the card's corner, out of its list
	xh.AnchorPoint = Vector2.new(0.5, 0.5)
	local function sitClose()
		xh.Position = UDim2.fromOffset(card.AbsolutePosition.X + card.AbsoluteSize.X - px(4), card.AbsolutePosition.Y + px(4))
	end
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(sitClose)
	task.defer(sitClose)
	text(xb, "✕", px(20), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	Toy.feel(xb)
	xb.Activated:Connect(function()
		drawPage(false)
	end)
	-- the reward path: nodes along a gold line, ticked when paid, the next one ringed
	local pathH = px(phone and 96 or 112)
	local path = frame(card, { Size = UDim2.new(1, 0, 0, pathH), LayoutOrder = 2 })
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
			text(box, "✓", px(16), JADE, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0, 0), ZIndex = 4 })
		end
		local words, color = rewardWords(r)
		text(cell, "★" .. r.at, px(13), GOLD, { LayoutOrder = 2, ZIndex = 2 })
		text(cell, last and (words .. " + rank up") or words, px(11), color, { LayoutOrder = 3, ZIndex = 2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromOffset(node + px(20), 0) })
	end
	-- missions and dailies side by side
	local cols = frame(card, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 })
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
local toastY = 0
local function toast(str, color, big)
	local S = computeScale()
	Toy.S = S
	local t = text(gui, str, px(big and 30 or 22), color or GOLD, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.26, toastY), TextTransparency = 1 })
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

remotes:WaitForChild("Notify").OnClientEvent:Connect(function(kind, finished, paid, chest)
	if kind ~= "mission" then
		return
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
end)

---------------------------------------------------------------------------- wiring
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
