-- The player's own aura (owner pick B 2026-10-22: realm aura + life beads, "make auras way better,
-- a bit like Warcraft 3 style"; research docs/research/2026-10-22_player_auras.md).
-- Realm aura: Super Power Fighting Simulator's rank aura (nobody buys it, none at the first rank,
-- it grows at every rank after) drawn the Warcraft 3 way: a glyph circle turning slowly on the
-- ground under the hero, light rising from it, in the realm colour the status title uses
-- (Config.realmColor). Each realm adds a layer: glyph and rising motes from realm 2, a counter-turning
-- rim ring from 3, rising wisps from 4, pulses spreading out from 6, flames up the body from 8.
-- Life beads: one bead per rebirth on a gold prayer-bead halo behind the head, kept forever. Every
-- Config.AURA_BEAD_BAND rebirths the beads change colour (Config.AURA_BEAD_COLORS: gold, crimson,
-- azure, violet, white jade), the new colour filling over the old, and grow, and the halo shines more.
-- No Highlight (the altar winner's gold rim stays its own) and no Light (R3): glowing particles and
-- neon beads only. Phone budget at the top: 7 emitters a player, ~110 live particles, 40 small parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlayerAura = {}

local TEX = "rbxasset://textures/particles/"
local WHITE = Color3.new(1, 1, 1)
local CHAIN = Color3.fromHex("B8862E")
local MAX_TIER = 9 -- realm 10 and up

local function seq(a, b, c)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.5, b), NumberSequenceKeypoint.new(1, c) })
end

-- fades in, holds, fades out: a flat glyph that is always there while two overlap
local HOLD = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.1), NumberSequenceKeypoint.new(0.75, 0.1), NumberSequenceKeypoint.new(1, 1) })

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function part(folder, name, size, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.CFrame = cf
	p.Parent = folder
	return p
end

-- an invisible part welded to `to` (emitter shapes take their size from a part)
local function holder(folder, to, name, size, cf)
	local p = part(folder, name, size, cf)
	p.Transparency = 1
	weld(to, p)
	return p
end

local function emitter(parent, props)
	local pe = Instance.new("ParticleEmitter")
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.EmissionDirection = Enum.NormalId.Top
	for k, v in props do
		pe[k] = v
	end
	pe.Parent = parent
	return pe
end

-- a flat emitter lying on the ground (particles face up: VelocityPerpendicular with a tiny upward speed)
local function flat(parent, props)
	props.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	props.Speed = NumberRange.new(0.01)
	return emitter(parent, props)
end

-- the realm aura: tier 0 (realm 1) none, up to MAX_TIER
local function realmAura(folder, hrp, hum, tier, color)
	local feet = hrp.CFrame * CFrame.new(0, -(hrp.Size.Y / 2 + hum.HipHeight) + 0.15, 0)
	local k = (tier - 1) / (MAX_TIER - 1) -- 0 at realm 2, 1 at realm 10
	local pale = color:Lerp(WHITE, 0.55)
	local R = 7 + 4 * k -- glyph diameter, studs
	local ground = holder(folder, hrp, "AuraGround", Vector3.new(1, 0.1, 1), feet)
	-- the glyph: two overlapping at any time, turning slowly
	local glyph = flat(ground, {
		Name = "Glyph",
		Texture = TEX .. "forcefield_vortex_main.dds",
		Color = ColorSequence.new(color, pale),
		Size = NumberSequence.new(R),
		Transparency = HOLD,
		Brightness = 2.5 + k,
		Lifetime = NumberRange.new(4),
		Rate = 0.6,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(25),
	})
	task.defer(glyph.Emit, glyph, 1) -- on screen at once, not after the first emit tick (realms 2-3 looked empty)
	-- motes rising from the circle's edge
	local rim = holder(folder, hrp, "AuraRim", Vector3.new(R * 0.8, 0.1, R * 0.8), feet)
	emitter(rim, {
		Name = "Motes",
		Texture = TEX .. "sparkles_main.dds",
		Color = ColorSequence.new(pale, color),
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = seq(0, 0.6 + 0.4 * k, 0),
		Transparency = NumberSequence.new(0.05),
		Brightness = 2,
		Lifetime = NumberRange.new(1.4, 2.2),
		Speed = NumberRange.new(2, 3.5 + 2 * k),
		Drag = 0.6,
		Rate = 8 + 10 * k,
	})
	if tier >= 2 then
		-- a wider ring turning the other way
		flat(ground, {
			Name = "Ring",
			Texture = TEX .. "explosion01_shockwave_main.dds",
			Color = ColorSequence.new(pale),
			Size = NumberSequence.new(R * 1.25),
			Transparency = HOLD,
			Brightness = 1.5,
			Lifetime = NumberRange.new(5),
			Rate = 0.45,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-15),
		})
	end
	if tier >= 3 then
		-- soft wisps rising round the body (Warcraft 3's Unholy Aura)
		local body = holder(folder, hrp, "AuraWisps", Vector3.new(3.6, 0.1, 3.6), feet)
		emitter(body, {
			Name = "Wisps",
			Texture = TEX .. "smoke_main.dds",
			Color = ColorSequence.new(color, pale),
			Shape = Enum.ParticleEmitterShape.Cylinder,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Size = seq(1.2, 1.6 + 1 * k, 0.3),
			Transparency = seq(0.5, 0.35, 1),
			Brightness = 1.5,
			Lifetime = NumberRange.new(1.2, 1.8),
			Speed = NumberRange.new(0.5, 1),
			Acceleration = Vector3.new(0, 5 + 4 * k, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-40, 40),
			Rate = 10 + 10 * k,
		})
	end
	if tier >= 5 then
		-- a pulse spreading out over the ground
		flat(ground, {
			Name = "Pulse",
			Texture = TEX .. "explosion01_shockwave_main.dds",
			Color = ColorSequence.new(color),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, R * 1.6) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Brightness = 2,
			Lifetime = NumberRange.new(1.4),
			Rate = 0.7,
		})
	end
	if tier >= 7 then
		-- flames licking up the body
		local base = holder(folder, hrp, "AuraFlames", Vector3.new(3.2, 0.1, 3.2), feet * CFrame.new(0, 0.3, 0))
		emitter(base, {
			Name = "Flames",
			Texture = TEX .. "fire_main.dds",
			Color = ColorSequence.new(pale, color),
			Shape = Enum.ParticleEmitterShape.Cylinder,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			Size = seq(1.8, 1.4, 0),
			Transparency = seq(0.2, 0.2, 1),
			Brightness = 2,
			Lifetime = NumberRange.new(0.6, 0.9),
			Speed = NumberRange.new(1, 2),
			Acceleration = Vector3.new(0, 10, 0),
			Rate = 22 + 8 * (tier - 7),
		})
	end
