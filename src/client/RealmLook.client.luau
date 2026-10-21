-- Lightning in the realm 9+ storm clouds (src/server/RealmLook.luau builds the cloud, attribute Storm).
-- A short event flash (R3 allows those): a few neon segments inside the cloud for a blink, then a soft
-- thunder if the peak is near. Only for storms on screen (R16), one strike per storm every 9 to 20 s.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sfx = require(Shared:WaitForChild("Sfx"))
local PerfMark = require(Shared:WaitForChild("PerfMark"))
local sect = workspace:WaitForChild("Sect")

local fx = Instance.new("Folder")
fx.Name = "LocalStorm"
fx.Parent = workspace

local BOLT = Color3.fromRGB(200, 210, 255)
local SEE = 700 -- studs: farther storms are a grey smudge, no strike
local HEAR = 260
local rng = Random.new()

-- where bolts start: under the Storm cloud's first part (its flat underside), and its width
local function centreOf(folder)
	local storm = folder:FindFirstChild("Storm")
	local base = storm and storm:FindFirstChildWhichIsA("BasePart")
	return base and base.Position - Vector3.new(0, base.Size.Y / 2, 0), base and base.Size.X or 0
end

local function strike(pos, width)
	local last = pos + Vector3.new(rng:NextNumber(-0.25, 0.25) * width, 0, rng:NextNumber(-0.15, 0.15) * width)
	local drop = width * rng:NextNumber(0.25, 0.4)
	for _ = 1, 5 do
		local nextPos = last + Vector3.new(rng:NextNumber(-5, 5), -drop / 5, rng:NextNumber(-5, 5))
		local b = Instance.new("Part")
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Material = Enum.Material.Neon
		b.Color = BOLT
		b.Size = Vector3.new(0.8, 0.8, (nextPos - last).Magnitude)
		b.CFrame = CFrame.lookAt((last + nextPos) / 2, nextPos)
		b.Parent = fx
		Debris:AddItem(b, 0.14)
		last = nextPos
	end
end

local storms = {} -- [RealmLook folder] = true (only realm 9+ ones carry Storm)
local function track(d)
	if d.Name == "RealmLook" and d:IsA("Folder") then
		storms[d] = true
	end
end
sect.DescendantAdded:Connect(track)
for _, d in sect:GetDescendants() do
	track(d)
end

local nextAt = {} -- [folder] = os.clock() of its next strike
task.spawn(function()
	while true do
		task.wait(0.5)
		local t0 = PerfMark.begin()
		local now = os.clock()
		local cam = workspace.CurrentCamera
		for folder in storms do
			if not folder.Parent then
				storms[folder] = nil
				nextAt[folder] = nil
			elseif folder:GetAttribute("Storm") then
				local at = nextAt[folder]
				if not at then
					nextAt[folder] = now + rng:NextNumber(3, 12)
				elseif now >= at then
					nextAt[folder] = now + rng:NextNumber(9, 20)
					local pos, width = centreOf(folder)
					if pos and cam and (cam.CFrame.Position - pos).Magnitude < SEE and PerfMark.onScreen(cam, pos, width / 2) then
						strike(pos, width)
						if (cam.CFrame.Position - pos).Magnitude < HEAR then
							Sfx.play("thunder", { at = pos })
						end
					end
				end
			end
		end
		PerfMark.finish("storm", t0)
	end
end)
