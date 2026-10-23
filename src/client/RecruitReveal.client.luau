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

-- the disciple index line under a reveal card (D60): its look and the entry's star row, and a gold
-- "New index star!" when this pull lit one. `one` = a recruit result { look, stars, newStar }.
local function indexLine(card, one, order)
	if not (one and one.look) then
		return
	end
	local px = Toy.px
	local row = Toy.frame(card, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order })
	Toy.list(row, true, px(4))
	Toy.text(row, Config.LOOK_NAMES[one.look] or "", px(18), WHITE, { LayoutOrder = 1 })
	Toy.stars(row, one.stars or 0, px(16), { LayoutOrder = 2 })
	if one.newStar then
		Toy.text(card, "New index star!", px(18), Config.starColor(one.stars), { LayoutOrder = order + 1 })
	end
end

local function start(rarityName, kept, one)
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
	indexLine(card, one, 5)

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

-- x10 / x50 (mock docs/art/mocks/recruit_multi_A.mp4): every orb flies out of the seal into a grid
-- and wobbles (harder, and tinting, for a rarer one); they open in a wave into disciple tiles; then the
-- best grows into the usual card above a tray of all of them and a count per rarity. A tap skips ahead.
-- Juice: a whoosh out, ticks as they land, a swell while they shake harder, a rising ding and sparks
-- per pop, a rare one holds the wave with a flash and a shake, a white flash for the best card, a
-- chime as the tray settles. Timing: Config.REVEAL_MULTI (Juice lights the platform at the card).
local M = Config.REVEAL_MULTI
local IS_STUDIO = RunService:IsStudio()
local TILE_BG = Color3.fromHex("2B2033")

