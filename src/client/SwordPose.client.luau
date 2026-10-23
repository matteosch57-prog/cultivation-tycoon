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
local ROOT_POSE = CFrame.new(0, RIDE.lift, 0) * CFrame.Angles(math.rad(-RIDE.lean), 0, 0) -- in the root part's axes
local WAIST_POSE = CFrame.Angles(math.rad(-RIDE.waistLean), 0, 0) -- in the lower torso's axes

local riders = {} -- [player] = { char, joints = { { joint, pose (in its own frame), base, written } } }

-- the pose `p` (given in the joint's parent part axes) as a change of the joint's Transform:
-- child = parent * F * T * C1^-1, so parent * p * F * T = parent * F * (F^-1 p F) * T
local function entry(j, p)
	local f = Rig.parentFrame(j)
	return { joint = j, pose = f:Inverse() * p * f }
end

local function track(player)
	local char = player.Character
	if not char or not player:GetAttribute("Riding") then
		return nil
	end
	local root, waist = Rig.rideJoints(char)
	local r = { char = char, joints = {} }
	if root then
		table.insert(r.joints, entry(root, ROOT_POSE))
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

RunService.PreSimulation:Connect(function()
	if next(riders) == nil then
		return
	end
	local t0 = PerfMark.begin()
	for player, r in riders do
		if r.char ~= player.Character or not r.char.Parent then
			riders[player] = track(player)
			continue
		end
		for _, e in r.joints do
			local j = e.joint
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
