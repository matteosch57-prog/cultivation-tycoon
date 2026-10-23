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
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Guard = require(script.Parent:WaitForChild("Guard"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local SwordLook = require(script.Parent:WaitForChild("SwordLook"))
local Rig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rig"))

local SwordRide = {}

local RIDE = Config.SWORD_RIDE
local api -- { sessions, notify, remotes }
local VOID_REACH = 200 -- studs of ray under a rider who asks to step off
local rides = {} -- [player] = { key, tier, sword, hum, hip, walk, joint, c0, strikes, conns }

local function tierOf(key)
	for i, t in RIDE.tiers do
		if t.key == key then
			return i, t
		end
	end
	return nil, nil
end

-- The rider's pose: HipHeight is NOT touched (Studio 2026-10-23: +1.2 HipHeight let a rider climb
-- 3.5-stud ledges), so the step height stays the walker's. The hover is drawn on every client by
-- SwordPose.client (the root joint lifts the body `lift` studs and leans it, the waist leans more,
-- through each joint's Transform: Motor6D and AnimationConstraint rigs alike). The sword is welded
-- under the lifted feet, or at the real feet when the rig has no root joint to lift.
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
		-- back to the walker's speed: Movement.client sets MOVE.walk on the client, so the server's own
		-- copy of WalkSpeed (16) is not the one to restore (Studio 2026-10-23)
		r.hum.WalkSpeed = Config.MOVE.walk
	end
	player:SetAttribute("Riding", nil)
	if reason and reason ~= "player" and reason ~= "gone" and reason ~= "switch" then -- a tier switch from the picker is no "Off the sword"
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
		-- the platform and the plaza ring under it (the Spirit Springs stand 13 studs out)
		if Vector2.new(d.X, d.Z).Magnitude < Config.ALTAR_RADIUS + 9 and d.Y > -(Config.ALTAR_HEIGHT + 4) and d.Y < 20 then
			return "altar"
		end
	end
	return nil
end

-- the islets of the rider's own peak whose bridge is not built yet: a flyer stays out of them (they
-- open by their bridge pad, D42), in world studs
local function closedIslets(s)
	local out = {}
	local plot, owned = s.plot, s.data.owned or {}
	if not (plot and plot.frame) then
		return out
	end
	for name, i in Config.ISLETS do
		if i.bridge and not Config.isletOpen(owned, name) then
			local c = plot.frame * Vector3.new(i.x, 0, i.z)
			table.insert(out, { x = math.floor(c.X), z = math.floor(c.Z), r = math.floor(i.r * 1.05 + 4) })
		end
	end
	return out
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
	local lift = RIDE.lift
	-- the feet are drawn `lift` over where they walk (hrp - half its height - HipHeight): the blade
	-- top goes there, so the rider stands on the sword and its underside floats `lift - 2*top` up
	if not Rig.rideJoints(char) then
		lift = 0 -- nothing lifts the body: the blade goes at the real feet, never through the legs
	end
	local feet = -(hrp.Size.Y / 2 + hum.HipHeight) + lift
	-- the whole model moves before it is parented: its WeldConstraints lock each part where it is
	-- when it enters the workspace (moving only the core would leave the blade at the template's spot)
	sword:PivotTo(hrp.CFrame * CFrame.new(0, feet - top, 0))
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1 = hrp, core
	weld.C0 = CFrame.new(0, feet - top, 0)
	weld.Parent = core
	sword.Parent = char
	local r = { key = key, tier = tier, sword = sword, hum = hum, strikes = 0, conns = {}, blocks = closedIslets(s) }
	player:SetAttribute("FlyBlocks", HttpService:JSONEncode(r.blocks))
	hum.WalkSpeed = Config.MOVE.walk * def.speed
	-- a server move (the Base / Ranks chips, portals, the altar) restarts the speed check: on the
	-- server CFrame changes only when a script writes it, never from the client's physics
	table.insert(r.conns, hrp:GetPropertyChangedSignal("CFrame"):Connect(function()
		r.last = nil
		r.strikes = 0
	end))
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
			-- no stepping off over the void: there must be ground within VOID_REACH under you
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if rides[player] and hrp then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { char }
				if not workspace:Raycast(hrp.Position, Vector3.new(0, -VOID_REACH, 0), params) then
					api.notify:FireClient(player, "swordNo", "void")
					return
				end
			end
			SwordRide.stop(player, "player")
		elseif type(key) == "string" and #key <= 24 then
			start(player, key)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		SwordRide.stop(player, "gone")
	end)
	-- where a flyer may go (SwordFly.client keeps inside these; the loop below puts anyone back who
	-- did not): under the ceiling, inside the map
	workspace:SetAttribute("FlyCeiling", RIDE.ceiling)
	workspace:SetAttribute("FlyBound", RIDE.bound)
	-- the checks: every 0.2 s for each rider (pads and the altar switch it off; the speed cap, the
	-- ceiling, the map edge and the rider's own closed islets put them back)
	local CHECK = 0.2
	task.spawn(function()
		while true do
			task.wait(CHECK)
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
				local pos = hrp.Position
				-- the speed cap: farther than the tier allows since the last good spot, a few checks
				-- running, goes back there
				local cap = Config.MOVE.walk * RIDE.tiers[r.tier].speed * RIDE.speedSlack
				r.last = r.last or pos
				if (pos - r.last).Magnitude > cap * CHECK + 4 then
					r.strikes += 1
					if r.strikes >= RIDE.speedStrikes then
						r.strikes = 0
						hrp.CFrame = CFrame.new(r.last) * hrp.CFrame.Rotation
						hrp.AssemblyLinearVelocity = Vector3.zero
						api.notify:FireClient(player, "swordNo", "speed")
					end
					continue
				end
				r.strikes = 0
				local back = nil
				if pos.Y > RIDE.ceiling + 8 then
					back = Vector3.new(pos.X, RIDE.ceiling, pos.Z)
				end
				local flat = Vector3.new(pos.X, 0, pos.Z)
				if flat.Magnitude > RIDE.bound + 10 then
					local edge = flat.Unit * RIDE.bound
					back = Vector3.new(edge.X, (back or pos).Y, edge.Z)
				end
				for _, z in r.blocks do
					local d = Vector3.new(pos.X - z.x, 0, pos.Z - z.z)
					if d.Magnitude < z.r and d.Magnitude > 0 then
						local edge = Vector3.new(z.x, 0, z.z) + d.Unit * (z.r + 3)
						back = Vector3.new(edge.X, pos.Y, edge.Z)
						if os.clock() - (r.blockToast or 0) > 3 then
							r.blockToast = os.clock()
							api.notify:FireClient(player, "swordNo", "bridge")
						end
					end
				end
				if back then
					hrp.CFrame = CFrame.new(back) * hrp.CFrame.Rotation
					hrp.AssemblyLinearVelocity = Vector3.zero
					pos = back
				end
				r.last = pos
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
