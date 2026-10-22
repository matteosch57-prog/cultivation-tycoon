-- Sect workers: outer disciples hired at a building (Config.WORKERS, hire pads in Main). Each one
-- is a real R15 avatar in plain classic clothes (no layered robes: cheap on phones), standing at a
-- spot of its building with a tool in the right hand. The rig is anchored with its joints
-- disabled (Rig.luau); the client plays the job loop by solving the joints by hand
-- (WorkerJobs.client.luau), so nothing is uploaded and nothing replicates while they work.
-- Mock and look pick: docs/art/mocks/workers.html (owner 2026-10-21: hire pads, straw hats).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rig = require(Shared:WaitForChild("Rig"))
local Config = require(Shared:WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local Workers = {}

Workers.TAG = "Worker"

local SKINS = { Color3.fromRGB(238, 204, 176), Color3.fromRGB(214, 170, 132), Color3.fromRGB(245, 215, 190) }
local WOOD = Color3.fromHex("7B5A44")
local IRON = Color3.fromHex("8E979F")
local STEEL = Color3.fromHex("DFE6EC")

-- Roblox's Man and Woman bodies (as the meditating disciples) and catalog items any experience
-- may put on an NPC. Classic shirts and pants are textures: no triangles.
local MAN = { Torso = 86500008, RightArm = 86500036, LeftArm = 86500054, LeftLeg = 86500064, RightLeg = 86500078 }
local WOMAN = { Torso = 86499666, RightArm = 86499698, LeftArm = 86499716, LeftLeg = 86499753, RightLeg = 86499793 }
local BROWN = { shirt = 9313401861, pants = 9313405331 } -- Peasant + / Peasant - (Winterhall)
local GREY = { shirt = 7287984658, pants = 7287986280 } -- Peasant+ / Peasant- (Silver Shades)
local RICE_HAT = 96473342681829 -- Classic Rice Farmer Straw Conical Hat
local PONYTAIL = 101082692371776 -- Xianxia Low Ponytail - Black
local BUNS = 113503254025840 -- Hair buns with Hairpins - Black

-- looks by job; a building's 2nd worker takes the second look when there is one
local LOOKS = {
	farmer = {
		{ body = MAN, head = 11180212350, clothes = BROWN, hat = { RICE_HAT } },
		{ body = WOMAN, head = 10725626210, clothes = BROWN, hat = { RICE_HAT }, hair = { BUNS } },
	},
	miner = {
		{ body = MAN, head = 10725826963, clothes = BROWN, hat = { RICE_HAT } },
		{ body = MAN, head = 11180212350, clothes = GREY, hat = { RICE_HAT } },
	},
	fighter = {
		{ body = MAN, head = 10725826963, clothes = GREY, hair = { PONYTAIL } },
		{ body = WOMAN, head = 10725626210, clothes = GREY, hair = { BUNS } },
	},
	alchemist = {
		{ body = MAN, head = 84767188836438, clothes = BROWN, face = { 123149555491840 } }, -- old man, white beard
		{ body = MAN, head = 11180212350, clothes = GREY },
	},
}

-- Tools, in "tool space": +Y runs along the shaft from the grip. In the hand the shaft points
-- forward (the hand's -Z), so a raised arm lifts it overhead and a lowered one points it down.
local TOOLS = {
	hoe = {
		{ Vector3.new(0.22, 5, 0.22), CFrame.new(0, 1.7, 0), WOOD },
		{ Vector3.new(0.9, 0.15, 1.2), CFrame.new(0, 4.15, 0.45), IRON }, -- blade hangs toward the ground
	},
	pick = {
		{ Vector3.new(0.22, 3, 0.22), CFrame.new(0, 0.8, 0), WOOD },
		{ Vector3.new(0.22, 0.22, 1.7), CFrame.new(0, 2.2, 0), IRON },
	},
	sword = {
		{ Vector3.new(0.18, 0.9, 0.18), CFrame.new(0, -0.1, 0), WOOD },
		{ Vector3.new(0.9, 0.18, 0.25), CFrame.new(0, 0.4, 0), Color3.fromHex("C9A24A") },
		{ Vector3.new(0.12, 3.4, 0.35), CFrame.new(0, 2.2, 0), STEEL },
	},
	fan = {
		{ Vector3.new(0.12, 1, 0.12), CFrame.new(0, 0.2, 0), WOOD },
		{ Vector3.new(1.3, 1.3, 0.08), CFrame.new(0, 1.2, 0), Color3.fromHex("F3E3B5") },
	},
}
local GRIP = CFrame.new(0, -0.3, -0.1) * CFrame.Angles(-math.pi / 2, 0, 0) -- tool space in the hand

-- Each building: its job, its tool, and the spots of workers 1..2 (Config.WORKER_MAX; owner
-- 2026-10-22: two farmers on every farm) in the building's frame (`frame` "axis" = the pad's own
-- frame like the builder, "centre" = turned to face its islet's centre). A spot is
-- { x, z, look-at x, look-at z }.
local FARM = { job = "farmer", tool = "hoe", frame = "axis", spots = { { -5, -7.6, -5, 0 }, { 5, -7.6, 5, 0 } } }
local MINE = { job = "miner", tool = "pick", frame = "axis", spots = { { 3.9, 2.9, 0, 0 }, { -3.9, 2.9, 0, 0 } } }
-- the tea terraces: a picker at each end of the steps (Builders tea faces the islet's centre)
local TEA = { job = "farmer", tool = "hoe", frame = "centre", spots = { { -7.4, 0, 0, 0 }, { 7.4, 0, 0, 0 } } }
Workers.JOBS = {
	garden = FARM,
	garden2 = FARM,
	garden3 = FARM,
	tea1 = TEA,
	tea2 = TEA,
	vein1 = MINE,
	vein2 = MINE,
	vein3 = MINE,
	training = {
		job = "fighter",
		tool = "sword",
		frame = "centre",
		spots = { { -2.6, 2.4, 3, 2.4 }, { 2.6, 2.4, -3, 2.4 } },
	},
	furnace = {
		job = "alchemist",
		tool = "fan",
		frame = "axis",
		spots = { { -4.4, 0.8, 0, 0.8 }, { 4.4, 0.8, 0, 0.8 } },
	},
}

local function describe(look, skin)
	local d = Instance.new("HumanoidDescription")
	for _, k in { "HeadColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor", "TorsoColor" } do
		d[k] = skin
	end
	for k, id in look.body do
		d[k] = id
	end
	d.Head = look.head
	d.Shirt = look.clothes.shirt
	d.Pants = look.clothes.pants
	local list = {}
	for _, kind in { "hair", "hat", "face" } do
		local t = ({ hair = Enum.AccessoryType.Hair, hat = Enum.AccessoryType.Hat, face = Enum.AccessoryType.Face })[kind]
		for _, id in look[kind] or {} do
			table.insert(list, { AssetId = id, AccessoryType = t, IsLayered = false })
		end
	end
	d:SetAccessories(list, true)
	return d
end

-- the tool's parts, each hung on the right hand by its own (disabled) RigidConstraint so the
-- client's joint walk carries it with the hand
local function arm(m, tool)
	local hand = m:FindFirstChild("RightHand")
	if not hand or not TOOLS[tool] then
		return
	end
	local grip = Instance.new("Attachment")
	grip.Name = "WorkerGrip"
	grip.CFrame = GRIP
	grip.Parent = hand
	local holder = Instance.new("Model")
	holder.Name = "Tool"
	for i, spec in TOOLS[tool] do
		local p = Style.P(
			holder,
			spec[1],
			hand.CFrame * GRIP * spec[2],
			spec[3],
			spec[3] == WOOD and Enum.Material.Wood or Enum.Material.Metal
		)
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		local a = Instance.new("Attachment")
		a.CFrame = spec[2]:Inverse()
		a.Parent = p
		local rc = Instance.new("RigidConstraint")
		rc.Name = "Tool" .. i
		rc.Attachment0, rc.Attachment1 = grip, a
		rc.Enabled = false
		rc.Parent = p
	end
	holder.Parent = m
end

-- one standing template per job and look, built once per server and cloned
local templates, pending = {}, {}

local function template(job, li, tool)
	local key = job .. li
	if templates[key] then
		return templates[key]
	end
	if pending[key] then
		table.insert(pending[key], coroutine.running())
		return coroutine.yield()
	end
	pending[key] = {}
	local look = LOOKS[job][li]
	local ok, m = pcall(
		Players.CreateHumanoidModelFromDescription,
		Players,
		describe(look, SKINS[(li - 1) % #SKINS + 1]),
		Enum.HumanoidRigType.R15
	)
	if ok then
		local hum = m:FindFirstChildOfClass("Humanoid")
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.RequiresNeck = false
		hum.BreakJointsOnDeath = false
		m:PivotTo(CFrame.identity)
		Rig.freeze(m)
		arm(m, tool)
		-- feet on the ground (y = 0 of the template)
		local low = math.huge
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Handle" and p.Parent == m then
				low = math.min(low, p.Position.Y - p.Size.Y / 2)
			end
		end
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.CFrame += Vector3.new(0, -low, 0)
			end
		end
		templates[key] = m
	else
		warn("[Workers] avatar build failed", job, li, m)
		m = nil
	end
	local waiting = pending[key]
	pending[key] = nil
	for _, co in waiting do
		task.spawn(co, m)
	end
	return m
end

local function buildingFrame(plotFrame, pad, how)
	if how == "centre" then
		local p = Vector3.new(pad.x, 0, pad.z)
		local i = Config.ISLETS[Config.isletAt(pad.x, pad.z)]
		return plotFrame * CFrame.lookAt(p, Vector3.new(i.x, 0, i.z)) * CFrame.Angles(0, math.pi, 0)
	end
	return plotFrame * CFrame.new(pad.x, 0, pad.z)
end

-- The ground under a spot: the building's floor or the island, found by a ray from just above
-- (5 studs: a ray from higher landed the alchemists on the pavilion roof).
local function ground(pos, include)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	local hit = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), params)
	return hit and hit.Position.Y or pos.Y
end

-- Worker `n` (1..3) of building `pad` on the peak at `plotFrame`. Returns the model at once; the
-- avatar arrives once its catalog assets load, unless the model was destroyed meanwhile.
-- `include` = what the feet may stand on (the built folder and the terrain).
function Workers.build(parent, plotFrame, pad, n, include)
	local spec = Workers.JOBS[pad.id]
	local spot = spec and spec.spots[n]
	if not spot then
		return nil
	end
	local bf = buildingFrame(plotFrame, pad, spec.frame)
	local pos = bf * Vector3.new(spot[1], 0, spot[2])
	local target = bf * Vector3.new(spot[3], 0, spot[4])
	local m = Instance.new("Model")
	m.Name = "Worker_" .. pad.id .. n
	m:SetAttribute("Job", spec.job)
	m:SetAttribute("Slot", n)
	m.Parent = parent
	task.spawn(function()
		local looks = LOOKS[spec.job]
		local t = template(spec.job, (n - 1) % #looks + 1, spec.tool)
		if not t or not m.Parent then
			return
		end
		local y = ground(pos, include)
		local at = CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(target.X, y, target.Z))
		local avatar = t:Clone()
		avatar.Name = "Avatar"
		avatar:PivotTo(at * avatar:GetPivot())
		avatar.Parent = m
		CollectionService:AddTag(m, Workers.TAG)
	end)
	return m
end

return Workers
