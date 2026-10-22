-- Idle chest return screen (D39, owner pick A, docs/art/mocks/idle_A_phone.jpg): "Welcome back!",
-- the chest shakes and bursts open, the offline qi explodes out of it and flies into the qi
-- counter, then one summon ball per free summon pops out; tap a ball to open it (the server rolls,
-- RecruitFx plays the rarity's column and sounds). Collect opens whatever is left, then closes.
-- The server sends Notify("idleChest", qi, secondsAway, summonsWaiting) a few seconds after a join.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local ChestModel = require(Shared:WaitForChild("ChestModel"))

local px, text, frame = Toy.px, Toy.text, Toy.frame
local GOLD = Color3.fromHex("FFE36B")
local MINT = Color3.fromHex("9FF5C8")
local GO = Color3.fromHex("47D16C")
local BALL = Color3.fromHex("B06BFF")

local chestFn = remotes:WaitForChild("ChestSummon")

local function commas(n)
	local s = tostring(math.floor(n))
	return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
local function short(n)
	n = math.floor(n or 0)
	if n < 1e6 then
		return commas(n)
	end
	local units = { "M", "B", "T", "Qa", "Qi" }
	local v, i = n / 1e6, 1
	while v >= 1000 and i < #units do
		v /= 1000
		i += 1
	end
	local digits = v < 10 and 2 or (v < 100 and 1 or 0)
	local f = 10 ^ digits
	return string.format("%." .. digits .. "f%s", math.floor(v * f) / f, units[i])
end
local function awayText(sec)
	local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
	if h > 0 then
		return string.format("%d h %d min", h, m)
	end
	return string.format("%d min", math.max(1, m))
end

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
		return math.clamp(vp.Y / 390, 0.78, 1.1)
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

local gui = Instance.new("ScreenGui")
gui.Name = "IdleChest"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 6 -- over the HUD and the shop
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = playerGui

---------------------------------------------------------------------------------------------
-- drawings (Toy icon shapes: outlined, two-tone, same language as the HUD)
local ui = {}

-- the chest in 3D (ChestModel, the same model as on the peak) in a ViewportFrame, with gold rays
-- behind it that burst when the lid opens. Returns the holder (rotated for the rattle) and a
-- function that sets the lid angle in degrees.
local function drawChest(parent, size)
	local holder = frame(parent, { Size = UDim2.fromOffset(size, size) })
	-- rays behind the chest: a wide soft set and a thin bright set, hidden until the lid opens
	local rays = frame(
		holder,
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(1, 1),
			ZIndex = 1,
		}
	)
	local function raySet(count, width, length, core, offset)
		local set = frame(
			rays,
			{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1, 1) }
		)
		for i = 1, count do
			local bar = frame(set, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(width, length * (i % 2 == 0 and 0.75 or 1)),
				Rotation = offset + i * (180 / count),
				BackgroundTransparency = 0,
				BackgroundColor3 = Color3.new(1, 1, 1),
			})
			Toy.corner(bar, UDim.new(0.5, 0))
			local g = Instance.new("UIGradient")
			g.Rotation = 90
			g.Color = ColorSequence.new(GOLD, Color3.fromHex("FFF6D0"))
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, core),
				NumberSequenceKeypoint.new(1, 1),
			})
			g.Parent = bar
		end
		return set
	end
	local soft = raySet(8, px(40), px(300), 0.55, 0)
	local sharp = raySet(6, px(7), px(250), 0.1, 15)
	local raysScale = Instance.new("UIScale")
	raysScale.Scale = 0
	raysScale.Parent = rays
	ui.raySoft, ui.raySharp = soft, sharp -- turned every frame below
	-- the 3D chest
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.ZIndex = 2
	vp.Ambient = Color3.fromRGB(150, 140, 135)
	vp.LightColor = Color3.fromRGB(255, 240, 220)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.Parent = holder
	local _, lid, hinge = ChestModel.build(vp, CFrame.new())
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(5.2, 6.2, -10.5), Vector3.new(0, 2.1, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	ui.rays = raysScale
	return holder, function(deg)
		ChestModel.setLid(lid, hinge, deg)
	end
end

-- the qi counter's centre on screen (HUD), where the exploding qi flies to
local function counterCentre()
	local hud = playerGui:FindFirstChild("Hud")
	local c = hud and hud:FindFirstChild("Counter", true)
	if c and c.AbsoluteSize.X > 0 then
		-- Absolute* is measured from below the top bar even with IgnoreGuiInset: convert to this gui
		return c.AbsolutePosition - gui.AbsolutePosition + Vector2.new(px(24), c.AbsoluteSize.Y / 2)
	end
	return Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, px(30))
