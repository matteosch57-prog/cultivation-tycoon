-- The sect workers' job loops as joint rotations (client: WorkerJobs.client.luau, which writes them
-- into the rig's joints with Rig.luau). Shared so a pose can be checked frame by frame in Studio
-- Edit too: `Moves.pose(job, slot, t, legs)` -> { [joint name] = CFrame }, `t` in seconds.
-- Joint axes (as the meditation pose): +X swings a limb forward; for the waist and neck, -X bends
-- forward; Y turns.
-- The whole body works (owner 2026-10-22: "some parts move while others stay frozen"): a move sets a
-- `stance` (the hips drop and drive forward into each blow, the feet stay planted, one ahead of the
-- other) and Moves.pose turns it into hip, knee and ankle angles (Rig.leg) plus `Body`, the body's
-- offset from where it stands. The client eases every joint toward its target, the hands slower
-- than the chest, so the arms follow through after the body (WorkerJobs).
local Rig = require(script.Parent:WaitForChild("Rig"))

local Moves = {}
local rad = math.rad

-- two-handed tools (owner 2026-10-22: the left hand floated beside the shaft): the left hand holds
-- the shaft this many studs from the right hand, placed each frame by Rig.reach (WorkerJobs)
Moves.TWO_HANDS = { farmer = 1.3, miner = 1.0 }

-- smooth value through cyclic keys { {phase, value}, ... } (phases 0..1, ascending, first at 0)
local function key(p, keys)
	local n = #keys
	for i = 1, n do
		local a, b = keys[i], keys[i % n + 1]
		local pb = i == n and 1 or b[1]
		if p >= a[1] and p < pb then
			local u = (p - a[1]) / (pb - a[1])
			u = u * u * (3 - 2 * u)
			return a[2] + (b[2] - a[2]) * u
		end
	end
	return keys[1][2]
end

local function A(x, y, z)
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end

-- a short rest: stand easy, tool down, look around
local function rest(t, rot)
	local look = 35 * math.sin(t * 0.9)
	-- stand easy: a slow breath through the knees, the feet a little apart
	rot.stance = { dy = -0.04 + 0.03 * math.sin(t * 1.4), dz = 0, left = -0.15, right = 0.15 }
	rot.Waist = A(3)
	rot.Neck = A(0, look)
	rot.RightShoulder = A(20, 0, 8)
	rot.RightElbow = A(25)
	rot.LeftShoulder = A(5, 0, -6)
	return rot
end

-- two-handed overhead swing (hoe, pick): `up` = how high the tool goes, `bend` = the strike lean,
-- `tip` = the wrists on the blow, set so the tool's head lands on the soil or the rock
local function swing(p, up, bend, tip)
	local sh = key(p, { { 0, 30 }, { 0.42, up }, { 0.52, 18 }, { 0.8, 26 } })
	local el = key(p, { { 0, 30 }, { 0.42, 25 }, { 0.52, 8 }, { 0.8, 25 } })
	local w = key(p, { { 0, -10 }, { 0.42, 6 }, { 0.52, -bend }, { 0.8, -14 } })
	-- the wrists tip the head of the tool down into the ground on the blow
	local wr = key(p, { { 0, tip * 0.6 }, { 0.42, 5 }, { 0.52, tip }, { 0.8, tip * 0.8 } })
	-- the hips rise a little on the lift and drop forward into the blow, the left foot ahead
	local dy = key(p, { { 0, -0.12 }, { 0.42, 0.02 }, { 0.52, -0.38 }, { 0.8, -0.2 } })
	local dz = key(p, { { 0, 0 }, { 0.42, 0.12 }, { 0.52, -0.22 }, { 0.8, -0.08 } })
	return {
		stance = { dy = dy, dz = dz, left = -0.6, right = 0.45, turn = -0.5 * w },
		Waist = A(w),
		Neck = A(-w * 0.5 - 6),
		RightShoulder = A(sh, 0, -14),
		RightElbow = A(el),
		RightWrist = A(wr),
		LeftShoulder = A(sh - 6, 0, 22),
		LeftElbow = A(el + 10),
		LeftWrist = A(wr),
	}
end

