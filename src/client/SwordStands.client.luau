-- The hub's Flying Sword booth (HubShop.luau): every viewer sees their OWN avatar standing on each
-- sword for sale (owner 2026-10-24: "swords maybe? like their own avatar on them"). A local copy of
-- this player's character, in its rest pose and leaned like a rider (Config.SWORD_RIDE.lean), put
-- with its feet on each stand's RiderSpot. Built only while the player is within NEAR studs of a stand
-- (three extra avatars cost nothing far away), and again after a respawn or an outfit change.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rig = require(Shared:WaitForChild("Rig"))

local player = Players.LocalPlayer
local NEAR = 150 -- studs
local LEAN = CFrame.Angles(math.rad(-Config.SWORD_RIDE.lean), 0, 0)

local riders = {} -- [spot] = the local copy standing on it
local look = 0 -- bumped on every respawn / outfit change: copies of an older look are rebuilt

-- a still copy of the character: no scripts, no tools, out of physics, root anchored
local function copy(char)
	local was = char.Archivable
	char.Archivable = true
	local ok, m = pcall(char.Clone, char)
	char.Archivable = was
	if not ok or not m then
		return nil
	end
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	local root = m:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		m:Destroy()
		return nil
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.EvaluateStateMachine = false
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	for _, d in m:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			d.Transform = CFrame.identity -- the rest pose, not the walk caught mid-step
		end
	end
	Rig.live(m)
	root.Transparency = 1
	return m, root, hum
end

local function place(spot)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return
	end
	local m, root, hum = copy(char)
	if not m then
		return
	end
	m.Name = "MyRider"
	m:SetAttribute("Look", look)
	-- feet on the blade: the root sits hip height plus half its own height over the spot, leaned
	local up = root.Size.Y / 2 + hum.HipHeight + 0.1
	m:PivotTo(spot.CFrame * CFrame.new(0, up, 0) * LEAN)
	m.Parent = spot.Parent
	riders[spot] = m
end

local function clear(spot)
	if riders[spot] then
		riders[spot]:Destroy()
		riders[spot] = nil
	end
end

local function refresh()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	for _, spot in CollectionService:GetTagged("SwordStand") do
		local near = hrp and spot:IsDescendantOf(workspace) and (spot.Position - hrp.Position).Magnitude < NEAR
		local r = riders[spot]
		if near and (not r or not r.Parent or r:GetAttribute("Look") ~= look) then
			clear(spot)
			place(spot)
		elseif not near and r then
			clear(spot)
		end
	end
	for spot in riders do
		if not spot:IsDescendantOf(workspace) then
			clear(spot)
		end
	end
end

local function watch(char)
	look += 1
	char:WaitForChild("HumanoidRootPart", 10)
	task.wait(1) -- hair and clothes arrive just after the body
	look += 1
end
player.CharacterAdded:Connect(watch)
player.CharacterAppearanceLoaded:Connect(function()
	look += 1
end)

while true do
	refresh()
	task.wait(1)
end
