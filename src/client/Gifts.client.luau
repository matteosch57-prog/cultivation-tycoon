-- The Free Gifts page (playtime gifts, D49; owner 2026-10-22: "way more explicit with the reward,
-- attractive, if you click on it it should open a juicy page with all timed rewards, and make them
-- interesting"; owner pick C, mock docs/art/mocks/timed_gift_C.jpg): the last gift (the Immortal)
-- as a big hero card on the left, its disciple turning in gold rays over a bar of today's play; the
-- other gifts in a list on the right, each with its time, its prize in words and colour, and a tick,
-- a Claim or its countdown. The HUD gift button opens it (GiftsOpen on the Player). Claim asks the
-- server (ClaimGift, R9: it alone checks the play time and pays); gifts are claimed in order, so a
-- gift whose time has passed behind an unclaimed one shows READY and gets its Claim right after.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local px, text, frame = Toy.px, Toy.text, Toy.frame
local GOLD = Color3.fromHex("FFD34D")
local MINT = Color3.fromHex("CFEEDD")
local CREAM = Color3.fromHex("F3ECFF")
local PALE_GOLD = Color3.fromHex("FFE9B0")
local MUTED = Color3.fromHex("E8E0F0")
local SUMMON = Color3.fromHex("D9B8FF")
local PILL = Color3.fromHex("FF9A8C")
local QI = Color3.fromHex("8FF0C8")
local INK = Toy.INK
local FONT = Enum.Font.FredokaOne

local gui = Instance.new("ScreenGui")
gui.Name = "Gifts"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 18 -- over the HUD, under the Intro (20)
gui.Parent = playerGui

local openEvent = Instance.new("BindableEvent")
openEvent.Name = "GiftsOpen"
openEvent.Parent = player -- not PlayerGui: the first LoadCharacter (Main onJoin) empties it, live joins spawn after this runs

local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice")
	local touch = if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
	if touch then
		return math.clamp(vp.Y / 390, 0.72, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

local function tween(obj, t, props, style, dir, reps, rev, delay)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, reps or 0, rev or false, delay or 0), props)
	tw:Play()
	return tw
end

-- 12.3K / 4.5M
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