end

-- what the beads show after `rebirths`: the band (1..#colors), how many beads already wear its colour
function PlayerAura.beads(rebirths)
	local n, B = math.max(0, rebirths or 0), Config.AURA_BEAD_BAND
	local top = #Config.AURA_BEAD_COLORS
	if n <= 0 then
		return 0, 0
	end
	local band = math.min(math.ceil(n / B), top)
	return band, math.min(n - (band - 1) * B, B)
end

-- the prayer-bead halo behind the head: AURA_BEAD_BAND slots on a gold chain, `lit` of them in the
-- band's colour, the rest in the band before (empty sockets in the first band)
local function halo(folder, head, rebirths)
	local band, lit = PlayerAura.beads(rebirths)
	if band == 0 then
		return
	end
	local B = Config.AURA_BEAD_BAND
	local colors = Config.AURA_BEAD_COLORS
	local R = 1.55
	local size = 0.3 + 0.04 * band
	local centre = head.CFrame * CFrame.new(0, 0.25, 0.8) -- behind the head (+Z is the back)
	local function at(i)
		local a = math.rad(i * 360 / B) -- slot 0 on top, clockwise seen from the front
		return centre * CFrame.new(-math.sin(a) * R, math.cos(a) * R, 0)
	end
	for i = 0, B - 1 do
		-- the chain link to the next slot
		local p0, p1 = at(i).Position, at(i + 1).Position
		local link = part(folder, "Chain", Vector3.new(0.07, 0.07, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1))
		link.Color = CHAIN
		link.Material = Enum.Material.Metal
		weld(head, link)
		-- the bead
		local own = i < lit
		if own or band > 1 then
			local b = part(folder, "LifeBead", Vector3.one * size, at(i))
			b.Shape = Enum.PartType.Ball
			b.Material = Enum.Material.Neon
			b.Color = own and colors[band] or colors[band - 1]
			weld(head, b)
		end
	end
	if band >= 2 then
		-- the halo shines more each band
		local box = holder(folder, head, "HaloShine", Vector3.new(R * 2, R * 2, 0.2), centre)
		emitter(box, {
			Name = "Shine",
			Texture = TEX .. "sparkles_main.dds",
			Color = ColorSequence.new(WHITE, colors[band]),
			Shape = Enum.ParticleEmitterShape.Box,
			Size = seq(0, 0.5 + 0.12 * band, 0),
			Transparency = NumberSequence.new(0.05),
			Brightness = 2,
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(0.2, 0.6),
			Rotation = NumberRange.new(0, 360),
			Rate = 3 * band,
		})
	end
end

function PlayerAura.clear(char)
	local old = char:FindFirstChild("PlayerAura")
	if old then
		old:Destroy()
	end
end

-- builds the aura on `char` for a player at `realm` with `rebirths` rebirths
function PlayerAura.build(char, realm, rebirths)
	PlayerAura.clear(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	local head = char:FindFirstChild("Head")
	if not hrp or not hum or not head then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "PlayerAura"
	local tier = math.min(realm or 1, MAX_TIER + 1) - 1
	if tier >= 1 then
		realmAura(folder, hrp, hum, tier, Config.realmColor(realm))
	end
	halo(folder, head, rebirths)
	if #folder:GetChildren() == 0 then
		folder:Destroy()
		return
	end
	folder.Parent = char
end

-- the aura for `player` from its Realm and Lives attributes
function PlayerAura.refresh(player)
	local char = player.Character
	local realm = player:GetAttribute("Realm")
	if not char or not realm then
		return
	end
	PlayerAura.build(char, realm, (player:GetAttribute("Lives") or 1) - 1)
end

-- every player, now and later: built on each spawn (again once the avatar's look has loaded, which
-- can change its height) and whenever the realm or the life changes
function PlayerAura.start()
	local Players = game:GetService("Players")
	local function watch(player)
		local function spawned(char)
			char:WaitForChild("HumanoidRootPart", 10)
			char:WaitForChild("Head", 10)
			PlayerAura.refresh(player)
		end
		player.CharacterAdded:Connect(spawned)
		player.CharacterAppearanceLoaded:Connect(function()
			PlayerAura.refresh(player)
		end)
		player:GetAttributeChangedSignal("Realm"):Connect(function()
			PlayerAura.refresh(player)
		end)
		player:GetAttributeChangedSignal("Lives"):Connect(function()
			PlayerAura.refresh(player)
		end)
		if player.Character then
			task.spawn(spawned, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end
end

return PlayerAura
