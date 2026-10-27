-- The Rankings screen (owner pick C 2026-10-23, mock docs/art/mocks/ranks_C.jpg): the hub wall's
-- three boards (Greatest Sects, Richest Qi, This Week) as tabs on the left, Global / your country /
-- Friends on top, the top RANK_READ in a scrolling list (head shots, the top 3 in gold, silver and
-- bronze) and your own row pinned at the bottom ("100+" past the list). "Go to the wall" is the old
-- Ranks chip teleport (TravelTo on the Player, Hud.client). The HUD's Ranks chip opens it (RanksOpen
-- on the Player). Lists come from the server on demand (Remotes.Rankings -> Ranks.fetch), kept here
-- RANK_CACHE s; nothing is asked while the screen is shut (R16).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local px, text, frame = Toy.px, Toy.text, Toy.frame
local INK = Toy.INK
local GOLD = Color3.fromHex("FFD34D")
local JADE = Color3.fromHex("3FD9A0")
local CREAM = Color3.fromHex("EFE6F5")
local PALE = Color3.fromHex("FFF1D6")
local MEDAL = { Color3.fromHex("FFD34D"), Color3.fromHex("E6ECF2"), Color3.fromHex("E0A060") }
local RANK_CACHE = 30 -- s a fetched list is reused before the server is asked again

-- the boards, in the wall's order (Config.RANKS[key].order)
local BOARDS = {}
for key, def in Config.RANKS do
	table.insert(BOARDS, { key = key, title = def.title, order = def.order })
end
table.sort(BOARDS, function(a, b)
	return a.order < b.order
end)
local SUB = { sects = "realms climbed", qi = "best qi/s", week = "hours played" }

-- country names for the tab (anything else shows its two-letter code)
local COUNTRY = {
	US = "USA",
	GB = "UK",
	FR = "France",
	ES = "Spain",
	DE = "Germany",
	IT = "Italy",
	PT = "Portugal",
	BR = "Brazil",
	MX = "Mexico",
	CA = "Canada",
	AU = "Australia",
	NL = "Netherlands",
	BE = "Belgium",
	CH = "Switzerland",
	PL = "Poland",
	RU = "Russia",
	UA = "Ukraine",
	TR = "Turkey",
	PH = "Philippines",
	ID = "Indonesia",
	MY = "Malaysia",
	TH = "Thailand",
	VN = "Vietnam",
	JP = "Japan",
	KR = "Korea",
	IN = "India",
	AR = "Argentina",
	CL = "Chile",
	CO = "Colombia",
	PE = "Peru",
	SE = "Sweden",
	NO = "Norway",
	DK = "Denmark",
	FI = "Finland",
	IE = "Ireland",
	NZ = "New Zealand",
	SA = "Saudi Arabia",
	AE = "UAE",
	EG = "Egypt",
	MA = "Morocco",
	DZ = "Algeria",
	ZA = "South Africa",
	RO = "Romania",
}

local gui = Instance.new("ScreenGui")
gui.Name = "Rankings"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 18 -- over the HUD, under the Intro (20)
gui.Parent = playerGui

local openEvent = Instance.new("BindableEvent")
openEvent.Name = "RanksOpen"
openEvent.Parent = player -- not PlayerGui: the first LoadCharacter (Main onJoin) empties it

