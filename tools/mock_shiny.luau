-- Studio mock (2026-10-23, owner: "mock it yes"): how a Shiny disciple could read in the 3D world,
-- for screenshots only. Run in Play, in the Server datamodel:
--   local run = <this file>; run(game.ServerScriptService.Server.Cultivators)
-- Builds workspace._ShinyMock high in the sky away from every pad: a row of 4 seated Elder lotus
-- disciples, 8 studs apart along +X, facing -Z (their front), a label in front of each:
--   Now  the live look: a slow drift of sparkles off the cushion
--   A    glitter (Pet Simulator 99's Shiny pets): fine sparkles all over the body, always on
--   B    gold rim: a soft gold outline that breathes (Highlight) + a few sparkles
--   C    glint ring: a ring of gold glints rising from the cushion + a star burst over the head every 2 s
-- The player's own avatar is never moved. Remove: workspace._ShinyMock:Destroy().
return function(CultivatorsModule)
	local Cultivators = require(CultivatorsModule)
	local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
	local TweenService = game:GetService("TweenService")
	local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
	local GOLD = Color3.fromHex("FFD34D")
	local WARM = Color3.fromRGB(255, 250, 220)

	local old = workspace:FindFirstChild("_ShinyMock")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "_ShinyMock"
	root.Parent = workspace

	local ORIGIN = CFrame.new(0, 900, 0)
	local GAP = 8
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(GAP * 5, 1, 20)
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromHex("3A3F47")
	floor.CFrame = ORIGIN * CFrame.new(GAP * 1.5, -0.5, 0)
	floor.Parent = root

	local function emitter(parent, props)
		local e = Instance.new("ParticleEmitter")
		e.Texture = SPARKLE
		e.LightEmission = 1
		e.Color = ColorSequence.new(WARM)
		for k, v in props do
			e[k] = v
		end
		e.Parent = parent
		return e
	end
	-- an invisible box over the seated body (the glitter's volume)
	local function bodyBox(m, cf)
		local p = Instance.new("Part")
		p.Name = "ShinyVolume"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Transparency = 1
		p.Size = Vector3.new(2.6, 3.4, 1.8)
		p.CFrame = cf * CFrame.new(0, 2.4, 0)
		p.Parent = m
		return p
	end

	local styles = {
		{ text = "Now", fx = function(m, cf)
			local a = Instance.new("Attachment")
			a.Parent = m:FindFirstChild("Cushion")
			emitter(a, { Rate = 4, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) }) })
		end },
		{ text = "A  Glitter", fx = function(m, cf)
			local box = bodyBox(m, cf)
			emitter(box, {
				Shape = Enum.ParticleEmitterShape.Box,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				Rate = 26,
				Lifetime = NumberRange.new(0.35, 0.7),
				Speed = NumberRange.new(0, 0.2),
				Rotation = NumberRange.new(0, 360),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.32), NumberSequenceKeypoint.new(1, 0) }),
				Color = ColorSequence.new(WARM, GOLD),
			})
		end },
		{ text = "B  Gold rim", fx = function(m, cf)
			local h = Instance.new("Highlight")
			h.Adornee = m
			h.FillColor = GOLD
			h.FillTransparency = 0.88
			h.OutlineColor = GOLD
			h.OutlineTransparency = 0.15
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = m
			TweenService:Create(h, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { OutlineTransparency = 0.7, FillTransparency = 0.96 }):Play()
			local box = bodyBox(m, cf)
			emitter(box, { Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Rate = 5, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0, 0.3), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 0) }) })
		end },
		{ text = "C  Glint ring", fx = function(m, cf)
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.Transparency = 1
			p.Size = Vector3.new(4.4, 0.2, 4.4)
			p.CFrame = cf * CFrame.new(0, 0.6, 0)
			p.Parent = m
			emitter(p, {
				Shape = Enum.ParticleEmitterShape.Cylinder,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
				EmissionDirection = Enum.NormalId.Top,
				Rate = 16,
				Lifetime = NumberRange.new(0.9, 1.3),
				Speed = NumberRange.new(1.2, 1.8),
				SpreadAngle = Vector2.new(0, 0),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
				Color = ColorSequence.new(GOLD),
			})
			local top = Instance.new("Attachment")
			top.Position = Vector3.new(0, 5.4, 0)
			top.Parent = p
			local burst = emitter(top, { Rate = 0, Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(2, 3.5), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }), Color = ColorSequence.new(WARM, GOLD) })
			task.spawn(function()
				while burst.Parent do
					burst:Emit(7)
					task.wait(2)
				end
			end)
		end },
	}

	local elder = Config.rarity("Elder")
	for i, st in styles do
		local cf = ORIGIN * CFrame.new((i - 1) * GAP, 0, 0)
		local m = Cultivators.build(root, cf, "lotus", elder, Config.RARITIES)
		st.fx(m, cf)
		-- the label in front of the disciple (its front faces -Z)
		local lab = Instance.new("Part")
		lab.Anchored = true
		lab.CanCollide = false
		lab.Transparency = 1
		lab.Size = Vector3.new(4, 1, 0.2)
		lab.CFrame = cf * CFrame.new(0, 0.6, -4)
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
		t.Text = st.text
		t.Parent = g
	end
	return root
end
