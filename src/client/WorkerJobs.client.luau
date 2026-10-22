-- Job loops for the sect workers (server: Workers.luau). The avatars stand on their own joints with
-- only the root anchored; each frame here writes the worker's job pose into the joints' Transforms
-- (Rig.luau) and puts the body's stance offset on the root: the farmer hoes, the miner swings a
-- pick, fighters strike the dummy or spar and bow, the alchemist fans the furnace and leans in to
-- look. Every joint eases toward its target, the outer ones slower (hands after elbows after
-- shoulders after the chest), so the arms follow through and a switch between moves never snaps.
-- Every loop has a pause now and then so a row of workers never moves in lockstep. Local only:
-- nothing replicates, and nothing moves off screen or beyond FAR studs (R16). The moves
-- themselves: WorkerMoves.luau.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PerfMark = require(Shared:WaitForChild("PerfMark"))
local Rig = require(Shared:WaitForChild("Rig"))
local Moves = require(Shared:WaitForChild("WorkerMoves"))

local TAG = "Worker"
local FAR = 130
local NEAR = 60 -- beyond this, every other frame
local BODY_R = 5

local workers = {}

-- how fast each joint catches up with its target (per second): the chest leads, the hands trail
local FOLLOW = {
	Body = 30,
	Waist = 30,
	Neck = 20,
	RightShoulder = 26,
	LeftShoulder = 26,
	RightElbow = 22,
	LeftElbow = 22,
	RightWrist = 18,
	LeftWrist = 18,
}
local FOLLOW_LEGS = 30 -- as fast as the body, so the planted feet stay put
-- the pose is read this far ahead, so the eased chest lands each blow on time and only the arms trail
local LEAD = 0.035

local function add(m)
	local avatar = m:WaitForChild("Avatar", 10)
	local root = avatar and avatar:WaitForChild("HumanoidRootPart", 10)
	if not root or not m.Parent then
		return
	end
	local job = m:GetAttribute("Job")
	if not job then
		return
	end
	local slot = m:GetAttribute("Slot") or 1
	local joints = Rig.joints(avatar)
	local grip = avatar:FindFirstChild("RightHand") and avatar.RightHand:FindFirstChild("WorkerGrip")
	workers[m] = {
		-- where the left hand holds a two-handed tool: studs along the shaft from the right hand
		shaft = grip and Moves.TWO_HANDS[job],
		grip = grip and grip.CFrame,
		joints = joints,
		legs = { Left = Rig.legLengths(joints, "Left"), Right = Rig.legLengths(joints, "Right") },
		now = {}, -- the eased pose, per joint
		rootPart = root,
		root = root.CFrame,
		centre = root.Position,
		job = job,
		slot = slot,
		-- the sparring pair (slots 2 and 3 of a building) shares one clock; everyone else starts anywhere
		phase = (m:GetAttribute("Job") == "fighter" and slot > 1) and 0 or math.random() * 30,
		frame = 0,
	}
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(m)
	task.spawn(add, m)
end)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(m)
	workers[m] = nil
end)
for _, m in CollectionService:GetTagged(TAG) do
	task.spawn(add, m)
end

-- the off hand on a two-handed tool: the left elbow bends down, out and a little back
local POLE = Vector3.new(-0.6, -1, 0.3)
local RIGHT_ARM = { "RightShoulder", "RightElbow", "RightWrist" }

-- ease `w.now[name]` toward the target pose and write it into the joints
local function drive(w, target, dt)
	local cur = w.now
	for name in w.joints do
		local goal = target[name] or CFrame.identity
		local k = 1 - math.exp(-(FOLLOW[name] or FOLLOW_LEGS) * dt)
		cur[name] = (cur[name] or goal):Lerp(goal, k)
	end
	-- a two-handed tool: the left hand holds the shaft where the right hand's tool puts it
	local out = cur
	if w.shaft then
		out = table.clone(cur)
		local hand = Rig.chain(w.joints, RIGHT_ARM, cur) * w.grip * CFrame.new(0, w.shaft, 0)
		Rig.reach(w.joints, "Left", hand.Position, POLE, out)
	end
	for name, j in w.joints do
		j.Transform = out[name]
	end
	-- the body's stance offset moves the anchored root (not the joint named Root)
	local goal = target.Body or CFrame.identity
	cur.Body = (cur.Body or goal):Lerp(goal, 1 - math.exp(-FOLLOW.Body * dt))
	w.rootPart.CFrame = w.root * cur.Body
end

-- PreSimulation: the engine applies every joint Transform in one batch right after
RunService.PreSimulation:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local t0 = PerfMark.begin()
	local eye = cam.CFrame.Position
	local now = workspace:GetServerTimeNow() -- one clock for every client, so a pair stays in step
	for m, w in workers do
		if not m.Parent then
			workers[m] = nil
		else
			local dist = (w.centre - eye).Magnitude
			w.frame += 1
			if dist < FAR and (dist < NEAR or w.frame % 2 == 0) and PerfMark.onScreen(cam, w.centre, BODY_R) then
				-- a far worker moves every other frame: it eases over both frames' time
				local step = (dist < NEAR) and dt or dt * 2
				drive(w, Moves.pose(w.job, w.slot, now + w.phase + LEAD, w.legs), math.min(step, 0.1))
			end
		end
	end
	PerfMark.finish("workers", t0)
end)
