-- Relic Terrace (owner pick B 2026-10-26; mocks docs/art/mocks/2026-10-26_relic_*.png, script
-- tools/mock_relic_hall.luau): a small floating isle off the peak's west rim, bridged from the lawn, with
-- a marble terrace of ten plinths under a "Relics" gate. Finishing Sect Missions rank N earns
-- Config.MISSION_RELICS[N]: its plinth shows the relic in full colour for good (rebirths never reset
-- missions). The rest stand as dark glass silhouettes, so the player sees what is still to earn
-- (Animal Crossing museum stands). Phone budget (R16): ~10 parts a relic, no lights, two glow emitters.
-- Relics 1-3 and 5-9 are free Creator Store models (owner pick 2026-10-26, sheet
-- docs/art/mocks/2026-10-26_relic_candidates.png), scripts stripped, saved as assets/relics/RelicN.rbxm
-- (Rojo: ServerStorage.RelicModels; pivot = bottom centre, front +Z). A missing file falls back to the
-- part build below. The Jade Seal and the Dragon Pearl stay our own builds (no free model fit).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local RelicHall = {}

local PAL = Style.PAL
local hex = Color3.fromHex
local GOLD = hex("FFD24A")
local LOCKED = hex("1C2030")

-- peak frame: the isle's centre and radius, and the islet rim its bridge leaves from. Behind the heart,
-- bridged from the Fields islet's back rim (owner 2026-10-27: "sometimes blocks the users close to it":
-- at (-98, 69) the isle stood 11 studs into the straight line between two neighbouring peaks). Here it
-- clears every peak-to-peak and peak-to-hub line by 90+, the neighbours' islets by 140+, our islets and
-- lobes by 21+ and their bridges by 45+; the heart rim behind the Main Hall can't be walked to (the level 5
-- hall's back corners overhang it), so the bridge leaves from the Fields islet
local ISLE = Vector3.new(-37, 0, -110)
local ISLE_R = 22
local RIM = Vector3.new(-77.2, 0, -87)
local N = #Config.MISSION_RELICS

local function P(parent, size, cf, color, mat, shape)
	local p = Style.P(parent, size, cf, color, mat, shape)
	p.CastShadow = false
	return p
end
local function cylY(parent, h, d, cf, color, mat)
	return P(parent, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, Enum.PartType.Cylinder)
end
local function glow(parent, at, color, rate)
	local box = P(parent, Vector3.new(2, 3, 2), CFrame.new(at), Color3.new(1, 1, 1))
	box.Transparency = 1
	box.CanCollide = false
	box.CanQuery = false
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.4), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(2, 3)
	pe.Speed = NumberRange.new(0.5, 1)
	pe.Acceleration = Vector3.new(0, 1, 0)
	pe.Rate = rate or 6
	pe.Parent = box
	return pe
end

