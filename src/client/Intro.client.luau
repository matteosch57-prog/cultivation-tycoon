-- The intro (D36, owner: "HEAVENLY GIFT with a nice shiny green GO button that bursts", then "make it
-- sexier, keep the coloring like the Qi color, make Qi explode from it and collect it slowly, sound
-- following it"): a brand-new save lands on a jade veil with a big qi drop turning in its rays, the
-- title, "+200 [qi]" and a jade GO. GO asks the server (ClaimWelcome, paid once per save, R9); the
-- drop bursts, qi drops explode across the screen, float, then fly one by one into the HUD's qi
-- counter, each with a ding that climbs in pitch. Shown only while the player attribute
-- WelcomeQi > 0. Owner 2026-10-23: the rays were cut by a straight line on top (they ran past the
-- screen's top edge), so the aura shrinks to fit the room above the drop; and "quick bouncy collect
-- is enough": the whole collect now takes under half the old 5.7 s.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Toy = require(Shared:WaitForChild("Toy"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local Haptic = require(Shared:WaitForChild("Haptic"))

local px, text, frame = Toy.px, Toy.text, Toy.frame
-- the qi drop's own colours (Toy Icon:qi)
local QI = Color3.fromHex("6FD6AE")
local QI_LIGHT = Color3.fromHex("9FF5C8")
local QI_PALE = Color3.fromHex("E8FFF4")
local VEIL = Color3.fromHex("0B1F1A")

local DROPS = 30 -- qi drops in the burst
local COLLECT_GAP = 0.03 -- s between two drops flying in (a quick, bouncy collect)
local COLLECT_FLY = 0.32 -- s for one drop's flight into the counter
local RAY_REACH = 200 -- longest ray's half length (px before Toy.S): the aura's top

local gui = Instance.new("ScreenGui")
gui.Name = "Intro"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None -- the whole screen: no inset strip cuts the rays
gui.ClipToDeviceSafeArea = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 20 -- over the HUD and the friends card
gui.Parent = playerGui

local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice") -- "phone" / "pc" forces a layout (testing)
	local touch = if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
	if touch then
		return math.clamp(vp.Y / 390, 0.78, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

local function tween(obj, t, props, style, dir, reps, rev, delay)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, reps or 0, rev or false, delay or 0), props)
	tw:Play()
	return tw
end

local function counterCentre()
	local hud = playerGui:FindFirstChild("Hud")
	local counter = hud and hud:FindFirstChild("Counter", true)
	if counter and counter.AbsoluteSize.X > 0 then
		return counter.AbsolutePosition + Vector2.new(px(24), counter.AbsoluteSize.Y / 2)
	end
	local vp = workspace.CurrentCamera.ViewportSize
	return Vector2.new(vp.X / 2, px(40))
end

local function disc(parent, size, color, transparency, z)
	local f = frame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = transparency,
		BackgroundColor3 = color,
		ZIndex = z or 1,
	})
	Toy.corner(f, UDim.new(0.5, 0))
	return f
end

local open = false
local goNow -- the open screen's GO (Studio test hook below)

