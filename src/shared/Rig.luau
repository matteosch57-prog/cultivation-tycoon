-- Hand posing for anchored R15 avatars (sect workers: server Workers.luau, client
-- WorkerJobs.client.luau). The rig's joints stay in the model but disabled, and every part is
-- anchored; a pose is solved by walking the joint graph from the root: each child part goes where
-- its joint puts it, with a rotation per joint name. New rigs carry AnimationConstraints rather
-- than Motor6Ds, and accessories and held tools hang on welds or RigidConstraints, so all of them
-- are joints here.
local Rig = {}

local function ends(j)
	if j:IsA("JointInstance") then
		return j.Part0, j.Part1
	end
	local a0, a1 = j.Attachment0, j.Attachment1
	return a0 and a0.Parent, a1 and a1.Parent
end

local function frames(j)
	if j:IsA("JointInstance") then
		return j.C0, j.C1
	end
	return j.Attachment0.CFrame, j.Attachment1.CFrame
end

-- The joint graph of model `m`, ordered from the root outward:
-- { root = part, steps = { { name, from, to, c0, c1, forward } } }. `forward` = the joint runs
-- from -> to (Part0 -> Part1); accessory welds run Handle -> body part, so they are walked backward.
function Rig.graph(m)
	local root = m:FindFirstChild("HumanoidRootPart")
	local joints = {}
	for _, j in m:GetDescendants() do
		if j:IsA("JointInstance") or j:IsA("AnimationConstraint") or j:IsA("RigidConstraint") then
			local a, b = ends(j)
			if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
				table.insert(joints, { j = j, a = a, b = b })
			end
		end
	end
	local seen = { [root] = true }
	local steps = {}
	local placed = true
	while placed do
		placed = false
		for _, e in joints do
			if not e.done then
				local c0, c1 = frames(e.j)
				if seen[e.a] and not seen[e.b] then
					table.insert(steps, { name = e.j.Name, from = e.a, to = e.b, c0 = c0, c1 = c1, forward = true })
					seen[e.b], e.done, placed = true, true, true
				elseif seen[e.b] and not seen[e.a] then
					table.insert(steps, { name = e.j.Name, from = e.b, to = e.a, c0 = c0, c1 = c1, forward = false })
					seen[e.a], e.done, placed = true, true, true
				end
			end
		end
	end
	return { root = root, steps = steps, joints = joints }
end

-- Solve a pose: `rot[name]` = the rotation of that joint (in its parent attachment frame), or nil
-- for rest. Appends the parts and their CFrames to `parts` / `cfs` (for workspace:BulkMoveTo) and
-- returns the map part -> CFrame.
function Rig.solve(g, rootCf, rot, parts, cfs)
	local at = { [g.root] = rootCf }
	for _, s in g.steps do
		local base = at[s.from]
		if s.forward then
			at[s.to] = base * s.c0 * (rot[s.name] or CFrame.identity) * s.c1:Inverse()
		else
			at[s.to] = base * s.c1 * s.c0:Inverse() -- a weld onto the body: no rotation of its own
		end
		if parts then
			table.insert(parts, s.to)
			table.insert(cfs, at[s.to])
		end
	end
	return at
end

-- Server: put the rig in a pose once, disable its joints and anchor every part.
function Rig.freeze(m, rot)
	local g = Rig.graph(m)
	local at = Rig.solve(g, g.root.CFrame, rot or {})
	for _, e in g.joints do
		e.j.Enabled = false
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			if at[p] then
				p.CFrame = at[p]
			end
		end
	end
end

return Rig
