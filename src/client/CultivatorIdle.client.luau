-- Meditation idle for the seated cultivators (server: Cultivators.luau). The avatars sit
-- cross-legged on their own joints, the root anchored; here the whole figure floats above its cushion and bobs, the upper body
-- rises and leans with each slow breath and sways side to side, and the head lives on its own: it
-- turns to watch a player who comes close, glances aside now and then, and drifts. The motes puff out
-- now and then, the face (a dynamic head) meditates with closed eyes, blinks them open now and then
-- and opens them with a faint smile to watch a close player, a ring pulses out on each in-breath (tier 8+), the orbs of light
-- circle, the magic circles turn, the halo circle and the spirit swords float with the figure, and
-- the Primordial's aura runs through every colour. Life: now and then the right hand lifts into a
-- raised mudra, a qi surge sends the orbs racing and the circles spinning while the figure draws in a
-- deep breath, and a visitor who comes close gets a small bow. Local only (nothing replicates): the motion stops
-- beyond FAR studs and the aura layers switch off beyond GLOW studs, which keeps phones cheap.
-- Phone fps 2026-10-23 (the owner's Pixel near a full sect of 41): only the nearest FULL_N figures
-- (within FULL_R) draw their orbs of light and blade orbs (the heavy particles), the Highlights (rims,
-- sword fans, Shiny outlines) go to the nearest figures up to HL_BUDGET, and the other figures move
-- on every SLOW-th frame. Phones and low graphics settings get the smaller budgets.
-- The figure moves through its own joints (Rig.luau): the float on its anchored root, the breath on
-- the waist, the look on the neck, the mudra on the shoulder, so the robe, the hair and the props
-- move with the body (owner 2026-10-22: the robe stayed behind and the hair stayed fixed when every
-- part was moved on its own). Each joint eases toward its target at its own pace, the head and arms
-- a beat after the chest, so the motion flows instead of moving as one block.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PerfMark = require(Shared:WaitForChild("PerfMark"))
local PerfScene = require(Shared:WaitForChild("PerfScene"))
local Rig = require(Shared:WaitForChild("Rig"))
local POSES = require(Shared:WaitForChild("CultivatorPoses"))

local TAG = "Cultivator"
local FAR = 150
local BODY_R = 9 -- studs: a figure with its aura and sword fan, for the on-screen test
local GLOW = 90
local SLOW = 3 -- a figure outside the full set moves every SLOW-th frame (its motion is slow anyway)
-- [small device or low graphics] = the budgets
local BUDGET = {
	[true] = { FULL_N = 8, FULL_R = 45, HL = 10 },
	[false] = { FULL_N = 16, FULL_R = 70, HL = 28 },
}
-- the heavy aura layers: only the full set draws them
local HEAVY = { Glow = true, Heart = true, Tail = true, BladeOrbs = true }
local WATCH = 24 -- studs: a player this close is watched
local HOVER = 0.7 -- studs above the cushion (Shop's Play: 2 studs read as detached)
local BOB = 0.25 -- studs of float bob
local FLOAT = 5.6 -- seconds per bob
local BREATH = 4.5 -- seconds per breath
local SWAY = 7.3 -- seconds per side-to-side sway
local NOD = 9.1 -- seconds per head drift
-- how fast each joint catches up with its target (per second): the chest leads, the head and the
-- arms follow a beat later (overlapping action)
local FOLLOW = { Waist = 9, Neck = 6, LeftShoulder = 5, RightShoulder = 5, LeftElbow = 4, RightElbow = 4 }
local TAU = math.pi * 2
local MUDRA = math.rad(55) -- how far the right arm lifts toward the chest
local SURGE = 2.5 -- seconds a qi surge lasts

local player = Players.LocalPlayer
local figures = {}

-- every aura layer of a figure: particle emitters, ribbons and orb trails; the heavy ones apart
local function layersOf(m)
	local list, heavy = {}, {}
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			table.insert(if HEAVY[d.Name] then heavy else list, d)
		end
	end
	return list, heavy
end

local function add(m)
	local avatar = m:WaitForChild("Avatar", 10)
	local waist = avatar and avatar:WaitForChild("UpperTorso", 10)
	local head = avatar and avatar:WaitForChild("Head", 10)
	if not waist or not head or not m.Parent then
		return
	end
	local root = avatar:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local f = { orbs = {}, orbBase = {}, circles = {}, swords = {}, swordBase = {}, phase = math.random() * 20 }
	f.joints = Rig.joints(avatar)
	f.now = {} -- the eased joint rotations
	f.pose = POSES[m:GetAttribute("Pose") or "seated"] or {}
	f.rootPart = root
	f.rootBase = root.CFrame
	-- the body's frame at the bottom of the chest, where the waist joint breathes; the neck above it
	f.pivot = waist.CFrame * CFrame.new(0, -waist.Size.Y / 2, 0)
	f.neck = f.pivot:ToObjectSpace(head.CFrame * CFrame.new(0, -head.Size.Y / 2, 0))
	f.centre = f.pivot.Position
	for _, p in m:GetChildren() do
		if p.Name == "AuraOrb" then
			table.insert(f.orbs, p)
			table.insert(f.orbBase, p.Position - f.centre)
		elseif p.Name == "SigilCircle" or p.Name == "SigilCircle2" then
			table.insert(f.circles, { part = p, base = p.CFrame, dir = p.Name == "SigilCircle" and 1 or -1 })
		elseif p.Name == "SwordFan" then
			-- a spirit sword is a Model of mesh pieces: every piece bobs with the same phase; the fan
			-- shares one rim glow (Aura)
			f.fan = p:FindFirstChild("Aura")
			for _, sword in p:GetChildren() do
				if sword.Name == "Sword" then
					table.insert(f.swords, sword)
					local pieces = {}
					for _, q in sword:GetDescendants() do
						if q:IsA("BasePart") then
							table.insert(pieces, { part = q, base = q.CFrame })
						end
					end
					table.insert(f.swordBase, pieces)
				end
			end
		elseif p.Name == "MountSword" then
			-- a flyer's sword rides the float with its rider
			f.mount = {}
			for _, q in p:GetDescendants() do
				if q:IsA("BasePart") then
					table.insert(f.mount, { part = q, base = q.CFrame })
				end
			end
		elseif p.Name == "HaloCircle" then
			-- the halo circle stands just behind the head, wherever the template put the head
			f.haloCircle = p
			f.haloTurn = p.CFrame.Rotation
			f.haloPos = head.Position - head.CFrame.LookVector * 0.85
		end
	end
	f.rim = avatar:FindFirstChild("Rim")
	local aura = m:FindFirstChild("Aura")
	f.halo = aura and aura:FindFirstChild("HaloAt")
	-- the halo sits just behind the head, wherever the template put the head
	f.haloBase = f.halo and f.halo.Parent.CFrame:PointToObjectSpace(head.Position - head.CFrame.LookVector * 0.7)
	f.motes = aura and aura:FindFirstChild("Motes", true)
	f.pulse = aura and aura:FindFirstChild("Pulse", true)
	f.layers, f.heavy = layersOf(m)
	f.lit, f.full = true, true
	f.acc = 0
	f.slot = math.random(0, SLOW - 1)
	f.prismatic = m:GetAttribute("Prismatic") == true
	f.nextPuff = os.clock() + 4 + math.random() * 8
	f.yaw, f.pitch = 0, 0
	f.glance, f.nextGlance = 0, os.clock() + 3 + math.random() * 6
	f.face = head:FindFirstChildOfClass("FaceControls")
	f.eyes, f.smile = 1, 0
	f.nextOpen = os.clock() + 2 + math.random() * 6
	-- life: a raised-hand mudra now and then, a qi surge now and then, a small bow to a visitor
	f.mudra, f.nextMudra = 0, os.clock() + 6 + math.random() * 12
	f.surgeAt, f.nextSurge = -100, os.clock() + 8 + math.random() * 14
	f.bowAt = -100
	f.orbAngle, f.circleAngle = math.random() * TAU, 0
	f.rimFill = f.rim and f.rim.FillTransparency
	f.model = m
	figures[m] = f
	-- a layer that arrives late (streaming, a Shiny's glints) joins the budget in the figure's state
	m.DescendantAdded:Connect(function(d)
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			local heavy = HEAVY[d.Name] == true
			table.insert(if heavy then f.heavy else f.layers, d)
			d.Enabled = if heavy then f.full else f.lit
		end
	end)
end

-- Arrival (owner 2026-10-22): a new recruit walks in from behind its cushion with Roblox's own R15
-- walk (a Roblox animation plays in any experience, nothing to upload), bows to the sect, then
-- its seated figure fades in where it stood. Research: a keyframed walk reads natural where a
-- procedural one reads stiff, and the default walk is what players know from their own avatar.
local WALK_ANIM = "rbxassetid://507777826"
local WALK_SPEED = 5 -- studs per second
local BOW_TIME = 1.8 -- seconds, down and up

-- the arrival bow at depth k (0..1) as joint rotations (+X swings a limb forward, -X bends the
-- waist forward), with the stance: hips back and down, the feet where they stood (Rig.leg)
local function bowPose(k, legs)
	local A = function(x, y, z)
		return CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0))
	end
	local rot = {
		Waist = A(-34 * k),
		Neck = A(-14 * k),
		RightShoulder = A(45 * k, 0, -22 * k),
		RightElbow = A(75 * k),
		LeftShoulder = A(45 * k, 0, 22 * k),
		LeftElbow = A(75 * k),
	}
	local dy, dz = -0.12 * k, 0.22 * k
	rot.Body = CFrame.new(0, dy, dz)
	for _, side in { "Left", "Right" } do
		if legs[side] then
			local hip, knee, ankle = Rig.leg(legs[side], dy, dz, 0)
			rot[side .. "Hip"] = CFrame.Angles(hip, 0, 0)
			rot[side .. "Knee"] = CFrame.Angles(knee, 0, 0)
			rot[side .. "Ankle"] = CFrame.Angles(ankle, 0, 0)
		end
	end
	return rot
end
local function arrive(m)
	local at = m:GetAttribute("ArrivedAt")
	if not at then
		return
	end
	-- the walker streams in after the tag sometimes: wait for it (the first try missed it)
	local walker = m:WaitForChild("Walker", 4)
	local avatar = m:WaitForChild("Avatar", 4)
	local cushion = m:WaitForChild("Cushion", 4)
	if not walker or not avatar or not cushion then
		return
	end
	local hrp = walker:WaitForChild("HumanoidRootPart", 4)
	local hum = walker:WaitForChild("Humanoid", 4)
	if not hrp or not hum or workspace:GetServerTimeNow() - at > 8 then
		walker:Destroy() -- joined late: only the seated figure
		return
	end
	local seated = {}
	for _, p in avatar:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(seated, p)
			p.LocalTransparencyModifier = 1
		end
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = WALK_ANIM
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if ok then
		track.Looped = true
		track:Play(0.2)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { m }
	local lift = hum.HipHeight + hrp.Size.Y / 2
	local function groundY(x, z, fallback)
		local hit = workspace:Raycast(Vector3.new(x, fallback + 8, z), Vector3.new(0, -20, 0), params)
		return hit and hit.Position.Y or fallback
	end
	local from = hrp.Position
	local goal = Vector3.new(cushion.Position.X, 0, cushion.Position.Z)
	local flat = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
	local dir = flat.Unit
	local baseY = cushion.Position.Y
	local dist = flat.Magnitude - 0.5
	-- the walk eases in, then slows over the last steps; the walk cycle slows with it so the feet
	-- never skate (owner 2026-10-22: the walk and the bow need the whole-body treatment too)
	local t0, d = os.clock(), 0
	while walker.Parent and m.Parent and d < dist do
		local dt = RunService.PreSimulation:Wait()
		local v = WALK_SPEED * math.min(1, (os.clock() - t0) / 0.4) * math.clamp((dist - d) / 1.6, 0.3, 1)
		d = math.min(dist, d + v * dt)
		if ok then
			track:AdjustSpeed(v / WALK_SPEED)
		end
		local x, z = from.X + dir.X * d, from.Z + dir.Z * d
		local pos = Vector3.new(x, groundY(x, z, baseY) + lift, z)
		hrp.CFrame = CFrame.lookAt(pos, pos + dir)
	end
	if ok then
		track:Stop(0.35)
	end
	task.wait(0.4) -- arrived: a breath standing still before the bow
	-- a bow to the sect from the hips: the hips sit back, the knees give, the chest folds forward
	-- and the hands meet in a salute, then everything rises again
	local stand = hrp.CFrame
	local joints = Rig.joints(walker)
	local legs = { Left = Rig.legLengths(joints, "Left"), Right = Rig.legLengths(joints, "Right") }
	local b0 = os.clock()
	while walker.Parent and m.Parent and os.clock() - b0 < BOW_TIME do
		RunService.PreSimulation:Wait()
		local u = (os.clock() - b0) / BOW_TIME
		-- down in the first third, a short hold, up slower
		local k = u < 0.3 and u / 0.3 or (u < 0.5 and 1 or 1 - (u - 0.5) / 0.5)
		k = k * k * (3 - 2 * k)
		local rot = bowPose(k, legs)
		Rig.apply(joints, rot)
		hrp.CFrame = stand * rot.Body
	end
	Rig.apply(joints, {})
	hrp.CFrame = stand
	-- the walker fades out as the seated figure fades in on its cushion, with a puff of qi
	local aura = m:FindFirstChild("Aura")
	local motes = aura and aura:FindFirstChild("Motes", true)
	if motes then
		motes:Emit(16)
	end
	local walkerParts = {}
	for _, p in walker:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(walkerParts, p)
		end
	end
	local f0 = os.clock()
	while m.Parent and os.clock() - f0 < 0.5 do
		local k = (os.clock() - f0) / 0.5
		for _, p in walkerParts do
			p.LocalTransparencyModifier = k
		end
		for _, p in seated do
			p.LocalTransparencyModifier = 1 - k
		end
		RunService.RenderStepped:Wait()
	end
	for _, p in seated do
		p.LocalTransparencyModifier = 0
	end
	if walker.Parent then
		walker:Destroy()
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(m)
	task.spawn(add, m)
	task.spawn(arrive, m)
end)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(m)
	figures[m] = nil
