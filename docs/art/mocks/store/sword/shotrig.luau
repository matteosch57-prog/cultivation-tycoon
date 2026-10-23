-- Thumbnail shoot rig (client, Play only). Rider held at P, camera placed relative to the sun.
-- _G.shot = { az, pitch, d, fov, shiftR, shiftU, yaw, speed, hide }
--   az: camera look azimuth, degrees from the sun's azimuth (+ = look right of the sun, sun goes left)
--   pitch: camera look pitch (+ = looking up); d: distance to the rider; shiftR/shiftU: camera slide
--   (studs) so the rider leaves the centre; yaw: rider facing, degrees from "facing the camera";
--   speed: studs/s the rider flies along its heading (loops every 5 s); hide: character hidden
local RS = game:GetService("RunService")
local p = game.Players.LocalPlayer
local char = p.Character
local hrp = char.HumanoidRootPart
_G.P = _G.P or hrp.Position
local sun = Vector3.new(-0.9053, 0, 0.1994).Unit
local sunAz = math.atan2(sun.X, sun.Z)
local t0 = os.clock()
local hidden = false
local function setHidden(h)
	if h == hidden then
		return
	end
	hidden = h
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = h and 1 or 0
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("SurfaceGui") then
			if h then
				d:SetAttribute("ShotWas", d.Enabled)
				d.Enabled = false
			elseif d:GetAttribute("ShotWas") ~= nil then
				d.Enabled = d:GetAttribute("ShotWas")
			end
			if h and d:IsA("ParticleEmitter") then
				d:Clear()
			end
		end
	end
end
pcall(function()
	RS:UnbindFromRenderStep("thumbcam")
end)
RS:BindToRenderStep("thumbcam", Enum.RenderPriority.Last.Value, function()
	local s = _G.shot
	local c = workspace.CurrentCamera
	game.Lighting.ClockTime = _G.thumbClock or 16.5
	if not s then
		return
	end
	local a = sunAz + math.rad(s.az or 0)
	local pitch = math.rad(s.pitch or 0)
	local look = Vector3.new(math.sin(a) * math.cos(pitch), math.sin(pitch), math.cos(a) * math.cos(pitch))
	local lookH = Vector3.new(look.X, 0, look.Z).Unit
	local right = lookH:Cross(Vector3.yAxis)
	-- rider facing: towards the camera, turned by yaw
	local y = math.rad(s.yaw or 0)
	local face = CFrame.Angles(0, y, 0):VectorToWorldSpace(-lookH)
	local heading = s.speed and s.speed > 0 and face or Vector3.zero
	local t = (os.clock() - t0) % 5
	local P = _G.P + heading * (s.speed or 0) * t
	hrp.CFrame = CFrame.lookAt(P, P + face)
	local cam = P - look * s.d - right * (s.shiftR or 0) - Vector3.yAxis * (s.shiftU or 0)
	c.CameraType = Enum.CameraType.Scriptable
	c.CFrame = CFrame.lookAt(cam, cam + look)
	c.FieldOfView = s.fov or 50
	_G.camCF = c.CFrame
	_G.riderCF = hrp.CFrame
	setHidden(s.hide == true)
end)
return "rig on"
