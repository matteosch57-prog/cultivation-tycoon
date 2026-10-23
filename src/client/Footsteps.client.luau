-- Footsteps: a step sound per surface for every character near the camera (owner 2026-10-22 "let's do it
-- all"; ported from Gladiator RNG D247, its Play-tested lessons kept):
--  * Roblox's stock RbxCharacterSounds keeps running (a same-named override is replaced at Play start), so
--    its sounds on every character's root are routed into a muted SoundGroup instead.
--  * The surface is read by a short ray under the root (works for remote characters too, whose
--    FloorMaterial is not simulated here; RespectCanCollide so walk-through parts are not the floor).
--  * Timing is a cadence from the ground speed, not the animation (avatar animation packs differ).
--  * A landing after Config.STEPS.landMinAir in the air = a louder double step.
-- Sounds: regions of the Kenney CC0 step atlas (Config.STEPS.atlas), all in the SFX group.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local PerfMark = require(Shared:WaitForChild("PerfMark"))

Sfx.init()

local C = Config.STEPS
local POOL = 3 -- sounds per character: a landing's double step + the next step can overlap
local GROUND_SLACK = 0.9 -- studs below the feet still counted as standing (a step down a stair)

local rigs = {} -- [player] = rig
local rng = Random.new()

-- the stock character sounds (RbxCharacterSounds' names), silenced by a zero-volume group
local STOCK = {
	Climbing = true, Died = true, FreeFalling = true, GettingUp = true, Jumping = true, Landing = true,
	Running = true, Splash = true, Swimming = true,
}
local muted = Instance.new("SoundGroup")
muted.Name = "StockMuted"
muted.Volume = 0
muted.Parent = SoundService

local function muteStock(inst)
	if inst:IsA("Sound") and STOCK[inst.Name] then
		inst.SoundGroup = muted
	end
end

local function watchCharacter(char)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if root then
		for _, s in root:GetChildren() do
			muteStock(s)
		end
		root.ChildAdded:Connect(muteStock) -- dies with the character
	end
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
end

local function jitter(amount)
	return 1 + (rng:NextNumber() * 2 - 1) * amount
end

local function pickVariant(rig, set, count)
	local i = rng:NextInteger(1, count)
	if count > 1 and i == rig.last[set] then
		i = i % count + 1 -- never the same clip twice in a row
	end
	rig.last[set] = i
	return i
end

-- the floor under the root: its material, or nil in the air
local function floorUnder(rig)
	local reach = rig.hum.HipHeight + rig.root.Size.Y / 2 + GROUND_SLACK
	local hit = workspace:Raycast(rig.root.Position, Vector3.new(0, -reach, 0), rig.ray)
	return hit and hit.Material or nil
end

local function step(rig, loud)
	local material = floorUnder(rig)
	if not material then
		return
	end
	local surface = C.surfaces[C.materials[material.Name] or "stone"]
	local regions = C.sets[surface[1]]
	local region = regions[pickVariant(rig, surface[1], #regions)]
	local s = rig.pool[rig.slot]
	rig.slot = rig.slot % POOL + 1
	s:Stop()
	s.PlaybackRegion = NumberRange.new(region[1], region[2])
	s.TimePosition = region[1]
	s.PlaybackSpeed = surface[2] * jitter(C.pitchJitter)
	s.Volume = C.volume * surface[3] * loud * jitter(C.volumeJitter)
	s:Play()
end

local function land(rig)
	step(rig, C.landVolume)
	task.delay(0.035, function()
		if rig.char.Parent then
			step(rig, C.landVolume * 0.8)
		end
	end)
end

local function makeRig(char, hum, root)
	local sfx = SoundService:WaitForChild("SFX")
	local pool = {}
	for i = 1, POOL do
		local s = Instance.new("Sound")
		s.Name = "Footstep" .. i
		s.SoundId = C.atlas
		s.PlaybackRegionsEnabled = true
		s.SoundGroup = sfx
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = C.rollOffMin
		s.RollOffMaxDistance = C.range
		s.Parent = root
		pool[i] = s
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { char }
	ray.RespectCanCollide = true
	local rig
	rig = {
		char = char, hum = hum, root = root, pool = pool, slot = 1, cycle = nil, airSince = nil, last = {}, ray = ray,
		jumpConn = hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				step(rig, 0.7) -- the push-off
			end
		end),
	}
	return rig
end

local function dropRig(player)
	local rig = rigs[player]
	if rig then
		rig.jumpConn:Disconnect()
		for _, s in rig.pool do
			s:Destroy()
		end
		rigs[player] = nil
	end
end

local function update(rig, dt, now)
	if rig.hum.Health <= 0 then
		return
	end
	if floorUnder(rig) == nil then
		rig.airSince = rig.airSince or now
		rig.cycle = nil
		return
	end
	if rig.airSince then
		local air = now - rig.airSince
		rig.airSince = nil
		if air >= C.landMinAir then
			land(rig)
			rig.cycle = 0 -- the landing was the step: the next one waits a full cycle
			return
		end
	end
	local v = rig.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	if speed < C.minSpeed then
		rig.cycle = nil
		return
	end
	local cycle = (rig.cycle or C.firstStep) + (C.cadenceBase + C.cadencePerSpeed * speed) * dt
	if cycle >= 1 then
		cycle = math.min(cycle - 1, 0.5) -- one step a frame, even after a hitch
		step(rig, 1)
	end
	rig.cycle = cycle
end

task.spawn(function() -- warm the atlas so the first step is not late
	local s = Instance.new("Sound")
	s.SoundId = C.atlas
	pcall(function()
		ContentProvider:PreloadAsync({ s })
	end)
end)
Players.PlayerRemoving:Connect(dropRig)
Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do
	watchPlayer(player)
end
RunService.Heartbeat:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local t0 = PerfMark.begin()
	local eye = cam.CFrame.Position
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local rig = rigs[player]
		if rig and (rig.char ~= char or not rig.root.Parent) then
			dropRig(player)
			rig = nil
		end
		if char and hum and root and (root.Position - eye).Magnitude <= C.range then
			if not rig then
				rig = makeRig(char, hum, root)
				rigs[player] = rig
			end
			update(rig, dt, now)
		elseif rig then
			rig.cycle, rig.airSince = nil, nil -- out of range: keep the pool, forget the timing
		end
	end
	PerfMark.finish("steps", t0)
end)