end)
for _, m in CollectionService:GetTagged(TAG) do
	task.spawn(add, m)
end

local MAX_YAW = math.rad(55)

-- Every 0.5 s, nearest first: which figures are lit (aura layers on), which are in the full set
-- (heavy layers on, moved every frame) and which keep their Highlights. A Highlight costs screen
-- fill on a phone (most of all the first, and more the more screen it covers; Roblox docs), and the
-- engine draws a limited number at once: rims, sword fans and Shiny outlines share HL budget slots
-- (the altar winner's rim and the swords' riders keep theirs, they are not figures).
local function setAll(list, on)
	for _, l in list do
		l.Enabled = on
	end
end
local function setHighlight(h, on)
	if h and h.Enabled ~= on then
		h.Enabled = on
	end
end
task.spawn(function()
	while true do
		task.wait(0.5)
		local cam = workspace.CurrentCamera
		if cam then
			local q = UserSettings().GameSettings.SavedQualityLevel.Value -- 0 = automatic
			local b = BUDGET[PerfScene.device() ~= "pc" or (q > 0 and q <= 4)]
			local eye = cam.CFrame.Position
			local list = {}
			for m, f in figures do
				if m.Parent then
					f.dist = (f.centre - eye).Magnitude
					table.insert(list, f)
				end
			end
			table.sort(list, function(x, y)
				return x.dist < y.dist
			end)
			local hl = 0
			for i, f in list do
				local lit = f.dist < GLOW
				local full = lit and i <= b.FULL_N and f.dist < b.FULL_R
				if lit ~= f.lit then
					f.lit = lit
					setAll(f.layers, lit)
				end
				if full ~= f.full then
					f.full = full
					setAll(f.heavy, full)
					for _, l in f.heavy do
						if not full and l:IsA("ParticleEmitter") then
							l:Clear()
						end
					end
				end
				f.shiny = f.shiny or f.model:FindFirstChild("ShinyOutline")
				for _, h in { f.rim, f.fan, f.shiny } do
					local on = lit and hl < b.HL
					if on then
						hl += 1
					end
					setHighlight(h, on)
				end
			end
		end
	end
end)