local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice")
	local touch = if forced
		then forced == "phone"
		else (
			playerGui:FindFirstChild("TouchGui") ~= nil
			or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		)
	if touch then
		return math.clamp(vp.Y / 390, 0.72, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

-- 4.2T / 950
local function compact(n)
	n = math.floor(n or 0)
	if n < 1000 then
		return tostring(n)
	end
	local units = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td" }
	local v, i = n / 1000, 1
	while v >= 1000 and i < #units do
		v /= 1000
		i += 1
	end
	local digits = v < 10 and 1 or 0
	local f = 10 ^ digits
	return string.format("%." .. digits .. "f%s", math.floor(v * f) / f, units[i])
end

local function hours(sec)
	local h, m = sec // 3600, (sec % 3600) // 60
	return h > 0 and string.format("%dh %02dm", h, m) or string.format("%dm", m)
end

local function valueText(key, r)
	if key == "sects" then
		return string.format("%d realms · %d %s", r.value or 0, r.extra or 1, r.extra == 1 and "life" or "lives")
	elseif key == "qi" then
		return compact(r.value) .. " qi/s"
	end
	return hours(r.value or 0)
end

-- the time to Monday 00:00 UTC, when This Week starts over (Config.rankWeek)
local function resetText()
	local now = workspace:GetServerTimeNow()
	local left = math.max(0, (7 * (Config.rankWeek(now) + 1) - 3) * 86400 - now)
	local d, h = left // 86400, (left % 86400) // 3600
	return d > 0 and string.format("Resets in %dd %dh", d, h)
		or string.format("Resets in %dh %dm", h, (left % 3600) // 60)
end

local function widthOf(str, size)
	return TextService:GetTextSize(str, size, Enum.Font.FredokaOne, Vector2.new(4000, 4000)).X
end

local function plainText(parent, str, size, color, props)
	local t = text(parent, str, size, color, props)
	t.UIStroke.Enabled = false
	return t
end

local cache = {} -- [key .. "/" .. scope] = { at = os.clock(), data }
local open = false
local state = { key = BOARDS[1].key, scope = "global" }
local testShow -- Studio hook

local function show()
	if open then
		return
	end
	open = true
	gui:ClearAllChildren()
	Toy.S = computeScale()
	local W, LEFT, GAP = px(560), px(124), px(12)
	local RX = LEFT + GAP -- the list column's left edge
	local RW = W - RX

	local veil = Instance.new("TextButton") -- swallows taps on the world behind
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 1
	veil.Parent = gui
	tween(veil, 0.35, { BackgroundTransparency = 0.35 })

	local body = frame(
		gui,
		{
			Active = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, px(6)),
			Size = UDim2.fromOffset(W, px(326)),
			ZIndex = 2,
		}
	)
	local pop = Instance.new("UIScale")
	pop.Scale = 0.3
	pop.Parent = body
	tween(pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	local title =
		text(body, "Rankings", px(30), GOLD, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0) })
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new(Color3.fromHex("FFF4C2"), GOLD)
	tg.Rotation = 90
	tg.Parent = title

	-- left: one tab per board
	local tabs = {}
	for i, b in BOARDS do
		local holder, btn = Toy.button(body, UDim2.fromOffset(LEFT, px(46)), CREAM, px(14))
		holder.Position = UDim2.fromOffset(0, px(46) + (i - 1) * px(54))
		local col = frame(btn, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
		Toy.list(col, false, 0)
		plainText(col, b.title, px(15), INK, { LayoutOrder = 1, ZIndex = 3 })
		plainText(col, SUB[b.key] or "", px(11), Color3.fromHex("5A4E66"), { LayoutOrder = 2, ZIndex = 3 })
		tabs[b.key] = btn
	end

	-- top: Global / your country / Friends
	local scopes = {}
	local cc = player:GetAttribute("RankCountry")
	local scopeDefs =
		{ { "global", "Global" }, { "country", cc and (COUNTRY[cc] or cc) or "Country" }, { "friends", "Friends" } }
	local sx = RX
	for _, s in scopeDefs do
		local w = math.max(px(78), widthOf(s[2], px(14)) + px(26))
		local holder, btn = Toy.button(body, UDim2.fromOffset(w, px(28)), CREAM, px(12))
		holder.Position = UDim2.fromOffset(sx, px(46))
		local t = plainText(
			btn,
			s[2],
			px(14),
			INK,
			{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 }
		)
		scopes[s[1]] = { btn = btn, label = t }
		sx += w + px(6)
	end
	local info =
		text(body, "", px(13), PALE, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(W, px(51)) })

	-- the list
	local listBox = frame(
		body,
		{
			Position = UDim2.fromOffset(RX, px(84)),
			Size = UDim2.fromOffset(RW, px(196)),
			BackgroundTransparency = 0.18,
			BackgroundColor3 = INK,
			ClipsDescendants = true,
		}
	)
	Toy.corner(listBox, UDim.new(0, px(14)))
	local ls = Instance.new("UIStroke")
	ls.Color = INK
	ls.Thickness = px(3)
	ls.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ls.Parent = listBox
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.ScrollBarThickness = px(5)
	scroll.ScrollBarImageColor3 = PALE
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = listBox
	Toy.list(
		scroll,
		false,
		0,
		{ HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top }
	)
	local empty = text(
		listBox,
		"",
		px(16),
		PALE,
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 }
	)

	local RH = px(28)
	local function rowLine(parent, r, rank, key, colour, rh)
		local name = (r.userId == player.UserId) and "You" or r.name
		plainText(
			parent,
			rank,
			px(14),
			colour,
			{
				Position = UDim2.fromOffset(px(10), 0),
				Size = UDim2.fromOffset(px(40), rh),
				AutomaticSize = Enum.AutomaticSize.None,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
			}
		)
		local head = Instance.new("ImageLabel")
		head.BackgroundColor3 = Color3.fromHex("3A3044")
		head.Size = UDim2.fromOffset(rh - px(6), rh - px(6))
		head.Position = UDim2.fromOffset(px(50), px(3))
		head.Image = "rbxthumb://type=AvatarHeadShot&id=" .. r.userId .. "&w=48&h=48"
		head.ZIndex = 3
		head.Parent = parent
		Toy.corner(head, UDim.new(0.5, 0))
		local value = plainText(
			parent,
			valueText(key, r),
			px(14),
			JADE,
			{
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -px(12), 0, 0),
				Size = UDim2.fromOffset(0, rh),
				AutomaticSize = Enum.AutomaticSize.X,
				ZIndex = 3,
			}
		)
		local nameX = px(50) + rh
		plainText(parent, name, px(14), colour == JADE and Color3.new(1, 1, 1) or colour, {
			Position = UDim2.fromOffset(nameX, 0),
			Size = UDim2.new(1, -nameX - widthOf(value.Text, px(14)) - px(20), 0, rh),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
		})
		return value
	end

	-- your row, pinned
	local mePlate = frame(
		body,
		{
			Position = UDim2.fromOffset(RX, px(288)),
			Size = UDim2.fromOffset(RW, px(34)),
			BackgroundTransparency = 0,
			BackgroundColor3 = GOLD,
		}
	)
	Toy.corner(mePlate, UDim.new(0, px(12)))
	local ms = Instance.new("UIStroke")
	ms.Color = INK
	ms.Thickness = px(3)
	ms.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ms.Parent = mePlate
	local meRow = frame(mePlate, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })

	local goHolder, goBtn = Toy.button(body, UDim2.fromOffset(LEFT, px(34)), JADE, px(12))
	goHolder.Position = UDim2.fromOffset(0, px(288))
	Toy.teleportTag(goBtn, px(13))
	plainText(
		goBtn,
		"Go to the wall",
		px(14),
		INK,
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 }
	)

	local xHolder, xBtn = Toy.button(body, UDim2.fromOffset(px(38), px(38)), Color3.fromHex("FF7A6B"), px(12))
	xHolder.AnchorPoint = Vector2.new(1, 0)
	xHolder.Position = UDim2.new(1, 0, 0, -px(2))
	text(
		xBtn,
		"X",
		px(22),
		Color3.new(1, 1, 1),
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 }
	)

	local asked = 0 -- the latest request; an older answer is dropped
	local function draw(data)
		for _, c in scroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		meRow:ClearAllChildren()
		local key = state.key
		local rows = data and data.rows or {}
		for i, r in rows do
			local f = frame(
				scroll,
				{
					Size = UDim2.new(1, 0, 0, RH),
					LayoutOrder = i,
					BackgroundTransparency = r.userId == player.UserId and 0.75 or (i % 2 == 0 and 0.94 or 1),
					BackgroundColor3 = r.userId == player.UserId and GOLD or Color3.new(1, 1, 1),
				}
			)
			rowLine(f, r, tostring(r.rank or i), key, MEDAL[i] or JADE, RH)
		end
		if not data then
			empty.Text = "Loading..."
		elseif #rows == 0 then
			empty.Text = state.scope == "friends" and "No friends ranked yet" or "Nobody ranked yet"
		else
			empty.Text = ""
		end
		local me = data and data.me
		if me then
			local v = rowLine(meRow, me, me.rank and ("#" .. me.rank) or "100+", key, INK, px(34))
			v.TextColor3 = INK
		end
		scroll.CanvasPosition = Vector2.zero
	end

	local function refresh()
		for key, btn in tabs do
			btn.BackgroundColor3 = key == state.key and GOLD or CREAM
		end
		for scope, s in scopes do
			s.btn.BackgroundColor3 = scope == state.scope and JADE or CREAM
		end
		info.Text = state.key == "week" and resetText()
			or (state.scope == "friends" and "You and your friends" or "Top " .. Config.RANK_READ)
		local id = state.key .. "/" .. state.scope
		local c = cache[id]
		if c and os.clock() - c.at < RANK_CACHE then
			draw(c.data)
			return
		end
		draw(nil)
		asked += 1
		local mine = asked
		task.spawn(function()
			local ok, data = pcall(function()
				return remotes:WaitForChild("Rankings"):InvokeServer(state.key, state.scope)
			end)
			if not open or mine ~= asked then
				return
			end
			if ok and type(data) == "table" then
				cache[id] = { at = os.clock(), data = data }
				if data.country then
					player:SetAttribute("RankCountry", data.country)
					local s = scopes.country
					if s and s.label.Text == "Country" then
						s.label.Text = COUNTRY[data.country] or data.country
					end
				end
				draw(data)
			else
				empty.Text = "Rankings are busy, try again soon"
			end
		end)
	end

	for key, btn in tabs do
		btn.Activated:Connect(function()
			if state.key ~= key then
				state.key = key
				Sfx.play("click")
				refresh()
			end
		end)
	end
	for scope, s in scopes do
		s.btn.Activated:Connect(function()
			if state.scope ~= scope then
				state.scope = scope
				Sfx.play("click")
				refresh()
			end
		end)
	end

	local function close()
		if not open then
			return
		end
		open = false
		asked += 1
		tween(pop, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(veil, 0.3, { BackgroundTransparency = 1 })
		task.wait(0.32)
		if not open then
			gui:ClearAllChildren()
		end
	end
	xBtn.Activated:Connect(close)
	veil.Activated:Connect(close)
	goBtn.Activated:Connect(function()
		task.spawn(close)
		local ev = player:FindFirstChild("TravelTo")
		if ev then
			ev:Fire("ranks")
		end
	end)

	refresh()
	pcall(function()
		remotes.MenuOpened:FireServer("ranks") -- analytics Menu (DATA.md)
	end)
end
testShow = show

openEvent.Event:Connect(show)

-- Studio test hook: player attribute RanksShow = true opens the screen
if RunService:IsStudio() then
	player:GetAttributeChangedSignal("RanksShow"):Connect(function()
		if player:GetAttribute("RanksShow") and testShow then
			testShow()
		end
	end)
end