local function show(amount)
	if open then
		return
	end
	open = true
	gui:ClearAllChildren()
	Toy.S = computeScale()

	local veil = frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BackgroundColor3 = VEIL, Active = true })
	tween(veil, 0.5, { BackgroundTransparency = 0.3 })

	local col = frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), AutomaticSize = Enum.AutomaticSize.XY })
	Toy.list(col, false, px(8))
	local pop = Instance.new("UIScale")
	pop.Scale = 0.2
	pop.Parent = col
	tween(pop, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)

	-- the big qi drop, turning rays and two soft halos behind it, breathing
	local stage = frame(col, { Size = UDim2.fromOffset(px(150), px(150)), LayoutOrder = 1 })
	-- premium rays (owner "make rays premium"): every ray fades out toward its tips and is brightest
	-- at the drop; a wide soft set turns slowly one way, a thin bright set faster the other way, and
	-- sparkles twinkle on a ring around them
	local function fade(f, core)
		local g = Instance.new("UIGradient")
		g.Rotation = 90 -- along the bar's length
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, QI), ColorSequenceKeypoint.new(0.5, QI_PALE), ColorSequenceKeypoint.new(1, QI) })
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, core),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
	end
	-- the rays and sparkles share one holder, shrunk after layout so the aura never runs off the top
	local aura = frame(stage, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1, 1) })
	local auraFit = Instance.new("UIScale")
	auraFit.Parent = aura
	local function raySet(count, width, length, core, offset)
		local set = frame(aura, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1, 1) })
		for i = 1, count do -- each bar crosses the centre: two rays (a GuiObject turns about its own centre)
			local bar = frame(set, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(width, length * (i % 2 == 0 and 0.78 or 1)),
				Rotation = offset + i * (180 / count),
				BackgroundTransparency = 0,
				BackgroundColor3 = Color3.new(1, 1, 1),
			})
			Toy.corner(bar, UDim.new(0.5, 0))
			fade(bar, core)
		end
		return set
	end
	local soft = raySet(8, px(46), px(RAY_REACH * 2), 0.55, 0)
	local sharp = raySet(6, px(8), px(330), 0.1, 15)
	tween(soft, 24, { Rotation = 360 }, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	tween(sharp, 16, { Rotation = -360 }, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local r = px(i % 2 == 0 and 112 or 136)
		local s = px(i % 3 == 0 and 12 or 8)
		local sp = frame(aura, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(a) * r, 0.5, math.sin(a) * r),
			Size = UDim2.fromOffset(s, s),
			Rotation = 45,
			BackgroundTransparency = 1,
			BackgroundColor3 = QI_PALE,
			ZIndex = 2,
		})
		tween(sp, 0.7 + (i % 4) * 0.15, { BackgroundTransparency = 0.05, Size = UDim2.fromOffset(s * 1.6, s * 1.6) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, (i % 5) * 0.2)
	end
	local halo1 = disc(stage, px(170), QI, 0.75, 2)
	local halo2 = disc(stage, px(120), QI_LIGHT, 0.6, 2)
	tween(halo1, 1.2, { Size = UDim2.fromOffset(px(196), px(196)), BackgroundTransparency = 0.88 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	tween(halo2, 0.9, { Size = UDim2.fromOffset(px(136), px(136)) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local drop = frame(stage, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(px(110), px(110)), ZIndex = 3 })
	Toy.qiIcon(drop, px(110))
	for _, d in drop:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += 3
		end
	end
	local dropScale = Instance.new("UIScale")
	dropScale.Parent = drop
	tween(dropScale, 0.8, { Scale = 1.08 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	-- fit the aura once laid out: the drop's centre at full size (the pop scales col about its centre)
	task.defer(function()
		RunService.Heartbeat:Wait()
		if not stage.Parent or pop.Scale <= 0 then
			return
		end
		local cc = col.AbsolutePosition.Y + col.AbsoluteSize.Y / 2
		local sc = stage.AbsolutePosition.Y + stage.AbsoluteSize.Y / 2
		local cy = cc + (sc - cc) / pop.Scale + gui.AbsolutePosition.Y
		auraFit.Scale = math.clamp((cy - px(8)) / px(RAY_REACH), 0.45, 1)
	end)

	local title = text(col, "HEAVENLY GIFT", px(52), QI_PALE, { LayoutOrder = 2 })
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, QI_PALE), ColorSequenceKeypoint.new(1, QI_LIGHT) })
	grad.Rotation = 90
	grad.Parent = title

	local row = frame(col, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	Toy.list(row, true, px(6))
	text(row, "+" .. amount, px(36), QI_LIGHT, { LayoutOrder = 1 })
	Toy.qiIcon(row, px(36), { LayoutOrder = 2 })

	frame(col, { Size = UDim2.fromOffset(1, px(6)), LayoutOrder = 4 })

	-- GO in the qi jade: breathing, a shine sweeping across it
	local goHolder, goBtn = Toy.button(col, UDim2.fromOffset(px(200), px(74)), QI, px(20))
	goHolder.LayoutOrder = 5
	goBtn.ClipsDescendants = true
	text(goBtn, "GO!", px(46), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	-- the shine keeps to the middle band: clipping is square, the corners are round
	local sweep = frame(goBtn, { Size = UDim2.new(0, px(26), 0.6, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.2, 0.5), BackgroundTransparency = 0.45, BackgroundColor3 = QI_PALE, ZIndex = 2 })
	tween(sweep, 1.3, { Position = UDim2.fromScale(1.2, 0.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 0.5)
	local breathe = Instance.new("UIScale")
	breathe.Parent = goBtn
	tween(breathe, 0.7, { Scale = 1.07 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	Sfx.play("buyChime")

	local busy = false
	local function go()
		if busy then
			return
		end
		busy = true
		local ok, gain = pcall(function()
			return remotes.ClaimWelcome:InvokeServer()
		end)
		if not ok then
			busy = false
			Sfx.play("deny")
			return
		end
		if not gain then
			print("[Tycoon] welcome gift already claimed")
		end
		Sfx.play("powerUp")
		Sfx.play("gather")
		local from = drop.AbsolutePosition + drop.AbsoluteSize / 2
		local target = counterCentre()
		local vp = workspace.CurrentCamera.ViewportSize
		-- the drop swells and bursts; the screen around it goes
		tween(dropScale, 0.12, { Scale = 1.4 })
		task.delay(0.1, function()
			tween(pop, 0.22, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		end)
		local flash = disc(gui, px(60), QI_PALE, 0.1, 5)
		flash.Position = UDim2.fromOffset(from.X, from.Y)
		flash.AnchorPoint = Vector2.new(0.5, 0.5)
		tween(flash, 0.35, { Size = UDim2.fromOffset(px(420), px(420)), BackgroundTransparency = 1 })
		-- qi explodes out across the screen, then floats
		local drops = {}
		local rng = Random.new()
		for i = 1, DROPS do
			local size = px(rng:NextInteger(22, 40))
			local d = frame(gui, { Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(from.X, from.Y), ZIndex = 6 })
			Toy.qiIcon(d, size)
			for _, g in d:GetDescendants() do
				if g:IsA("GuiObject") then
					g.ZIndex += 6
				end
			end
			local a = (i / DROPS) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local r = px(rng:NextNumber(110, 300))
			-- wide and mostly downward: the drop sits high, so upward ones would pile on the top edge
			local dy = math.sin(a) * r * (math.sin(a) < 0 and 0.45 or 1.1)
			local out = from + Vector2.new(math.cos(a) * r * 1.6, dy)
			if out.Y < px(110) then
				out = Vector2.new(out.X, px(110) + rng:NextNumber(0, px(140))) -- scatter, never a row on the edge
			end
			out = Vector2.new(math.clamp(out.X, px(40), vp.X - px(40)), math.min(out.Y, vp.Y - px(60)))
			tween(d, rng:NextNumber(0.3, 0.42), { Position = UDim2.fromOffset(out.X, out.Y), Rotation = rng:NextNumber(-25, 25) }, Enum.EasingStyle.Back)
			table.insert(drops, { d = d, at = out })
		end
		tween(veil, 0.6, { BackgroundTransparency = 0.6 }, nil, nil, nil, nil, 0.1)
		-- the counter bounces as the drops land (the HUD's own Bump scale: one UIScale per object counts)
		local hud = playerGui:FindFirstChild("Hud")
		local counter = hud and hud:FindFirstChild("Counter", true)
		local bump = counter and counter:FindFirstChild("Bump")
		if counter and not bump and not counter:FindFirstChildOfClass("UIScale") then
			bump = Instance.new("UIScale")
			bump.Name = "Bump"
			bump.Parent = counter
		end
		local function bounce(peak)
			if bump and bump.Parent then
				bump.Scale = peak
				tween(bump, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
		-- the quick collect: nearest to the counter first, a fast stream with a climbing ding
		table.sort(drops, function(x, y)
			return (x.at - target).Magnitude < (y.at - target).Magnitude
		end)
		task.delay(0.5, function()
			for k, it in drops do
				-- a little hop up first, then a dive into the counter: bouncy, not floaty
				local hop = tween(it.d, 0.1, { Position = UDim2.fromOffset(it.at.X, it.at.Y - px(14)), Rotation = 0 }, Enum.EasingStyle.Quad)
				hop.Completed:Once(function()
					local fly = tween(it.d, COLLECT_FLY, { Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(px(14), px(14)) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
					fly.Completed:Once(function()
						it.d:Destroy()
						if k % 2 == 1 or k == #drops then
							Sfx.play("orb", { volume = 0.35, pitch = 0.85 + 0.75 * k / #drops })
							bounce(1.12)
						end
					end)
				end)
				task.wait(COLLECT_GAP)
			end
			task.wait(0.1 + COLLECT_FLY)
			Sfx.play("buy")
			Haptic.play("reward")
			bounce(1.3)
			tween(veil, 0.3, { BackgroundTransparency = 1 })
			task.wait(0.32)
			gui:ClearAllChildren()
			open = false
		end)
	end
	goBtn.Activated:Connect(go)
	goNow = go

	-- a small X (owner 2026-10-23): a way out when GO keeps failing. The gift is not claimed, so the
	-- server offers it again next session; WelcomeQi is zeroed locally only, so the Daily Blessing,
	-- the offers and the tips stop waiting for the intro this session
	local xHolder, xBtn = Toy.button(gui, UDim2.fromOffset(px(44), px(44)), Color3.fromHex("FF7A6B"), px(22))
	xHolder.AnchorPoint = Vector2.new(1, 0)
	xHolder.Position = UDim2.new(1, -px(16), 0, GuiService.TopbarInset.Max.Y + px(8))
	xHolder.ZIndex = 3
	text(xBtn, "X", px(24), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	xBtn.Activated:Connect(function()
		if busy or not open then
			return
		end
		busy = true
		tween(veil, 0.3, { BackgroundTransparency = 1 })
		task.wait(0.3)
		gui:ClearAllChildren()
		open = false
		player:SetAttribute("WelcomeQi", 0)
	end)
end

-- no launch screen (ReplicatedFirst.Launch missing, e.g. a Rojo still serving an older project tree,
-- or it failed before drawing): nothing would ever set LaunchDone, and the gift, the return screen
-- and the tips would wait forever. Launch draws before any StarterPlayerScripts run, so its absence
-- a few seconds in means it is not coming.
task.delay(5, function()
	if not player:GetAttribute("LaunchDone") and not playerGui:FindFirstChild("Launch") then
		warn("[Tycoon] no launch screen (restart Rojo if ReplicatedFirst.Launch is missing): skipping it")
		player:SetAttribute("LaunchDone", true)
	end
end)

local function check()
	while not player:GetAttribute("LaunchDone") do -- the gift is the launch screen's reward (src/first/Launch)
		player:GetAttributeChangedSignal("LaunchDone"):Wait()
	end
	local amount = player:GetAttribute("WelcomeQi") or 0
	if amount > 0 then
		show(amount)
	end
end
player:GetAttributeChangedSignal("WelcomeQi"):Connect(check)
task.spawn(check)
-- Studio test hook: player attribute IntroGo = true presses GO (no mouse input in tests)
if game:GetService("RunService"):IsStudio() then
	player:GetAttributeChangedSignal("IntroGo"):Connect(function()
		if player:GetAttribute("IntroGo") and goNow and open then
			goNow()
		end
	end)
end