-- the ten relics in Config.MISSION_RELICS order; t = the top of the plinth
local RELICS = {
	function(m, t) -- Sect Broom
		P(m, Vector3.new(0.35, 4.2, 0.35), t * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, 0.15), PAL.timber)
		P(m, Vector3.new(1.8, 1.4, 0.6), t * CFrame.new(0.15, 0.7, 0), GOLD, Enum.Material.Foil)
	end,
	function(m, t) -- Practice Sword on a stand
		P(m, Vector3.new(2.4, 0.3, 0.8), t * CFrame.new(0, 0.15, 0), PAL.timberDark)
		P(m, Vector3.new(0.3, 4, 0.6), t * CFrame.new(0, 2.6, 0), hex("B98A55"), Enum.Material.Wood)
		P(m, Vector3.new(1.4, 0.3, 0.5), t * CFrame.new(0, 1.1, 0), PAL.timberDark)
	end,
	function(m, t) -- Incense Burner
		cylY(m, 1.6, 2.2, t * CFrame.new(0, 0.8, 0), hex("8C6A3A"), Enum.Material.Metal)
		cylY(m, 0.3, 2.6, t * CFrame.new(0, 1.7, 0), hex("B88A3A"), Enum.Material.Metal)
		P(m, Vector3.new(0.15, 1.6, 0.15), t * CFrame.new(0, 2.6, 0), hex("C0392B"))
	end,
	function(m, t) -- Jade Seal on a red silk cushion, a crouching beast knob, a red cord with a gold tassel
		local JADE = hex("5FBF94")
		P(m, Vector3.new(3.2, 0.5, 3.2), t * CFrame.new(0, 0.25, 0), hex("A3202A"), Enum.Material.Fabric)
		for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
			P(m, Vector3.new(0.35, 0.35, 0.35), t * CFrame.new(c[1] * 1.5, 0.4, c[2] * 1.5), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
		end
		P(m, Vector3.new(2.2, 1.5, 2.2), t * CFrame.new(0, 1.25, 0), JADE, Enum.Material.Glass)
		P(m, Vector3.new(2.3, 0.18, 2.3), t * CFrame.new(0, 1.98, 0), GOLD, Enum.Material.Metal)
		-- the beast: body, chest, head with ears, curled tail
		P(m, Vector3.new(1.1, 0.8, 1.6), t * CFrame.new(0, 2.5, -0.1), JADE, Enum.Material.Glass)
		P(m, Vector3.new(1, 1.1, 0.8), t * CFrame.new(0, 2.75, 0.55), JADE, Enum.Material.Glass)
		P(m, Vector3.new(0.9, 0.8, 0.8), t * CFrame.new(0, 3.5, 0.75), JADE, Enum.Material.Glass)
		for _, sx in { -1, 1 } do
			P(m, Vector3.new(0.25, 0.35, 0.2), t * CFrame.new(sx * 0.3, 4, 0.7), JADE, Enum.Material.Glass)
		end
		P(m, Vector3.new(0.5, 0.5, 0.5), t * CFrame.new(0, 3, -0.85), JADE, Enum.Material.Glass, Enum.PartType.Ball)
		P(m, Vector3.new(0.12, 1.2, 0.12), t * CFrame.new(1.2, 1.4, 0.9), hex("C0392B"))
		P(m, Vector3.new(0.35, 0.6, 0.35), t * CFrame.new(1.2, 0.65, 0.9), GOLD, Enum.Material.Fabric)
	end,
	function(m, t) -- Bronze Ding (three legs, two handles)
		cylY(m, 1.8, 2.8, t * CFrame.new(0, 1.5, 0), hex("8C6A3A"), Enum.Material.Metal)
		cylY(m, 0.3, 3.2, t * CFrame.new(0, 2.5, 0), hex("B88A3A"), Enum.Material.Metal)
		for k = 0, 2 do
			P(m, Vector3.new(0.4, 0.8, 0.4), t * CFrame.Angles(0, k * math.pi * 2 / 3, 0) * CFrame.new(0, 0.4, -1), hex("6E5230"), Enum.Material.Metal)
		end
		for _, s in { -1, 1 } do
			P(m, Vector3.new(0.3, 1, 0.9), t * CFrame.new(s * 1.2, 3.1, 0), hex("B88A3A"), Enum.Material.Metal)
		end
	end,
	function(m, t) -- Phoenix Fan
		for i = -3, 3 do
			P(m, Vector3.new(0.5, 3.6, 0.2), t * CFrame.Angles(0, 0, i * 0.22) * CFrame.new(0, 2, 0), hex("FFB04A"), Enum.Material.Foil)
		end
	end,
	function(m, t) -- Sect Scroll on a rack
		P(m, Vector3.new(3, 2.2, 0.15), t * CFrame.new(0, 2, 0) * CFrame.Angles(-0.25, 0, 0), hex("F3E6C4"), Enum.Material.Fabric)
		for _, s in { -1, 1 } do
			cylY(m, 2.6, 0.45, t * CFrame.new(s * 1.6, 2, 0) * CFrame.Angles(-0.25, 0, 0), PAL.timberDark)
		end
	end,
	function(m, t) -- Hall Bell in a frame
		for _, s in { -1, 1 } do
			P(m, Vector3.new(0.4, 4.4, 0.4), t * CFrame.new(s * 1.6, 2.2, 0), PAL.vermilion)
		end
		P(m, Vector3.new(4, 0.4, 0.5), t * CFrame.new(0, 4.4, 0), PAL.timberDark)
		cylY(m, 2.2, 2, t * CFrame.new(0, 2.9, 0), hex("8C6A3A"), Enum.Material.Metal)
	end,
	function(m, t) -- Sword in Stone
		P(m, Vector3.new(2.6, 1.4, 2.2), t * CFrame.new(0, 0.7, 0), PAL.rock, Enum.Material.Slate)
		P(m, Vector3.new(0.3, 4.4, 0.7), t * CFrame.new(0, 3.2, 0), hex("E4ECF2"), Enum.Material.Metal)
		P(m, Vector3.new(1.8, 0.3, 0.5), t * CFrame.new(0, 5, 0), GOLD, Enum.Material.Metal)
		glow(m, (t * CFrame.new(0, 3.5, 0)).Position, hex("CFE6FF"), 5)
	end,
	function(m, t) -- Dragon Pearl: a glowing pearl held up by a gold four-talon claw on a cloud base
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			P(m, Vector3.new(1.3, 0.8, 1.3), t * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.4, -0.9), hex("F4F1E6"), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
		cylY(m, 1.4, 0.7, t * CFrame.new(0, 1.2, 0), GOLD, Enum.Material.Metal)
		for k = 0, 3 do
			local claw = t * CFrame.Angles(0, k * math.pi / 2, 0)
			P(m, Vector3.new(0.35, 1.4, 0.35), claw * CFrame.new(0, 2.1, -0.6) * CFrame.Angles(-0.5, 0, 0), GOLD, Enum.Material.Metal)
			P(m, Vector3.new(0.3, 1, 0.3), claw * CFrame.new(0, 3.1, -1.05) * CFrame.Angles(0.35, 0, 0), GOLD, Enum.Material.Metal)
			P(m, Vector3.new(0.2, 0.5, 0.2), claw * CFrame.new(0, 3.75, -0.95) * CFrame.Angles(0.9, 0, 0), hex("FFF6D6"), Enum.Material.Metal)
		end
		P(m, Vector3.new(2, 2, 2), t * CFrame.new(0, 3.3, 0), hex("FFF2B0"), Enum.Material.Glass, Enum.PartType.Ball).Transparency = 0.2
		P(m, Vector3.new(1.1, 1.1, 1.1), t * CFrame.new(0, 3.3, 0), hex("FFC94A"), Enum.Material.Neon, Enum.PartType.Ball)
		glow(m, (t * CFrame.new(0, 3.3, 0)).Position, hex("FFE27A"), 6)
	end,
}

