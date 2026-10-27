-- Movement (owner 2026-10-21: "redo the moving and jumping, walking speed a bit higher, fit our
-- style"): a cultivator's light step. A faster walk, a higher jump that floats down softly, and one
-- cloud step in the air (jump again) that leaves a jade ring under the feet. The ring is a plain
-- jade object, never a light (R3). Numbers: Config.MOVE. Local to this player's own character
-- (the client owns its character's physics, so nothing here waits on the server).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PerfMark = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PerfMark"))

local player = Players.LocalPlayer
local MOVE = Config.MOVE
local JADE = Color3.fromHex("9FF5D0")
local NEW_PRESS = 0.12 -- s without a jump request before the next one counts as a new press

local function ring(at)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = JADE
	p.Transparency = 0.25
	p.Size = Vector3.new(0.2, 2, 2)
	p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)) -- the round faces up
	p.Parent = workspace
	local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(p, info, { Size = Vector3.new(0.1, 7, 7), Transparency = 1, CFrame = p.CFrame - Vector3.new(0, 0.6, 0) }):Play()
	task.delay(0.45, function()
		p:Destroy()
	end)
end

-- a Swift Steps level bought now speeds the walk at once (never a sword ride's speed)
player:GetAttributeChangedSignal("Dao_steps"):Connect(function()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and not player:GetAttribute("Riding") then
		hum.WalkSpeed = Config.walkSpeed(player:GetAttribute("Dao_steps"))
	end
end)

local conns = {}
local function setup(char)
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	-- a character can be replaced before its parts arrive (slow phone joins, live 2026-10-27): give up
	-- on it then, the next CharacterAdded sets up the new one
	local hum = char:WaitForChild("Humanoid", 60)
	local root = hum and char:WaitForChild("HumanoidRootPart", 60)
	if not root or player.Character ~= char then
		return
	end
	hum.WalkSpeed = Config.walkSpeed(player:GetAttribute("Dao_steps")) -- Swift Steps (Karma Shop)
	hum.UseJumpPower = false
	hum.JumpHeight = MOVE.jumpHeight
	-- the player's own animations stay untouched (owner 2026-10-22: "I want to use my avatar
	-- fully"; a Ninja run and Levitation jump used to replace them here)

	-- the soft fall: an upward force that takes part of gravity away while falling
	local att = Instance.new("Attachment")
	att.Name = "FloatAt"
	att.Parent = root
	local float = Instance.new("VectorForce")
	float.Name = "Float"
	float.RelativeTo = Enum.ActuatorRelativeTo.World
	float.ApplyAtCenterOfMass = true
	float.Attachment0 = att
	float.Force = Vector3.zero
	float.Parent = root

	local steps, lastReq, airSince = 0, 0, nil
	table.insert(conns, hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Freefall or new == Enum.HumanoidStateType.Jumping then
			airSince = airSince or os.clock()
		else
			airSince = nil
			steps = 0
		end
	end))
	-- a cloud step: a new jump press while in the air (JumpRequest covers keys, pads and the
	-- phone's jump button; holding it repeats, so only a press after a gap counts)
	table.insert(conns, UserInputService.JumpRequest:Connect(function()
		local now = os.clock()
		local fresh = now - lastReq > NEW_PRESS
		lastReq = now
		if not fresh or not airSince or now - airSince < 0.15 or steps >= MOVE.airSteps then
			return
		end
		if hum.Health <= 0 or hum:GetState() ~= Enum.HumanoidStateType.Freefall then
			return
		end
		steps += 1
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, MOVE.stepUp, v.Z)
		ring(root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0))
	end))
	table.insert(conns, RunService.Heartbeat:Connect(function()
		if not airSince then
			if float.Force ~= Vector3.zero then
				float.Force = Vector3.zero
			end
			return
		end
		local t0 = PerfMark.begin()
		local falling = root.AssemblyLinearVelocity.Y < 0
		local want = falling and Vector3.new(0, root.AssemblyMass * workspace.Gravity * MOVE.floatFall, 0) or Vector3.zero
		if float.Force ~= want then
			float.Force = want
		end
		PerfMark.finish("move", t0)
	end))
end

if player.Character then
	task.spawn(setup, player.Character)
end
player.CharacterAdded:Connect(setup)
