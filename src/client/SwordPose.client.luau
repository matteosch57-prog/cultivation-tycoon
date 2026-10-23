-- The sword rider's pose (D76), drawn on every client for every player riding (player attribute
-- Riding): the body lifted Config.SWORD_RIDE.lift studs off the root and leaned forward `lean`
-- degrees at the root joint, `waistLean` more at the waist, so the feet stand on the blade the
-- server welded `lift` over the walking feet. HipHeight is never touched (the step height stays the
-- walker's). Written into each joint's Transform in PreSimulation, after the Animator wrote this
-- frame's pose, so it works on Motor6D and AnimationConstraint rigs alike (Studio 2026-10-23: new
-- avatars have AnimationConstraints, and a C0 edit on the server never reached them).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rig = require(Shared:WaitForChild("Rig"))
local PerfMark = require(Shared:WaitForChild("PerfMark"))

local RIDE = Config.SWORD_RIDE
local LEAN = CFrame.Angles(math.rad(-RIDE.lean), 0, 0) -- the root's lean, in the root part's axes
local WAIST_POSE = CFrame.Angles(math.rad(-RIDE.waistLean), 0, 0) -- in the lower torso's axes
-- The lift corrects itself (Studio 2026-10-23: with the rider's own idle the feet floated 0.6 to 1.1
-- studs over the blade, each animation pack moves the hips its own way): every frame the lowest
-- foot's bottom is measured against the sword's BladeTop attachment and a per-rider correction eases
-- the gap to 0 at FIT_RATE, within +- FIT_MAX studs of RIDE.lift.
local FIT_RATE = 10 -- 1/s
local FIT_MAX = 1.5 -- studs
local FEET = { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" } -- R15 feet, R6 legs

local riders = {} -- [player] = { char, fix, joints = { { joint, frame, root?, pose, base, written } } }

-- the pose `p` (given in the joint's parent part axes) as a change of the joint's Transform:
-- child = parent * F * T * C1^-1, so parent * p * F * T = parent * F * (F^-1 p F) * T
local function entry(j, p, isRoot)
	local f = Rig.parentFrame(j)
	return { joint = j, frame = f, root = isRoot, pose = f:Inverse() * p * f }
end

-- the bottom of a part's world box
local function bottom(p)
	local r = p.CFrame
	local s = p.Size
	return p.Position.Y - (math.abs(r.RightVector.Y) * s.X + math.abs(r.UpVector.Y) * s.Y + math.abs(r.LookVector.Y) * s.Z) / 2
end

local function track(player)
	local char = player.Character
	if not char or not player:GetAttribute("Riding") then
		return nil
	end
	local root, waist = Rig.rideJoints(char)
	local r = { char = char, fix = 0, joints = {}, feet = {} }
	for _, name in FEET do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(r.feet, part)
		end
	end
	if root then
		table.insert(r.joints, entry(root, CFrame.new(0, RIDE.lift, 0) * LEAN, true))
	end
	if waist then
		table.insert(r.joints, entry(waist, WAIST_POSE))
	end
	return r
end

-- put a joint back the way the Animator left it (a joint no track drives keeps what was written)
local function release(r)
	for _, e in r.joints do
		if e.joint.Parent and e.written and e.joint.Transform == e.written then
			e.joint.Transform = e.base
		end
	end
end

local function refresh(player)
	local old = riders[player]
	if old then
		release(old)
	end
	riders[player] = track(player)
end

local function watch(player)
	player:GetAttributeChangedSignal("Riding"):Connect(function()
		refresh(player)
	end)
	player.CharacterAdded:Connect(function()
		refresh(player)
	end)
	refresh(player)
end
for _, p in Players:GetPlayers() do
	watch(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(p)
	riders[p] = nil
end)

RunService.PreSimulation:Connect(function(dt)
	if next(riders) == nil then
		return
	end
	local t0 = PerfMark.begin()
	for player, r in riders do
		if r.char ~= player.Character or not r.char.Parent then
			riders[player] = track(player)
			continue
		end
		-- the fit: the lowest foot onto the blade top (measured on last frame's solved pose)
		local sword = r.char:FindFirstChild("RideSword")
		local top = sword and sword:FindFirstChild("BladeTop", true)
		if top and #r.feet > 0 then
			local low = math.huge
			for _, foot in r.feet do
				low = math.min(low, bottom(foot))
			end
			local gap = low - top.WorldPosition.Y
			r.fix = math.clamp(r.fix - gap * math.min(1, FIT_RATE * dt), -FIT_MAX, FIT_MAX)
		end
		for _, e in r.joints do
			local j = e.joint
			if e.root then
				e.pose = e.frame:Inverse() * (CFrame.new(0, RIDE.lift + r.fix, 0) * LEAN) * e.frame
			end
			-- this frame's animated Transform, or the last one if no animation wrote over ours
			-- (never stack the pose twice)
			local base = (e.written and j.Transform == e.written) and e.base or j.Transform
			e.base = base
			e.written = e.pose * base
			j.Transform = e.written
		end
	end
	PerfMark.finish("swordPose", t0)
end)
