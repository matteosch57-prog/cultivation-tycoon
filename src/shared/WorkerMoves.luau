-- The sect workers' job loops as joint rotations (client: WorkerJobs.client.luau, which solves the
-- rig with Rig.luau). Shared so a pose can be checked frame by frame in Studio Edit too:
-- `Moves.pose(job, slot, t)` -> { [joint name] = CFrame }, `t` in seconds.
-- Joint axes (as the meditation pose): +X swings a limb forward; for the waist and neck, -X bends
-- forward; Y turns.
local Moves = {}
local rad = math.rad

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
	rot.Waist = A(3)
	rot.Neck = A(0, look)
	rot.RightShoulder = A(20, 0, 8)
	rot.RightElbow = A(25)
	rot.LeftShoulder = A(5, 0, -6)
	return rot
end

-- two-handed overhead swing (hoe, pick): `up` = how high the tool goes, `bend` = the strike lean
local function swing(p, up, bend)
	local sh = key(p, { { 0, 30 }, { 0.42, up }, { 0.52, 18 }, { 0.8, 26 } })
	local el = key(p, { { 0, 30 }, { 0.42, 25 }, { 0.52, 8 }, { 0.8, 25 } })
	local w = key(p, { { 0, -10 }, { 0.42, 6 }, { 0.52, -bend }, { 0.8, -14 } })
	return {
		Waist = A(w),
		Neck = A(-w * 0.5 - 6),
		RightShoulder = A(sh, 0, -14),
		RightElbow = A(el),
		LeftShoulder = A(sh - 6, 0, 18),
		LeftElbow = A(el + 10),
		LeftHip = A(12),
		RightHip = A(-6),
		LeftKnee = A(-14),
		RightKnee = A(-8),
	}
end

-- a forward sword cut with the left hand on guard; `turn` twists the body into it
local function cut(p)
	local sh = key(p, { { 0, 25 }, { 0.35, 155 }, { 0.48, 45 }, { 0.75, 30 } })
	local sz = key(p, { { 0, 10 }, { 0.35, 35 }, { 0.48, -25 }, { 0.75, 5 } })
	local turn = key(p, { { 0, 0 }, { 0.35, -18 }, { 0.48, 22 }, { 0.75, 5 } })
	return {
		Waist = A(-6, turn),
		RightShoulder = A(sh, 0, sz),
		RightElbow = A(15),
		LeftShoulder = A(45, 0, 20),
		LeftElbow = A(80),
		LeftHip = A(22),
		RightHip = A(-18),
		LeftKnee = A(-22),
		RightKnee = A(-10),
	}
end

local function guard(p)
	local lean = key(p, { { 0, 2 }, { 0.4, 10 }, { 0.6, 4 } })
	return {
		Waist = A(lean),
		Neck = A(-lean * 0.6),
		RightShoulder = A(85, 0, -25),
		RightElbow = A(55),
		LeftShoulder = A(30, 0, 15),
		LeftElbow = A(70),
		LeftHip = A(-14),
		RightHip = A(16),
		LeftKnee = A(-12),
		RightKnee = A(-20),
	}
end

local function bow(u)
	local b = math.sin(u * math.pi) -- down and up again
	return {
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
	local cycle = 2.2
	local n, p = math.floor(t / cycle), (t / cycle) % 1
	if n % 6 == 5 then
		return rest(t, {})
	end
	return swing(p, 150, 26)
end

function JOBS.miner(_, t)
	local cycle = 1.6
	local n, p = math.floor(t / cycle), (t / cycle) % 1
	if n % 7 == 6 then
		return rest(t, {})
	end
	return swing(p, 165, 32)
end

function JOBS.fighter(w, t)
	if w.slot == 1 then -- the dummy
		local cycle = 1.4
		local n, p = math.floor(t / cycle), (t / cycle) % 1
		if n % 8 == 7 then
			return rest(t, {})
		end
		return cut(p)
	end
	-- the sparring pair takes turns: slot 2 attacks in the first half, slot 3 in the second, and
	-- every 5th exchange both bow (they share one clock, so they bow together)
	local cycle = 2.8
	local n, p = math.floor(t / cycle), (t / cycle) % 1
	if n % 5 == 4 then
		return bow(p)
	end
	local mine = w.slot == 2 and p < 0.5 or w.slot == 3 and p >= 0.5
	local q = (p * 2) % 1
	return mine and cut(q) or guard(q)
end

function JOBS.alchemist(_, t)
	local cycle = 9
	local p = (t / cycle) % 1
	if p > 0.75 then -- lean in and look into the cauldron
		local u = math.sin((p - 0.75) / 0.25 * math.pi)
		return {
			Waist = A(-24 * u),
			Neck = A(-18 * u),
			RightShoulder = A(30, 0, -10),
			RightElbow = A(50),
			LeftShoulder = A(10 + 25 * u, 0, -8),
		}
	end
	local f = math.sin(t / 0.7 * math.pi * 2)
	return {
		Waist = A(-4 + 1.5 * math.sin(t)),
		Neck = A(-8),
		RightShoulder = A(55 + 6 * f, 0, -18 * f),
		RightElbow = A(65),
		RightWrist = A(0, 0, 20 * f),
		LeftShoulder = A(10, 0, -6),
		LeftElbow = A(20),
	}
end

-- t = seconds on the worker's own clock; slot = its place at the building (1..3)
function Moves.pose(job, slot, t)
	local f = JOBS[job]
	return f and f({ slot = slot }, t) or {}
end

return Moves
