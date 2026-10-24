-- Incense Blessing (owner pick A 2026-10-22; research 2026-10-22_neighbour_visits, mock
-- docs/art/mocks/neighbour_visits.html): every peak has an incense shrine beside its entrance.
-- A visitor holds the shrine's prompt for BLESS_HOLD s: a stick lights, BOTH get BLESS_SECONDS of
-- their own income (offline rate: no tide, pill or friends), the owner gets a toast. Once per
-- visitor and sect a UTC day, at most BLESS_GIVE_MAX given and BLESS_GET_MAX received a day, never
-- on your own shrine. The owner's share needs a giver whose account and play time are real
-- (BLESS_MIN_ACCOUNT_DAYS, BLESS_MIN_PLAY): an alt feeds nobody. Today's sticks stay lit and a
-- plaque counts every blessing the sect ever had (`blessTotal`, a monotonic record).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Bless = {}
local api -- { sessions, rate, publish, notify, telemetry, style, palette, kit }

local EMBER = Color3.fromHex("FF8A3C")

local function today()
	return os.time() // 86400
end

-- the day's record on a save, reset when the UTC day changed
local function daily(data, key)
	local r = data[key]
	if type(r) ~= "table" or r.day ~= today() then
		r = { day = today(), n = 0, to = {} }
		data[key] = r
	end
	r.to = r.to or {}
	return r
end

-- light the first `lit` sticks, write the lifetime count on the plaque
local function paint(plot, lit, total)
	local m = plot.shrine
	if not m then
		return
	end
	m:SetAttribute("Lit", lit) -- a full shrine (BLESS_GET_MAX) is no target for the HUD's incense button
	for k = 1, Config.BLESS_GET_MAX do
		local tip = m:FindFirstChild("Tip" .. k)
		if tip then
			local on = k <= lit
			tip.Color = on and EMBER or Color3.fromHex("3A2A22")
			tip.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			local light = tip:FindFirstChildOfClass("PointLight")
			local smoke = tip:FindFirstChildOfClass("ParticleEmitter")
			if light then
				light.Enabled = on
			end
			if smoke then
				smoke.Enabled = on
			end
		end
	end
	local label = m:FindFirstChild("Count", true)
	if label then
		-- the number in round digits and its own colour (owner: the Fantasy "1" read as "I")
		label.RichText = true
		label.Text = total and total > 0
				and string.format('Blessed <font face="FredokaOne" color="#7CF5C8">%d</font> time%s', total, total == 1 and "" or "s")
			or "Incense Shrine"
	end
end

-- the shrine of a plot shows its owner's day and record (nobody: cold and blank)
function Bless.refresh(plot)
	if plot.shrine then -- clients hide the prompt on their own shrine and on an empty peak
		plot.shrine:SetAttribute("OwnerId", plot.owner and plot.owner.UserId or 0)
	end
	local s = plot.owner and api and api.sessions[plot.owner]
	if not s then
		paint(plot, 0, 0)
		return
	end
	local got = daily(s.data, "blessGot")
	paint(plot, got.n, s.data.blessTotal or 0)
end

-- the sects this player already blessed today ("id,id"), so its client hides those prompts
function Bless.mark(player, s)
	local ids = {}
	for id in daily(s.data, "blessGave").to do
		table.insert(ids, id)
	end
	player:SetAttribute("BlessedTo", table.concat(ids, ","))
	-- the HUD's incense button (Incense.client): sticks left today, and the UTC day they count for
	player:SetAttribute("IncenseLeft", math.max(0, Config.BLESS_GIVE_MAX - daily(s.data, "blessGave").n))
	player:SetAttribute("IncenseDay", today())
end

-- Studio test hook (a solo Play cannot bless: your own shrine is hidden). Set the workspace
-- attribute BlessTest = true: every EMPTY peak's shrine then acts as owned by you, so you bless it
-- as a visitor and get both toasts (giver and owner) on your own session. Never on a live server.
local function testOwner(plot, player)
	if RunService:IsStudio() and workspace:GetAttribute("BlessTest") and not plot.owner then
		return player
	end
	return plot.owner
end

-- the shrine this player can bless now that the incense button goes to (Main, Teleport "shrine"):
-- someone else's (or a Studio test peak), not blessed by them today, not full; the nearest one.
-- nil when none is free or no incense is left.
function Bless.target(player, s, from)
	local gave = daily(s.data, "blessGave")
	if gave.n >= Config.BLESS_GIVE_MAX then
		return nil
	end
	local best, bestD
	for _, plot in api.plots do
		local owner = testOwner(plot, player)
		local os_ = owner and api.sessions[owner]
		local test = owner == player and plot.owner == nil
		local key = test and "test" .. plot.index or tostring(owner and owner.UserId)
		if plot.shrineAt and os_ and (owner ~= player or test) and not gave.to[key] and daily(os_.data, "blessGot").n < Config.BLESS_GET_MAX then
			local d = (plot.shrineAt.Position - from).Magnitude
			if not bestD or d < bestD then
				best, bestD = plot, d
			end
		end
	end
	return best
