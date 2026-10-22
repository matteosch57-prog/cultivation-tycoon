-- The player's own aura (owner 2026-10-22: "give the user auras based on realms and or
-- reincarnation"; research docs/research/2026-10-22_player_auras.md). Super Power Fighting
-- Simulator's rank aura, copied: nobody buys it, it appears by itself from the second rank and
-- grows in steps (wisps, then flames, then sparks), in the rank's colour. Ours follows the realm in
-- the realm colour the status title already uses (Config.realmColor). Style "B" adds the lives: one
-- gold bead per rebirth on a halo behind the head, which a rebirth never takes back. Style "C"
-- grows the aura with the lives instead of the realm.
-- No Highlight (the altar winner's gold rim stays its own) and no Light (R3): glowing particles and
-- small neon beads only. Phone budget: at most 3 emitters a player, ~110 live particles at the top
-- step (2x the first mock, which read too faint past 30 studs: docs/art/mocks/2026-10-22_aura_row*).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlayerAura = {}

local TEX = "rbxasset://textures/particles/"
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromHex("FFD36A")
local MAX_TIER = 10
local MAX_BEADS = 9

local function seq(a, b, c)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.5, b), NumberSequenceKeypoint.new(1, c) })
end

-- an invisible, weightless part welded to the root (emitter shapes need a part to take their size from)
local function holder(folder, hrp, name, size, offset)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.CFrame = hrp.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = hrp
	w.Part1 = p
	w.Parent = p
	p.Parent = folder
	return p
end

local function emitter(parent, props)
	local pe = Instance.new("ParticleEmitter")
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Shape = Enum.ParticleEmitterShape.Cylinder
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	pe.EmissionDirection = Enum.NormalId.Top
	for k, v in props do
		pe[k] = v
	end
	pe.Parent = parent
	return pe
end

-- what style `style` shows for a player at `realm` in life `lives`: tier (0 = none), colour, beads
function PlayerAura.look(style, realm, lives)
	realm, lives = realm or 1, lives or 1
	if style == "C" then
		return math.min(lives, MAX_TIER) - 1, Config.RARITIES[math.min(lives, #Config.RARITIES)].color, 0
	end
	local beads = style == "B" and math.min(lives - 1, MAX_BEADS) or 0
	return math.min(realm, MAX_TIER) - 1, Config.realmColor(realm), beads
end

function PlayerAura.clear(char)
	local old = char:FindFirstChild("PlayerAura")
	if old then
		old:Destroy()
	end
end

-- builds the aura on `char`: tier 0 none, 1 wisps, 3 + flames, 5 + sparks, growing to tier 9
function PlayerAura.build(char, tier, color, beads)
	PlayerAura.clear(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or (tier <= 0 and (beads or 0) <= 0) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "PlayerAura"
	local feet = -(hrp.Size.Y / 2 + hum.HipHeight) -- from the root's centre down to the ground
	local k = (tier - 1) / (MAX_TIER - 2) -- 0 at tier 1, 1 at tier 9
	local tint = ColorSequence.new(color, color:Lerp(WHITE, 0.6))

	if tier >= 1 then
		-- wisps rising from a ring round the feet
		local r = 4.2 + 1.4 * k
		local ring = holder(folder, hrp, "AuraRing", Vector3.new(r, 0.2, r), CFrame.new(0, feet + 0.2, 0))
		emitter(ring, {
			Name = "Wisps",
			Texture = TEX .. "smoke_main.dds",
			Color = tint,
			Size = seq(1.2, 1.8 + 1.2 * k, 0.4),
			Transparency = seq(0.35, 0.2 - 0.1 * k, 1),
			Brightness = 2,
			Lifetime = NumberRange.new(0.9 + 0.5 * k, 1.3 + 0.6 * k),
			Speed = NumberRange.new(0.4, 0.8),
			Acceleration = Vector3.new(0, 4 + 4 * k, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-40, 40),
			Rate = 16 + 14 * k,
		})
	end
	if tier >= 3 then
		-- flames licking up the body
		local r = 3 + 1 * k
		local base = holder(folder, hrp, "AuraFlames", Vector3.new(r, 0.2, r), CFrame.new(0, feet + 0.4, 0))
		emitter(base, {
			Name = "Flames",
			Texture = TEX .. "fire_main.dds",
			Color = ColorSequence.new(color:Lerp(WHITE, 0.35), color),
			Size = seq(1.6 + 0.8 * k, 1.3 + 0.8 * k, 0),
			Transparency = seq(0.15, 0.15, 1),
			Brightness = 2,
			Lifetime = NumberRange.new(0.5, 0.7 + 0.4 * k),
			Speed = NumberRange.new(1, 2),
			Acceleration = Vector3.new(0, 6 + 6 * k, 0),
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			Rate = 18 + 16 * k,
		})
	end
	if tier >= 5 then
		-- sparks twinkling round the whole body
		local shell = holder(folder, hrp, "AuraSparks", Vector3.new(4.5, 6, 4.5), CFrame.new(0, feet + 3, 0))
		emitter(shell, {
			Name = "Sparks",
			Texture = TEX .. "sparkles_main.dds",
			Color = ColorSequence.new(WHITE, color),
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Size = seq(0, 0.7 + 0.5 * k, 0),
			Transparency = NumberSequence.new(0.05),
			Brightness = 2,
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(0.5, 1.5),
			Drag = 2,
			Rotation = NumberRange.new(0, 360),
			Rate = 6 + 8 * k,
		})
	end

	-- lives: one gold bead per rebirth on a halo behind the head, spreading from the top to the sides
	local head = char:FindFirstChild("Head")
	if head and (beads or 0) > 0 then
		local R = 1.35
		for i = 1, beads do
			local a = math.rad((i - 1) * 30 - (beads - 1) * 15) -- 30 degrees apart, centred on the top
			local b = Instance.new("Part")
			b.Name = "LifeBead"
			b.Shape = Enum.PartType.Ball
			b.Size = Vector3.new(0.38, 0.38, 0.38)
			b.Material = Enum.Material.Neon
			b.Color = GOLD
			b.CanCollide = false
			b.CanQuery = false
			b.CanTouch = false
			b.CastShadow = false
			b.Massless = true
			b.CFrame = head.CFrame * CFrame.new(math.sin(a) * R, 0.15 + math.cos(a) * R, 0.75)
			local w = Instance.new("WeldConstraint")
			w.Part0 = head
			w.Part1 = b
			w.Parent = b
			b.Parent = folder
		end
	end
	folder.Parent = char
end

-- the aura for `player` from its Realm and Lives attributes, in Config.PLAYER_AURA_STYLE
function PlayerAura.refresh(player, style)
	local char = player.Character
	if not char or not player:GetAttribute("Realm") then
		return
	end
	local tier, color, beads = PlayerAura.look(style or Config.PLAYER_AURA_STYLE, player:GetAttribute("Realm"), player:GetAttribute("Lives"))
	PlayerAura.build(char, tier, color, beads)
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
