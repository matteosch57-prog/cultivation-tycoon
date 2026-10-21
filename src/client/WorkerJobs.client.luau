-- Job loops for the sect workers (server: Workers.luau). The avatars are anchored with their joints
-- disabled; here each frame the joints are solved by hand (Rig.luau) with a rotation per joint
-- from the worker's job: the farmer hoes, the miner swings a pick, fighters strike the dummy or
-- spar and bow, the alchemist fans the furnace and leans in to look. Every loop has a pause now and
-- then so a row of workers never moves in lockstep. Local only: nothing replicates, and nothing
-- moves off screen or beyond FAR studs (R16). The moves themselves: WorkerMoves.luau.
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
	workers[m] = {
		graph = Rig.graph(avatar),
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

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local t0 = PerfMark.begin()
	local eye = cam.CFrame.Position
	local now = workspace:GetServerTimeNow() -- one clock for every client, so a pair stays in step
	local parts, cfs = {}, {}
	for m, w in workers do
		if not m.Parent then
			workers[m] = nil
		else
			local dist = (w.centre - eye).Magnitude
			w.frame += 1
			if dist < FAR and (dist < NEAR or w.frame % 2 == 0) and PerfMark.onScreen(cam, w.centre, BODY_R) then
				Rig.solve(w.graph, w.root, Moves.pose(w.job, w.slot, now + w.phase), parts, cfs)
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	PerfMark.finish("workers", t0)
end)