-- a Creator Store relic (ServerStorage.RelicModels.RelicN) fitted onto the plinth top `t`; false if absent
local FIT_W, FIT_H = 3.6, 4.6
local function placeModel(m, t, i)
	local folder = ServerStorage:FindFirstChild("RelicModels")
	local src = folder and folder:FindFirstChild("Relic" .. i)
	if not (src and src:IsA("Model")) then
		return false
	end
	local c = src:Clone()
	for _, d in c:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy() -- never run a script from a free model
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
		end
	end
	local size = c:GetExtentsSize()
	local k = math.min(FIT_W / math.max(size.X, size.Z, 0.1), FIT_H / math.max(size.Y, 0.1))
	c:ScaleTo(c:GetScale() * k)
	c:PivotTo(t)
	for _, d in c:GetChildren() do
		d.Parent = m
	end
	c:Destroy()
	return true
end

-- a locked relic: one dark glass shape (textures, decals and glows off)
local function silhouette(item)
	for _, d in item:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = LOCKED
			d.Material = Enum.Material.Glass
			d.Transparency = math.max(d.Transparency, 0.3)
			if d:IsA("MeshPart") then
				pcall(function()
					d.TextureID = ""
				end)
			end
		elseif d:IsA("Decal") then
			-- tinted, not removed: the Phoenix Fan is two decals on an invisible part (removed, the
			-- locked fan showed nothing at all)
			d.Color3 = LOCKED
			d.Transparency = math.max(d.Transparency, 0.3)
		elseif d:IsA("SurfaceAppearance") or d:IsA("SurfaceGui") then
			d:Destroy()
		elseif d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Light") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Sparkles") then
			d.Enabled = false -- Style.cauldron (relic 5) brings a Fire and a PointLight
		end
	end
end