end

---------------------------------------------------------------------------------------------
local busy = false
local balls = {}

-- the chests' world labels would show through the veil behind the card: hide them while it is open
local function chestLabels(on)
	local sect = workspace:FindFirstChild("Sect")
	for _, d in sect and sect:GetDescendants() or {} do
		if d:IsA("BillboardGui") and d.Parent and d.Parent.Name == "IdleChest" then
			d.Enabled = on
		end
	end
end

local function close()
	if not gui.Enabled then
		return
	end
	chestLabels(true)
	tween(ui.scale, 0.2, { Scale = 0.8 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tween(ui.veil, 0.25, { BackgroundTransparency = 1 })
	task.delay(0.25, function()
		gui.Enabled = false
	end)
end

-- tap a ball: the server rolls; the ball shakes, bursts in the rarity's colour, the disciple shows
local function openBall(b)
	if b.state ~= "closed" then
		return
	end
	b.state = "opening"
	local ok, res = pcall(function()
		return chestFn:InvokeServer()
	end)
	if not ok or not res then
		b.state = "closed"
		return
	end
	local r = Config.rarity(res.rarity)
	for i = 1, 6 do
		b.holder.Rotation = (i % 2 == 0 and 1 or -1) * (14 - i * 2)
		task.wait(0.04)
	end
	b.holder.Rotation = 0
	-- burst: a ring in the rarity colour widens and fades, the ball becomes the disciple
	local ring = frame(ui.layer, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(px(20), px(20)),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = r.color,
		ZIndex = 9,
	})
	local at = b.holder.AbsolutePosition - gui.AbsolutePosition + b.holder.AbsoluteSize / 2
	ring.Position = UDim2.fromOffset(at.X, at.Y)
	Toy.corner(ring, UDim.new(1, 0))
	tween(ring, 0.45, { Size = UDim2.fromOffset(px(140), px(140)), BackgroundTransparency = 1 })
	task.delay(0.5, function()
		ring:Destroy()
	end)
	b.orb:Destroy()
	b.face.BackgroundColor3 = r.color
	b.face.BackgroundTransparency = 0
	Toy.disciple(b.face, math.floor(b.size * 0.8), res.rarity, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), ZIndex = 6 }, true)
	b.label.Text = res.rarity
	b.label.TextColor3 = r.color:Lerp(Color3.new(1, 1, 1), 0.35)
	local sc = b.holder:FindFirstChildOfClass("UIScale")
	sc.Scale = 1.35
	tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	local fx = playerGui:FindFirstChild("RecruitFx") -- Juice: the recruit sound and the column on the platform
	if fx then
		fx:Fire(res.rarity, res.kept)
	else
		Sfx.play("recruit")
	end
	b.state = "open"
end