end

-- where a player lands to bless a shrine: on the avenue side, BLESS_STAND studs out (inside the
-- prompt's reach), turned a little past the pot so the camera behind the avatar sees the shrine
-- beside it (facing the pot head-on, the avatar hid it: Studio 2026-10-24)
local BLESS_STAND = 7
function Bless.standAt(plot)
	local at = plot.shrineAt * CFrame.new(-1.5, 4, BLESS_STAND)
	return CFrame.lookAt(at.Position, (plot.shrineAt * CFrame.new(-5, 4, 0)).Position)
end

local function trigger(plot, player)
	local api_ = api
	local owner = testOwner(plot, player)
	local test = owner == player and plot.owner == nil
	local s = api_.sessions[player]
	local os_ = owner and api_.sessions[owner]
	if not s or not os_ or (owner == player and not test) or s.blessBusy then
		return
	end
	s.blessBusy = true
	local gave = daily(s.data, "blessGave")
	local got = daily(os_.data, "blessGot")
	local key = test and "test" .. plot.index or tostring(owner.UserId) -- a test peak counts as its own sect
	if gave.to[key] then
		api_.notify:FireClient(player, "blessNo", "Already blessed today")
	elseif gave.n >= Config.BLESS_GIVE_MAX then
		api_.notify:FireClient(player, "blessNo", "No incense left today")
	elseif got.n >= Config.BLESS_GET_MAX then
		api_.notify:FireClient(player, "blessNo", "Their shrine is full today")
	else
		gave.n += 1
		gave.to[key] = true
		got.n += 1
		os_.data.blessTotal = (os_.data.blessTotal or 0) + 1
		local mine = math.floor(api_.rate(s, true) * Config.BLESS_SECONDS)
		s.data.qi += mine
		api_.telemetry.source(player, s.data, mine, "bless")
		local real = test or player.AccountAge >= Config.BLESS_MIN_ACCOUNT_DAYS and (s.data.playSec or 0) >= Config.BLESS_MIN_PLAY
		local theirs = real and math.floor(api_.rate(os_, true) * Config.BLESS_SECONDS) or 0
		if theirs > 0 then
			os_.data.qi += theirs
			api_.telemetry.source(owner, os_.data, theirs, "blessed")
		end
		api_.telemetry.custom(player, "Social", "bless_given", api_.telemetry.realmBucket(s.data.realm))
		api_.telemetry.custom(owner, "Social", "bless_got", api_.telemetry.realmBucket(os_.data.realm))
		paint(plot, got.n, os_.data.blessTotal)
		api_.notify:FireClient(player, "blessGave", mine, owner.DisplayName)
		api_.notify:FireClient(owner, "blessed", player.DisplayName, theirs)
		Bless.mark(player, s)
		api_.publish(player)
		api_.publish(owner)
	end
	task.delay(1, function()
		s.blessBusy = nil
	end)
end

-- the shrine (owner pick 2026-10-22 of three Creator Store burners, docs/art/mocks/shrine_candidates.jpg;
-- the plinth-and-pot and the kit pavilion were both "ugly"): a celadon incense pot (the free mesh of
-- asset 98661629860539, rebuilt from its id, no inserted scripts) on a carved stone pedestal, full of
-- incense sticks (BLESS_GET_MAX of them light up), two stone lanterns, and a gilt plaque on red posts
-- with the count, facing the avenue. Called once per plot (Bless.refresh repaints it).
local POT_MESH = "rbxassetid://4204056065"
local POT = Vector3.new(0.4047, 0.2083, 0.2924) -- the mesh's own size; scaled by POT_SCALE
local POT_SCALE = 8.5
local CELADON = Color3.fromHex("B9C4B1")
function Bless.build(plot)
	local P, PAL, Kit = api.style.P, api.palette, api.kit
	local m = Instance.new("Model")
	m.Name = "Shrine"
	local at = Config.BLESS_SHRINE_AT
	-- +Z faces the avenue (+X of the peak frame)
	local cf = plot.frame * CFrame.new(at.X, 0, at.Z) * CFrame.Angles(0, math.rad(90), 0)
	-- the pedestal: a stepped stone base, a carved drum, a cap
	P(m, Vector3.new(5.2, 0.5, 5.2), cf * CFrame.new(0, 0.25, 0), PAL.stone)
	P(m, Vector3.new(4.2, 0.5, 4.2), cf * CFrame.new(0, 0.75, 0), PAL.stoneLight)
	P(m, Vector3.new(1.6, 3.2, 3.2), cf * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.pi / 2), PAL.stone, nil, Enum.PartType.Cylinder)
	P(m, Vector3.new(0.3, 3.5, 3.5), cf * CFrame.new(0, 2.15, 0) * CFrame.Angles(0, 0, math.pi / 2), PAL.gold, Enum.Material.Metal, Enum.PartType.Cylinder)
	P(m, Vector3.new(0.4, 3.9, 3.9), cf * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.pi / 2), PAL.stoneLight, nil, Enum.PartType.Cylinder)
	local top = cf * CFrame.new(0, 2.8, 0)
	-- the pot
	local size = POT * POT_SCALE
	local ok, pot = pcall(AssetService.CreateMeshPartAsync, AssetService, POT_MESH, {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Automatic,
	})
	if not ok or not pot then
		warn("[Tycoon][bless] event=pot_mesh_failed")
		pot = P(m, Vector3.new(size.Y, size.X * 0.8, size.X * 0.8), top * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), CELADON, Enum.Material.Marble, Enum.PartType.Cylinder)
	else
		pot.Anchored = true
		pot.Size = size
		pot.CFrame = top * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, math.rad(90), 0) -- handles to the sides
		pot.Color = CELADON
		pot.Material = Enum.Material.Marble
		pot.Parent = m
	end
	pot.Name = "Burner"
	-- the ash bed just under the rim
	local bed = top * CFrame.new(0, size.Y * 0.86, 0)
	P(m, Vector3.new(0.15, size.Z * 0.78, size.Z * 0.78), bed * CFrame.Angles(0, 0, math.pi / 2), Color3.fromHex("C7AC78"), Enum.Material.Sand, Enum.PartType.Cylinder)
	-- twelve sticks fanned a little: red foot, tan body, grey ash at the tip; the first
	-- BLESS_GET_MAX of them carry the ember that lights for a blessing
	local rng = Random.new(31)
	for k = 1, 12 do
		local a = (k - 1) / 12 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = (k % 3 == 0) and 0.15 or rng:NextNumber(0.25, 0.55)
		local tilt = CFrame.Angles(math.sin(a) * 0.12, 0, -math.cos(a) * 0.12)
		local foot = bed * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r) * tilt
		local len = rng:NextNumber(2.6, 3.2)
		local foot1 = P(m, Vector3.new(0.12, 0.5, 0.12), foot * CFrame.new(0, 0.25, 0), Color3.fromHex("AF132D"))
		local body = P(m, Vector3.new(0.09, len, 0.09), foot * CFrame.new(0, 0.5 + len / 2, 0), Color3.fromHex("C7AC78"), Enum.Material.Wood)
		local ash = P(m, Vector3.new(0.11, 0.35, 0.11), foot * CFrame.new(0, 0.5 + len + 0.17, 0), Color3.fromHex("CACBD1"), Enum.Material.Slate)
		for _, q in { foot1, body, ash } do
			q.CanCollide = false
		end
		if k <= Config.BLESS_GET_MAX then
			local tip = P(m, Vector3.new(0.16, 0.16, 0.16), foot * CFrame.new(0, 0.5 + len + 0.38, 0), Color3.fromHex("3A2A22"))
			tip.Name = "Tip" .. k
			tip.CanCollide = false
			local light = Instance.new("PointLight") -- the ember itself lights the pot (a real lit object)
			light.Color = EMBER
			light.Range = 6
			light.Brightness = 1
			light.Enabled = false
			light.Parent = tip
			local smoke = Instance.new("ParticleEmitter")
			smoke.Color = ColorSequence.new(Color3.fromHex("F2EEE6"))
			smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
			smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.9) })
			smoke.Lifetime = NumberRange.new(3, 4.5)
			smoke.Rate = 3
			smoke.Speed = NumberRange.new(0.7, 1.1)
			smoke.Acceleration = Vector3.new(0.15, 0.35, 0)
			smoke.RotSpeed = NumberRange.new(-30, 30)
			smoke.LightEmission = 0
			smoke.Enabled = false
			smoke.Parent = tip
		end
	end
	-- two stone lanterns either side, and the plaque low on red posts in front
	for _, sx in { -1, 1 } do
		api.style.lantern(m, cf * CFrame.new(sx * 4.4, 0, 1.2), 0.75)
	end
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.35, 2.3, 0.35), cf * CFrame.new(sx * 2.5, 1.15, 3.6), Kit.RED)
	end
	local board = Kit.plaque(m, cf * CFrame.new(0, 1.75, 3.6), 4.6, 1.2, "Incense Shrine") -- low: the pot shows above it
	local label = board:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Name = "Count"
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Bless"
	prompt.ObjectText = "Incense Shrine"
	prompt.HoldDuration = Config.BLESS_HOLD
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pot
	prompt.Triggered:Connect(function(player)
		trigger(plot, player)
	end)
	m:SetAttribute("PlotIndex", plot.index)
	m.Parent = plot.folder
	plot.shrine = m
	plot.shrineAt = cf
	paint(plot, 0, 0)
end

function Bless.init(deps)
	api = deps
	-- a new UTC day: every shrine goes cold and every player's incense refills without a rejoin
	task.spawn(function()
		local day = today()
		while true do
			task.wait(20)
			if today() ~= day then
				day = today()
				for _, plot in api.plots do
					Bless.refresh(plot)
				end
				for player, s in api.sessions do
					if player.Parent then
						Bless.mark(player, s)
					end
				end
			end
		end
	end)
end

return Bless
