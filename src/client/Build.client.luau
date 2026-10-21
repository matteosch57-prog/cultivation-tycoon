-- Buying feel: price cards over your pads, a hologram preview of the building when you walk
-- close, and an assemble animation (parts rise into place, lights come on) when it is built.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local sect = workspace:WaitForChild("Sect")
local Sfx = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Sfx"))

local PREVIEW_RANGE = 18 -- studs (horizontal) from the pad centre
local JADE = Color3.fromHex("6FB59C")
local GOLD = Color3.fromHex("D4A445")
local INK = Color3.fromHex("1B1420") -- HUD outline colour
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

local function fmt(n)
	n = math.floor(n or 0)
	local units = { "", "K", "M", "B", "T", "Qa" }
	local i, v = 1, n
	while v >= 1000 and i < #units do
		v /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(n)
	end
	local digits = v < 10 and 2 or (v < 100 and 1 or 0)
	local f = 10 ^ digits
	return string.format("%." .. digits .. "f%s", math.floor(v * f) / f, units[i])
end

---------------------------------------------------------------------------------------------
-- Price cards + preview, one record per pad of mine
local pads = {} -- [pad] = { card, cost, bar, costText, hint, preview, parts, shown, fade }

local function makeCard(pad)
	-- Same language as the HUD: chunky outlined text, no panel, no bar. Drawn on top of the
	-- beacon beam (AlwaysOnTop) so the light never covers it.
	local bb = Instance.new("BillboardGui")
	bb.Name = "PadCard"
	bb.Adornee = pad
	bb.Size = UDim2.fromOffset(240, 78)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.MaxDistance = 110
	bb.AlwaysOnTop = false -- outlined text stays readable over the beam; AlwaysOnTop cards
	-- also vanished from Studio captures, so they could not be verified
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.AnchorPoint = Vector2.new(0.5, 1) -- the distance scale shrinks it toward the pad
	f.Position = UDim2.fromScale(0.5, 1)
	f.BackgroundTransparency = 1
	f.Parent = bb
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = f
	local function text(order, size, color)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AutomaticSize = Enum.AutomaticSize.XY
		t.Size = UDim2.new()
		t.FontFace = FONT
		t.TextSize = size
		t.TextColor3 = color
		t.LayoutOrder = order
		local st = Instance.new("UIStroke")
		st.Color = INK
		st.Thickness = math.max(2, size * 0.13)
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = t
		t.Parent = f
		return t
	end
	local title = text(1, 20, Color3.new(1, 1, 1))
	title.Text = pad:GetAttribute("Title") or ""
	local feature = pad:GetAttribute("Feature")
	if feature then
		-- feature buildings say what they DO
		text(2, 14, GOLD:Lerp(Color3.new(1, 1, 1), 0.3)).Text = feature
	end
	local costText = text(3, 22, Color3.fromHex("9FF5C8"))
	local sc = Instance.new("UIScale")
	sc.Name = "DistanceScale"
	sc.Parent = f
	bb.Parent = player:WaitForChild("PlayerGui")
	return bb, costText
end

local function setPreview(rec, on)
	if rec.shown == on then
		return
	end
	if not rec.preview then
		rec.shown = on
		TweenService:Create(rec.card, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, on and 2.4 or 5.5, 0) }):Play()
		return
	end
	rec.shown = on
	if on and not rec.prepared then
		-- first show: turn the hidden copy into a hologram (local-only changes)
		rec.prepared = true
		for _, p in rec.parts do
			p.Material = Enum.Material.ForceField
			p.Color = p.Color:Lerp(JADE, 0.55)
			p.Transparency = 0
			p.LocalTransparencyModifier = 1
		end
	end
	if rec.fade then
		rec.fade:Cancel()
	end
	-- up close the building is the focus: the card drops to just above the pad
	TweenService:Create(rec.card, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, on and 2.4 or 5.5, 0) }):Play()
	local v = rec.value
	rec.fade = TweenService:Create(v, TweenInfo.new(on and 0.45 or 0.3, Enum.EasingStyle.Quad), { Value = on and 0.15 or 1 })
	rec.fade:Play()
end

local GREEN = Color3.fromHex("59D39F")
local RED = Color3.fromHex("E0544B")
local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalPadFX"
fxFolder.Parent = workspace

