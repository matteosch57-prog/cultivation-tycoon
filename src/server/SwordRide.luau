-- Flying Sword ride (D76, owner pick "Hover ride, faster each level"; PS99's hoverboards copied as
-- is). A sword pass (Config.SHOP_PASSES with `ride`) lets its owner stand on that sword: the server
-- welds the tier's look (SwordLook) under the feet, raises HipHeight by SWORD_RIDE.lift (the ride
-- floats a stud over the ground and still WALKS: stairs, slopes and walls work as on foot, so the
-- light stairs and locked isles stay closed) and sets WalkSpeed to MOVE.walk x the tier's speed.
-- Everyone sees it (the weld replicates). It gives no qi.
--
-- The client asks (Remotes.SwordRide: a sword key to mount, false to step off); the server checks
-- ownership, the place and the cap (R9). Off by itself: within SWORD_RIDE.padRadius of any pad (the
-- pads also ignore a rider: it never buys anything), on the Heavenly Altar while a round runs, on
-- death / reset, and when the root moves faster than the tier allows for a few checks running.
-- Player attributes: Riding = the sword key while riding, SwordPick = the last sword ridden (saved).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Guard = require(script.Parent:WaitForChild("Guard"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local SwordLook = require(script.Parent:WaitForChild("SwordLook"))

local SwordRide = {}

local RIDE = Config.SWORD_RIDE
local api -- { sessions, notify, remotes }
local rides = {} -- [player] = { key, tier, sword, hum, hip, walk, joint, c0, strikes, conns }

local function tierOf(key)
	for i, t in RIDE.tiers do
		if t.key == key then
			return i, t
		end
	end
	return nil, nil
end

-- the rider's lean: the root joint (R15 LowerTorso.Root, R6 HumanoidRootPart.RootJoint) tilted
-- forward; the animations still play over it
local function rootJoint(char)
	local lower = char:FindFirstChild("LowerTorso")
	local j = lower and lower:FindFirstChild("Root")
	if not j then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		j = hrp and hrp:FindFirstChild("RootJoint")
	end
	return j and j:IsA("Motor6D") and j or nil
end

function SwordRide.stop(player, reason)
	local r = rides[player]
	if not r then
		return
	end
	rides[player] = nil
	for _, c in r.conns do
		c:Disconnect()
	end
	if r.sword then
		r.sword:Destroy()
	end
	if r.hum and r.hum.Parent then
		r.hum.HipHeight = r.hip
		r.hum.WalkSpeed = r.walk
	end
	if r.joint and r.joint.Parent then
		r.joint.C0 = r.c0
	end
	player:SetAttribute("Riding", nil)
	if reason and reason ~= "player" and reason ~= "gone" then
		api.notify:FireClient(player, "swordOff", reason)
	end
end

-- why a ride cannot start or go on here (nil = it can)
local function blocked(hrp)
	local pos = hrp.Position
	for _, p in CollectionService:GetTagged("StepPad") do
		local d = pos - p.Position
		if Vector2.new(d.X, d.Z).Magnitude < RIDE.padRadius and math.abs(d.Y) < 10 then
			return "pad"
		end
	end
	local top = workspace:GetAttribute("AltarTop")
	if top and (workspace:GetAttribute("AltarUntil") or 0) > workspace:GetServerTimeNow() then
		local d = pos - top
		if Vector2.new(d.X, d.Z).Magnitude < (Config.ALTAR_RADIUS or 12) + 6 and d.Y > -4 and d.Y < 20 then
			return "altar"
		end
	end
	return nil
end

local function start(player, key)
	local s = api.sessions[player]
	local tier, def = tierOf(key)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (s and tier and hum and hrp and hum.Health > 0) then
		return
	end
	if not (s.passes and s.passes[key]) then
		return -- not owned (the client only offers owned swords)
	end
	local why = blocked(hrp)
	if why then
		api.notify:FireClient(player, "swordNo", why)
		return
	end
	SwordRide.stop(player, "switch")
	local sword = SwordLook.template(tier):Clone()
	local core = sword.PrimaryPart
	local top = sword:GetAttribute("Top") or 0.1
	local hip = hum.HipHeight
	local lift = RIDE.lift
	-- the feet stay at hrp - (half its height + HipHeight) while the lift raises the root: the blade
	-- top goes there, so the rider stands on the sword and its underside floats `lift - 2*top` up
	local feet = -(hrp.Size.Y / 2 + hip)
	core.CFrame = hrp.CFrame * CFrame.new(0, feet - top, 0)
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1 = hrp, core
	weld.C0 = CFrame.new(0, feet - top, 0)
	weld.Parent = core
	sword.Parent = char
	local r = { key = key, tier = tier, sword = sword, hum = hum, hip = hip, walk = hum.WalkSpeed, strikes = 0, conns = {} }
	hum.HipHeight = hip + lift
	hum.WalkSpeed = Config.MOVE.walk * def.speed
	local joint = rootJoint(char)
	if joint then
		r.joint, r.c0 = joint, joint.C0
		joint.C0 = joint.C0 * CFrame.Angles(math.rad(-RIDE.lean), 0, 0)
	end
	table.insert(r.conns, hum.Died:Connect(function()
		SwordRide.stop(player, "gone")
	end))
	table.insert(r.conns, char.AncestryChanged:Connect(function()
		if not char:IsDescendantOf(workspace) then
			SwordRide.stop(player, "gone")
		end
	end))
	rides[player] = r
	s.data.swordPick = key
	player:SetAttribute("Riding", key)
	player:SetAttribute("SwordPick", key)
	Telemetry.custom(player, "Sword", "ride", key, Telemetry.realmBucket(s.data.realm or 1))
end

-- a pass bought or found on join: the HUD button needs to know the last pick
function SwordRide.onJoin(player, s)
	if type(s.data.swordPick) == "string" and tierOf(s.data.swordPick) then
		player:SetAttribute("SwordPick", s.data.swordPick)
	end
end

function SwordRide.init(a)
	api = a
	local ev = Instance.new("RemoteEvent")
	ev.Name = "SwordRide"
	ev.Parent = api.remotes
	ev.OnServerEvent:Connect(function(player, key)
		if not Guard.allow(player, "SwordRide") then
			return
		end
		if key == false then
			SwordRide.stop(player, "player")
		elseif type(key) == "string" and #key <= 24 then
			start(player, key)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		SwordRide.stop(player, "gone")
	end)
	-- the checks: every 0.2 s for each rider (pads, the altar, the speed cap)
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, r in rides do
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not hrp then
					SwordRide.stop(player, "gone")
					continue
				end
				local why = blocked(hrp)
				if why then
					SwordRide.stop(player, why)
					continue
				end
				local v = hrp.AssemblyLinearVelocity
				local cap = Config.MOVE.walk * RIDE.tiers[r.tier].speed * RIDE.speedSlack
				if Vector2.new(v.X, v.Z).Magnitude > cap then
					r.strikes += 1
					if r.strikes >= RIDE.speedStrikes then
						SwordRide.stop(player, "speed")
					end
				else
					r.strikes = 0
				end
			end
		end
	end)
end

-- Studio hook (DebugSet "ride", key | false): ride without the button (ownership still checked)
function SwordRide.debugRide(player, key)
	if key == false or key == nil then
		SwordRide.stop(player, "player")
	else
		start(player, key)
	end
end

return SwordRide
