-- The guide trail (B01 step 5, mock A, Q2 picked 2026-10-21): jade chevrons painted on the ground
-- from the player's feet to the next pad, the same pad the HUD "Next:" names (the cheapest open
-- one). Shown while the sect has fewer than GUIDE_BUILT buildings, and later only after GUIDE_IDLE
-- seconds standing still. The chevrons are plain jade objects, never a light (RULES R3); they
-- drift slowly toward the pad. Local to this player.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

local JADE = Color3.fromHex("6FD6AA")
local EDGE = Color3.fromHex("225C4A")
local SPACING = 3.2 -- studs between chevrons
local SPEED = 2.2 -- studs per second toward the pad
local POOL = 30 -- chevrons at most (a ~95-stud trail)
local NEAR = 5 -- hide the last stretch: the pad's own beacon takes over

local folder = Instance.new("Folder")
folder.Name = "LocalGuide"
folder.Parent = workspace

local function part(parent, size, color, cf)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = color
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- one chevron = two arms in a V pointing along its model's -Z (LookVector), with a dark rim
-- slightly larger underneath so it reads on the light lawn and on the stone path
local chevrons = {}
for i = 1, POOL do
	local m = Instance.new("Model")
	m.Name = "Chevron"
	local arms = {}
	for side = -1, 1, 2 do
		local yaw = CFrame.Angles(0, side * math.rad(40), 0)
		local at = CFrame.new(side * 0.55, 0, 0.45) * yaw
		table.insert(arms, { part(m, Vector3.new(0.5, 0.12, 1.7), JADE, at), at })
		table.insert(
			arms,
			{ part(m, Vector3.new(0.72, 0.08, 1.9), EDGE, at * CFrame.new(0, -0.03, 0)), at * CFrame.new(0, -0.03, 0) }
		)
	end
	m.Parent = folder
	chevrons[i] = { model = m, arms = arms, shown = true }
end

local function place(c, cf, alpha)
	for _, a in c.arms do
		a[1].CFrame = cf * a[2]
		a[1].Transparency = alpha
	end
end

local function hide(c)
	if c.shown then
		c.shown = false
		for _, a in c.arms do
			a[1].Transparency = 1
		end
	end
end

local function myPads()
	local list = {}
	local peak = workspace:FindFirstChild("Sect")
		and workspace.Sect:FindFirstChild("Peak" .. tostring(player:GetAttribute("PlotIndex")))
	local built = peak and peak:FindFirstChild("Built")
	if built then
		for _, p in built:GetChildren() do
			if p.Name:sub(1, 4) == "Pad_" and p:GetAttribute("OwnerId") == player.UserId then
				table.insert(list, p)
			end
		end
	end
	return list
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundY(x, z, fallback)
	rayParams.FilterDescendantsInstances = { folder, player.Character }
	local hit = workspace:Raycast(Vector3.new(x, fallback + 12, z), Vector3.new(0, -30, 0), rayParams)
	return hit and hit.Position.Y or fallback
end

local target
local scan = 0
local still, lastPos = 0, nil
local offset = 0

RunService.RenderStepped:Connect(function(dt)
	scan += dt
	if scan > 0.5 then
		scan = 0
		local best
		for _, p in myPads() do
			if not best or (p:GetAttribute("Cost") or 0) < (best:GetAttribute("Cost") or 0) then
				best = p
			end
		end
		target = best
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		if lastPos and (hrp.Position - lastPos).Magnitude > 0.2 then
			still = 0
		else
			still += dt
		end
		lastPos = hrp.Position
	end
	local early = (player:GetAttribute("Built") or 0) < Config.GUIDE_BUILT and (player:GetAttribute("Realm") or 1) == 1
	local want = hrp and target and target.Parent and (early or still >= Config.GUIDE_IDLE)
	local from = hrp and Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
	local to = target and Vector3.new(target.Position.X, 0, target.Position.Z)
	local length = want and (to - from).Magnitude - NEAR or 0
	if length < 2 then
		for _, c in chevrons do
			hide(c)
		end
		return
	end
	local dir = (to - from).Unit
	offset = (offset + SPEED * dt) % SPACING
	local padY = target.Position.Y
	for i, c in chevrons do
		local d = 1.5 + (i - 1) * SPACING + offset
		if d > length then
			hide(c)
		else
			local p = from + dir * d
			local y = groundY(p.X, p.Z, padY) + 0.08
			-- fade in at the feet and out before the pad, so the trail never pops
			local alpha = math.max(0, 1 - math.min((d - 1.5) / 3, (length - d) / 3, 1))
			c.shown = true
			place(c, CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X + dir.X, y, p.Z + dir.Z)), alpha)
		end
	end
end)
