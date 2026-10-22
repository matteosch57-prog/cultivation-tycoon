-- Juice: the constant small feedback that makes a tycoon feel alive.
--  * "+qi" numbers float up off your buildings every few seconds (what each one earns)
--  * qi orbs bob and spin; collecting one flashes light and plays a ding
--  * every waterfall has its own positional sound; ambience + music bed (Sfx.init)
--  * pills, expansions and breakthroughs get their sounds and light
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local PerfMark = require(Shared:WaitForChild("PerfMark"))
local Toy = require(Shared:WaitForChild("Toy"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local sect = workspace:WaitForChild("Sect")

Sfx.init()

local INK = Color3.fromHex("1B1420")
local fx = Instance.new("Folder")
fx.Name = "LocalJuice"
fx.Parent = workspace

local function short(n)
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	local units = { "K", "M", "B", "T", "Qa" }
	local v, i = n / 1000, 1
	while v >= 1000 and i < #units do
		v /= 1000
		i += 1
	end
	return string.format(v < 10 and "%.1f%s" or "%.0f%s", math.floor(v * 10) / 10, units[i])
end

local function myPlot()
	local idx = player:GetAttribute("PlotIndex")
	return idx and sect:FindFirstChild("Peak" .. idx) or nil
end

-- a short burst of real light (a flash, not a standing fake glow)
local function flash(pos, color, range, brightness, time)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = fx
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 24
	light.Brightness = brightness or 4
	light.Parent = p
	TweenService:Create(light, TweenInfo.new(time or 0.8, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	task.delay((time or 0.8) + 0.1, function()
		p:Destroy()
	end)
end

-- rising sparkle column (recruit reveals, breakthroughs)
local function pillar(pos, color, height, time)
	local base = Instance.new("Part")
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.Transparency = 1
	base.Size = Vector3.new(3, 0.2, 3)
	base.Position = pos
	base.Parent = fx
	local a0 = Instance.new("Attachment")
	a0.Parent = base
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, height or 30, 0)
	a1.Parent = base
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Width0 = 3
	beam.Width1 = 1
	beam.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4), color)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	beam.Parent = base
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.5))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new(0.5, 0)
	pe.Speed = NumberRange.new(12, 22)
	pe.Lifetime = NumberRange.new(0.8, 1.4)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.SpreadAngle = Vector2.new(12, 12)
	pe.Rate = 0
	pe.Parent = base
	pe:Emit(40)
	TweenService:Create(beam, TweenInfo.new(time or 1.6, Enum.EasingStyle.Quad), { Width0 = 0, Width1 = 0 }):Play()
	flash(pos + Vector3.new(0, 3, 0), color, 30, 5, time or 1.6)
	task.delay((time or 1.6) + 1.5, function()
		base:Destroy()
	end)
end

---------------------------------------------------------------------------------------------
-- floating "+qi" off every earning building of mine, every few seconds
local INCOME = {}
for _, pad in Config.PADS do
	INCOME[pad.id] = pad.income
end
local function floatText(pos, str, color)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = fx
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 40)
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.Parent = p
	-- the qi drop in front of the number (R18: every amount shows its currency icon)
	local row = Toy.frame(bb, { Size = UDim2.fromScale(1, 1) })
	Toy.list(row, true, 3)
	Toy.icon(row, "qi", 24, { LayoutOrder = 1 })
	local t = Toy.text(row, str, 22, color, { LayoutOrder = 2 })
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = row
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(p, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { Position = pos + Vector3.new(0, 7, 0) }):Play()
	task.delay(0.9, function()
		local info = TweenInfo.new(0.7)
		TweenService:Create(t, info, { TextTransparency = 1 }):Play()
		for _, d in row:GetDescendants() do
			if d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
				TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("ImageLabel") then
				TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
			end
		end
	end)
	task.delay(1.7, function()
		p:Destroy()
	end)
end

