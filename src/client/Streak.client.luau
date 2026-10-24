-- The Daily Blessing card (login streak, D58, owner pick A, mock docs/art/mocks/streak_A.jpg, "make
-- it more attractive"): seven tiles over a dark veil with slow gold rays behind the card; done days
-- are jade with a tick, today's tile lifts, glows and breathes, the disciple days show the disciple
-- in its rarity aura. Claim asks the server (ClaimStreak, R9: it alone checks the day and pays),
-- today's tile turns jade, the reward line pops, and the card closes. Shown once a day when
-- StreakReady, after the launch screen and the Heavenly Gift; on a brand-new save's first session
-- it waits FIRST_DELAY s so the gift and the first steps come first.
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
local JADE = Color3.fromHex("59D39F")
local CREAM = Color3.fromHex("F3ECFF")
local PALE_GOLD = Color3.fromHex("FFE9B0")
local INK = Toy.INK
local FIRST_DELAY = 90 -- s into a brand-new save's first session

local gui = Instance.new("ScreenGui")
gui.Name = "Streak"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 18 -- over the HUD, under the Intro (20)
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

local function tween(obj, t, props, style, dir, reps, rev, delay)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, reps or 0, rev or false, delay or 0), props)
	tw:Play()
	return tw
end

-- what day `i` pays: the step itself, or its `again` once its disciple was given
local function payOf(i, got)
	local step = Config.STREAK[i]
	if step.rarity and got[i] then
		return step.again
	end
	return step
end

-- 12.3K / 4.5M (the reward line)
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

