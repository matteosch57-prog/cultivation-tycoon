-- Turns the follow camera to look the way the avatar was just placed (owner 2026-10-24: "when
-- spawning a new player, make sure they look toward their island"). The server's PivotTo moves the
-- avatar but the camera keeps its old direction, so a new player first saw the bridge behind them.
-- Main.server sets FaceAt / FaceLook and bumps FaceTurn on each placement (spawn on the peak, the
-- MY BASE and RANKINGS teleports); the launch screen's dive ends where this leaves the camera.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local BACK, UP = 17, 7 -- studs behind and above the avatar, about the start zoom below

-- the start zoom (owner 2026-10-24: "make the default zoom higher like 20%"): Roblox starts the follow
-- camera 12.5 studs out; the camera module only moves out to a raised minimum, so the minimum is held
-- at CAMERA_ZOOM until the follow camera runs (the launch screen holds it first), then given back, and
-- the player can zoom in again
task.spawn(function()
	local before = player.CameraMinZoomDistance
	player.CameraMinZoomDistance = math.max(before, Config.CAMERA_ZOOM)
	local t0 = os.clock()
	repeat
		task.wait(0.1)
	until (player.Character and workspace.CurrentCamera.CameraType == Enum.CameraType.Custom) or os.clock() - t0 > 180
	task.wait(0.3)
	player.CameraMinZoomDistance = before
end)

local turn = 0
local function face()
	turn += 1
	local mine = turn
	local at, look = player:GetAttribute("FaceAt"), player:GetAttribute("FaceLook")
	if typeof(at) ~= "Vector3" or typeof(look) ~= "Vector3" then
		return
	end
	-- wait for the avatar to arrive here (the move can reach this client after the attribute)
	local t0 = os.clock()
	local hrp
	repeat
		local char = player.Character
		hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - at).Magnitude < 12 then
			break
		end
		task.wait(0.05)
	until os.clock() - t0 > 3 or mine ~= turn
	if mine ~= turn or not hrp then
		return
	end
	local flat = (look * Vector3.new(1, 0, 1))
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local cam = workspace.CurrentCamera
	if cam.CameraType ~= Enum.CameraType.Custom then
		return -- the launch screen holds the camera; its dive reads it again at the tap
	end
	local focus = hrp.Position + Vector3.new(0, 1.5, 0)
	cam.CFrame = CFrame.lookAt(focus - flat * BACK + Vector3.new(0, UP, 0), focus)
end

player:GetAttributeChangedSignal("FaceTurn"):Connect(face)
if player:GetAttribute("FaceTurn") then
	task.spawn(face)
end