-- PreSimulation: the engine applies the joints' Transforms in one batch right after
local frame = 0
RunService.PreSimulation:Connect(function(frameDt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local t0 = PerfMark.begin()
	local eye = cam.CFrame.Position
	local char = player and player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local now = os.clock()
	frame += 1
	local parts, cfs = {}, {}
	for m, f in figures do
		local dist = (f.centre - eye).Magnitude
		f.acc += frameDt
		if not m.Parent or not f.rootPart.Parent then
			figures[m] = nil
		elseif dist < FAR and (f.full or (frame + f.slot) % SLOW == 0) and PerfMark.onScreen(cam, f.centre, BODY_R) then -- nothing moves unseen
			-- the time since this figure last moved (SLOW frames for one outside the full set)
			local dt = math.min(f.acc, 0.25) -- (a figure seen again after a while eases in, no jump)
			f.acc = 0
			local ease = math.min(1, dt * 2.5)
			local t = now + f.phase
			local b = math.sin(t / BREATH * TAU)
			local s = math.sin(t / SWAY * TAU)
			-- a figure seen again after a while gets fresh timers: otherwise every overdue surge and
			-- mudra fired at once the moment the platform came into view (Play 2026-10-22)
			if now - (f.lastSeen or 0) > 1 then
				f.nextSurge = math.max(f.nextSurge, now + 4 + math.random() * 12)
				f.nextMudra = math.max(f.nextMudra, now + 2 + math.random() * 10)
			end
			f.lastSeen = now
			-- a qi surge: the figure draws in a deep breath, orbs and circles race, the rim flares
			if f.lit and now > f.nextSurge then
				f.surgeAt = now
				f.nextSurge = now + 14 + math.random() * 14
				if f.motes then
					f.motes:Emit(14)
				end
			end
			local k = math.max(0, 1 - (now - f.surgeAt) / SURGE)
			k = k * k * (3 - 2 * k) -- smooth in and out
			-- outside the full set the figure holds its float height: moving the anchored root moves the
			-- whole avatar (every limb, robe and accessory), and the swords, halo and orbs ride on it, so
			-- a held figure only breathes through its joints (Studio 2026-10-24: 2.4 ms a frame for 41)
			-- a figure joining or leaving the full set eases between the two (a straight switch jumped
			-- up to 0.24 studs in one frame), then a held figure stops writing at all
			local target = f.full and (HOVER + BOB * math.sin(t / FLOAT * TAU) + 0.25 * k) or HOVER
			local up = target
			if f.up and math.abs(target - f.up) > 0.02 then
				up = f.up + (target - f.up) * math.min(1, dt * 3)
			end
			local moved = up ~= f.up
			f.up = up
			local lift = f.pivot + Vector3.new(0, up, 0)
			-- the whole figure floats on its anchored root; the folded legs ride with it
			if moved then
				f.rootPart.CFrame = f.rootBase + Vector3.new(0, up, 0)
			end
			-- the raised mudra: the right hand lifts to the chest for a few breaths, then returns
			local raise = now > f.nextMudra and now < f.nextMudra + 3.5
			if now > f.nextMudra + 3.5 then
				f.nextMudra = now + 10 + math.random() * 12
			end
			f.mudra += ((raise and 1 or 0) - f.mudra) * math.min(1, dt * 3)
			-- a small bow to a visitor, once each time someone comes close
			local bow = math.sin(math.pi * math.clamp((now - f.bowAt) / 1.2, 0, 1)) * math.rad(10)
			-- the chest rises and leans with each breath and sways side to side, on the waist joint
			local goal = {}
			goal.Waist = CFrame.new(0, 0.05 * b + 0.06 * k, 0) * CFrame.Angles(math.rad(-1.5 * b) - bow * 0.4 - math.rad(3) * k, 0, math.rad(1.2 * s))
			-- the shoulders rise a little on the in-breath, and the right hand lifts into the mudra;
			-- both turn in the body's frame, so the baked pose is undone around them
			local rise = math.rad(1.5 * b + 2 * k)
			goal.LeftShoulder = CFrame.Angles(0, 0, -rise)
			goal.RightShoulder = CFrame.Angles(-MUDRA * f.mudra, 0, rise)
			goal.RightElbow = CFrame.Angles(math.rad(-15) * f.mudra, 0, 0)
			for _, name in { "LeftShoulder", "RightShoulder", "RightElbow" } do
				local p = f.pose[name]
				if p then
					goal[name] = p:Inverse() * goal[name] * p
				end
			end
			-- the head watches a player who comes close, otherwise glances aside now and then
			local yaw, pitch = 0, 0
			local watching = false
			if root then
				local rel = lift:PointToObjectSpace(root.Position + Vector3.new(0, 1.5, 0))
				if rel.Magnitude < WATCH and rel.Z < 2 then
					yaw = math.clamp(math.atan2(-rel.X, -rel.Z), -MAX_YAW, MAX_YAW)
					pitch = math.clamp(math.atan2(rel.Y - f.neck.Y, math.sqrt(rel.X * rel.X + rel.Z * rel.Z)), math.rad(-20), math.rad(20))
					watching = true
				end
			end
			if watching and not f.watched then
				f.bowAt = now
			end
			f.watched = watching
			if not watching then
				if now > f.nextGlance then
					f.glance = (f.glance == 0) and math.rad(math.random(-35, 35)) or 0
					f.nextGlance = now + (f.glance == 0 and 5 + math.random() * 7 or 1.5 + math.random() * 1.5)
				end
				yaw = f.glance
			end
			f.yaw += (yaw - f.yaw) * ease
			f.pitch += (pitch - f.pitch) * ease
			-- eyes: closed in meditation, open for a moment now and then, wide open with a faint smile
			-- while watching a player
			if f.face then
				local eyes, smile = 0.92, 0
				if watching then
					eyes, smile = 0, 0.35
				elseif now > f.nextOpen then
					eyes = 0.1
					if now > f.nextOpen + 1.6 then
						f.nextOpen = now + 5 + math.random() * 8
					end
				end
				f.eyes += (eyes - f.eyes) * math.min(1, dt * 6)
				f.smile += (smile - f.smile) * ease
				-- a face pose write re-deforms the dynamic head: only a visible change is written
				if math.abs(f.eyes - (f.eyesSet or -1)) > 0.02 or math.abs(f.smile - (f.smileSet or -1)) > 0.02 then
					f.eyesSet, f.smileSet = f.eyes, f.smile
					f.face.LeftEyeClosed, f.face.RightEyeClosed = f.eyes, f.eyes
					f.face.LeftLipCornerPuller, f.face.RightLipCornerPuller = f.smile, f.smile
				end
			end
			local n = math.sin(t / NOD * TAU)
			goal.Neck = CFrame.Angles(0, f.yaw, 0) * CFrame.Angles(f.pitch - bow + math.rad(2.5 * n + 1 * b), math.rad(3 * math.sin(t / NOD * 0.5 * TAU)), math.rad(-1.6 * s))
			-- ease each joint toward its goal (the head and arms trail the chest) and write it
			local cur = f.now
			for name, rate in FOLLOW do
				local j = f.joints[name]
				if j then
					local g = goal[name] or CFrame.identity
					local c = (cur[name] or g):Lerp(g, 1 - math.exp(-rate * dt))
					cur[name] = c
					j.Transform = c
				end
			end
			if f.halo and moved then
				f.halo.Position = f.haloBase + Vector3.new(0, up, 0)
			end
			-- the magic circles turn (the second the other way), the halo circle about its own axis
			f.circleAngle += dt * 0.25 * (1 + 4 * k)
			f.orbAngle += dt * 0.6 * (1 + 3 * k)
			for _, c in f.circles do
				table.insert(parts, c.part)
				table.insert(cfs, c.base * CFrame.Angles(0, f.circleAngle * c.dir, 0))
			end
			if f.rim and f.lit then
				local fill = f.rimFill - 0.12 * k -- more washed the robe out to one colour
				if fill ~= f.rim.FillTransparency then
					f.rim.FillTransparency = fill
				end
			end
			if f.haloCircle and (f.full or moved) then
				table.insert(parts, f.haloCircle)
				table.insert(cfs, CFrame.new(f.haloPos + Vector3.new(0, up, 0)) * f.haloTurn * CFrame.Angles(0, now * 0.4, 0))
			end
			if moved then
				for _, piece in f.mount or {} do
					table.insert(parts, piece.part)
					table.insert(cfs, piece.base + Vector3.new(0, up, 0))
				end
			end
			-- the spirit swords hover with the figure, each on its own small rhythm (a held figure's
			-- swords hold still with it)
			-- (they bob 0.12 studs: every other frame is enough, and they are most of the parts moved)
			local swordsNow = if f.full then (frame + f.slot) % 2 == 0 else moved
			for i, pieces in swordsNow and f.swordBase or {} do
				local hover = Vector3.new(0, up + (f.full and 0.12 * math.sin(now * 1.7 + i * 0.9) or 0), 0)
				for _, piece in pieces do
					table.insert(parts, piece.part)
					table.insert(cfs, piece.base + hover)
				end
			end
			-- the orbs circle (alternate directions from 4 orbs); in a surge they race and rise. Only in
			-- the full set: elsewhere their light is off and they are invisible parts
			local spin = CFrame.Angles(0, f.orbAngle, 0)
			for i, orb in f.full and f.orbs or {} do
				local dir = (i % 2 == 0) and -1 or 1
				local turn = #f.orbs > 3 and CFrame.Angles(0, f.orbAngle * dir, 0) or spin
				table.insert(parts, orb)
				table.insert(cfs, CFrame.new(f.centre + Vector3.new(0, up + 0.25 * math.sin(now * 1.3 + i) + 0.8 * k, 0) + turn * f.orbBase[i]))
			end
			if f.lit then
				if f.motes and now > f.nextPuff then
					f.motes:Emit(6)
					f.nextPuff = now + 8 + math.random() * 6
				end
				-- one ring pulse at the top of each in-breath
				if f.pulse and b > 0.97 and not f.pulsed then
					f.pulse:Emit(1)
				end
				f.pulsed = b > 0.97
				if f.prismatic and now > (f.nextHue or 0) then
					f.nextHue = now + 0.1
					local c = Color3.fromHSV((now * 0.08) % 1, 0.9, 1)
					local cs = ColorSequence.new({ ColorSequenceKeypoint.new(0, c), ColorSequenceKeypoint.new(1, c:Lerp(Color3.new(1, 1, 1), 0.2)) })
					for _, l in f.layers do
						l.Color = cs
					end
					for _, c2 in f.circles do
						c2.part.Color = c
					end
					for _, l in f.heavy do
						l.Color = cs
					end
					if f.fan then
						f.fan.FillColor = c
						f.fan.OutlineColor = c:Lerp(Color3.new(1, 1, 1), 0.3)
					end
					if f.haloCircle then
						f.haloCircle.Color = c
					end
					if f.rim then
						f.rim.FillColor = c
						f.rim.OutlineColor = c:Lerp(Color3.new(1, 1, 1), 0.4)
					end
				end
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	PerfMark.finish("cultivators", t0)
end)