local function build(away, summons, mode)
	for _, c in gui:GetChildren() do
		c:Destroy()
	end
	table.clear(balls)
	Toy.S = computeScale()
	ui.veil = frame(
		gui,
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BackgroundColor3 = Color3.fromHex("140E1E") }
	)
	ui.layer = frame(gui, { Size = UDim2.fromScale(1, 1), ZIndex = 5 }) -- flying qi and bursts
	local card = frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.XY,
	})
	ui.scale = Instance.new("UIScale")
	ui.scale.Scale = 0.6
	ui.scale.Parent = card
	Toy.list(card, false, px(6))
	-- "chest" = opened from its green pad (the starter chest): teach what it is
	text(card, mode == "chest" and "Your Idle Chest!" or "Welcome back!", px(28), GOLD, { LayoutOrder = 1 })
	text(
		card,
		mode == "chest" and string.format("It fills while you're away (up to %d h)", Config.OFFLINE_CAP / 3600)
			or "Your sect worked for " .. awayText(away),
		px(15),
		Color3.new(1, 1, 1),
		{ LayoutOrder = 2 }
	)
	local row = frame(card, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	Toy.list(row, true, px(18))
	local chest, setLid = drawChest(row, px(150))
	chest.LayoutOrder = 1
	ui.chest, ui.setLid = chest, setLid
	local right = frame(row, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	Toy.list(right, false, px(8), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
	local _, amount = Toy.amount(right, "qi", px(34), Color3.new(1, 1, 1), { LayoutOrder = 1 })
	amount.Text = "+0"
	ui.amount = amount
	text(
		right,
		summons > 0 and (summons == 1 and "1 free summon" or summons .. " free summons") or "Half speed while away",
		px(15),
		MINT,
		{ LayoutOrder = 2 }
	)
	local ballRow = frame(right, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	Toy.list(ballRow, true, px(10))
	for i = 1, summons do
		local size = px(56)
		local holder = frame(ballRow, { Size = UDim2.fromOffset(size, size + px(18)), LayoutOrder = i })
		local sc = Instance.new("UIScale")
		sc.Scale = 0
		sc.Parent = holder
		local face = Instance.new("TextButton")
		face.Text = ""
		face.AutoButtonColor = false
		face.Size = UDim2.fromOffset(size, size)
		face.BackgroundTransparency = 1
		face.Parent = holder
		Toy.corner(face, UDim.new(1, 0))
		-- the closed ball: a purple spirit orb with a shine and a gold swirl
		local orb = frame(
			face,
			{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = BALL, ZIndex = 4 }
		)
		Toy.corner(orb, UDim.new(1, 0))
		local st = Instance.new("UIStroke")
		st.Color = Toy.INK
		st.Thickness = px(3)
		st.Parent = orb
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(Color3.fromHex("E2C2FF"), BALL)
		g.Rotation = 60
		g.Parent = orb
		local swirl = frame(orb, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.5),
			ZIndex = 5,
		})
		local sw = Instance.new("UIStroke")
		sw.Color = GOLD
		sw.Thickness = px(3)
		sw.Parent = swirl
		Toy.corner(swirl, UDim.new(1, 0))
		local shine = frame(orb, {
			Size = UDim2.fromScale(0.3, 0.2),
			Position = UDim2.fromScale(0.22, 0.16),
			BackgroundTransparency = 0.4,
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 6,
		})
		Toy.corner(shine, UDim.new(1, 0))
		local label = text(
			holder,
			"Tap",
			px(13),
			Color3.new(1, 1, 1),
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, size + px(2)) }
		)
		local b = {
			holder = holder,
			face = face,
			orb = orb,
			swirl = swirl,
			label = label,
			size = size,
			state = "hidden",
			bob = i * 0.7,
		}
		face.Activated:Connect(function()
			task.spawn(openBall, b)
		end)
		table.insert(balls, b)
	end
	local hold, btn = Toy.button(card, UDim2.fromOffset(px(210), px(48)), GO, px(14))
	hold.LayoutOrder = 4
	text(
		btn,
		"Collect",
		px(22),
		Color3.new(1, 1, 1),
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 }
	)
	btn.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		for _, b in balls do -- whatever is still closed opens now, quickly
			if b.state == "closed" then
				openBall(b)
				task.wait(0.25)
			end
		end
		task.wait(#balls > 0 and 0.8 or 0)
		close()
		busy = false
	end)
end

