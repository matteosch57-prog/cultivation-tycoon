-- Studio mock (2026-10-26, owner: "show me the same disciples in the different weather ... mock them and let
-- me choose"): three ways a weather mutation could read on a seated disciple, for screenshots only.
-- Run in Play, in the Server datamodel:
--   local run = <this file>; run(game.ServerScriptService.Server.Cultivators)
-- Builds workspace._MutMock high in the sky away from every pad: 3 rows (looks A / B / C) x 5 columns
-- (Plain, Dewy, Thunderborn, Bloodlit, Starforged), the SAME disciple everywhere (Elder, lotus look), 8
-- studs apart along +X, rows 10 studs apart along +Z, all facing -Z, a label in front of each:
--   A  Tint (live now): a light fill in the weather colour + its particles (Grow a Garden "shiny aura")
--   B  Recolour: the figure washed in the weather colour + its particles (Grow a Garden Bloodlit "red
--      appearance", Moonlit "purple appearance")
--   C  Element shell: a shimmering shell of the weather around the body + its particles (Grow a Garden
--      Frozen "encased in an ice block", Shocked "glowing neon effect around the surface")
-- Force a weather to see the same row under each sky (Weather.client draws it on every client):
--   workspace:SetAttribute("Weather", "thunder"); workspace:SetAttribute("WeatherUntil", workspace:GetServerTimeNow() + 120)
-- The player's own avatar is never moved. Remove: workspace._MutMock:Destroy().
return function(CultivatorsModule)
	local Cultivators = require(CultivatorsModule)
	local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
	local TweenService = game:GetService("TweenService")
	local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
	local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

	local old = workspace:FindFirstChild("_MutMock")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "_MutMock"
	root.Parent = workspace

	local ORIGIN = CFrame.new(0, 900, 0)
	local GAP, ROW = 8, 10
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(GAP * 6, 1, ROW * 3 + 6)
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromHex("3A3F47")
	floor.CFrame = ORIGIN * CFrame.new(GAP * 2, -0.5, ROW)
	floor.Parent = root

	-- the live particles per mutation (Main mutationGlow LOOKS)
	local FX = {
		Dewy = { Texture = SPARKLE, Rate = 8, Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(2, 4), Acceleration = Vector3.new(0, -14, 0), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(60, 60), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.2) }), Squash = NumberSequence.new(1.2) },
		Thunderborn = { Texture = SPARKLE, Rate = 14, Lifetime = NumberRange.new(0.12, 0.3), Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 0) }), Rotation = NumberRange.new(0, 360) },
		Bloodlit = { Texture = SMOKE, Rate = 6, Lifetime = NumberRange.new(1.6, 2.2), Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 2.6) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }), RotSpeed = NumberRange.new(-30, 30) },
		Starforged = { Texture = SPARKLE, Rate = 10, Lifetime = NumberRange.new(0.9, 1.4), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.75), NumberSequenceKeypoint.new(1, 0) }), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120) },
	}
	local function particles(m, w)
		local avatar = m:WaitForChild("Avatar", 10)
		local torso = avatar and (avatar:FindFirstChild("UpperTorso") or avatar.PrimaryPart)
		if not torso then
			return nil
		end
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(w.color:Lerp(Color3.new(1, 1, 1), 0.25), w.color)
		e.LightEmission, e.LightInfluence, e.Brightness, e.ZOffset = 0.7, 0, 2, 1
		for k, v in FX[w.mut] do
			e[k] = v
		end
		e.Parent = torso
		return avatar
	end
	local function highlight(m, avatar, w, fill, outline)
		local h = Instance.new("Highlight")
		h.Adornee = avatar
		h.FillColor = w.color
		h.FillTransparency = fill
		h.OutlineColor = w.color
		h.OutlineTransparency = outline
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = m
		return h
	end
	-- C: a shell round the seated body; Dewy is glassy water, the others the animated ForceField shimmer
	local function shell(m, cf, w)
		local p = Instance.new("Part")
		p.Name = "MutShell"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(5.2, 5.2, 5.2)
		p.CFrame = cf * CFrame.new(0, 2.6, 0)
		p.Color = w.color
		if w.mut == "Dewy" then
			p.Material = Enum.Material.Glass
			p.Transparency = 0.55
			p.Reflectance = 0.2
		else
			p.Material = Enum.Material.ForceField
			p.Transparency = 0
		end
		p.Parent = m
		if w.mut == "Thunderborn" then -- the shell flickers like a charge
			task.spawn(function()
				while p.Parent do
					p.Transparency = math.random() < 0.25 and 0.6 or 0
					task.wait(0.08 + math.random() * 0.15)
				end
			end)
		end
	end

	local looks = {
		{ text = "A Tint", apply = function(m, cf, w)
			local avatar = particles(m, w)
			if avatar then
				highlight(m, avatar, w, 0.72, 0.2)
			end
		end },
		{ text = "B Recolour", apply = function(m, cf, w)
			local avatar = particles(m, w)
			if avatar then
				local h = highlight(m, avatar, w, 0.35, 0)
				TweenService:Create(h, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { FillTransparency = 0.5 }):Play()
			end
		end },
		{ text = "C Shell", apply = function(m, cf, w)
			particles(m, w)
			shell(m, cf, w)
		end },
	}
	local cols = { false }
	for _, w in Config.WEATHERS do
		table.insert(cols, w)
	end

	local function label(cf, text)
		local lab = Instance.new("Part")
		lab.Anchored = true
		lab.CanCollide = false
		lab.Transparency = 1
		lab.Size = Vector3.new(6, 1.2, 0.2)
		lab.CFrame = cf
		lab.Parent = root
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.Parent = lab
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0
		t.Text = text
		t.Parent = g
	end

	local elder = Config.rarity("Elder")
	for r, look in looks do
		for c, w in cols do
			local cf = ORIGIN * CFrame.new((c - 1) * GAP, 0, (r - 1) * ROW)
			local m = Cultivators.build(root, cf, "lotus", elder, Config.RARITIES)
			if w then
				task.spawn(look.apply, m, cf, w)
			end
			label(cf * CFrame.new(0, 0.6, -4), (c == 1 and look.text .. " · " or "") .. (w and w.mut or "Plain"))
		end
	end
	return root
end
