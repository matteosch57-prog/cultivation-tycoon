-- Meditation idle for the seated cultivators (server: Cultivators.luau). The avatars are anchored
-- in a cross-legged pose; here the upper body rises and leans with each slow breath and sways side to
-- side, the head drifts on its own rhythm, the aura ring and halo swell with the breath, the sparkles
-- puff out now and then, and the qi orbs circle and bob. Local only (nothing replicates), skipped
-- beyond FAR studs.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "Cultivator"
local FAR = 150
local BREATH = 4.5 -- seconds per breath
local SWAY = 7.3 -- seconds per side-to-side sway
local NOD = 9.1 -- seconds per head drift
local LEGS = { HumanoidRootPart = true, LowerTorso = true, LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true }
local HEADWEAR = { [Enum.AccessoryType.Hair] = true, [Enum.AccessoryType.Face] = true, [Enum.AccessoryType.Hat] = true }

local figures = {}

local function add(m)
	local avatar = m:WaitForChild("Avatar", 10)
	local waist = avatar and avatar:WaitForChild("UpperTorso", 10)
	local head = avatar and avatar:WaitForChild("Head", 10)
	if not waist or not head or not m.Parent then
		return
	end
	local f = { body = {}, bodyBase = {}, head = {}, headBase = {}, orbs = {}, orbBase = {}, swell = {}, phase = math.random() * 20 }
	-- breathe about the bottom of the chest; the head turns about the neck
	f.pivot = waist.CFrame * CFrame.new(0, -waist.Size.Y / 2, 0)
	f.neck = f.pivot:ToObjectSpace(head.CFrame * CFrame.new(0, -head.Size.Y / 2, 0))
	for _, p in avatar:GetDescendants() do
		if p:IsA("BasePart") and not LEGS[p.Name] then
			local acc = p.Parent
			local onHead = p == head or (acc:IsA("Accessory") and HEADWEAR[acc.AccessoryType])
			local rel = f.pivot:ToObjectSpace(p.CFrame)
			if onHead then
				table.insert(f.head, p)
				table.insert(f.headBase, f.neck:ToObjectSpace(rel))
			else
				table.insert(f.body, p)
				table.insert(f.bodyBase, rel)
			end
		end
	end
	f.centre = f.pivot.Position
	for _, p in m:GetChildren() do
		if p.Name == "QiOrb" then
			table.insert(f.orbs, p)
			table.insert(f.orbBase, p.Position - f.centre)
		elseif p.Name == "AuraRing" or p.Name == "Halo" then
			table.insert(f.swell, { part = p, size = p.Size })
		end
	end
	local aura = m:FindFirstChild("Aura")
	f.emitter = aura and aura:FindFirstChildOfClass("ParticleEmitter")
	f.nextPuff = os.clock() + 4 + math.random() * 8
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

local TAU = math.pi * 2

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
			local t = now + f.phase
			local b = math.sin(t / BREATH * TAU)
			local s = math.sin(t / SWAY * TAU)
			local body = f.pivot * CFrame.new(0, 0.05 * b, 0) * CFrame.Angles(math.rad(-1.5 * b), 0, math.rad(1.2 * s))
			for i, p in f.body do
				table.insert(parts, p)
				table.insert(cfs, body * f.bodyBase[i])
			end
			-- the head leans against the sway and drifts slowly, so it never moves as one block
			local n = math.sin(t / NOD * TAU)
			local neck = body * f.neck * CFrame.Angles(math.rad(2.5 * n + 1 * b), math.rad(3 * math.sin(t / NOD * 0.5 * TAU)), math.rad(-1.6 * s))
			for i, p in f.head do
				table.insert(parts, p)
				table.insert(cfs, neck * f.headBase[i])
			end
			local spin = CFrame.Angles(0, now * 0.6, 0)
			for i, orb in f.orbs do
				local dir = (i % 2 == 0) and -1 or 1
				local turn = #f.orbs > 3 and CFrame.Angles(0, now * 0.6 * dir, 0) or spin
				table.insert(parts, orb)
				table.insert(cfs, CFrame.new(f.centre + turn * f.orbBase[i] + Vector3.new(0, 0.25 * math.sin(now * 1.3 + i), 0)))
			end
			-- the aura swells with the in-breath
			local k = 1 + 0.06 * (b + 1)
			for _, w in f.swell do
				w.part.Size = Vector3.new(w.size.X, w.size.Y * k, w.size.Z * k)
			end
			if f.emitter and now > f.nextPuff then
				f.emitter:Emit(6)
				f.nextPuff = now + 8 + math.random() * 6
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