-- Golden / Rainbow relics (Config.relicTiers; owner pick A 2026-10-27, copies Pet Simulator 99's Golden and
-- Rainbow pets): the whole relic turns gold foil, a Rainbow one cycles through the rainbow as one colour
-- (RelicGlow.client animates the parts tagged "RelicRainbow"; `RainbowSpread` = hue per stud of height).
local RAINBOW_SPARKS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, hex("FF5A5A")),
	ColorSequenceKeypoint.new(0.25, hex("FFD24A")),
	ColorSequenceKeypoint.new(0.5, hex("5AF08C")),
	ColorSequenceKeypoint.new(0.75, hex("5AB4FF")),
	ColorSequenceKeypoint.new(1, hex("C77DFF")),
})
local function paint(item, color, mat)
	for _, d in item:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			d.Color = color
			d.Material = mat
			if d:IsA("MeshPart") then
				pcall(function()
					d.TextureID = ""
				end)
			end
		elseif d:IsA("Decal") then
			d.Color3 = color
		elseif d:IsA("SurfaceAppearance") then
			d:Destroy()
		end
	end
end
local function rainbow(inst, spread)
	CollectionService:AddTag(inst, "RelicRainbow")
	inst:SetAttribute("RainbowSpread", spread)
end
local function tierLook(m, item, tier, at)
	local sparks = glow(m, at, GOLD, tier == "rainbow" and 10 or 7)
	if tier == "rainbow" then
		sparks.Color = RAINBOW_SPARKS
	end
	paint(item, GOLD, Enum.Material.Foil)
	if tier == "rainbow" then
		rainbow(item, 0)
	end
end

-- the isle's frame in the peak frame: +Z faces the bridge
local function isleFrame(plot)
	return plot.frame * CFrame.lookAt(ISLE, RIM) * CFrame.Angles(0, math.pi, 0)
end

-- plinth i's top-centre cf: front row 1-5 low, back row 6-10 two steps up and set half a gap over, so
-- every back relic and plaque shows between the front ones (Play check: a 1.6 rise hid them)
local function spot(at, i)
	local back = i > 5
	return at * CFrame.new((back and -9.625 or -12.375) + ((i - 1) % 5) * 5.5, back and 4 or 1.6, back and -4.5 or 3.5)
end

-- the isle, its bridge, the terrace and the gate: built once per peak (they never change)
function RelicHall.build(plot)
	if plot.relicIsle then
		return
	end
	local m = Instance.new("Model")
	m.Name = "RelicTerrace"
	local at = isleFrame(plot)
	local isle = Style.island(m, at, ISLE_R, 77, function(x, z) -- no boulders against the terrace
		return math.abs(x) < 20 and math.abs(z) < 12
	end, false)
	-- the lawn parts (green-led colours: top, lip, drips) wear the Sect Style ground (RelicHall.ground)
	for _, d in isle:GetDescendants() do
		if d:IsA("BasePart") and d.Color.G > d.Color.R and d.Color.G > d.Color.B then
			d:SetAttribute("Lawn", true)
		end
	end
	local rim = plot.frame * RIM
	Style.bridge(m, rim + Vector3.new(0, 0.05, 0), (at * Vector3.new(0, 0.05, ISLE_R - 3)), 6)
	-- two marble tiers, railing on the sides and back, the gate at the back
	P(m, Vector3.new(34, 1.6, 16), at * CFrame.new(0, 0.8, 0), PAL.stoneLight, Enum.Material.Marble)
	P(m, Vector3.new(34, 1.2, 8), at * CFrame.new(0, 2.2, -4), PAL.stoneLight, Enum.Material.Marble) -- a 1.2 step
	P(m, Vector3.new(34, 2.4, 6), at * CFrame.new(0, 2.8, -5), PAL.stoneLight, Enum.Material.Marble) -- and another
	P(m, Vector3.new(34.4, 0.25, 0.4), at * CFrame.new(0, 2.9, 0), PAL.gold, Enum.Material.Metal)
	P(m, Vector3.new(34.4, 0.25, 0.4), at * CFrame.new(0, 4.1, -2), PAL.gold, Enum.Material.Metal)
	P(m, Vector3.new(8, 0.8, 3), at * CFrame.new(0, 0.4, 9.5), PAL.stone) -- the step up from the bridge
	for _, s in { -1, 1 } do
		Kit.railing(m, (at * CFrame.new(s * 17, 4, -8)).Position, (at * CFrame.new(s * 17, 4, -2)).Position, 2)
		Kit.railing(m, (at * CFrame.new(s * 17, 1.6, 0)).Position, (at * CFrame.new(s * 17, 1.6, 8)).Position, 2)
		Kit.railing(m, (at * CFrame.new(s * 17, 4, -8)).Position, (at * CFrame.new(s * 8, 4, -8)).Position, 2)
	end
	Kit.gate(m, at * CFrame.new(0, 4, -8), 12, 11, "Relics")
	m.Parent = plot.folder
	plot.relicIsle = m
	RelicHall.ground(plot)
