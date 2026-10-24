-- The guide trail (B01 step 5, mock A, Q2 picked 2026-10-21): jade chevrons painted on the ground
-- from the player's feet to the next pad, the same pad the HUD "Next:" names (the cheapest open
-- one, or the recruiting building's while it waits: Config.guidePick, then shown always). Shown
-- while the sect has fewer than GUIDE_BUILT buildings, and later only after GUIDE_IDLE
-- seconds standing still. The chevrons are plain jade objects, never a light (RULES R3); they
-- drift slowly toward the pad. Local to this player. A first-time tip (Tips.client, D50) takes the
-- trail over by setting the local attribute TipTarget (a Vector3) while it is shown. A local
-- attribute GuideTo (Vector3) points the trail at that spot instead, shown at once (the Heavenly
-- Altar row sets it on a tap); it wins over a tip.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PerfMark = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PerfMark"))

local player = Players.LocalPlayer

local JADE = Color3.fromHex("6FD6AA")
local EDGE = Color3.fromHex("225C4A")
local SPACING = 3.2 -- studs between chevrons
local SPEED = 2.2 -- studs per second toward the pad
local POOL = 36 -- chevrons at most (a ~115-stud trail)
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

-- Sky Islets: the trail never points across open sky. When the goal stands on another islet, it
-- follows the whole way there, bridge after bridge (out over the bridges toward it, or back over this
-- islet's own bridge toward the heart), with no gap at the bridges (owner 2026-10-24: "they cut at
-- bridges, it shouldnt be"). Islets and bridges: Config.ISLETS, Config.bridgeEnds.
local function peakFrame()
	local idx = player:GetAttribute("PlotIndex")
	if not idx then
		return nil
	end
	local a = (idx - 1) / Config.PLOT_COUNT * math.pi * 2
	local c = Vector3.new(math.cos(a) * Config.PLOT_RADIUS, 0, math.sin(a) * Config.PLOT_RADIUS)
	return CFrame.lookAt(c, Vector3.zero) * CFrame.Angles(0, math.pi, 0)
end
local BRIDGE_HALF = 4 -- studs: feet this close to a bridge's line, between its ends, are on it
-- islet `name`, then each islet on the way back to the heart
local function chain(name)
	local list = {}
	while name do
		table.insert(list, name)
		name = Config.ISLETS[name].from
	end
	return list
end
-- the corners of the walk to `toWorld` (world, Y = 0), ending at it: 2 studs before and after each
-- bridge it crosses
local function route(fromWorld, toWorld)
	local goal = Vector3.new(toWorld.X, 0, toWorld.Z)
	local frame = peakFrame()
	if not frame then
		return { goal }
	end
	local lf, lt = frame:PointToObjectSpace(fromWorld), frame:PointToObjectSpace(toWorld)
	local down = chain((Config.isletAt(lt.X, lt.Z)))
	local onDown = {}
	for i, name in down do
		onDown[name] = i
	end
	-- on a bridge, the walk goes on over it: the far end of it toward the goal comes first
	local here = Config.isletAt(lf.X, lf.Z)
	local feet = Vector3.new(lf.X, 0, lf.Z)
	for name, i in Config.ISLETS do
		if i.bridge then
			local foot, land = Config.bridgeEnds(name)
			local ab = land - foot
			local t = (feet - foot):Dot(ab) / ab:Dot(ab)
			if t > 0 and t < 1 and (foot + ab * t - feet).Magnitude < BRIDGE_HALF then
				here = if onDown[name] then i.from else name
			end
		end
	end
	local up = chain(here)
	local pts = {}
	local function cross(a, b) -- over one bridge, from end a to end b (peak frame)
		local d = (b - a).Unit * 2
		table.insert(pts, frame * (a - d))
		table.insert(pts, frame * (b + d))
	end
	local meet = #down
	for _, name in up do -- back toward the heart until the goal's chain
		if onDown[name] then
			meet = onDown[name]
			break
		end
		local foot, land = Config.bridgeEnds(name)
		cross(land, foot)
	end
	for i = meet - 1, 1, -1 do -- then out to the goal's islet
		local foot, land = Config.bridgeEnds(down[i])
		cross(foot, land)
	end
	for i, p in pts do
		pts[i] = Vector3.new(p.X, 0, p.Z)
	end
	table.insert(pts, goal)
	return pts
end
-- the trail's line from the feet `from` along `pts`: when the feet are on it (on a bridge, say),
-- it starts from the nearest point of it, so the corners already walked never pull the trail back
local ON_ROUTE = 8
local function trailLine(from, pts)
	local bestD, bestK, bestQ = (pts[1] - from).Magnitude, 0, nil
	for k = 1, #pts - 1 do
		local a, b = pts[k], pts[k + 1]
		local ab = b - a
		local t = ab.Magnitude > 0 and math.clamp((from - a):Dot(ab) / ab:Dot(ab), 0, 1) or 0
		local q = a + ab * t
		local d = (q - from).Magnitude
		if d < bestD then
			bestD, bestK, bestQ = d, k, q
		end
	end
	local line = { from }
	if bestK > 0 and bestD < ON_ROUTE then
		table.insert(line, bestQ)
	else
		bestK = 0
	end
	for k = bestK + 1, #pts do
		table.insert(line, pts[k])
	end
	return line
end

local target, priority
local scan = 0
local still, lastPos = 0, nil
local offset = 0

RunService.RenderStepped:Connect(function(dt)
	local t0 = PerfMark.begin()
	scan += dt
	if scan > 0.5 then
		scan = 0
		target, priority = Config.guidePick(myPads()) -- the recruiting building first (Config.GUIDE_PRIORITY)
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
	local guideTo = player:GetAttribute("GuideTo") or player:GetAttribute("TipTarget")
	local goalPos = guideTo or (target and target.Parent and target.Position)
	local want = hrp and goalPos and (guideTo or early or priority or still >= Config.GUIDE_IDLE)
	local from = hrp and Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
	local line = want and trailLine(from, route(hrp.Position, goalPos))
	local length = -NEAR
	for k = 2, line and #line or 0 do
		length += (line[k] - line[k - 1]).Magnitude
	end
	if length < 2 then
		for _, c in chevrons do
			hide(c)
		end
		PerfMark.finish("guide", t0)
		return
	end
	offset = (offset + SPEED * dt) % SPACING
	local padY = goalPos.Y
	local k, segStart = 2, 0 -- the stretch of the line the next chevron falls on
	for i, c in chevrons do
		local d = 1.5 + (i - 1) * SPACING + offset
		while k < #line and d > segStart + (line[k] - line[k - 1]).Magnitude do
			segStart += (line[k] - line[k - 1]).Magnitude
			k += 1
		end
		if d > length then
			hide(c)
		else
			local a, b = line[k - 1], line[k]
			local dir = (b - a).Magnitude > 0 and (b - a).Unit or Vector3.zAxis
			local p = a + dir * (d - segStart)
			local y = groundY(p.X, p.Z, padY) + 0.08
			-- fade in at the feet and out before the pad, so the trail never pops
			local alpha = math.max(0, 1 - math.min((d - 1.5) / 3, (length - d) / 3, 1))
			c.shown = true
			place(c, CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X + dir.X, y, p.Z + dir.Z)), alpha)
		end
	end
	PerfMark.finish("guide", t0)
end)