-- a forward sword cut with the left hand on guard; `turn` twists the body into it. `stop` = the
-- shoulder on the blow (low to cut the dummy, high where a partner's raised sword meets it) and
-- `tip` the wrist then
local function cut(p, stop, tip)
	local sh = key(p, { { 0, 25 }, { 0.35, 155 }, { 0.48, stop }, { 0.75, 30 } })
	-- the wrist levels the blade on the blow, so it cuts the dummy at chest height
	local wr = key(p, { { 0, -20 }, { 0.35, 10 }, { 0.48, tip }, { 0.75, -30 } })
	local sz = key(p, { { 0, 10 }, { 0.35, 35 }, { 0.48, -25 }, { 0.75, 5 } })
	local turn = key(p, { { 0, 0 }, { 0.35, -18 }, { 0.48, 22 }, { 0.75, 5 } })
	-- a step of weight into the cut: the hips lunge forward and down, the body turns with it
	local dz = key(p, { { 0, 0 }, { 0.35, 0.15 }, { 0.48, -0.35 }, { 0.75, -0.05 } })
	local dy = key(p, { { 0, -0.15 }, { 0.35, -0.08 }, { 0.48, -0.32 }, { 0.75, -0.18 } })
	return {
		stance = { dy = dy, dz = dz, left = -0.75, right = 0.6, turn = turn * 0.5 },
		Waist = A(-6, turn * 0.5),
		RightShoulder = A(sh, 0, sz),
		RightElbow = A(15),
		RightWrist = A(wr),
		LeftShoulder = A(45, 0, 20),
		LeftElbow = A(80),
	}
end

local function guard(p)
	local lean = key(p, { { 0, 2 }, { 0.4, 10 }, { 0.6, 4 } })
	-- braced: the weight sinks onto the back foot as the blow lands
	local dy = key(p, { { 0, -0.18 }, { 0.4, -0.32 }, { 0.6, -0.22 } })
	local dz = key(p, { { 0, 0 }, { 0.4, 0.15 }, { 0.6, 0.05 } })
	return {
		stance = { dy = dy, dz = dz, left = -0.5, right = 0.55 },
		Waist = A(lean),
		Neck = A(-lean * 0.6),
		RightShoulder = A(20, 0, -40), -- found by a search: the blade rises 37 degrees across the
		RightElbow = A(60), -- partner's blow and meets it at its height
		RightWrist = A(-45),
		LeftShoulder = A(30, 0, 15),
		LeftElbow = A(70),
	}
end

local function bow(u)
	local b = math.sin(u * math.pi) -- down and up again
	return {
		stance = { dy = -0.06 * b, dz = 0.12 * b, left = -0.1, right = 0.1 },
		Waist = A(-35 * b),
		Neck = A(-15 * b),
		RightShoulder = A(40 * b, 0, -20 * b),
		RightElbow = A(70 * b),
		LeftShoulder = A(40 * b, 0, 20 * b),
		LeftElbow = A(70 * b),
	}
end

-- job(w, t) -> rot; t = seconds since the worker started (its own phase)
local JOBS = {}

function JOBS.farmer(_, t)
	local cycle = 2.8
	local n, p = math.floor(t / cycle), (t / cycle) % 1
	if n % 6 == 5 then
		return rest(t, {})
	end
	return swing(p, 150, 26, -18)
end

function JOBS.miner(_, t)
	local cycle = 2.2
	local n, p = math.floor(t / cycle), (t / cycle) % 1
	if n % 7 == 6 then
		return rest(t, {})
	end
	return swing(p, 165, 32, -28)
end

function JOBS.fighter(w, t)
	if w.slot == 1 then -- the dummy
		local cycle = 1.9
		local n, p = math.floor(t / cycle), (t / cycle) % 1
		if n % 8 == 7 then
			return rest(t, {})
		end
		return cut(p, 45, -45)
	end
	-- the sparring pair takes turns: slot 2 attacks in the first half, slot 3 in the second, and
	-- every 5th exchange both bow (they share one clock, so they bow together)
	local cycle = 3.4
	local n, p = math.floor(t / cycle), (t / cycle) % 1
	if n % 5 == 4 then
		return bow(p)
	end
	local mine = w.slot == 2 and p < 0.5 or w.slot == 3 and p >= 0.5
	local q = (p * 2) % 1
	return mine and cut(q, 80, -70) or guard(q)
end

function JOBS.alchemist(_, t)
	local cycle = 9
	local p = (t / cycle) % 1
	if p > 0.75 then -- lean in and look into the cauldron
		local u = math.sin((p - 0.75) / 0.25 * math.pi)
		return {
			stance = { dy = -0.2 * u, dz = 0.1 * u, left = -0.3, right = 0.3 },
			Waist = A(-24 * u),
			Neck = A(-18 * u),
			RightShoulder = A(30, 0, -10),
			RightElbow = A(50),
			LeftShoulder = A(10 + 25 * u, 0, -8),
		}
	end
	-- fan the cauldron's belly, where the fire is, not the rim
	local f = math.sin(t / 0.9 * math.pi * 2)
	return {
		-- crouched at the fire door, rocking a little with each stroke of the fan
		stance = { dy = -0.22 + 0.04 * f, dz = 0.05, left = -0.3, right = 0.35 },
		Waist = A(-18 + 1.5 * math.sin(t)),
		Neck = A(-6),
		RightShoulder = A(14 + 8 * f, 0, -18 * f),
		RightElbow = A(45),
		RightWrist = A(0, 0, 20 * f),
		LeftShoulder = A(10, 0, -6),
		LeftElbow = A(20),
	}
end

-- The stance as leg angles: each foot stays where it was planted (`left` / `right` = its forward
-- offset, front is -Z) while the hips move by dy / dz and turn by `turn` degrees; `Body` = the
-- body's offset for the client to put on the anchored root.
local function stand(rot, legs)
	local st = rot.stance
	rot.stance = nil
	if not st then
		return rot
	end
	rot.Body = CFrame.new(0, st.dy, st.dz) * A(0, st.turn or 0)
	for _, side in { "Left", "Right" } do
		local len = legs and legs[side]
		if len then
			local hip, knee, ankle = Rig.leg(len, st.dy, st.dz, side == "Left" and st.left or st.right)
			rot[side .. "Hip"] = CFrame.Angles(hip, 0, 0) * A(0, -(st.turn or 0))
			rot[side .. "Knee"] = CFrame.Angles(knee, 0, 0)
			rot[side .. "Ankle"] = CFrame.Angles(ankle, 0, 0)
		end
	end
	return rot
end

-- t = seconds on the worker's own clock; slot = its place at the building (1..3); legs = the
-- worker's leg lengths ({ Left, Right } from Rig.legLengths), nil to leave the legs at rest
function Moves.pose(job, slot, t, legs)
	local f = JOBS[job]
	return f and stand(f({ slot = slot }, t), legs) or {}
end

return Moves
