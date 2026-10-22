-- Incense Blessing (owner pick A 2026-10-22; research 2026-10-22_neighbour_visits, mock
-- docs/art/mocks/neighbour_visits.html): every peak has an incense shrine beside its entrance.
-- A visitor holds the shrine's prompt for BLESS_HOLD s: a stick lights, BOTH get BLESS_SECONDS of
-- their own income (offline rate: no tide, pill or friends), the owner gets a toast. Once per
-- visitor and sect a UTC day, at most BLESS_GIVE_MAX given and BLESS_GET_MAX received a day, never
-- on your own shrine. The owner's share needs a giver whose account and play time are real
-- (BLESS_MIN_ACCOUNT_DAYS, BLESS_MIN_PLAY): an alt feeds nobody. Today's sticks stay lit and a
-- plaque counts every blessing the sect ever had (`blessTotal`, a monotonic record).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Bless = {}
local api -- { sessions, rate, publish, notify, telemetry, style, palette }

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

local function trigger(plot, player)
	local api_ = api
	local owner = plot.owner
	local s = api_.sessions[player]
	local os_ = owner and api_.sessions[owner]
	if not s or not os_ or owner == player or s.blessBusy then
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
		local real = player.AccountAge >= Config.BLESS_MIN_ACCOUNT_DAYS and (s.data.playSec or 0) >= Config.BLESS_MIN_PLAY
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

-- the shrine: a stone plinth, a bronze burner with BLESS_GET_MAX sticks, a plaque with the count.
-- Called once per plot (it outlives owners; Bless.refresh repaints it).
function Bless.build(plot)
	local P, PAL = api.style.P, api.palette
	local m = Instance.new("Model")
	m.Name = "Shrine"
	local at = Config.BLESS_SHRINE_AT
	local cf = plot.frame * CFrame.new(at.X, 0, at.Z) -- its +X faces the avenue (the shrine stands left of it)
	P(m, Vector3.new(4.2, 0.8, 4.2), cf * CFrame.new(0, 0.4, 0), PAL.stone)
	P(m, Vector3.new(3.4, 0.6, 3.4), cf * CFrame.new(0, 1.1, 0), PAL.stoneLight)
	local burner = P(m, Vector3.new(1.6, 2.6, 2.6), cf * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.pi / 2), BRONZE, Enum.Material.Metal, Enum.PartType.Cylinder)
	burner.Name = "Burner"
	P(m, Vector3.new(2.9, 0.25, 2.9), cf * CFrame.new(0, 3.05, 0), PAL.gold, Enum.Material.Metal)
	for k = 1, Config.BLESS_GET_MAX do
		local a = (k - 1) / Config.BLESS_GET_MAX * math.pi * 2
		local base = cf * CFrame.new(math.cos(a) * 0.7, 3.1, math.sin(a) * 0.7)
		local stick = P(m, Vector3.new(0.12, 2.2, 0.12), base * CFrame.new(0, 1.1, 0) * CFrame.Angles(math.cos(a) * 0.08, 0, math.sin(a) * 0.08), Color3.fromHex("7B3B2A"))
		stick.CanCollide = false
		local tip = P(m, Vector3.new(0.2, 0.25, 0.2), base * CFrame.new(0, 2.25, 0), Color3.fromHex("3A2A22"))
		tip.Name = "Tip" .. k
		tip.CanCollide = false
		local light = Instance.new("PointLight") -- the ember itself lights the burner (a real lit object)
		light.Color = EMBER
		light.Range = 5
		light.Brightness = 0.8
		light.Enabled = false
		light.Parent = tip
		local smoke = Instance.new("ParticleEmitter")
		smoke.Color = ColorSequence.new(Color3.fromHex("F2EEE6"))
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.7) })
		smoke.Lifetime = NumberRange.new(2.5, 3.5)
		smoke.Rate = 2
		smoke.Speed = NumberRange.new(0.8, 1.2)
		smoke.Acceleration = Vector3.new(0.2, 0.3, 0)
		smoke.LightEmission = 0
		smoke.Enabled = false
		smoke.Parent = tip
	end
	-- plaque on a low post in front, facing the avenue
	local post = P(m, Vector3.new(0.4, 2.4, 0.4), cf * CFrame.new(2.9, 1.2, 0), PAL.timberDark or Color3.fromHex("4A3330"))
	post.CanCollide = false
	local board = P(m, Vector3.new(0.2, 1.1, 3.2), cf * CFrame.new(3.05, 2.2, 0), Color3.fromHex("3A2410"))
	board.Name = "Plaque"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right -- +X of the shrine frame: toward the avenue
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Count"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.Fantasy
	label.TextColor3 = Color3.fromRGB(255, 225, 150)
	label.Text = "Incense Shrine"
	label.Parent = gui
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Bless"
	prompt.ObjectText = "Incense Shrine"
	prompt.HoldDuration = Config.BLESS_HOLD
	prompt.MaxActivationDistance = 9
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