-- A beam of light standing on the pad, visible from across the island: it calls the player
-- to the next thing to buy. Green = affordable, red = not yet. Local to this player.
local function makeBeacon(pad)
	local base = Instance.new("Part")
	base.Name = "Beacon"
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.Transparency = 1
	base.Size = Vector3.new(3.4, 0.2, 3.4)
	base.CFrame = CFrame.new(pad.Position + Vector3.new(0, 0.3, 0))
	base.Parent = fxFolder
	local a0 = Instance.new("Attachment")
	a0.Parent = base
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 38, 0)
	a1.Parent = base
	local function beam(w0, w1, transp)
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Width0 = w0
		b.Width1 = w1
		b.Segments = 1
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, transp),
			NumberSequenceKeypoint.new(0.15, transp + 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		b.Parent = base
		return b
	end
	local core = beam(1.6, 0.6, 0.15)
	local glow = beam(4.2, 2, 0.65)
	-- motes rising up the beam
	local motes = Instance.new("ParticleEmitter")
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Speed = NumberRange.new(6, 11)
	motes.Lifetime = NumberRange.new(1.4, 2.2)
	motes.Size = NumberSequence.new(0.35, 0)
	motes.LightEmission = 1
	motes.Rate = 7
	motes.Parent = base
	-- a ring that pulses outward on the ground
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Size = Vector3.new(0.05, 4.2, 4.2)
	ring.CFrame = CFrame.new(pad.Position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = fxFolder
	local pulse = TweenService:Create(ring, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Size = Vector3.new(0.05, 8, 8), Transparency = 1 })
	pulse:Play()
	local function setColor(c)
		core.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.35), c)
		glow.Color = ColorSequence.new(c)
		motes.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.5))
		ring.Color = c
	end
	return { parts = { base, ring }, setColor = setColor, core = core, glow = glow, motes = motes }
end

-- the pad sinks into the ground when bought (the server has already removed the real one)
local function sinkGhost(cf, size, color)
	local g = Instance.new("Part")
	g.Anchored = true
	g.CanCollide = false
	g.CanQuery = false
	g.CanTouch = false
	g.Shape = Enum.PartType.Cylinder
	g.Material = Enum.Material.SmoothPlastic
	g.Color = color
	g.Size = size
	g.CFrame = cf
	g.Parent = fxFolder
	TweenService:Create(g, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = cf - Vector3.new(0, 0.6, 0), Size = size * Vector3.new(1, 0.4, 0.4), Transparency = 1 }):Play()
	task.delay(0.6, function()
		g:Destroy()
	end)
end

local function addPad(pad)
	if pads[pad] or pad:GetAttribute("OwnerId") ~= player.UserId then
		return
	end
	local card, costText = makeCard(pad)
	local rec = { card = card, costText = costText, cost = pad:GetAttribute("Cost") or 0, shown = false }
	rec.beacon = makeBeacon(pad)
	rec.padCF, rec.padSize = pad.CFrame, pad.Size
	local preview = pad:FindFirstChild("Preview")
	if preview then
		rec.preview = preview
		rec.parts = {}
		for _, d in preview:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(rec.parts, d)
			end
		end
		rec.value = Instance.new("NumberValue")
		rec.value.Value = 1
		rec.value.Changed:Connect(function(x)
			for _, p in rec.parts do
				p.LocalTransparencyModifier = x
			end
		end)
	end
	pads[pad] = rec
	rec.cleanup = function()
		if not pads[pad] then
			return
		end
		pads[pad] = nil
		card:Destroy()
		if rec.value then
			rec.value:Destroy()
		end
		for _, p in rec.beacon.parts do
			p:Destroy()
		end
		if rec.affordable and rec.onPad then -- bought by me just now, not a realm reset
			sinkGhost(rec.padCF, rec.padSize, GREEN)
			Sfx.play("buy")
			Sfx.play("buyChime")
		end
	end
	pad.AncestryChanged:Connect(function(_, parent)
		if not parent then
			rec.cleanup()
		end
	end)
end

local function isPad(d)
	return d:IsA("BasePart") and d.Name:sub(1, 4) == "Pad_"
end

---------------------------------------------------------------------------------------------
-- Assemble animation for freshly built models
local function burst(position)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(8, 1, 8)
	holder.Position = position
	holder.Parent = workspace
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(JADE:Lerp(Color3.new(1, 1, 1), 0.4), GOLD)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Speed = NumberRange.new(10, 18)
	sparks.Lifetime = NumberRange.new(0.7, 1.2)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.Acceleration = Vector3.new(0, -14, 0)
	sparks.Rate = 0
	sparks.Parent = holder
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(235, 225, 205))
	dust.Size = NumberSequence.new(1.5, 3.5)
	dust.Transparency = NumberSequence.new(0.4, 1)
	dust.Speed = NumberRange.new(6, 9)
	dust.Lifetime = NumberRange.new(0.8, 1.2)
	dust.SpreadAngle = Vector2.new(90, 5)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Drag = 4
	dust.Rate = 0
	dust.Parent = holder
	sparks:Emit(45)
	dust:Emit(24)
	task.delay(2.5, function()
		holder:Destroy()
	end)
end

