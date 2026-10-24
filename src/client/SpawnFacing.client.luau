-- Turns the follow camera to look the way the avatar was just placed (owner 2026-10-24: "when
-- spawning a new player, make sure they look toward their island"). The server's PivotTo moves the
-- avatar but the camera keeps its old direction, so a new player first saw the bridge behind them.
-- Main.server sets FaceAt / FaceLook and bumps FaceTurn on each placement (spawn on the peak, the
-- MY BASE and RANKINGS teleports); the launch screen's dive ends where this leaves the camera.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local BACK, UP = 14, 6 -- studs behind and above the avatar, about the default follow distance

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
