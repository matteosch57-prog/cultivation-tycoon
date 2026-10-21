-- Breathing idle for the seated cultivators (server: Cultivators.luau). The avatars are anchored
-- in a cross-legged pose; here the upper body rises and leans a little with each slow breath and
-- the Immortal's qi orbs circle. Local only (nothing replicates), skipped beyond FAR studs.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "Cultivator"
local FAR = 150
local BREATH = 4.5 -- seconds per breath
local LEGS = { HumanoidRootPart = true, LowerTorso = true, LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true }

local figures = {}

local function add(m)
	local avatar = m:WaitForChild("Avatar", 10)
	local waist = avatar and avatar:WaitForChild("UpperTorso", 10)
	if not waist or not m.Parent then
		return
	end
	local f = { model = m, parts = {}, base = {}, orbs = {}, orbBase = {}, phase = math.random() * BREATH }
	-- breathe about the bottom of the chest
	f.pivot = waist.CFrame * CFrame.new(0, -waist.Size.Y / 2, 0)
	for _, p in avatar:GetDescendants() do
		if p:IsA("BasePart") and not LEGS[p.Name] then
			table.insert(f.parts, p)
			table.insert(f.base, f.pivot:ToObjectSpace(p.CFrame))
		end
	end
	f.centre = f.pivot.Position
	for _, p in m:GetChildren() do
		if p.Name == "QiOrb" then
			table.insert(f.orbs, p)
			table.insert(f.orbBase, p.Position - f.centre)
		end
	end
	figures[m] = f
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(m)
	task.spawn(add, m)
end)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(m)
	figures[m] = nil
end)
for _, m in CollectionService:GetTagged(TAG) do
	task.spawn(add, m)
end

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local eye = cam.CFrame.Position
	local now = os.clock()
	local parts, cfs = {}, {}
	for m, f in figures do
		if not m.Parent then
			figures[m] = nil
		elseif (f.centre - eye).Magnitude < FAR then
			local b = math.sin((now + f.phase) / BREATH * math.pi * 2)
			local cf = f.pivot * CFrame.new(0, 0.04 * b, 0) * CFrame.Angles(math.rad(-1.2 * b), 0, 0)
			for i, p in f.parts do
				table.insert(parts, p)
				table.insert(cfs, cf * f.base[i])
			end
			local spin = CFrame.Angles(0, now * 0.6, 0)
			for i, orb in f.orbs do
				table.insert(parts, orb)
				table.insert(cfs, CFrame.new(f.centre + spin * f.orbBase[i] + Vector3.new(0, 0.2 * math.sin(now * 1.3 + i), 0)))
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