local FLOAT_EVERY = 3
task.spawn(function()
	while true do
		task.wait(FLOAT_EVERY)
		local plot = myPlot()
		local built = plot and plot:FindFirstChild("Built")
		if built then
			local mult = Config.incomeMult(player:GetAttribute("Realm") or 1)
			local cam = workspace.CurrentCamera.CFrame.Position
			local shown = 0
			for _, m in built:GetChildren() do
				local inc = INCOME[m.Name]
				if m:IsA("Model") and inc and inc > 0 and shown < 9 then
					local cf, size = m:GetBoundingBox()
					local top = cf.Position + Vector3.new(0, size.Y / 2 + 1.5, 0)
					if (top - cam).Magnitude < 110 then
						shown += 1
						-- stagger them so they ripple rather than fire in one frame
						task.delay(shown * 0.18, floatText, top, "+" .. short(inc * mult * FLOAT_EVERY), Color3.fromHex("9FF5C8"))
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------------------------------------
-- qi orbs bob and spin (local motion on the server's anchored orb)
local orbs = {}
local function trackOrb(o)
	if orbs[o] then
		return
	end
	orbs[o] = { base = o.CFrame, t0 = os.clock() + math.random() * 3 }
	o.AncestryChanged:Connect(function(_, parent)
		if not parent then
			orbs[o] = nil
		end
	end)
end
sect.DescendantAdded:Connect(function(d)
	if d.Name == "QiOrb" and d:IsA("BasePart") then
		task.defer(trackOrb, d)
	end
end)
for _, d in sect:GetDescendants() do
	if d.Name == "QiOrb" and d:IsA("BasePart") then
		trackOrb(d)
	end
end
RunService.RenderStepped:Connect(function()
	local t0 = PerfMark.begin()
	local t = os.clock()
	local cam = workspace.CurrentCamera
	for o, info in orbs do
		if PerfMark.onScreen(cam, info.base.Position, 3) then -- nothing moves unseen
			local k = t - info.t0
			o.CFrame = info.base * CFrame.new(0, math.sin(k * 2.2) * 0.6, 0) * CFrame.Angles(0, k * 1.5, 0)
		end
	end
	PerfMark.finish("orbs", t0)
end)

---------------------------------------------------------------------------------------------
-- waterfalls: positional rush of water on each one
local function hookWaterfall(m)
	if m:GetAttribute("Sounding") then
		return
	end
	local part = m:FindFirstChildWhichIsA("BasePart")
	if part then
		m:SetAttribute("Sounding", true)
		Sfx.loopAt(part, Sfx.WATERFALL, 0.5, 80)
	end
end
sect.DescendantAdded:Connect(function(d)
	if d.Name == "Waterfall" and d:IsA("Model") then
		task.defer(hookWaterfall, d)
	end
end)
for _, d in sect:GetDescendants() do
	if d.Name == "Waterfall" and d:IsA("Model") then
		hookWaterfall(d)
	end
end

---------------------------------------------------------------------------------------------
-- server events
local function plotCentre()
	local idx = player:GetAttribute("PlotIndex")
	if not idx then
		return nil
	end
	local a = (idx - 1) / Config.PLOT_COUNT * math.pi * 2
	return Vector3.new(math.cos(a) * Config.PLOT_RADIUS, 2, math.sin(a) * Config.PLOT_RADIUS)
end

-- reward fly-to: little qi drops leave a world point on screen and land in the HUD counter
local flyGui = Instance.new("ScreenGui")
flyGui.Name = "QiFly"
flyGui.IgnoreGuiInset = true
flyGui.ResetOnSpawn = false
flyGui.DisplayOrder = 5
flyGui.Parent = player:WaitForChild("PlayerGui")
local function flyToCounter(worldPos, count)
	local hud = player.PlayerGui:FindFirstChild("Hud")
	local counter = hud and hud:FindFirstChild("Counter", true)
	if not counter then
		return
	end
	local cam = workspace.CurrentCamera
	local sp, onScreen = cam:WorldToViewportPoint(worldPos)
	local from = onScreen and Vector2.new(sp.X, sp.Y) or cam.ViewportSize / 2
	local to = counter.AbsolutePosition + Vector2.new(counter.AbsoluteSize.Y * 0.5, counter.AbsoluteSize.Y * 0.5)
	for i = 1, count do
		local d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Size = UDim2.fromOffset(14, 14)
		d.Position = UDim2.fromOffset(from.X + math.random(-30, 30), from.Y + math.random(-30, 30))
		d.BackgroundColor3 = Color3.fromHex("6FD6AE")
		d.Parent = flyGui
		Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
		local st = Instance.new("UIStroke")
		st.Color = INK
		st.Thickness = 2
		st.Parent = d
		task.delay(i * 0.04, function()
			local tw = TweenService:Create(d, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(to.X, to.Y), Size = UDim2.fromOffset(8, 8) })
			tw:Play()
			tw.Completed:Wait()
			d:Destroy()
		end)
	end
end

remotes.Notify.OnClientEvent:Connect(function(kind, a, b)
	if kind == "orb" then
		Sfx.play("orb")
		if typeof(b) == "Vector3" then
			flash(b, Color3.fromHex("9FF5D0"), 18, 4, 0.5)
			flyToCounter(b, 10)
		end
	elseif kind == "pill" then
		Sfx.play("pillReady")
	elseif kind == "expand" then
		Sfx.play("expand")
		Sfx.play("gong", { volume = 0.7 })
		local c = plotCentre()
		if c then
			pillar(c + Vector3.new(0, 1, 0), Color3.fromHex("9FF5C8"), 60, 2)
		end
	elseif kind == "tide" then
		Sfx.play("gong", { volume = 0.6 })
		local c = plotCentre()
		if c then
			pillar(c + Vector3.new(0, 1, 0), Color3.fromHex("9FD0FF"), 50, 2)
		end
	elseif kind == "reincarnate" then
		Sfx.play("thunder")
		task.delay(0.3, function()
			Sfx.play("gong")
		end)
		if a == player.DisplayName then
			local c = plotCentre()
			if c then
				pillar(c + Vector3.new(0, 1, 0), Color3.fromHex("D9B8FF"), 80, 2.5)
			end
		end
	elseif kind == "breakthrough" then
		Sfx.play("thunder")
		task.delay(0.15, function()
			Sfx.play("gong")
		end)
	end
end)

-- recruits: the Hud tells us the rarity through this local event
local recruitFx = Instance.new("BindableEvent")
recruitFx.Name = "RecruitFx"
recruitFx.Parent = player:WaitForChild("PlayerGui")
recruitFx.Event:Connect(function(rarityName, kept, results)
	local r = Config.rarity(rarityName)
	local c = plotCentre()
	if not c or not kept then
		return
	end
	-- the platform sits at the peak's centre; light a column there in the rarity colour when the
	-- on-screen orb bursts (RecruitReveal owns the sounds)
	local at = Config.revealBurst(rarityName)
	if results and #results > 1 then
		local _, burst = Config.revealMultiTimes(results)
		at = burst
	end
	task.delay(at, function()
		pillar(c + Vector3.new(0, 1.5, 0), r.color, 18 + r.bonus * 14, 1.2 + r.bonus * 0.3)
	end)
end)

-- pill swallowed
player:GetAttributeChangedSignal("BoostUntil"):Connect(function()
	if (player:GetAttribute("BoostUntil") or 0) > workspace:GetServerTimeNow() then
		Sfx.play("gulp")
		task.delay(0.35, function()
			Sfx.play("powerUp")
		end)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			pillar(hrp.Position - Vector3.new(0, 2.5, 0), Color3.fromHex("FFD36B"), 16, 1.2)
		end
	end
end)