end

-- the isle's lawn in the peak's Sect Style ground (plot.styleGround = { material, colour }), or green
-- again with none (owner 2026-10-27: "relic place should follow general island style"). Main's
-- buildGrounds calls it whenever the peak's ground changes.
local lawnColours = {}
function RelicHall.ground(plot)
	if not plot.relicIsle then
		return
	end
	local sg = plot.styleGround
	for _, d in plot.relicIsle:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Lawn") then
			if not lawnColours[d] then
				lawnColours[d] = { d.Material, d.Color }
				d.Destroying:Connect(function()
					lawnColours[d] = nil
				end)
			end
			local was = lawnColours[d]
			d.Material = sg and sg[1] or was[1]
			d.Color = sg and sg[2] or was[2]
		end
	end
end

-- the ten plinths for `rank` (Sect Missions rank: relics 1 .. rank - 1 earned); `newest` = the index of
-- a relic just earned (a gold burst over it)
function RelicHall.show(plot, rank, newest)
	RelicHall.build(plot)
	if plot.relics then
		plot.relics:Destroy()
	end
	local earned, golden, rainbows = Config.relicTiers(rank)
	local f = Instance.new("Model")
	f.Name = "Relics"
	local at = isleFrame(plot)
	for i = 1, N do
		local t = spot(at, i)
		local m = Instance.new("Model")
		m.Name = "Relic" .. i
		P(m, Vector3.new(4.4, 0.6, 4.4), t * CFrame.new(0, 0.3, 0), PAL.stone)
		P(m, Vector3.new(3.4, 2.4, 3.4), t * CFrame.new(0, 1.8, 0), PAL.stoneLight, Enum.Material.Marble)
		local tier = i <= rainbows and "rainbow" or i <= golden and "golden" or nil
		P(m, Vector3.new(3.9, 0.4, 3.9), t * CFrame.new(0, 3.2, 0), i <= earned and PAL.gold or PAL.stone, Enum.Material.Metal)
		Kit.plaque(m, t * CFrame.new(0, 1.8, 1.85), 3, 0.7, i <= earned and Config.relicName(i, tier) or "Rank " .. (i + 1))
		local item = Instance.new("Model")
		item.Name = "Item"
		item.Parent = m
		if not placeModel(item, t * CFrame.new(0, 3.4, 0), i) then
			RELICS[i](item, t * CFrame.new(0, 3.4, 0))
		end
		if i > earned then
			silhouette(item)
		elseif tier then
			-- a relic drawn only with decals (the Phoenix Fan: decals on an invisible part) can't be painted,
			-- its texture stays dark under any tint: a Golden / Rainbow one is our own part build instead.
			-- Others just lose their decals (Play check: rebuilding the broom too left a 2-part stub)
			local solid = false
			for _, d in item:GetDescendants() do
				if d:IsA("BasePart") and d.Transparency < 1 then
					solid = true
					break
				end
			end
			if not solid then
				item:ClearAllChildren()
				RELICS[i](item, t * CFrame.new(0, 3.4, 0))
			else
				for _, d in item:GetDescendants() do
					if d:IsA("Decal") then
						d:Destroy()
					end
				end
			end
			tierLook(m, item, tier, (t * CFrame.new(0, 4.5, 0)).Position)
		end
		if i <= earned and i == newest then
			local burst = glow(m, (t * CFrame.new(0, 5, 0)).Position, GOLD, 0)
			burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.9), NumberSequenceKeypoint.new(1, 0) })
			burst.Speed = NumberRange.new(4, 8)
			burst.SpreadAngle = Vector2.new(180, 180)
			task.defer(function()
				burst:Emit(60)
			end)
		end
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanTouch = false
			end
		end
		m.Parent = f
	end
	f.Parent = plot.relicIsle
	plot.relics = f
end

return RelicHall