-- 5 min / 2 hours / 1h30
local function atText(sec)
	if sec >= 3600 then
		return sec % 3600 == 0 and string.format("%d hour%s", sec // 3600, sec >= 7200 and "s" or "") or string.format("%dh%02d", sec // 3600, (sec % 3600) // 60)
	end
	return string.format("%d min", sec // 60)
end

-- a countdown: 4:12 / 1h19
local function clock(s)
	s = math.max(0, math.ceil(s))
	return s >= 3600 and string.format("%dh%02d", s // 3600, (s % 3600) // 60) or string.format("%d:%02d", s // 60, s % 60)
end

-- what gift i pays, as { text, colour } pieces (one per reward, never a sentence: owner, never cut text)
local function piecesOf(prize)
	local out = {}
	if prize.rarity then
		table.insert(out, { prize.rarity, Config.rarity(prize.rarity).color })
	end
	if prize.pill > 0 then
		table.insert(out, { "2x Qi " .. atText(prize.pill), PILL })
	end
	if prize.summons > 0 then
		table.insert(out, { "+" .. prize.summons .. " summon" .. (prize.summons > 1 and "s" or ""), SUMMON })
	end
	if prize.qiSec > 0 then
		table.insert(out, { "+" .. short((player:GetAttribute("AwayRate") or 0) * prize.qiSec) .. " qi", QI })
	end
	return out
end

-- the prize's picture: the disciple, the pill, a summon, else qi
local function prizeIcon(parent, prize, size, props)
	if prize.rarity then
		return Toy.disciple(parent, size, prize.rarity, props)
	elseif prize.pill > 0 then
		return Toy.icon(parent, "pill", size, props)
	elseif prize.summons > 0 then
		return Toy.icon(parent, "disciple", size, props)
	end
	return Toy.qiIcon(parent, size, props)
end

-- the real disciple (as Streak.client's): a copy of the one standing in this peak's Disciple Garden
-- (Shop.luau, ForSale_<key>) turned to the camera in a viewport, in its rarity aura; the atlas
-- figure if the garden has not streamed in
local function realDisciple(parent, size, rarity, props)
	local key = Config.shopKeyOf(rarity)
	local sect = workspace:FindFirstChild("Sect")
	local peak = sect and sect:FindFirstChild("Peak" .. tostring(player:GetAttribute("PlotIndex")))
	local garden = peak and peak:FindFirstChild("DiscipleGarden", true)
	local src = garden and key and garden:FindFirstChild("ForSale_" .. key, true)
	if not (src and src:IsA("Model")) then
		return Toy.disciple(parent, size, rarity, props)
	end
	local holder = frame(parent, { Size = UDim2.fromOffset(size, size) })
	for k, v in props or {} do
		holder[k] = v
	end
	Toy.aura(holder, Config.rarityIndex(rarity), size)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.ZIndex = 3
	vp.Ambient = Color3.fromRGB(170, 165, 175)
	vp.LightColor = Color3.fromRGB(255, 245, 230)
	vp.LightDirection = Vector3.new(-0.3, -1, 0.5)
	vp.Parent = holder
	local old = src.Archivable
	src.Archivable = true
	local copy = src:Clone()
	src.Archivable = old
	if not copy then
		holder:Destroy()
		return Toy.disciple(parent, size, rarity, props)
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	copy:PivotTo(CFrame.identity) -- the seat faces its LookVector: -Z here
	copy.Parent = vp
	local cf, ext = copy:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 28
	local focus = cf.Position + Vector3.new(0, ext.Y * 0.12, 0)
	cam.CFrame = CFrame.lookAt(focus + Vector3.new(0, ext.Y * 0.08, -ext.Y * 2.3), focus)
	cam.Parent = vp
	vp.CurrentCamera = cam
	return holder
end

-- a white disc with a jade tick (a claimed gift)
local function tick(parent, size, props)
	local check = frame(parent, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1) })
	for k, v in props or {} do
		check[k] = v
	end
	Toy.corner(check, UDim.new(0.5, 0))
	local cs = Instance.new("UIStroke")
	cs.Color = INK
	cs.Thickness = px(2)
	cs.Parent = check
	for _, b in { { -0.16, 0.08, 0.32, 45 }, { 0.08, -0.02, 0.6, -50 } } do
		frame(check, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + b[1], 0.5 + b[2]),
			Size = UDim2.new(b[3], 0, 0, px(4)),
			Rotation = b[4],
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromHex("2A9D6A"),
			ZIndex = check.ZIndex + 1,
		})
	end
	return check
end

