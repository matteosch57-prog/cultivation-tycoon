-- Flying Sword flight (D76 v2, owner 2026-10-23 after trying the hover ride: "i cant fly with them?
-- When i jump they got removed? this is bad"): real flight, copied from Adopt Me's flying pets and the
-- cultivation games' Fly key. While this player rides (attribute Riding, set by the server):
--   PC        WASD flies where the camera looks (look up + W climbs, look down dives); hold Space to
--             rise, Ctrl or Q to sink; no input = hover in place with a gentle bob
--   phone     the thumbstick flies camera-relative; hold Jump to rise; the down arrow beside it sinks
--   gamepad   left stick, A rises, B sinks
-- Jumping never steps off: only the sword button, death / reset and the server's auto-off zones do.
-- The client owns its character, so the flight is local and instant: PlatformStand on, a
-- LinearVelocity eased toward the input x the tier's speed (rise / sink at RISE of it), an
-- AlignOrientation facing the way you go, banked into turns and pitched into a climb or a dive. It
-- never goes over the ceiling or out of the map (workspace attributes FlyCeiling / FlyBound) and
-- never into a closed islet of your own peak (player attribute FlyBlocks); the server checks the
-- same and puts you back (SwordRide.luau, R9).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local PerfMark = require(Shared:WaitForChild("PerfMark"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local RIDE = Config.SWORD_RIDE
local RISE = RIDE.rise -- share of the tier speed for rising and sinking
local EASE = 5 -- 1/s: how fast the velocity follows the input
local CEIL_EASE = 8 -- studs under the ceiling where the climb eases off
local GLIDE = 25 -- studs/s: the fastest fall after stepping off in the air (Adopt Me's glide)
local HOVER = 3.6 -- studs the root keeps over the ground (a walker's is ~3): the lifted feet and the sword stay clear

local fly -- { char, hum, root, att, lv, ao, speed, vel, heading, bank }
local sinkHeld = false

local function tierSpeed(key)
	for _, t in RIDE.tiers do
		if t.key == key then
			return Config.MOVE.walk * t.speed
		end
	end
	return Config.MOVE.walk
end

-- the phone's sink button: a toy down arrow left of Jump, only while riding
local gui = Instance.new("ScreenGui")
gui.Name = "SwordFly"
gui.ResetOnSpawn = false -- R19
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2
gui.Enabled = false
gui.Parent = playerGui
local sinkBtn
local function placeSink()
	gui:ClearAllChildren()
	sinkBtn = nil
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	if not (jump and jump.Visible and jump.AbsoluteSize.X > 0) then
		return
	end
	local size = math.floor(jump.AbsoluteSize.X * 0.72)
	local holder, btn = Toy.button(gui, UDim2.fromOffset(size, size), Color3.fromHex("3A2C44"), size / 2)
	holder.AnchorPoint = Vector2.new(1, 0.5)
	local at = jump.AbsolutePosition - gui.AbsolutePosition
	holder.Position = UDim2.fromOffset(at.X - size * 0.25, at.Y + jump.AbsoluteSize.Y / 2)
	-- a down chevron: two white bars meeting at the bottom (a glyph the Roblox font may not have)
	for _, side in { -1, 1 } do
		local bar = Toy.frame(btn, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * size * 0.1, 0.5, 0),
			Size = UDim2.fromOffset(math.floor(size * 0.34), math.max(3, math.floor(size * 0.1))),
			Rotation = side * -40,
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 3,
		})
		Toy.corner(bar, UDim.new(1, 0))
	end
	btn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			sinkHeld = true
		end
	end)
	btn.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			sinkHeld = false
		end
	end)
	sinkBtn = btn
end

-- the PlayerModule's controls (the raw move vector: thumbstick or WASD), looked up once and never
-- from the frame loop: Studio Play had no PlayerModule in PlayerScripts (only StarterPlayer's copy,
-- which must not be required: it would build a second set of controls), and a WaitForChild in
-- PreSimulation yielded every frame, so the sword never flew (Studio 2026-10-23)
local controls = nil
task.spawn(function()
	local scripts = player:WaitForChild("PlayerScripts", 10)
	local pm = scripts and scripts:WaitForChild("PlayerModule", 30)
	if not pm then
		return
	end
	local ok, mod = pcall(require, pm)
	if ok and type(mod) == "table" and mod.GetControls then
		local ok2, c = pcall(mod.GetControls, mod)
		controls = ok2 and c or nil
	end
end)
local function keyDown(...)
	for _, k in { ... } do
		if UserInputService:IsKeyDown(k) then
			return true
		end
	end
	return false
end
-- the move vector in the camera's flat frame (x right, z back), never yielding: the controls when
-- they give one, else WASD / arrows, else the humanoid's MoveDirection turned into the camera's yaw
local function moveVector(hum)
	if controls then
		local ok, v = pcall(controls.GetMoveVector, controls)
		if ok and typeof(v) == "Vector3" and v.Magnitude > 0.01 then
			return v
		end
	end
	local x = (keyDown(Enum.KeyCode.D, Enum.KeyCode.Right) and 1 or 0) - (keyDown(Enum.KeyCode.A, Enum.KeyCode.Left) and 1 or 0)
	local z = (keyDown(Enum.KeyCode.S, Enum.KeyCode.Down) and 1 or 0) - (keyDown(Enum.KeyCode.W, Enum.KeyCode.Up) and 1 or 0)
	if x ~= 0 or z ~= 0 then
		return Vector3.new(x, 0, z).Unit
	end
	local md = hum and hum.MoveDirection or Vector3.zero
	if md.Magnitude > 0.01 then
		local look = workspace.CurrentCamera.CFrame.LookVector
		local yaw = CFrame.lookAt(Vector3.zero, Vector3.new(look.X, 0, look.Z) + Vector3.new(0, 0, 1e-4))
		return yaw:VectorToObjectSpace(md)
	end
	return Vector3.zero
end

local function padDown(button)
	local ok, down = pcall(UserInputService.IsGamepadButtonDown, UserInputService, Enum.UserInputType.Gamepad1, button)
	return ok and down
end

local function stop()
	if not fly then
		return
	end
	local f = fly
	fly = nil
	gui.Enabled = false
	sinkHeld = false
	for _, x in { f.lv, f.ao, f.att } do
		if x then
			x:Destroy()
		end
	end
	if f.hum.Parent then
		f.hum.PlatformStand = false
		f.hum:ChangeState(Enum.HumanoidStateType.Freefall) -- the walk takes over (a soft landing: Movement.client)
		-- off in the air: glide down, the fall capped at GLIDE until the feet touch something
		local hum, root = f.hum, f.root
		local glide
		glide = RunService.PreSimulation:Connect(function()
			local state = hum:GetState()
			if fly or not root.Parent or hum.Health <= 0 or (state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.FallingDown) then
				glide:Disconnect()
				return
			end
			local v = root.AssemblyLinearVelocity
			if v.Y < -GLIDE then
				root.AssemblyLinearVelocity = Vector3.new(v.X, -GLIDE, v.Z)
			end
		end)
	end
end

local function start()
	stop()
	local key = player:GetAttribute("Riding")
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (key and hum and root and hum.Health > 0) then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "SwordFlyAt"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = 1e7
	lv.VectorVelocity = Vector3.zero
	lv.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.Responsiveness = 14
	ao.MaxTorque = 1e7
	ao.CFrame = CFrame.lookAt(Vector3.zero, root.CFrame.LookVector * Vector3.new(1, 0, 1) + Vector3.new(0, 0, 1e-4))
	ao.Parent = root
	hum.PlatformStand = true
	local look = root.CFrame.LookVector
	fly = { char = char, hum = hum, root = root, att = att, lv = lv, ao = ao, speed = tierSpeed(key), vel = root.AssemblyLinearVelocity, heading = Vector3.new(look.X, 0, look.Z).Unit, bank = 0 }
	gui.Enabled = true
	placeSink()
end

-- the closed islets of this player's own peak (server-made list of { x, z, r } in world studs)
local blocks = {}
local function readBlocks()
	local ok, t = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("FlyBlocks") or "[]")
	blocks = ok and type(t) == "table" and t or {}
