-- Joint-driven motion for R15 avatar NPCs (sect workers: Workers.luau + WorkerJobs.client.luau;
-- disciples: Cultivators.luau + CultivatorIdle.client.luau). The root stays anchored and every
-- other part hangs on the rig's own joints, so the client moves a figure by writing each joint's
-- Transform (and the root's CFrame for the whole body). Layered robes, hair and props then follow
-- the body: they are skinned to or welded on the parts the joints carry. The old way (joints off,
-- every part anchored and moved on its own) left the robe sleeves behind the arms and missed hair
-- that streamed in late (owner 2026-10-22, capture in docs/research/2026-10-22_npc_animation.md).
-- New rigs carry AnimationConstraints rather than Motor6Ds; both have C0/Attachment0 and Transform.
local Rig = {}

-- the joints that drive the body (accessory welds and constraints are not in this list)
local function isBodyJoint(j)
	return (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) and not (j.Parent and j.Parent.Name == "Handle")
end

-- a joint's two frames: on its parent part (C0 / Attachment0) and on its child part (C1 / Attachment1);
-- nil while an AnimationConstraint lacks an attachment (live 2026-10-27: a figure half streamed in, or
-- one streamed out and back in, threw 13k errors a day here)
local function frames(j)
	if j:IsA("Motor6D") then
		return j.C0, j.C1
	end
	local a0, a1 = j.Attachment0, j.Attachment1
	if not (a0 and a1) then
		return nil, nil
	end
	return a0.CFrame, a1.CFrame
end

-- Server: make a built avatar live. Root anchored, everything else unanchored, massless and
-- out of physics; the animation constraints kinematic (staff: turning IsKinematic off makes the
-- arms lag); every weld enabled again. The model streams in whole (Atomic), so the client never
-- finds a figure without its hair.
function Rig.live(m)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		elseif d:IsA("AnimationConstraint") then
			d.IsKinematic = true
			d.Enabled = true
		elseif d:IsA("JointInstance") or d:IsA("RigidConstraint") then
			d.Enabled = true
		end
	end
	-- the figure never walks, falls or climbs: its Humanoid only carries the look, so its state machine
	-- is off (no per-frame state work for every disciple and worker; research 2026-10-22 P2)
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.EvaluateStateMachine = false
	end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
end

-- Server: bake a pose into the rest frame (`rot[name]` = the joint's rotation in its parent
-- attachment frame), so every client and every capture sees it with no script running. The client's
-- Transforms then add small motions on top.
function Rig.bake(m, rot)
	for _, j in m:GetDescendants() do
		local r = rot[j.Name]
		if r and isBodyJoint(j) then
			if j:IsA("Motor6D") then
				j.C0 = j.C0 * r
			else
				j.Attachment0.CFrame = j.Attachment0.CFrame * r
			end
		end
	end
end

-- Client: the body joints of a figure by name.
function Rig.joints(m)
	local map = {}
	for _, j in m:GetDescendants() do
		if isBodyJoint(j) then
			map[j.Name] = j
		end
	end
	return map
end

-- Client: write one frame (`rot[name]`, rest for the joints it leaves out). Call it in
-- RunService.PreSimulation: the engine applies every Transform in one batch after it.
function Rig.apply(joints, rot)
	for name, j in joints do
		j.Transform = rot[name] or CFrame.identity
	end
end

-- The rest-pose lengths of a leg (hip to knee, knee to ankle) from its rig attachments, for the
-- foot planting in Rig.leg.
function Rig.legLengths(joints, side)
	local hip, knee, ankle = joints[side .. "Hip"], joints[side .. "Knee"], joints[side .. "Ankle"]
	if not (hip and knee and ankle) then
		return nil
	end
	local _, hip1 = frames(hip)
	local knee0, knee1 = frames(knee)
	local ankle0 = frames(ankle)
	if not (hip1 and knee0 and ankle0) then
		return nil
	end
	return {
		thigh = (hip1.Position - knee0.Position).Magnitude,
		shin = (knee1.Position - ankle0.Position).Magnitude,
	}
end

-- Two-bone leg in the body's side view: the hip has moved by `dy` (down < 0) and `dz` (forward
-- < 0, front is -Z) from where the foot was planted at rest (`foot` = the foot's own forward
-- offset at rest, studs). Returns the hip and knee pitch (radians, +X swings forward, a knee bends
-- back with a negative angle) that keep the ankle where it was, and the ankle pitch that keeps the
-- sole flat.
function Rig.leg(len, dy, dz, foot)
	local a, b = len.thigh, len.shin
	-- the ankle seen from the moved hip: straight down a + b at rest
	local y = -(a + b) - dy
	local z = (foot or 0) - dz
	local d = math.clamp(math.sqrt(y * y + z * z), math.abs(a - b) + 1e-3, a + b - 1e-3)
	local knee = math.pi - math.acos(math.clamp((a * a + b * b - d * d) / (2 * a * b), -1, 1))
	local toAnkle = math.atan2(-z, -y) -- forward (+) when the ankle is ahead of the hip
	local inner = math.acos(math.clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1))
	local hip = toAnkle + inner
	return hip, -knee, knee - hip