local function startMulti(results)
	finish()
	Toy.S = computeScale()
	local px = Toy.px
	local n = #results
	local popTimes, zoomAt = Config.revealMultiTimes(results)
	local rareFrom = Config.revealMultiRare(n)
	local endAt = zoomAt + M.hold
	local best = 1
	for i, r in results do
		if Config.rarityIndex(r.rarity) > Config.rarityIndex(results[best].rarity) then
			best = i
		end
	end
	local bestName = results[best].rarity
	local bestIdx = Config.rarityIndex(bestName)
	local rarity = Config.rarity(bestName)
	local vp = workspace.CurrentCamera.ViewportSize
	local from = recruitPoint()
	local small = n > 10
	-- the grid in the middle; after the zoom, the card up top and the tiles in tray rows under it
	local cols, size, gap = small and 10 or 5, px(small and 30 or 58), px(small and 6 or 14)
	local rows = math.ceil(n / cols)
	local gridTop = Vector2.new(vp.X / 2 - (cols * size + (cols - 1) * gap) / 2, vp.Y * 0.44 - (rows * size + (rows - 1) * gap) / 2)
	local per, tSize, tGap = small and 17 or 10, px(small and 20 or 34), px(small and 4 or 6)
	local trayTop = Vector2.new(vp.X / 2 - (math.min(n, per) * tSize + (math.min(n, per) - 1) * tGap) / 2, vp.Y * (small and 0.69 or 0.77))
	local cardAt = Vector2.new(vp.X / 2, vp.Y * 0.32)

	gui.Enabled = true
	local veil = Instance.new("TextButton")
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Parent = gui

	-- the best card's aura (behind everything else), as in the single reveal
	local aura = Toy.frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(px(400), px(400)), Visible = false, ZIndex = 2 })
	local glows = {}
	for i, k in { 3.1, 2.3, 1.6 } do
		glows[i] = circle(aura, px(110) * k, rarity.color, { Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 })
	end
	local rayA = bestIdx >= 3 and rays(aura, 12, px(190), px(28), rarity.color, 0.35) or nil
	local rayB = bestIdx >= 4 and rays(aura, 8, px(150), px(16), WHITE, 0.55) or nil

	-- orbs, tiles and the tray fade as one group at the end
	local layer = Instance.new("CanvasGroup")
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.ZIndex = 3
	layer.Parent = gui
	local items = {}
	for i, r in results do
		local idx = Config.rarityIndex(r.rarity)
		local col = Config.rarity(r.rarity).color
		local c, row = (i - 1) % cols, (i - 1) // cols
		local tc, tr = (i - 1) % per, (i - 1) // per
		local it = {
			idx = idx,
			delay = (i - 1) * (small and 0.008 or 0.03),
			popAt = popTimes[i],
			grid = gridTop + Vector2.new(size / 2 + c * (size + gap), size / 2 + row * (size + gap)),
			tray = trayTop + Vector2.new(tSize / 2 + tc * (tSize + tGap), tSize / 2 + tr * (tSize + tGap)),
		}
		it.orb = circle(layer, size, Config.RARITIES[1].color, { Visible = false, ZIndex = 3 })
		local ost = Instance.new("UIStroke")
		ost.Color = INK
		ost.Thickness = px(small and 2 or 3)
		ost.Parent = it.orb
		circle(it.orb, size * 0.36, WHITE, { Position = UDim2.fromScale(0.36, 0.32), BackgroundTransparency = 0.15, ZIndex = 4 })
		-- the burst ring where it opens, and rays behind a Core or rarer tile
		it.ring = circle(layer, size, WHITE, { BackgroundTransparency = 1, Visible = false, ZIndex = 5 })
		it.ringStroke = Instance.new("UIStroke")
		it.ringStroke.Color = col
		it.ringStroke.Parent = it.ring
		if idx >= 3 then
			it.rayHolder = Toy.frame(layer, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 0), Visible = false, ZIndex = 2 })
			it.rays = rays(it.rayHolder, 8, size * 1.1, math.max(px(5), size * 0.16), col, 0.3)
		end
		-- the tile: the disciple in a dark rounded square ringed in its rarity colour
		it.tile = Toy.frame(layer, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 0, BackgroundColor3 = TILE_BG, ClipsDescendants = true, Visible = false, ZIndex = 4 })
		Toy.corner(it.tile, UDim.new(0.26, 0))
		local tst = Instance.new("UIStroke")
		tst.Color = col
		tst.Thickness = math.max(2, px(small and 2 or 4))
		tst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		tst.Parent = it.tile
		Toy.disciple(it.tile, size, r.rarity, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1.08), Size = UDim2.fromScale(0.9, 0.9), ZIndex = 5 }, true)
		if r.newStar then -- this pull lit an index star (D60): that star, in its colour, in the tile's corner
			Toy.text(it.tile, "★", math.max(px(10), size * 0.34), Config.starColor(r.stars), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -px(1), 0, 0), ZIndex = 7 })
		end
		it.scale = Instance.new("UIScale")
		it.scale.Parent = it.tile
		-- a white flash over the tile as it opens, and sparks flying off in its colour
		it.flash = Toy.frame(it.tile, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = WHITE, ZIndex = 6 })
		Toy.corner(it.flash, UDim.new(0.26, 0))
		it.sparks = {}
		for k = 1, idx >= rareFrom and 8 or 4 do
			it.sparks[k] = circle(layer, math.max(px(4), size * 0.16), col, { Visible = false, ZIndex = 6 })
		end
		items[i] = it
	end

	-- the count per rarity just above the tray (clear of the HUD's realm bar): "x10: 1 Elder · 2 Inner · 7 Outer"
	local summary = Toy.frame(layer, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(vp.X / 2, trayTop.Y - px(6)), AutomaticSize = Enum.AutomaticSize.XY, Visible = false, ZIndex = 6 })
	Toy.list(summary, true, px(5))
	Toy.text(summary, "x" .. n .. ":", px(17), WHITE, { LayoutOrder = 0 })
	local counts = {}
	for _, r in results do
		counts[r.rarity] = (counts[r.rarity] or 0) + 1
	end
	local order = 1
	for k = #Config.RARITIES, 1, -1 do
		local def = Config.RARITIES[k]
		if counts[def.name] then
			if order > 1 then
				Toy.text(summary, "·", px(17), WHITE, { LayoutOrder = order * 2 - 1 })
			end
			local short = string.gsub(def.name, " Disciple$", "")
			Toy.text(summary, counts[def.name] .. " " .. short, px(17), def.color, { LayoutOrder = order * 2 })
			order += 1
		end
	end

	-- the best one's card (a CanvasGroup so it fades as one)
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
	Toy.disciple(card, px(96), bestName, { LayoutOrder = 1 }, true)
	local nameLabel = Toy.text(card, bestName .. "!", px(36), rarity.color, { LayoutOrder = 2 })
	local bonusRow = Toy.frame(card, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	Toy.list(bonusRow, true, px(5))
	Toy.text(bonusRow, string.format("+%d%%", math.floor(rarity.bonus * 100 + 0.5)), px(21), WHITE, { LayoutOrder = 1 })
	Toy.icon(bonusRow, "qi", px(23), { LayoutOrder = 2 })
	if not results[best].kept then
		Toy.text(card, "Sect full", px(16), PINK, { LayoutOrder = 4 })
	end
	indexLine(card, results[best], 5)

	local flash = Toy.frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BackgroundColor3 = WHITE, ZIndex = 7 })

	local t0 = os.clock()
	local state = { burst = false, shakeUntil = 0, shakeAmp = 0 }
	run = state
	Sfx.play("gather", { volume = 1.4 })
	Sfx.play("rise", { volume = 1.2 })
	-- the swell peaks as the first orb opens
	task.delay(math.max(0, M.pop - 0.85), function()
		if run == state then
			Sfx.play("padSpin", { volume = 1.3 })
		end
	end)

	-- a tap skips ahead: every orb open and the best card out, then to the end
	veil.Activated:Connect(function()
		if run ~= state then
			return
		end
		local t = os.clock() - t0
		if t < zoomAt - 0.05 then
			t0 -= zoomAt - t
		elseif t < endAt - 0.3 then
			t0 -= endAt - 0.3 - t
		end
	end)

	conn = RunService.RenderStepped:Connect(function()
		if run ~= state then
			return
		end
		local pm = PerfMark.begin()
		local t = os.clock() - t0
		-- Studio captures: the local attribute RevealAt (seconds) holds the reveal at that moment
		local held = IS_STUDIO and player:GetAttribute("RevealAt")
		if held then
			t = held
		end
		if t >= endAt then
			finish()
			PerfMark.finish("reveal", pm)
			return
		end
		local fade = 1 - seg(t, endAt - 0.3, endAt)
		veil.BackgroundTransparency = 1 - 0.55 * easeOut(seg(t, 0, 0.3)) * fade
		layer.GroupTransparency = 1 - fade
		local toTray = easeOut(seg(t, zoomAt, zoomAt + 0.4))
		-- a short shake on a rare pop and on the best card
		local shake = t < state.shakeUntil and state.shakeAmp * (state.shakeUntil - t) / 0.25 or 0
		local sx, sy = math.sin(t * 90) * shake, math.cos(t * 77) * shake
		layer.Position = UDim2.fromOffset(sx, sy)
		-- the grid breathes faster and faster before the wave
		local charge = seg(t, 0.6, M.pop)
		local pulse = 1 + 0.08 * charge * math.max(0, math.sin(t * (10 + 18 * charge)))
		for i, it in items do
			if t < it.popAt then
				-- fly out on an arc, then wobble in place; a rare orb climbs toward its colour
				local f = easeOut(seg(t, it.delay, it.delay + 0.5))
				local pos = from:Lerp(it.grid, f) - Vector2.new(0, math.sin(f * math.pi) * px(50))
				local wob = t > 0.6 and math.sin(t * (30 + it.idx * 14) + i) * px(1 + it.idx * 1.4) * size / px(58) or 0
				local s = size * (0.5 + 0.5 * f) * pulse
				if f >= 1 and not it.landed then
					it.landed = true
					if not small or i == n then
						Sfx.play("padSnap", { volume = small and 0.6 or 0.35, pitch = 1.3 + 0.3 * i / n })
					end
				end
				it.orb.Visible = t >= it.delay
				it.orb.Position = UDim2.fromOffset(pos.X + wob, pos.Y)
				it.orb.Size = UDim2.fromOffset(s, s)
				if it.idx >= rareFrom and t > 0.9 then
					it.orb.BackgroundColor3 = Config.RARITIES[math.min(it.idx, 1 + math.floor((t - 0.9) * 3))].color
				end
			else
				if not it.open then
					it.open = true
					it.orb.Visible = false
					it.tile.Visible = true
					it.ring.Visible = true
					if it.rayHolder then
						it.rayHolder.Visible = true
					end
					-- a rising ding per orb (every third one at x50, every rare one always)
					if not small or i % 3 == 1 or it.idx >= 3 then
						Sfx.play("padReady", { pitch = 1 + 0.4 * i / n, volume = small and 0.9 or 1.3 })
					end
					if it.idx >= rareFrom then
						-- a rare one: the wave holds, the screen shakes, the chime climbs with the rarity
						Sfx.play("rareChime", { pitch = 0.9 + 0.08 * it.idx })
						if it.idx >= 4 then
							Sfx.play("powerUp", { volume = 0.7 })
						end
						state.shakeUntil, state.shakeAmp = t + 0.25, px(2 + it.idx)
					end
				end
				local fl = seg(t, it.popAt, it.popAt + 0.22)
				it.flash.BackgroundTransparency = fl
				local sp = seg(t, it.popAt, it.popAt + 0.45)
				for k, d in it.sparks do
					d.Visible = sp < 1
					if sp < 1 then
						local a = k / #it.sparks * math.pi * 2 + i
						local r = size * (0.4 + easeOut(sp) * (it.idx >= rareFrom and 1.6 or 0.9))
						d.Position = UDim2.fromOffset(it.grid.X + math.cos(a) * r, it.grid.Y + math.sin(a) * r)
						d.BackgroundTransparency = sp
					end
				end
				local b = seg(t, it.popAt, it.popAt + 0.3)
				it.ring.Visible = b < 1
				it.ring.Position = UDim2.fromOffset(it.grid.X, it.grid.Y)
				local rs = size * (0.4 + 1.8 * b)
				it.ring.Size = UDim2.fromOffset(rs, rs)
				it.ringStroke.Thickness = math.max(0, px(small and 5 or 8) * (1 - b))
				it.ringStroke.Transparency = b
				if it.rays then
					local a = 0.5 * seg(t, it.popAt, it.popAt + 0.2) * (1 - seg(t, zoomAt, zoomAt + 0.3))
					it.rayHolder.Position = UDim2.fromOffset(it.grid.X, it.grid.Y)
					it.rays.Rotation = t * 40
					for _, h in it.rays:GetChildren() do
						local beam = h:FindFirstChildOfClass("Frame")
						if beam then
							beam.BackgroundTransparency = 1 - a
						end
					end
				end
				if it.placedAt ~= toTray then -- only while it moves (50 tiles, every frame)
					it.placedAt = toTray
					local pos = it.grid:Lerp(it.tray, toTray)
					local s = size + (tSize - size) * toTray
					it.tile.Position = UDim2.fromOffset(pos.X, pos.Y)
					it.tile.Size = UDim2.fromOffset(s, s)
				end
				it.scale.Scale = math.max(0.01, back(seg(t, it.popAt, it.popAt + 0.25)))
			end
		end

		if t >= zoomAt then
			if not state.burst then
				state.burst = true
				aura.Visible = true
				card.Visible = true
				state.shakeUntil, state.shakeAmp = t + 0.25, px(3 + bestIdx)
				task.delay(0.4, function()
					if run == state then
						Sfx.play("land", { volume = 1.2 }) -- the tray settles
					end
				end)
				Sfx.play("recruit")
				if bestIdx >= 3 then
					Sfx.play("rareChime")
				end
				if bestIdx >= 4 then
					task.delay(0.1, Sfx.play, "powerUp")
				end
				if bestIdx >= 5 then
					task.delay(0.2, Sfx.play, "gong")
				end
				if bestIdx >= 7 then
					task.delay(0.05, Sfx.play, "thunder")
				end
			end
			summary.Visible = t >= zoomAt + 0.3
			flash.BackgroundTransparency = 1 - 0.7 * (1 - seg(t, zoomAt, zoomAt + 0.25))
			-- the card grows out of the best tile and rises to the top
			local p = seg(t, zoomAt, zoomAt + 0.35)
			local pos = items[best].grid:Lerp(cardAt, easeOut(p))
			card.Position = UDim2.fromOffset(pos.X, pos.Y)
			aura.Position = UDim2.fromOffset(pos.X, pos.Y)
			cardScale.Scale = math.max(0.01, back(p) * (0.9 + 0.1 * fade))
			card.GroupTransparency = 1 - fade
			local col = rarity.color
			if bestName == "Primordial" then
				col = Color3.fromHSV((t * 0.35) % 1, 0.55, 1)
				nameLabel.TextColor3 = col
			end
			local breathe = 1 + 0.05 * math.sin(t * 3)
			for i, g in glows do
				local k = ({ 3.1, 2.3, 1.6 })[i]
				g.BackgroundColor3 = col
				g.BackgroundTransparency = 1 - (0.4 - i * 0.1) * fade * seg(t, zoomAt, zoomAt + 0.3)
				g.Size = UDim2.fromOffset(px(110) * k * breathe, px(110) * k * breathe)
			end
			for ri, ring in { rayA, rayB } do
				if ring then
					ring.Rotation = ri == 1 and t * 22 or -t * 34
					local from2 = zoomAt + 0.1 * (ri - 1)
					for _, h in ring:GetChildren() do
						local beam = h:FindFirstChildOfClass("Frame")
						if beam then
							if ri == 1 then
								beam.BackgroundColor3 = col
							end
							beam.BackgroundTransparency = 1 - fade * seg(t, from2, from2 + 0.3)
						end
					end
				end
			end
		end
		PerfMark.finish("reveal", pm)
	end)
end

-- Hud fires Player.RecruitFx (made by Juice) with (rarity name, kept, results) after a recruit (the
-- idle chest too, with one result); results (x10 / x50) open every orb, else the single reveal
local fx = player:WaitForChild("RecruitFx")
fx.Event:Connect(function(rarityName, kept, results)
	if results and #results > 1 then
		startMulti(results)
	else
		start(rarityName, kept, results and results[1])
	end
end)