local function minutes(sec)
	return sec >= 60 and string.format("%d min", sec // 60) or string.format("%d s", sec)
end

-- the lines a tile writes under its picture (one short line per reward)
local function linesOf(pay)
	local lines = {}
	if pay.rarity then
		table.insert(lines, pay.rarity)
	end
	if (pay.qiSec or 0) > 0 then
		table.insert(lines, minutes(pay.qiSec) .. " qi")
	end
	if (pay.summons or 0) > 0 then
		table.insert(lines, "+" .. pay.summons .. " summon" .. (pay.summons > 1 and "s" or ""))
	end
	return lines
end

-- the real disciple (owner: "day 2 and 7 should show actual skins"): a copy of the one standing in
-- this peak's Disciple Garden (Shop.luau, ForSale_<key>), turned to face the camera in a viewport;
-- the atlas figure if the garden has not streamed in
local function realDisciple(parent, size, rarity)
	local key = Config.shopKeyOf(rarity)
	local sect = workspace:FindFirstChild("Sect")
	local peak = sect and sect:FindFirstChild("Peak" .. tostring(player:GetAttribute("PlotIndex")))
	local garden = peak and peak:FindFirstChild("DiscipleGarden", true)
	local src = garden and key and garden:FindFirstChild("ForSale_" .. key, true)
	if not (src and src:IsA("Model")) then
		return Toy.disciple(parent, size, rarity, { LayoutOrder = 2 })
	end
	local holder = frame(parent, { Size = UDim2.fromOffset(size, size), LayoutOrder = 2 })
	Toy.aura(holder, Config.rarityIndex(rarity), size) -- the rarity's UI aura behind the figure
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
		return Toy.disciple(parent, size, rarity, { LayoutOrder = 2 })
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

-- the reward drawing and its lines inside a tile
local function rewardArt(parent, pay, size)
	if pay.rarity then
		realDisciple(parent, size, pay.rarity)
		local l = text(parent, pay.rarity, px(12), Config.rarity(pay.rarity).color, { LayoutOrder = 3 })
		l.UIStroke.Thickness = px(2)
		if (pay.summons or 0) > 0 then
			local m = text(parent, "+" .. pay.summons .. " summons", px(12), INK, { LayoutOrder = 4 })
			m.UIStroke.Enabled = false
		end
		return
	end
	local row = frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	Toy.list(row, true, px(2))
	if (pay.qiSec or 0) > 0 then
		Toy.qiIcon(row, math.floor(size * (pay.summons and 0.6 or 0.8)), { LayoutOrder = 1 })
	end
	if (pay.summons or 0) > 0 then
		Toy.icon(row, "disciple", math.floor(size * (pay.qiSec and 0.6 or 0.8)), { LayoutOrder = 2 })
	end
	-- one short line per reward (owner: never cut text), so a tile never has to squeeze a sentence
	local order = 3
	if (pay.qiSec or 0) > 0 then
		local l = text(parent, minutes(pay.qiSec) .. " qi", px(12), INK, { LayoutOrder = order })
		l.UIStroke.Enabled = false
		order += 1
	end
	if (pay.summons or 0) > 0 then
		local l = text(parent, "+" .. pay.summons .. " summon" .. (pay.summons > 1 and "s" or ""), px(12), INK, { LayoutOrder = order })
		order += 1
		l.UIStroke.Enabled = false
	end
end

local open = false
local claimNow -- the open card's Claim (Studio test hook)

local function show()
	if open then
		return
	end
	open = true
	gui:ClearAllChildren()
	Toy.S = computeScale()
	local day = player:GetAttribute("StreakDay") or 1
	local got = {}
	for _, k in string.split(player:GetAttribute("StreakGot") or "", ",") do
		if tonumber(k) then
			got[tonumber(k)] = true
		end
	end

	local veil = Instance.new("TextButton") -- swallows taps on the world behind
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 1
	veil.Parent = gui
	tween(veil, 0.35, { BackgroundTransparency = 0.35 })

	-- slow gold rays behind the card
	local rays = frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(1, 1), ZIndex = 1 })
	for i = 1, 10 do
		local bar = frame(rays, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(px(70), px(i % 2 == 0 and 620 or 760)),
			Rotation = i * 18,
			BackgroundTransparency = 0,
			BackgroundColor3 = PALE_GOLD,
		})
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.82), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = bar
	end
	tween(rays, 40, { Rotation = 360 }, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)

	local col = frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 2 })
	Toy.list(col, false, px(10))
	local pop = Instance.new("UIScale")
	pop.Scale = 0.3
	pop.Parent = col
	tween(pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	local title = text(col, "Daily Blessing", px(38), GOLD, { LayoutOrder = 1 })
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new(Color3.fromHex("FFF4C2"), GOLD)
	tg.Rotation = 90
	tg.Parent = title

	local row = frame(col, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	local rl = Toy.list(row, true, px(8))
	rl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	-- every tile as wide as the widest line needs (owner: text never leaves its frame) and as tall
	-- as the tallest stack
	local W, H = px(80), px(108)
	for i = 1, #Config.STREAK do
		local pay = payOf(i, got)
		for _, line in linesOf(pay) do
			local w = TextService:GetTextSize(line, px(12), Enum.Font.FredokaOne, Vector2.new(4000, 4000)).X
			W = math.max(W, w + px(16))
		end
		local h = px(15) + px(pay.rarity and 64 or 40) + #linesOf(pay) * px(14) + px(22)
		H = math.max(H, h)
	end
	local todayTile, todayCheck, todayScale, todayBreath
	for i = 1, #Config.STREAK do
		local done = i < day or (i == day and not player:GetAttribute("StreakReady"))
		local now = i == day and not done
		local big = Config.STREAK[i].rarity ~= nil and not got[i]
		local holder = frame(row, { Size = UDim2.fromOffset(W, H + px(10)), LayoutOrder = i })
		local tile = frame(holder, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, now and -px(10) or 0),
			Size = UDim2.fromOffset(W, H),
			BackgroundTransparency = 0,
			BackgroundColor3 = done and JADE or now and GOLD or big and PALE_GOLD or CREAM,
		})
		Toy.corner(tile, UDim.new(0, px(12)))
		local st = Instance.new("UIStroke")
		st.Color = now and Color3.new(1, 1, 1) or INK
		st.Thickness = px(now and 4 or 3)
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = tile
		local inner = frame(tile, { Size = UDim2.fromScale(1, 1) })
		local il = Toy.list(inner, false, px(2))
		il.VerticalAlignment = Enum.VerticalAlignment.Center
		text(inner, "Day " .. i, px(15), Color3.new(1, 1, 1), { LayoutOrder = 1 })
		local pay = payOf(i, got)
		rewardArt(inner, pay, px(pay.rarity and 64 or 40))
		local check = frame(tile, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -px(4), 0, px(4)),
			Size = UDim2.fromOffset(px(24), px(24)),
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Visible = done,
			ZIndex = 5,
		})
		Toy.corner(check, UDim.new(0.5, 0))
		local cs = Instance.new("UIStroke")
		cs.Color = INK
		cs.Thickness = px(2)
		cs.Parent = check
		-- the tick: a short and a long jade bar
		for _, b in { { -0.16, 0.08, 0.32, 45 }, { 0.08, -0.02, 0.6, -50 } } do
			frame(check, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5 + b[1], 0.5 + b[2]),
				Size = UDim2.new(b[3], 0, 0, px(4)),
				Rotation = b[4],
				BackgroundTransparency = 0,
				BackgroundColor3 = Color3.fromHex("2A9D6A"),
				ZIndex = 6,
			})
		end
		if now then
			todayTile, todayCheck = tile, check
			local glow = frame(holder, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -px(4)),
				Size = UDim2.fromOffset(W + px(18), H + px(18)),
				BackgroundTransparency = 0.55,
				BackgroundColor3 = GOLD,
				ZIndex = 0,
			})
			Toy.corner(glow, UDim.new(0, px(18)))
			tween(glow, 0.8, { BackgroundTransparency = 0.85, Size = UDim2.fromOffset(W + px(26), H + px(26)) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			todayScale = Instance.new("UIScale")
			todayScale.Parent = tile
			todayBreath = tween(todayScale, 0.8, { Scale = 1.05 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		end
	end

	-- the reward line: empty until the claim (owner: the old "your streak waits" line read as filler)
	local note = text(col, "", px(20), GOLD, { LayoutOrder = 3, Visible = false })
	note.UIStroke.Thickness = px(3)
	local noteScale = Instance.new("UIScale")
	noteScale.Parent = note

	local claimHolder, claimBtn = Toy.button(col, UDim2.fromOffset(px(230), px(58)), GOLD, px(16))
	claimHolder.LayoutOrder = 4
	local claimText = text(claimBtn, "Claim", px(30), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	-- the Claim breathes (no shine bar: owner, "there's a weird square")
	local breathe = Instance.new("UIScale")
	breathe.Parent = claimHolder
	local breathing = tween(breathe, 0.75, { Scale = 1.05 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	Sfx.play("buyChime")

	local function close()
		tween(pop, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(veil, 0.3, { BackgroundTransparency = 1 })
		task.wait(0.32)
		gui:ClearAllChildren()
		open = false
	end

	local busy, claimed = false, false
	local function claim()
		if busy then
			return
		end
		if claimed or not player:GetAttribute("StreakReady") then
			close()
			return
		end
		busy = true
		local ok, res = pcall(function()
			return remotes.ClaimStreak:InvokeServer()
		end)
		busy = false
		if not ok or not res then
			Sfx.play("deny")
			close()
			return
		end
		claimed = true
		breathing:Cancel()
		breathe.Scale = 1
		-- the juice (owner: "make the claim action juicy"): the shared reward burst on the button
		-- (Toy.reward, D61: squeeze, pop, gold motes, chime, buzz), today's tile punches up, flashes
		-- white and turns jade, the tick pops in, then the reward line bounces up under the row
		local hud = playerGui:FindFirstChild("Hud")
		if Toy.reward then
			Toy.reward(claimBtn, { flyTo = (res.qi or 0) > 0 and hud and hud:FindFirstChild("Counter", true) or nil })
		else
			Sfx.play("powerUp")
		end
		if todayTile then
			todayBreath:Cancel()
			local punch = todayScale
			local flash = frame(todayTile, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 4 })
			Toy.corner(flash, UDim.new(0, px(12)))
			tween(flash, 0.45, { BackgroundTransparency = 1 })
			Debris:AddItem(flash, 0.5)
			tween(punch, 0.12, { Scale = 1.28 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out).Completed:Connect(function()
				tween(punch, 0.4, { Scale = 1 }, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
			end)
			tween(todayTile, 0.25, { BackgroundColor3 = JADE })
			todayCheck.Visible = true
			local s = Instance.new("UIScale")
			s.Scale = 0.2
			s.Parent = todayCheck
			tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.15)
		end
		local parts = {}
		if (res.qi or 0) > 0 then
			table.insert(parts, "+" .. short(res.qi) .. " qi")
		end
		if (res.summons or 0) > 0 then
			table.insert(parts, "+" .. res.summons .. " free summon" .. (res.summons > 1 and "s" or ""))
		end
		if res.rarity then
			table.insert(parts, res.rarity .. " joins your sect!")
		end
		note.Text = table.concat(parts, "  ")
		note.Visible = true
		noteScale.Scale = 0.3
		tween(noteScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.2)
		claimText.Text = "See you tomorrow!"
		claimText.TextSize = px(22)
		claimBtn.BackgroundColor3 = JADE
	end
	claimBtn.Activated:Connect(claim)
	claimNow = claim
	local xHolder, xBtn = Toy.button(gui, UDim2.fromOffset(px(44), px(44)), Color3.fromHex("FF7A6B"), px(12))
	xHolder.AnchorPoint = Vector2.new(1, 0)
	xHolder.Position = UDim2.new(1, -px(16), 0, GuiService.TopbarInset.Max.Y + px(8))
	xHolder.ZIndex = 3
	text(xBtn, "X", px(24), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	xBtn.Activated:Connect(function()
		if not busy then
			close()
		end
	end)
end

-- the card never opens over another screen (owner 2026-10-23): it waits until each of these is gone.
-- A screen counts while its gui is Enabled and draws something (Gifts and Intro stay Enabled, emptied);
-- the Friends gui always holds its HUD row, so only its card counts
local COVERS = { "Shop", "WelcomeOffer", "StarterOffer", "Gifts", "Intro", "Breakthrough", "Reincarnation", "Disciples", "Index", "RecruitOdds", "IdleChest" }
local function covered()
	for _, name in COVERS do
		local g = playerGui:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled and #g:GetChildren() > 0 then
			return true
		end
	end
	local friends = playerGui:FindFirstChild("Friends")
	return friends ~= nil and friends:FindFirstChild("Card") ~= nil
end

-- once a day, after the launch screen and the gift (a new save waits FIRST_DELAY s)
-- (a new save: NewSave since the gift is paid on join, WelcomeQi while an intro was still shown)
local function newSave()
	return player:GetAttribute("NewSave") == true or (player:GetAttribute("WelcomeQi") or 0) > 0
end
local hadGift = newSave()
local shownToday = false
task.spawn(function()
	while true do
		task.wait(1)
		local ready = player:GetAttribute("StreakReady")
		if not ready then
			shownToday = false
		elseif not shownToday and not open and player:GetAttribute("LaunchDone") and (player:GetAttribute("WelcomeQi") or 0) == 0 then
			if newSave() then
				hadGift = true
			end
			if (not hadGift or time() > FIRST_DELAY) and not covered() then
				shownToday = true
				show()
			end
		end
	end
end)
player:GetAttributeChangedSignal("WelcomeQi"):Connect(function()
	if (player:GetAttribute("WelcomeQi") or 0) > 0 then
		hadGift = true
	end
end)

-- Studio test hooks: player attribute StreakOpen = true opens the card, StreakClaim = true claims
if RunService:IsStudio() then
	player:GetAttributeChangedSignal("StreakOpen"):Connect(function()
		if player:GetAttribute("StreakOpen") then
			show()
		end
	end)
	player:GetAttributeChangedSignal("StreakClaim"):Connect(function()
		if player:GetAttribute("StreakClaim") and claimNow and open then
			claimNow()
		end
	end)
end
