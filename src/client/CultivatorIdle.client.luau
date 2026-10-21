-- Meditation idle for the seated cultivators (server: Cultivators.luau). The avatars are anchored
-- in a cross-legged pose; here the whole figure floats above its cushion and bobs, the upper body
-- rises and leans with each slow breath and sways side to side, and the head lives on its own: it
-- turns to watch a player who comes close, glances aside now and then, and drifts. The motes puff out
-- now and then, the face (a dynamic head) meditates with closed eyes, blinks them open now and then
-- and opens them with a faint smile to watch a close player, a ring pulses out on each in-breath (tier 8+), the orbs of light
-- circle, the magic circles turn, the halo circle and the spirit swords float with the figure, and
-- the Primordial's aura runs through every colour. Life: now and then the right hand lifts into a
-- raised mudra, a qi surge sends the orbs racing and the circles spinning while the figure draws in a
-- deep breath, and a visitor who comes close gets a small bow. Local only (nothing replicates): the motion stops
-- beyond FAR studs and the aura layers switch off beyond GLOW studs, which keeps phones cheap.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PerfMark = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PerfMark"))

local TAG = "Cultivator"
local FAR = 150
local BODY_R = 6 -- studs: a figure with its aura, for the on-screen test
local GLOW = 90
local WATCH = 24 -- studs: a player this close is watched
local HOVER = 0.7 -- studs above the cushion (Shop's Play: 2 studs read as detached)
local BOB = 0.25 -- studs of float bob
local FLOAT = 5.6 -- seconds per bob
local BREATH = 4.5 -- seconds per breath
local SWAY = 7.3 -- seconds per side-to-side sway
local NOD = 9.1 -- seconds per head drift
local LEGS = { HumanoidRootPart = true, LowerTorso = true, LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true }
local HEADWEAR = { [Enum.AccessoryType.Hair] = true, [Enum.AccessoryType.Face] = true, [Enum.AccessoryType.Hat] = true }
local RIGHT_ARM = { RightUpperArm = true, RightLowerArm = true, RightHand = true }
local TAU = math.pi * 2
local MUDRA = math.rad(55) -- how far the right arm lifts toward the chest
local SURGE = 2.5 -- seconds a qi surge lasts

local player = Players.LocalPlayer
local figures = {}

-- every aura layer of a figure: particle emitters, ribbons and orb trails
local function layersOf(m)
	local list = {}
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			table.insert(list, d)
		end
	end
	return list
end

local function add(m)
	local avatar = m:WaitForChild("Avatar", 10)
	local waist = avatar and avatar:WaitForChild("UpperTorso", 10)
	local head = avatar and avatar:WaitForChild("Head", 10)
	if not waist or not head or not m.Parent then
		return
	end
	local f = { legs = {}, legsBase = {}, body = {}, bodyBase = {}, head = {}, headBase = {}, orbs = {}, orbBase = {}, circles = {}, swords = {}, swordBase = {}, phase = math.random() * 20 }
	-- breathe about the bottom of the chest; the head turns about the neck
	f.pivot = waist.CFrame * CFrame.new(0, -waist.Size.Y / 2, 0)
	f.neck = f.pivot:ToObjectSpace(head.CFrame * CFrame.new(0, -head.Size.Y / 2, 0))
	for _, p in avatar:GetDescendants() do
		if p:IsA("BasePart") then
			local acc = p.Parent
			local rel = f.pivot:ToObjectSpace(p.CFrame)
			if LEGS[p.Name] then
				table.insert(f.legs, p)
				table.insert(f.legsBase, rel)
			elseif p == head or (acc:IsA("Accessory") and HEADWEAR[acc.AccessoryType]) then
				table.insert(f.head, p)
				table.insert(f.headBase, f.neck:ToObjectSpace(rel))
			else
				table.insert(f.body, p)
				table.insert(f.bodyBase, rel)
			end
		end
	end
	f.centre = f.pivot.Position
	-- the right arm can lift into a raised mudra: it turns about the shoulder
	local upper = avatar:FindFirstChild("RightUpperArm")
	if upper then
		f.shoulder = f.pivot:ToObjectSpace(upper.CFrame * CFrame.new(0, upper.Size.Y / 2, 0))
		f.arm = {}
		for i, p in f.body do
			if RIGHT_ARM[p.Name] then
				f.arm[i] = true
			end
		end
	end
	for _, p in m:GetChildren() do
		if p.Name == "AuraOrb" then
			table.insert(f.orbs, p)
			table.insert(f.orbBase, p.Position - f.centre)
		elseif p.Name == "SigilCircle" or p.Name == "SigilCircle2" then
			table.insert(f.circles, { part = p, base = p.CFrame, dir = p.Name == "SigilCircle" and 1 or -1 })
		elseif p.Name == "Sword" then
			table.insert(f.swords, p)
			table.insert(f.swordBase, p.CFrame)
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
	f.layers = layersOf(m)
	f.lit = true
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

local MAX_YAW = math.rad(55)

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local t0 = PerfMark.begin()
	local eye = cam.CFrame.Position
	local char = player and player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local now = os.clock()
	local ease = math.min(1, dt * 2.5)
	local parts, cfs = {}, {}
	for m, f in figures do
		local dist = (f.centre - eye).Magnitude
		if m.Parent and (dist < GLOW) ~= f.lit then
			f.lit = dist < GLOW
			for _, l in f.layers do
				l.Enabled = f.lit
			end
			if f.rim then
				f.rim.Enabled = f.lit
			end
		end
		if not m.Parent then
			figures[m] = nil
		elseif dist < FAR and PerfMark.onScreen(cam, f.centre, BODY_R) then -- nothing moves unseen
			local t = now + f.phase
			local b = math.sin(t / BREATH * TAU)
			local s = math.sin(t / SWAY * TAU)
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
			local up = HOVER + BOB * math.sin(t / FLOAT * TAU) + 0.25 * k
			local lift = f.pivot + Vector3.new(0, up, 0)
			for i, p in f.legs do
				table.insert(parts, p)
				table.insert(cfs, lift * f.legsBase[i])
			end
			-- the raised mudra: the right hand lifts to the chest for a few breaths, then returns
			local raise = now > f.nextMudra and now < f.nextMudra + 3.5
			if now > f.nextMudra + 3.5 then
				f.nextMudra = now + 10 + math.random() * 12
			end
			f.mudra += ((raise and 1 or 0) - f.mudra) * math.min(1, dt * 3)
			-- a small bow to a visitor, once each time someone comes close
			local bow = math.sin(math.pi * math.clamp((now - f.bowAt) / 1.2, 0, 1)) * math.rad(10)
			local body = lift * CFrame.new(0, 0.05 * b + 0.06 * k, 0) * CFrame.Angles(math.rad(-1.5 * b) - bow * 0.4 - math.rad(3) * k, 0, math.rad(1.2 * s))
			local arm = f.shoulder and body * f.shoulder * CFrame.Angles(-MUDRA * f.mudra, 0, 0) * f.shoulder:Inverse()
			for i, p in f.body do
				table.insert(parts, p)
				table.insert(cfs, (arm and f.arm[i] and arm or body) * f.bodyBase[i])
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
				f.face.LeftEyeClosed, f.face.RightEyeClosed = f.eyes, f.eyes
				f.face.LeftLipCornerPuller, f.face.RightLipCornerPuller = f.smile, f.smile
			end
			local n = math.sin(t / NOD * TAU)
			local neck = body * f.neck * CFrame.Angles(0, f.yaw, 0) * CFrame.Angles(f.pitch - bow + math.rad(2.5 * n + 1 * b), math.rad(3 * math.sin(t / NOD * 0.5 * TAU)), math.rad(-1.6 * s))
			for i, p in f.head do
				table.insert(parts, p)
				table.insert(cfs, neck * f.headBase[i])
			end
			if f.halo then
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
				f.rim.FillTransparency = f.rimFill - 0.3 * k
			end
			if f.haloCircle then
				table.insert(parts, f.haloCircle)
				table.insert(cfs, CFrame.new(f.haloPos + Vector3.new(0, up, 0)) * f.haloTurn * CFrame.Angles(0, now * 0.4, 0))
			end
			-- the spirit swords hover with the figure, each on its own small rhythm
			for i, sword in f.swords do
				table.insert(parts, sword)
				table.insert(cfs, f.swordBase[i] + Vector3.new(0, up + 0.12 * math.sin(now * 1.7 + i * 0.9), 0))
			end
			-- the orbs circle (alternate directions from 4 orbs); in a surge they race and rise
			local spin = CFrame.Angles(0, f.orbAngle, 0)
			for i, orb in f.orbs do
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
					for _, sword in f.swords do
						sword.Color = c
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
