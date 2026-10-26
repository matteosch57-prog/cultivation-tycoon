-- Relic Terrace (owner pick B 2026-10-26; mocks docs/art/mocks/2026-10-26_relic_*.png, script
-- tools/mock_relic_hall.luau): a small floating isle off the peak's west rim, bridged from the lawn, with
-- a marble terrace of ten plinths under a "Relics" gate. Finishing Sect Missions rank N earns
-- Config.MISSION_RELICS[N]: its plinth shows the relic in full colour for good (rebirths never reset
-- missions). The rest stand as dark glass silhouettes, so the player sees what is still to earn
-- (Animal Crossing museum stands). Phone budget (R16): ~10 parts a relic, no lights, two glow emitters.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local RelicHall = {}

local PAL = Style.PAL
local hex = Color3.fromHex
local GOLD = hex("FFD24A")
local LOCKED = hex("1C2030")

-- peak frame: the isle's centre and radius, and the free lawn rim its bridge leaves from (clear of the
-- pads, the hub portal at (-27, r - 12) and the incense shrine; checked against Config.ISLETS)
local ISLE = Vector3.new(-98, 0, 69)
local ISLE_R = 22
local RIM = Vector3.new(-56.5, 0, 39.6)
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
	function(m, t) -- Golden Broom
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
	function(m, t) -- Jade Seal with a beast knob
		P(m, Vector3.new(2.4, 1.8, 2.4), t * CFrame.new(0, 0.9, 0), PAL.jade, Enum.Material.Glass)
		P(m, Vector3.new(1.4, 1.4, 1.4), t * CFrame.new(0, 2.5, 0), PAL.jade, Enum.Material.Glass, Enum.PartType.Ball)
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
	function(m, t) -- Dragon Pearl in a gold coil
		P(m, Vector3.new(2.2, 2.2, 2.2), t * CFrame.new(0, 2.4, 0), hex("FFF2B0"), Enum.Material.Glass, Enum.PartType.Ball)
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			P(m, Vector3.new(0.5, 0.5, 0.9), t * CFrame.new(0, 1 + i * 0.25, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.5), GOLD, Enum.Material.Metal)
		end
		glow(m, (t * CFrame.new(0, 2.4, 0)).Position, hex("FFE27A"), 6)
	end,
}

-- the isle's frame in the peak frame: +Z faces the bridge
local function isleFrame(plot)
	return plot.frame * CFrame.lookAt(ISLE, RIM) * CFrame.Angles(0, math.pi, 0)
end

-- plinth i's top-centre cf: front row 1-5 low, back row 6-10 a step up
local function spot(at, i)
	local back = i > 5
	return at * CFrame.new(-12 + ((i - 1) % 5) * 6, back and 3.2 or 1.6, back and -3.5 or 3.5)
end

-- the isle, its bridge, the terrace and the gate: built once per peak (they never change)
function RelicHall.build(plot)
	if plot.relicIsle then
		return
	end
	local m = Instance.new("Model")
	m.Name = "RelicTerrace"
	local at = isleFrame(plot)
	Style.island(m, at, ISLE_R, 77, nil, false)
	local rim = plot.frame * RIM
	Style.bridge(m, rim + Vector3.new(0, 0.05, 0), (at * Vector3.new(0, 0.05, ISLE_R - 3)), 6)
	-- two marble tiers, railing on the sides and back, the gate at the back
	P(m, Vector3.new(34, 1.6, 16), at * CFrame.new(0, 0.8, 0), PAL.stoneLight, Enum.Material.Marble)
	P(m, Vector3.new(34, 1.6, 7), at * CFrame.new(0, 2.4, -4.5), PAL.stoneLight, Enum.Material.Marble)
	P(m, Vector3.new(34.4, 0.25, 0.4), at * CFrame.new(0, 3.3, -1), PAL.gold, Enum.Material.Metal)
	P(m, Vector3.new(8, 0.8, 3), at * CFrame.new(0, 0.4, 9.5), PAL.stone) -- the step up from the bridge
	for _, s in { -1, 1 } do
		Kit.railing(m, (at * CFrame.new(s * 17, 3.2, -8)).Position, (at * CFrame.new(s * 17, 3.2, -1)).Position, 2)
		Kit.railing(m, (at * CFrame.new(s * 17, 1.6, -1)).Position, (at * CFrame.new(s * 17, 1.6, 8)).Position, 2)
		Kit.railing(m, (at * CFrame.new(s * 17, 3.2, -8)).Position, (at * CFrame.new(s * 8, 3.2, -8)).Position, 2)
	end
	Kit.gate(m, at * CFrame.new(0, 3.2, -8), 12, 11, "Relics")
	m.Parent = plot.folder
	plot.relicIsle = m
end

-- the ten plinths for `rank` (Sect Missions rank: relics 1 .. rank - 1 earned); `newest` = the index of
-- a relic just earned (a gold burst over it)
function RelicHall.show(plot, rank, newest)
	RelicHall.build(plot)
	if plot.relics then
		plot.relics:Destroy()
	end
	local earned = math.clamp((rank or 1) - 1, 0, N)
	local f = Instance.new("Model")
	f.Name = "Relics"
	local at = isleFrame(plot)
	for i = 1, N do
		local t = spot(at, i)
		local m = Instance.new("Model")
		m.Name = "Relic" .. i
		P(m, Vector3.new(4.4, 0.6, 4.4), t * CFrame.new(0, 0.3, 0), PAL.stone)
		P(m, Vector3.new(3.4, 2.4, 3.4), t * CFrame.new(0, 1.8, 0), PAL.stoneLight, Enum.Material.Marble)
		P(m, Vector3.new(3.9, 0.4, 3.9), t * CFrame.new(0, 3.2, 0), i <= earned and PAL.gold or PAL.stone, Enum.Material.Metal)
		Kit.plaque(m, t * CFrame.new(0, 1.8, 1.85), 3, 0.7, i <= earned and Config.MISSION_RELICS[i] or "Rank " .. (i + 1))
		local item = Instance.new("Model")
		item.Name = "Item"
		item.Parent = m
		RELICS[i](item, t * CFrame.new(0, 3.4, 0))
		if i > earned then
			for _, d in item:GetDescendants() do
				if d:IsA("BasePart") then
					d.Color = LOCKED
					d.Material = Enum.Material.Glass
					d.Transparency = math.max(d.Transparency, 0.3)
				elseif d:IsA("ParticleEmitter") then
					d.Enabled = false
				end
			end
		elseif i == newest then
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