-- the show: chest in, shake, burst, qi explodes and flies to the counter, balls pop out
local function play(gain, away, summons, mode)
	build(away, summons, mode)
	gui.Enabled = true
	chestLabels(false)
	tween(ui.veil, 0.3, { BackgroundTransparency = 0.45 })
	tween(ui.scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	Sfx.play("toast")
	task.wait(0.55)
	for i = 1, 8 do -- the chest rattles
		ui.chest.Rotation = (i % 2 == 0 and 1 or -1) * (3 + i)
		task.wait(0.05)
	end
	ui.chest.Rotation = 0
	-- the lid flies up and tips back
	Sfx.play("padSnap")
	Sfx.play("buyChime")
	-- the lid swings open on its hinge (Back easing: it overshoots and settles), the rays burst out
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.5 and ui.setLid do
			local k = (os.clock() - t0) / 0.5
			local back = 1 + 2.70158 * (k - 1) ^ 3 + 1.70158 * (k - 1) ^ 2 -- easeOutBack
			ui.setLid(110 * back)
			RunService.RenderStepped:Wait()
		end
		ui.setLid(110)
	end)
	tween(ui.rays, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local centre = ui.chest.AbsolutePosition - gui.AbsolutePosition + ui.chest.AbsoluteSize * Vector2.new(0.5, 0.5)
	-- the qi explodes: drops burst out in a ring, hang a beat, then stream into the counter
	local drops = math.clamp(6 + math.floor(math.log10(math.max(gain, 1)) * 2), 8, 18)
	local target = counterCentre()
	for i = 1, drops do
		local d = Toy.qiIcon(
			ui.layer,
			px(26),
			{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(centre.X, centre.Y), ZIndex = 7 }
		)
		local a = (i / drops) * math.pi * 2 + math.random() * 0.4
		local dist = px(70) + math.random() * px(70)
		local out = centre + Vector2.new(math.cos(a), math.sin(a) - 0.35) * dist
		tween(
			d,
			0.35,
			{ Position = UDim2.fromOffset(out.X, out.Y), Rotation = math.random(-60, 60) },
			Enum.EasingStyle.Quad
		)
		task.delay(0.45 + i * 0.05, function()
			tween(
				d,
				0.45,
				{ Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(px(12), px(12)) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			task.delay(0.45, function()
				d:Destroy()
				Sfx.play("orb", { volume = 0.35 })
			end)
		end)
	end
	-- the amount counts up while the drops fly
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 1.3 and ui.amount.Parent do
			local k = (os.clock() - t0) / 1.3
			ui.amount.Text = "+" .. short(gain * (1 - (1 - k) ^ 3))
			task.wait()
		end
		ui.amount.Text = "+" .. short(gain)
	end)
	task.wait(0.9)
	-- the summon balls pop out of the chest one by one
	for _, b in balls do
		b.state = "closed"
		local sc = b.holder:FindFirstChildOfClass("UIScale")
		tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		Sfx.play("padWake", { volume = 1.5 })
		task.wait(0.22)
	end
end

-- closed balls bob and their swirl turns
RunService.RenderStepped:Connect(function()
	if not gui.Enabled then
		return
	end
	local t = os.clock()
	if ui.raySoft then
		ui.raySoft.Rotation = (t * 18) % 360
		ui.raySharp.Rotation = -(t * 26) % 360
	end
	for _, b in balls do
		if b.state == "closed" then
			b.face.Position = UDim2.fromOffset(0, math.sin(t * 3 + b.bob) * px(3))
			b.swirl.Rotation = (t * 120 + b.bob * 50) % 360
		end
	end
end)

remotes:WaitForChild("Notify").OnClientEvent:Connect(function(kind, gain, away, summons, mode)
	if kind == "idleChest" and not gui.Enabled then
		while not player:GetAttribute("LaunchDone") do -- after the launch screen's tap (src/first/Launch)
			player:GetAttributeChangedSignal("LaunchDone"):Wait()
		end
		task.spawn(play, gain or 0, away or 0, math.clamp(summons or 0, 0, Config.CHEST_SUMMON_MAX), mode)
	end
end)