end

-- The frame of the last part of a chain of joints (`names`, from the parent part outward) in the
-- first joint's parent part space, with the Transforms in `rot` (rest for the ones it lacks).
function Rig.chain(joints, names, rot)
	local cf = CFrame.identity
	for _, name in names do
		local j = joints[name]
		local c0, c1
		if j then
			c0, c1 = frames(j)
		end
		if not c0 then
			return CFrame.identity -- a rig missing a joint: no reach, rather than an error every frame
		end
		cf = cf * c0 * (rot[name] or CFrame.identity) * c1:Inverse()
	end
	return cf
end

-- The turn, as a joint Transform, that swings vector `from` onto `to` (both in the parent part's
-- space) about the joint whose parent frame is `c0`.
local function swing(c0, from, to)
	local turn = CFrame.fromRotationBetweenVectors(from.Unit, to.Unit)
	return c0.Rotation:Inverse() * turn * c0.Rotation
end

-- Two-bone arm reach: the shoulder and elbow Transforms that put the `side` hand's palm on
-- `target` (a point in UpperTorso space), the elbow bending toward `pole` (a direction in the same
-- space). Writes them into `rot`. Used for the off hand on a two-handed tool (WorkerJobs).
function Rig.reach(joints, side, target, pole, rot)
	local sh, el, wr = joints[side .. "Shoulder"], joints[side .. "Elbow"], joints[side .. "Wrist"]
	if not (sh and el and wr) then
		return
	end
	local sh0, sh1 = frames(sh)
	local el0, el1 = frames(el)
	local wr0, wr1 = frames(wr)
	if not (sh0 and el0 and wr0) then
		return
	end
	-- the bones at rest, each in its own part's space: shoulder -> elbow, elbow -> palm (the
	-- forearm and the hand taken as one straight bone)
	local upperLocal = el0.Position - sh1.Position
	local lowerLocal = wr0.Position - el1.Position
	local a = upperLocal.Magnitude
	local b = lowerLocal.Magnitude + wr1.Position.Magnitude
	local s = sh0.Position
	local toT = target - s
	local d = math.clamp(toT.Magnitude, math.abs(a - b) + 1e-3, a + b - 1e-3)
	local dir = toT.Unit
	local side2 = pole - dir * pole:Dot(dir)
	if side2.Magnitude < 1e-4 then
		return
	end
	side2 = side2.Unit
	local alpha = math.acos(math.clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1))
	local upperDir = dir * math.cos(alpha) + side2 * math.sin(alpha)
	local elbow = s + upperDir * a
	-- the shoulder: swing the upper arm's rest direction onto upperDir
	local restUpper = (sh0 * sh1:Inverse()):VectorToWorldSpace(upperLocal)
	local tShoulder = swing(sh0, restUpper, upperDir)
	rot[side .. "Shoulder"] = tShoulder
	-- the elbow: in the upper arm as now placed, swing the forearm onto the palm
	local upper = sh0 * tShoulder * sh1:Inverse()
	local elFrame = upper * el0
	local restLower = (elFrame * el1:Inverse()):VectorToWorldSpace(lowerLocal)
	local inElbow = elFrame.Rotation:Inverse()
	rot[side .. "Elbow"] =
		CFrame.fromRotationBetweenVectors((inElbow * restLower).Unit, (inElbow * (target - elbow)).Unit)
	rot[side .. "Wrist"] = CFrame.identity
end


-- A character's root and waist joints (Motor6D or AnimationConstraint: new avatars carry the latter,
-- Studio 2026-10-23), for the sword rider's pose (SwordPose.client, SwordRide.luau). nil when absent.
function Rig.rideJoints(char)
	local root, waist
	for _, d in char:GetDescendants() do
		if isBodyJoint(d) then
			if d.Name == "Root" or d.Name == "RootJoint" then
				root = d
			elseif d.Name == "Waist" then
				waist = d
			end
		end
	end
	return root, waist
end

-- a joint's frame on its parent part (Motor6D C0 / AnimationConstraint Attachment0), nil without one
function Rig.parentFrame(j)
	return (frames(j))
end

return Rig