local function animateBuild(model)
	local builtAt = model:GetAttribute("BuiltAt")
	if not builtAt or workspace:GetServerTimeNow() - builtAt > 3 then
		return -- joined late or rebuilt: just show it
	end
	task.wait() -- let the whole subtree arrive
	local parts, effects = {}, {}
	local minY, maxY = math.huge, -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			minY = math.min(minY, d.Position.Y)
			maxY = math.max(maxY, d.Position.Y)
		elseif (d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke")) and d.Enabled then
			d.Enabled = false
			table.insert(effects, d)
		end
	end
	if #parts == 0 then
		return
	end
	local cf, size = model:GetBoundingBox()
	burst(Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2 + 1, cf.Position.Z))
	local mine = model.Parent and model.Parent.Parent and model.Parent.Parent.Name == ("Peak" .. tostring(player:GetAttribute("PlotIndex")))
	if mine then
		Sfx.play("rise")
	end
	local span = math.max(maxY - minY, 1)
	local total = 0.45 + math.min(1.2, span / 22) -- a smooth wave, longer for tall buildings
	local rng = Random.new()
	for _, p in parts do
		local target = p.CFrame
		local rel = (p.Position.Y - minY) / span
		p.LocalTransparencyModifier = 1
		p.CFrame = target - Vector3.new(0, 1.2 + rel * 1.2, 0)
		-- Quint out: fast start, long soft landing (no Back overshoot, which read as jitter)
		local info = TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, rel * total + rng:NextNumber(0, 0.05))
		TweenService:Create(p, info, { CFrame = target, LocalTransparencyModifier = 0 }):Play()
	end
	-- lights and effects come on once the structure has settled
	-- it settles: chime, a flash of warm light, and a temple bell for a Main Hall level
	task.delay(total + 0.35, function()
		if mine then
			Sfx.play("land")
			if model.Name:match("^mainhall") then
				Sfx.play("hallBell")
			end
		end
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Position = cf.Position + Vector3.new(0, size.Y * 0.2, 0)
		holder.Parent = workspace
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 225, 160)
		light.Range = math.clamp(math.max(size.X, size.Z) * 1.2, 16, 50)
		light.Brightness = 5
		light.Parent = holder
		TweenService:Create(light, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
		task.delay(1, function()
			holder:Destroy()
		end)
	end)
	task.delay(total + 0.7, function()
		for _, e in effects do
			if e.Parent then
				e.Enabled = true
			end
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Wiring
sect.DescendantAdded:Connect(function(d)
	if isPad(d) then
		task.defer(addPad, d)
	elseif d:IsA("Model") and d.Parent and d.Parent.Name == "Built" and d:GetAttribute("BuiltAt") then
		task.spawn(animateBuild, d)
	end
end)
for _, d in sect:GetDescendants() do
	if isPad(d) then
		addPad(d)
	end
end

-- Card text + preview distance, a few times a second (cheap: a handful of pads)
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.15 then
		return
	end
	acc = 0
	local qi = player:GetAttribute("Qi") or 0
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	for pad, rec in pads do
		if not pad:IsDescendantOf(workspace) then
			rec.cleanup() -- a missed AncestryChanged must not leave a card floating
			continue
		end
		-- a beam right beside the camera would fill the screen: fade it out up close
		local camPos = workspace.CurrentCamera.CFrame.Position
		local camNear = Vector2.new(camPos.X - pad.Position.X, camPos.Z - pad.Position.Z).Magnitude < 14
		rec.beacon.core.Enabled = not camNear
		rec.beacon.glow.Enabled = not camNear
		local ok = qi >= rec.cost
		local d = math.huge
		if hrp then
			d = Vector3.new(pad.Position.X - hrp.Position.X, 0, pad.Position.Z - hrp.Position.Z).Magnitude
			setPreview(rec, d < PREVIEW_RANGE)
		end
		local onPad = d < 2.6
		rec.onPad = d < 4
		-- stepping onto a pad you can't afford yet: one soft "not yet" per visit
		if onPad and not ok and not rec.denied then
			rec.denied = true
			Sfx.play("deny")
		elseif not onPad then
			rec.denied = false
		end
		-- far cards shrink so a distant pad never buries the HUD; near ones stay full size
		local cam = workspace.CurrentCamera
		local camDist = (cam.CFrame.Position - pad.Position).Magnitude
		local sc = rec.card:FindFirstChild("DistanceScale", true)
		if sc then
			sc.Scale = math.clamp(40 / math.max(camDist, 1), 0.6, 1)
		end
		if onPad and not ok then
			rec.costText.Text = "Need " .. fmt(rec.cost - qi) .. " more"
		else
			rec.costText.Text = fmt(rec.cost) .. " Qi"
		end
		rec.costText.TextColor3 = ok and Color3.fromHex("9FF5C8") or Color3.fromHex("FF8A80")
		if rec.affordable ~= ok then
			rec.affordable = ok
			-- pad, beam and ring switch colour together; affordable beams stand brighter
			pad.Color = ok and GREEN or RED
			rec.beacon.setColor(ok and GREEN or RED)
			rec.beacon.core.Width0 = ok and 1.8 or 1.1
			rec.beacon.glow.Width0 = ok and 4.6 or 2.6
			rec.beacon.motes.Rate = ok and 9 or 3
		end
	end
end)