end
player:GetAttributeChangedSignal("FlyBlocks"):Connect(readBlocks)
readBlocks()

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

RunService.PreSimulation:Connect(function(dt)
	local f = fly
	if not f then
		return
	end
	if not f.root.Parent or f.hum.Health <= 0 then
		stop()
		return
	end
	local t0 = PerfMark.begin()
	f.hum.PlatformStand = true
	-- the input: camera-relative move (with the camera's pitch), rise / sink held
	local cam = workspace.CurrentCamera
	local mv = moveVector(f.hum)
	local dir = cam.CFrame:VectorToWorldSpace(Vector3.new(mv.X, 0, mv.Z))
	local amount = math.min(1, mv.Magnitude)
	local rise = (keyDown(Enum.KeyCode.Space) or padDown(Enum.KeyCode.ButtonA) or f.hum.Jump) and 1 or 0
	f.hum.Jump = false -- a held jump rises; it never jumps or steps off
	local sink = (keyDown(Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.Q) or padDown(Enum.KeyCode.ButtonB) or sinkHeld) and 1 or 0
	local target = (dir.Magnitude > 0 and dir.Unit * f.speed * amount or Vector3.zero) + Vector3.new(0, (rise - sink) * f.speed * RISE, 0)
	if target.Magnitude < 0.5 then
		target = Vector3.new(0, math.sin(os.clock() * 2) * 0.6, 0) -- hover with a gentle bob
	end
	-- the limits: the ceiling, the map's edge, closed islets of my own peak, the ground under me
	local pos = f.root.Position
	local ceiling = workspace:GetAttribute("FlyCeiling") or math.huge
	-- the climb eases to nothing over the last CEIL_EASE studs (Studio 2026-10-23: W + Space looking up
	-- overshot 126 to 134.5), and over it pulls back down
	local room = ceiling - pos.Y
	if room < CEIL_EASE and target.Y > 0 then
		target = Vector3.new(target.X, target.Y * math.max(0, room / CEIL_EASE), target.Z)
	end
	if room < 0 then
		target = Vector3.new(target.X, math.min(target.Y, room * 4), target.Z)
	end
	local bound = workspace:GetAttribute("FlyBound") or math.huge
	local flat = Vector3.new(pos.X, 0, pos.Z)
	if flat.Magnitude > bound then
		local out = flat.Unit
		local along = target:Dot(out)
		if along > 0 then
			target -= out * along
		end
		target -= out * (flat.Magnitude - bound) * 2
	end
	for _, b in blocks do
		local d = Vector3.new(pos.X - b.x, 0, pos.Z - b.z)
		if d.Magnitude < b.r + 4 and d.Magnitude > 0 then
			local out = d.Unit
			local inward = -target:Dot(out)
			if inward > 0 then
				target += out * inward
			end
			if d.Magnitude < b.r + 2 then
				target += out * 10
			end
		end
	end
	rayParams.FilterDescendantsInstances = { f.char }
	local hit = workspace:Raycast(pos, Vector3.new(0, -(HOVER + 6), 0), rayParams)
	if hit and pos.Y - hit.Position.Y < HOVER then
		-- touching down keeps you on the sword, hovering over the ground (sinking or skimming a slope)
		target = Vector3.new(target.X, math.max(target.Y, (HOVER - (pos.Y - hit.Position.Y)) * 6), target.Z)
	end
	-- eased in and out
	local k = 1 - math.exp(-EASE * dt)
	f.vel = f.vel:Lerp(target, k)
	if room < CEIL_EASE and f.vel.Y > 0 then
		f.vel = Vector3.new(f.vel.X, math.min(f.vel.Y, math.max(0, room) / CEIL_EASE * f.speed * RISE), f.vel.Z) -- no momentum past it
	end
	f.lv.VectorVelocity = f.vel
	-- facing: the way you fly (or the last way), banked into turns, pitched into climbs and dives
	local hv = Vector3.new(f.vel.X, 0, f.vel.Z)
	local heading = f.heading
	if hv.Magnitude > 2 then
		heading = hv.Unit
	end
	local turn = f.heading:Cross(heading).Y -- + = turning left
	f.heading = heading
	f.bank += ((math.clamp(turn / math.max(dt, 1e-3) * 0.4, -1, 1) * math.rad(15)) - f.bank) * k
	local pitch = math.atan2(f.vel.Y, math.max(hv.Magnitude, 8)) * 0.6
	f.ao.CFrame = CFrame.lookAt(Vector3.zero, heading) * CFrame.Angles(pitch, 0, f.bank)
	PerfMark.finish("swordFly", t0)
end)

player:GetAttributeChangedSignal("Riding"):Connect(function()
	if player:GetAttribute("Riding") then
		start()
	else
		stop()
	end
end)
player.CharacterAdded:Connect(function()
	stop()
	if player:GetAttribute("Riding") then
		task.defer(start)
	end
end)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	if fly then
		task.defer(placeSink)
	end
end)
