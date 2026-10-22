-- The recruit reveal (mock docs/art/mocks/recruit_b.gif, owner pick 2026-10-21: "B with nice sound
-- and auras"). A qi orb flies out of the HUD's Recruit button, charges up through the rarity colours
-- (one step per rarity above Outer Disciple, shaking harder each step), bursts, and the disciple
-- stands in an aura that grows with its rarity: a glow for all, rays from Core, a second ray ring
-- from Elder, sparkles from Immortal, every colour for Primordial. A tap skips ahead. Timing:
-- Config.REVEAL (Juice lights the platform at the burst). Sounds are the game's own Sfx set.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local Toy = require(Shared:WaitForChild("Toy"))
local PerfMark = require(Shared:WaitForChild("PerfMark"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local INK = Toy.INK
local PINK = Color3.fromHex("FFB3A8")
local WHITE = Color3.new(1, 1, 1)
local R = Config.REVEAL

local gui = Instance.new("ScreenGui")
gui.Name = "RecruitReveal"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = playerGui

local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice")
	local touch = if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
	if touch then
		return math.clamp(vp.Y / 390, 0.78, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

local function circle(parent, size, color, props)
	local f = Toy.frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 0, BackgroundColor3 = color })
	for k, v in props or {} do
		f[k] = v
	end
	Toy.corner(f, UDim.new(0.5, 0))
	return f
end

-- where the orb starts: the centre of the HUD's Recruit button (bottom right when it is not found)
local function recruitPoint()
	local hud = playerGui:FindFirstChild("Hud")
	local seal = hud and hud:FindFirstChild("RecruitSeal", true)
	if seal then
		return seal.AbsolutePosition + seal.AbsoluteSize / 2
	end
	if hud then
		for _, d in hud:GetDescendants() do
			if d:IsA("TextLabel") and d.Text == "Recruit" then
				local b = d:FindFirstAncestorOfClass("TextButton") or d
				return b.AbsolutePosition + b.AbsoluteSize / 2
			end
		end
	end
	local vp = workspace.CurrentCamera.ViewportSize
	return Vector2.new(vp.X - 120, vp.Y - 60)
end

local function easeOut(x)
	return 1 - (1 - x) ^ 3
end
local function back(x) -- overshoot then settle
	local c = 1.7
	return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2
end
local function seg(t, a, b)
	return math.clamp((t - a) / (b - a), 0, 1)
end

local run -- the reveal in progress
local conn

local function finish()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	run = nil
	gui:ClearAllChildren()
	gui.Enabled = false
end

-- a ray: a container spun around the centre, its top half a fading beam
local function rays(parent, n, len, width, color, transparency)
	local ring = Toy.frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(len * 2, len * 2) })
	for i = 1, n do
		local holder = Toy.frame(ring, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, len * 2), Rotation = (i - 1) * 360 / n })
		local beam = Toy.frame(holder, { Size = UDim2.fromScale(1, 0.5), BackgroundTransparency = 0, BackgroundColor3 = color })
		Toy.corner(beam, UDim.new(0.5, 0))
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.75, transparency), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = beam
	end
	return ring
end

-- a four-point sparkle
local function sparkle(parent, size)
	local s = Toy.frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size) })
	for _, rot in { 0, 90 } do
		local bar = Toy.frame(s, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.22, 1), Rotation = rot, BackgroundTransparency = 0, BackgroundColor3 = WHITE })
		Toy.corner(bar, UDim.new(0.5, 0))
	end
	return s
end