-- where the ladder stands: n = the next gift (0 = all claimed today), played = seconds played today
local function ladder()
	local n = player:GetAttribute("GiftNext") or 0
	local last = Config.GIFT_TIMES[#Config.GIFT_TIMES]
	if n == 0 or not Config.GIFT_TIMES[n] then
		return 0, last
	end
	return n, player:GetAttribute("GiftPlay") or (Config.GIFT_TIMES[n] - (player:GetAttribute("GiftIn") or 0))
end

local open = false
local claimNow -- the open page's Claim (Studio test hook)

local function show()
	if open then
		return
	end
	open = true
	gui:ClearAllChildren()
	Toy.S = computeScale()
	local N = #Config.GIFT_TIMES

	local veil = Instance.new("TextButton") -- swallows taps on the world behind
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 1
	veil.Parent = gui
	tween(veil, 0.35, { BackgroundTransparency = 0.35 })

	local body = frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, px(6)), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 2 })
	local bl = Toy.list(body, true, px(16))
	bl.VerticalAlignment = Enum.VerticalAlignment.Top
	local pop = Instance.new("UIScale")
	pop.Scale = 0.3
	pop.Parent = body
	tween(pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	-- the hero card: the grand prize (the last gift)
	local grand = Config.giftPrize(N)
	local HW, HH = px(250), px(312)
	local hero = frame(body, { Size = UDim2.fromOffset(HW, HH), LayoutOrder = 1, BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true })
	Toy.corner(hero, UDim.new(0, px(16)))
	local hg = Instance.new("UIGradient")
	hg.Color = ColorSequence.new(Color3.fromHex("4A3414"), Color3.fromHex("1D1520"))
	hg.Rotation = 90
	hg.Parent = hero
	local hs = Instance.new("UIStroke")
	hs.Color = INK
	hs.Thickness = px(3)
	hs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hs.Parent = hero
	-- slow gold rays behind the disciple
	local rays = frame(hero, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, px(118)), Size = UDim2.fromOffset(1, 1) })
	for i = 1, 9 do
		local bar = frame(rays, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(px(34), px(340)),
			Rotation = i * 20,
			BackgroundTransparency = 0,
			BackgroundColor3 = PALE_GOLD,
		})
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = bar
	end
	tween(rays, 30, { Rotation = 360 }, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	local hc = frame(hero, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	local hl = Toy.list(hc, false, px(3))
	hl.VerticalAlignment = Enum.VerticalAlignment.Top
	local hp = Instance.new("UIPadding")
	hp.PaddingTop = UDim.new(0, px(10))
	hp.Parent = hc
	text(hc, "Play " .. atText(grand.at) .. " today", px(17), Color3.fromHex("FFE08A"), { LayoutOrder = 1 })
	local art = frame(hc, { Size = UDim2.fromOffset(px(150), px(150)), LayoutOrder = 2 })
	local artScale = Instance.new("UIScale")
	artScale.Parent = art
	tween(artScale, 1.1, { Scale = 1.05 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	if grand.rarity then
		realDisciple(art, px(150), grand.rarity, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	else
		prizeIcon(art, grand, px(120), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	end
	local gp = piecesOf(grand)
	local heroName = text(hc, gp[1][1], px(32), gp[1][2], { LayoutOrder = 3 })
	heroName.UIStroke.Thickness = px(4)
	if grand.rarity then
		text(hc, "+" .. math.floor(Config.rarity(grand.rarity).bonus * 100 + 0.5) .. "% qi disciple", px(16), Color3.new(1, 1, 1), { LayoutOrder = 4 })
	end
	for k = 2, #gp do
		text(hc, gp[k][1], px(16), gp[k][2], { LayoutOrder = 3 + k })
	end
	-- today's play towards the grand prize; it turns into the Claim when the gift is next and ready
	local barHolder = frame(hc, { Size = UDim2.fromOffset(HW - px(28), px(22)), LayoutOrder = 10 })
	local track = frame(barHolder, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("3A3044"), ClipsDescendants = true })
	Toy.corner(track, UDim.new(1, 0))
	local ts = Instance.new("UIStroke")
	ts.Color = INK
	ts.Thickness = px(2)
	ts.Parent = track
	local fill = frame(track, { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = GOLD })
	Toy.corner(fill, UDim.new(1, 0))
	local barText = text(track, "", px(14), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	local heroClaimHolder, heroClaim = Toy.button(hc, UDim2.fromOffset(HW - px(40), px(44)), GOLD, px(14))
	heroClaimHolder.LayoutOrder = 11
	heroClaimHolder.Visible = false
	text(heroClaim, "Claim", px(26), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	local heroCheck = tick(hero, px(30), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -px(22), 0, px(22)), Visible = false, ZIndex = 5 })

	-- the list: every other gift, one row each
	local col = frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	Toy.list(col, false, px(5))
	local title = text(col, "Free Gifts", px(30), GOLD, { LayoutOrder = 0 })
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new(Color3.fromHex("FFF4C2"), GOLD)
	tg.Rotation = 90
	tg.Parent = title
	-- every row as wide as the widest prize needs (owner: text never leaves its frame)
	local TIME_W, ICON, STATUS_W, RH = px(58), px(26), px(76), px(36)
	local textW = 0
	for i = 1, N - 1 do
		local w = 0
		for _, p in piecesOf(Config.giftPrize(i)) do
			w += TextService:GetTextSize(p[1], px(16), FONT, Vector2.new(4000, 4000)).X + px(8)
		end
		textW = math.max(textW, w)
	end
	local RW = px(10) + TIME_W + ICON + px(8) + textW + STATUS_W + px(10)
	local rows = {}
	for i = 1, N - 1 do
		local prize = Config.giftPrize(i)
		local holder = frame(col, { Size = UDim2.fromOffset(RW, RH + px(3)), LayoutOrder = i })
		local shadow = frame(holder, { Size = UDim2.fromOffset(RW, RH), Position = UDim2.fromOffset(0, px(3)), BackgroundTransparency = 0, BackgroundColor3 = INK })
		Toy.corner(shadow, UDim.new(0, px(10)))
		local row = frame(holder, { Size = UDim2.fromOffset(RW, RH), BackgroundTransparency = 0, BackgroundColor3 = CREAM })
		Toy.corner(row, UDim.new(0, px(10)))
		local rs = Instance.new("UIStroke")
		rs.Color = INK
		rs.Thickness = px(3)
		rs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rs.Parent = row
		local line = frame(row, { Size = UDim2.new(1, -STATUS_W, 1, 0) })
		local ll = Toy.list(line, true, px(6))
		ll.VerticalAlignment = Enum.VerticalAlignment.Center
		ll.HorizontalAlignment = Enum.HorizontalAlignment.Left
		local lp = Instance.new("UIPadding")
		lp.PaddingLeft = UDim.new(0, px(10))
		lp.Parent = line
		local t = text(line, atText(prize.at), px(14), INK, { LayoutOrder = 1, Size = UDim2.fromOffset(TIME_W, RH), AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Left })
		t.UIStroke.Enabled = false
		prizeIcon(line, prize, ICON, { LayoutOrder = 2, ZIndex = 3 })
		for k, p in piecesOf(prize) do
			text(line, p[1], px(16), p[2], { LayoutOrder = 2 + k })
		end
		-- the right end: a tick, a Claim, READY or the countdown
		local status = text(row, "", px(15), MUTED, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -px(10), 0.5, 0) })
		local claimHolder, claimBtn = Toy.button(row, UDim2.fromOffset(STATUS_W - px(8), RH - px(10)), GOLD, px(10))
		claimHolder.AnchorPoint = Vector2.new(1, 0.5)
		claimHolder.Position = UDim2.new(1, -px(5), 0.5, -px(2))
		claimHolder.Visible = false
		text(claimBtn, "Claim", px(17), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		local check = tick(row, px(24), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -px(14), 0.5, 0), Visible = false, ZIndex = 4 })
		local sc = Instance.new("UIScale")
		sc.Parent = row
		rows[i] = { row = row, status = status, claimHolder = claimHolder, claimBtn = claimBtn, check = check, scale = sc }
	end
	-- the reward line under the list: empty until a claim
	local note = text(col, "", px(17), GOLD, { LayoutOrder = N + 1, Visible = false })
	local noteScale = Instance.new("UIScale")
	noteScale.Parent = note

	local readyGlow -- the breathing of the gift that can be claimed now
	local function refresh()
		local n, played = ladder()
		local ready = n > 0 and (player:GetAttribute("GiftIn") or 0) == 0
		for i, r in rows do
			local claimed = n == 0 or i < n
			local now = ready and i == n
			r.row.BackgroundColor3 = claimed and MINT or now and GOLD or CREAM
			r.check.Visible = claimed
			r.claimHolder.Visible = now
			r.status.Visible = not claimed and not now
			if not claimed and not now then
				local left = Config.GIFT_TIMES[i] - played
				r.status.Text = left <= 0 and "READY" or clock(left)
				r.status.TextColor3 = left <= 0 and GOLD or MUTED
			end
		end
		local heroNow = ready and n == N
		heroClaimHolder.Visible = heroNow
		barHolder.Visible = not heroNow
		heroCheck.Visible = n == 0
		fill.Size = UDim2.fromScale(math.clamp(played / grand.at, 0, 1), 1)
		barText.Text = n == 0 and ("New gifts in " .. clock(player:GetAttribute("GiftResetIn") or 0)) or string.format("%d / %d min", played // 60, grand.at // 60)
		-- the claimable row breathes
		-- (the hero's disciple breathes already)
		local target = ready and rows[n] and rows[n].scale or nil
		if readyGlow and readyGlow.target ~= target then
			readyGlow.tw:Cancel()
			readyGlow = nil
		end
		if target and not readyGlow then
			readyGlow = { target = target, tw = tween(target, 0.75, { Scale = 1.04 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true) }
		end
	end
	refresh()
	Sfx.play("buyChime")

	local function close()
		tween(pop, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(veil, 0.3, { BackgroundTransparency = 1 })
		task.wait(0.32)
		gui:ClearAllChildren()
		open = false
	end

	local busy = false
	local function claim()
		local n = ladder()
		if busy or n == 0 or (player:GetAttribute("GiftIn") or 0) ~= 0 then
			return
		end
		busy = true
		local ok, res = pcall(function()
			return remotes.ClaimGift:InvokeServer()
		end)
		busy = false
		if not ok or type(res) ~= "table" then
			Sfx.play("deny")
			return
		end
		if readyGlow then
			readyGlow.tw:Cancel()
			readyGlow = nil
		end
		-- the juice: the shared reward burst on the Claim (Toy.reward, D61: squeeze, pop, gold motes,
		-- chime, buzz, the qi flies to the counter), the row punches up, flashes white and turns jade
		local btn = n == N and heroClaim or rows[n].claimBtn
		local hud = playerGui:FindFirstChild("Hud")
		Toy.reward(btn, { flyTo = (res.qi or 0) > 0 and hud and hud:FindFirstChild("Counter", true) or nil })
		local r = rows[n]
		if r then
			r.scale.Scale = 1
			local flash = frame(r.row, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6 })
			Toy.corner(flash, UDim.new(0, px(10)))
			tween(flash, 0.45, { BackgroundTransparency = 1 })
			Debris:AddItem(flash, 0.5)
			tween(r.scale, 0.12, { Scale = 1.12 }).Completed:Connect(function()
				tween(r.scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Elastic)
			end)
		end
		local parts = {}
		if (res.qi or 0) > 0 then
			table.insert(parts, "+" .. short(res.qi) .. " qi")
		end
		if (res.summons or 0) > 0 then
			table.insert(parts, "+" .. res.summons .. " free summon" .. (res.summons > 1 and "s" or ""))
		end
		if (res.pill or 0) > 0 then
			table.insert(parts, "2x Qi for " .. atText(res.pill))
		end
		if res.rarity then
			table.insert(parts, res.rarity .. " joins your sect!")
		end
		note.Text = table.concat(parts, "  ")
		note.Visible = true
		noteScale.Scale = 0.3
		tween(noteScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.15)
		task.delay(0.2, function()
			if open then
				refresh()
			end
		end)
	end
	for _, r in rows do
		r.claimBtn.Activated:Connect(claim)
	end
	heroClaim.Activated:Connect(claim)
	claimNow = claim

	local xHolder, xBtn = Toy.button(gui, UDim2.fromOffset(px(44), px(44)), Color3.fromHex("FF7A6B"), px(22))
	xHolder.AnchorPoint = Vector2.new(1, 0)
	xHolder.Position = UDim2.new(1, -px(16), 0, GuiService.TopbarInset.Max.Y + px(8))
	xHolder.ZIndex = 3
	text(xBtn, "X", px(24), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	local function shut()
		if not busy and open then
			close()
		end
	end
	xBtn.Activated:Connect(shut)
	veil.Activated:Connect(shut)

	-- the timers tick while the page is open
	task.spawn(function()
		while open and gui:IsAncestorOf(body) do
			task.wait(1)
			if open and gui:IsAncestorOf(body) then
				refresh()
			end
		end
	end)
end

openEvent.Event:Connect(show)

-- Studio test hooks: player attribute GiftsShow = true opens the page, GiftsClaim = true claims
if RunService:IsStudio() then
	player:GetAttributeChangedSignal("GiftsShow"):Connect(function()
		if player:GetAttribute("GiftsShow") then
			show()
		end
	end)
	player:GetAttributeChangedSignal("GiftsClaim"):Connect(function()
		if player:GetAttribute("GiftsClaim") and claimNow and open then
			claimNow()
		end
	end)
end
