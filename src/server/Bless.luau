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
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Bless = {}
local api -- { sessions, rate, publish, notify, telemetry, style, palette, kit }

local EMBER = Color3.fromHex("FF8A3C")
local BRONZE = Color3.fromHex("8C6A3A")

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
		label.Text = total and total > 0 and string.format("Blessed %d time%s", total, total == 1 and "" or "s") or "Incense Shrine"
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
	local key = tostring(owner.UserId)
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

-- the shrine (owner 2026-10-22: the first plinth-and-pot was "ugly"; made premium from the kit): an
-- open kit pavilion on a stone deck with its stair to the avenue, a bronze ding censer under it
-- (three legs, loop handles, a gold rim) holding BLESS_GET_MAX sticks, a pair of stone lanterns at
-- the stair, and a gilt plaque on the front beam with the count. Called once per plot (it outlives
-- owners; Bless.refresh repaints it).
local W, COL = 6, 6.2 -- pavilion span and column height (Kit.pavilion)
function Bless.build(plot)
	local P, PAL, Kit = api.style.P, api.palette, api.kit
	local m = Instance.new("Model")
	m.Name = "Shrine"
	local at = Config.BLESS_SHRINE_AT
	-- the stair (+Z of the pavilion) turned to face the avenue (+X of the peak frame)
	local cf = plot.frame * CFrame.new(at.X, 0, at.Z) * CFrame.Angles(0, math.rad(90), 0)
	local _, deckH = Kit.pavilion(m, cf, W, COL)
	local floor = cf * CFrame.new(0, deckH, 0)
	-- the ding: three legs, a round body darkening to the base, a gold lip, two loop handles
	local dark = Color3.fromHex("5E4A2C")
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		P(m, Vector3.new(0.35, 1.1, 0.35), floor * CFrame.new(math.cos(a) * 0.95, 0.55, math.sin(a) * 0.95), dark, Enum.Material.Metal)
	end
	local burner = P(m, Vector3.new(1.4, 2.6, 2.6), floor * CFrame.new(0, 1.75, 0) * CFrame.Angles(0, 0, math.pi / 2), BRONZE, Enum.Material.Metal, Enum.PartType.Cylinder)
	burner.Name = "Burner"
	P(m, Vector3.new(0.5, 2.2, 2.2), floor * CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.pi / 2), dark, Enum.Material.Metal, Enum.PartType.Cylinder)
	P(m, Vector3.new(0.25, 2.9, 2.9), floor * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.pi / 2), PAL.gold, Enum.Material.Metal, Enum.PartType.Cylinder)
	P(m, Vector3.new(0.1, 2.4, 2.4), floor * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromHex("CDBB98"), Enum.Material.Sand, Enum.PartType.Cylinder) -- the ash
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.2, 0.9, 0.2), floor * CFrame.new(sx * 1.05, 3.05, 0), PAL.gold, Enum.Material.Metal)
		P(m, Vector3.new(0.2, 0.2, 0.7), floor * CFrame.new(sx * 1.05, 3.45, 0), PAL.gold, Enum.Material.Metal)
	end
	for k = 1, Config.BLESS_GET_MAX do
		local a = (k - 1) / Config.BLESS_GET_MAX * math.pi * 2
		local base = floor * CFrame.new(math.cos(a) * 0.6, 2.65, math.sin(a) * 0.6)
		local stick = P(m, Vector3.new(0.12, 2.4, 0.12), base * CFrame.new(0, 1.2, 0) * CFrame.Angles(math.cos(a) * 0.08, 0, math.sin(a) * 0.08), Color3.fromHex("7B3B2A"))
		stick.CanCollide = false
		local tip = P(m, Vector3.new(0.2, 0.25, 0.2), base * CFrame.new(0, 2.45, 0), Color3.fromHex("3A2A22"))
		tip.Name = "Tip" .. k
		tip.CanCollide = false
		local light = Instance.new("PointLight") -- the ember itself lights the censer (a real lit object)
		light.Color = EMBER
		light.Range = 6
		light.Brightness = 1
		light.Enabled = false
		light.Parent = tip
		local smoke = Instance.new("ParticleEmitter")
		smoke.Color = ColorSequence.new(Color3.fromHex("F2EEE6"))
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.9) })
		smoke.Lifetime = NumberRange.new(3, 4)
		smoke.Rate = 3
		smoke.Speed = NumberRange.new(0.8, 1.2)
		smoke.Acceleration = Vector3.new(0.15, 0.35, 0)
		smoke.LightEmission = 0
		smoke.Enabled = false
		smoke.Parent = tip
	end
	-- a pair of stone lanterns either side of the stair
	for _, sx in { -1, 1 } do
		api.style.lantern(m, cf * CFrame.new(sx * 3.6, 0, W / 2 + 4.6), 0.7)
	end
	-- the gilt plaque on the front beam, facing the stair: "Blessed N times"
	local board = Kit.plaque(m, floor * CFrame.new(0, COL - 1.1, W / 2 + 0.45), 4.4, 1.1, "Incense Shrine")
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
	prompt.Parent = burner
	prompt.Triggered:Connect(function(player)
		trigger(plot, player)
	end)
	m:SetAttribute("PlotIndex", plot.index)
	m.Parent = plot.folder
	plot.shrine = m
	paint(plot, 0, 0)
end

function Bless.init(deps)
	api = deps
end

return Bless