local function start(rarityName, kept)
	finish()
	Toy.S = computeScale()
	local px = Toy.px
	local idx = Config.rarityIndex(rarityName)
	local rarity = Config.rarity(rarityName)
	local steps = idx - 1
	local burstAt = Config.revealBurst(rarityName)
	local holdEnd = burstAt + 0.35 + R.hold + R.holdPer * steps
	local endAt = holdEnd + 0.3
	local vp = workspace.CurrentCamera.ViewportSize
	local centre = Vector2.new(vp.X / 2, vp.Y * 0.46)
	local from = recruitPoint()

	gui.Enabled = true
	local veil = Instance.new("TextButton")
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Parent = gui

	-- the orb: a coloured ball with a glassy highlight, motes circling it while it charges
	local orbSize = px(84)
	local orb = circle(gui, orbSize, Config.RARITIES[1].color, { ZIndex = 5 })
	local ost = Instance.new("UIStroke")
	ost.Color = INK
	ost.Thickness = px(4)
	ost.Parent = orb
	local hi = circle(orb, orbSize * 0.36, WHITE, { Position = UDim2.fromScale(0.36, 0.32), BackgroundTransparency = 0.15, ZIndex = 6 })
	circle(orb, orbSize * 0.62, WHITE, { Position = UDim2.fromScale(0.42, 0.4), BackgroundTransparency = 0.75, ZIndex = 6 })
	local motes = {}
	for i = 1, 6 do
		motes[i] = circle(gui, px(9), Config.RARITIES[1].color, { ZIndex = 4, Visible = false })
	end

	-- the burst: a white ring and flying drops in the rarity colour
	local ring = circle(gui, px(120), WHITE, { BackgroundTransparency = 1, Visible = false, ZIndex = 7 })
	local rst = Instance.new("UIStroke")
	rst.Color = WHITE
	rst.Thickness = px(10)
	rst.Parent = ring
	local bits = {}
	for i = 1, 12 do
		local b = circle(gui, px(13), rarity.color, { Visible = false, ZIndex = 7 })
		local bs = Instance.new("UIStroke")
		bs.Color = INK
		bs.Thickness = px(3)
		bs.Parent = b
		bits[i] = b
	end

	-- the aura (behind the card) and the card
	local aura = Toy.frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(px(400), px(400)), Visible = false, ZIndex = 2 })
	local glows = {}
	for i, k in { 3.1, 2.3, 1.6 } do
		glows[i] = circle(aura, px(120) * k, rarity.color, { Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0.6 + i * 0.1 })
	end
	local rayA = idx >= 3 and rays(aura, 12, px(200), px(30), rarity.color, 0.35) or nil
	local rayB = idx >= 4 and rays(aura, 8, px(160), px(18), WHITE, 0.55) or nil
	local sparks = {}
	if idx >= 5 then
		for i = 1, 8 do
			sparks[i] = sparkle(aura, px(16))
		end
	end

	-- (a CanvasGroup so the whole card fades as one at the end)
	local card = Instance.new("CanvasGroup")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.AutomaticSize = Enum.AutomaticSize.XY
	card.Size = UDim2.new()
	card.BackgroundTransparency = 1
	card.Visible = false
	card.ZIndex = 8
	card.Parent = gui
	local cpad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		cpad[side] = UDim.new(0, px(8))
	end
	cpad.Parent = card
	Toy.list(card, false, px(2))
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	Toy.disciple(card, px(118), rarityName, { LayoutOrder = 1 }, true) -- the reveal draws its own aura
	local nameLabel = Toy.text(card, rarityName .. "!", px(42), rarity.color, { LayoutOrder = 2 })
	local bonusRow = Toy.frame(card, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	Toy.list(bonusRow, true, px(5))
	Toy.text(bonusRow, string.format("+%d%%", math.floor(rarity.bonus * 100 + 0.5)), px(24), WHITE, { LayoutOrder = 1 })
	Toy.icon(bonusRow, "qi", px(26), { LayoutOrder = 2 })
	if not kept then
		Toy.text(card, "Sect full", px(18), PINK, { LayoutOrder = 4 })
	end

	local t0 = os.clock()
	local state = { burst = false }
	run = state
	Sfx.play("gather", { volume = 1.4 })

	-- a tap skips ahead: to the burst while charging, then to the end
	veil.Activated:Connect(function()
		if run ~= state then
			return
		end
		local t = os.clock() - t0
		if t < burstAt - 0.05 then
			t0 -= burstAt - t
		elseif t < holdEnd then
			t0 -= holdEnd - t
		end
	end)

	conn = RunService.RenderStepped:Connect(function()
		if run ~= state then
			return
		end
		local pm = PerfMark.begin()
		local t = os.clock() - t0
		if t >= endAt then
			finish()
			PerfMark.finish("reveal", pm)
			return
		end
		local fade = 1 - seg(t, holdEnd, endAt)
		veil.BackgroundTransparency = 1 - 0.5 * easeOut(seg(t, 0, 0.3)) * fade

		-- fly and charge
		if t < burstAt then
			local f = easeOut(seg(t, 0, R.fly))
			local pos = from:Lerp(centre, f) - Vector2.new(0, math.sin(f * math.pi) * px(60))
			local charge = steps > 0 and seg(t, R.fly, burstAt) or 0
			local step = math.min(steps, math.floor(charge * steps + 0.0001))
			if t >= R.fly and step > 0 and step ~= state.shown then
				state.shown = step
				Sfx.play("padReady", { pitch = 1 + 0.12 * step, volume = 1.6 })
			end
			local col = Config.RARITIES[math.clamp(step + 1, 1, idx)].color
			local stepT = steps > 0 and (charge * steps - step) or 1
			local pulse = 1 + 0.16 * (1 - stepT) * (step > 0 and 1 or 0)
			local shake = t >= R.fly and math.sin(t * 70) * px(1 + step * 1.5) or 0
			local size = orbSize * (0.5 + 0.5 * f) * pulse * (1 + charge * 0.3)
			orb.Position = UDim2.fromOffset(pos.X + shake, pos.Y)
			orb.Size = UDim2.fromOffset(size, size)
			orb.BackgroundColor3 = col
			hi.BackgroundTransparency = 0.15
			for i, m in motes do
				m.Visible = t >= R.fly and steps > 0
				local a = i / #motes * math.pi * 2 + t * 4
				m.Position = UDim2.fromOffset(centre.X + math.cos(a) * size * 0.85, centre.Y + math.sin(a) * size * 0.85)
				m.BackgroundColor3 = col
			end
		elseif not state.burst then
			state.burst = true
			orb.Visible = false
			for _, m in motes do
				m.Visible = false
			end
			ring.Visible = true
			for _, b in bits do
				b.Visible = true
			end
			aura.Visible = true
			card.Visible = true
			aura.Position = UDim2.fromOffset(centre.X, centre.Y)
			card.Position = UDim2.fromOffset(centre.X, centre.Y)
			-- the burst sounds climb with the rarity
			Sfx.play("recruit")
			if idx >= 3 then
				Sfx.play("rareChime")
			end
			if idx >= 4 then
				task.delay(0.1, Sfx.play, "powerUp")
			end
			if idx >= 5 then
				task.delay(0.2, Sfx.play, "gong")
			end
			if idx >= 7 then
				task.delay(0.05, Sfx.play, "thunder")
			end
		end

		if state.burst then
			local b = seg(t, burstAt, burstAt + 0.45)
			ring.Visible = b < 1
			ring.Position = UDim2.fromOffset(centre.X, centre.Y)
			local rs = px(40) + b * px(360)
			ring.Size = UDim2.fromOffset(rs, rs)
			rst.Thickness = math.max(0, px(10) * (1 - b))
			rst.Transparency = b
			for i, bit in bits do
				bit.Visible = b < 1
				local a = i / #bits * math.pi * 2
				local r = px(40) + b * px(200)
				bit.Position = UDim2.fromOffset(centre.X + math.cos(a) * r, centre.Y + math.sin(a) * r)
				bit.BackgroundTransparency = b
			end
			-- the card pops, the aura breathes and turns; everything fades at the end
			local pop = seg(t, burstAt, burstAt + 0.35)
			cardScale.Scale = math.max(0.01, back(pop) * (0.9 + 0.1 * fade))
			local col = rarity.color
			if rarityName == "Primordial" then
				col = Color3.fromHSV((t * 0.35) % 1, 0.55, 1)
				nameLabel.TextColor3 = col
			end
			local breathe = 1 + 0.05 * math.sin(t * 3)
			for i, g in glows do
				g.BackgroundColor3 = col
				g.BackgroundTransparency = 1 - (1 - (0.6 + i * 0.1)) * fade * seg(t, burstAt, burstAt + 0.3)
				g.Size = UDim2.fromOffset(px(120) * ({ 3.1, 2.3, 1.6 })[i] * breathe, px(120) * ({ 3.1, 2.3, 1.6 })[i] * breathe)
			end
			if rayA then
				rayA.Rotation = t * 22
				for _, h in rayA:GetChildren() do
					local beam = h:FindFirstChildOfClass("Frame")
					if beam then
						beam.BackgroundColor3 = col
						beam.BackgroundTransparency = 1 - fade * seg(t, burstAt, burstAt + 0.3)
					end
				end
			end
			if rayB then
				rayB.Rotation = -t * 34
				for _, h in rayB:GetChildren() do
					local beam = h:FindFirstChildOfClass("Frame")
					if beam then
						beam.BackgroundTransparency = 1 - fade * seg(t, burstAt + 0.1, burstAt + 0.4)
					end
				end
			end
			for i, s in sparks do
				local a = i / #sparks * math.pi * 2 + t * 0.8
				local r = px(130) + math.sin(t * 2 + i) * px(18)
				s.Position = UDim2.new(0.5, math.cos(a) * r, 0.5, math.sin(a) * r)
				s.Rotation = t * 90 + i * 20
				local tw = 0.5 + 0.5 * math.sin(t * 6 + i * 1.7)
				for _, bar in s:GetChildren() do
					bar.BackgroundTransparency = 1 - tw * fade
				end
			end
			card.GroupTransparency = 1 - fade
		end
		PerfMark.finish("reveal", pm)
	end)
end

-- Hud fires PlayerGui.RecruitFx (made by Juice) with (rarity name, kept) after a recruit
local fx = playerGui:WaitForChild("RecruitFx")
fx.Event:Connect(start)
