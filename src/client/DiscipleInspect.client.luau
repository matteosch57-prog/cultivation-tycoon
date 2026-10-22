-- Look at a seated disciple and see its stars (owner 2026-10-22: "stars should count on their
-- performance too. And they could show when you look at them"). Its card floats over its head: the
-- rarity and look in the rarity's colour, its five index stars (gold / dim), and the qi it adds now,
-- its rarity's bonus raised by those stars (Config.discipleStarMult, the server's discipleMult).
-- Three ways to show it, mocked for the owner's pick (workspace attribute InspectMock):
--   "tap"  Bee Swarm Simulator: tap or click a bee in the hive and its card opens; tap again or away
--          to close (it also closes after CARD_S seconds)
--   "tag"  "tap", plus a small star row always over every seated disciple's head (tower defense
--          units' star badges, Anime Defenders)
--   "near" Grow a Garden: hover a plant (mouse) or stand next to one (touch) and its card shows
-- Works on every peak: the owner's Index attribute replicates, so a visitor sees a friend's stars too.
-- Each BillboardGui sits in PlayerGui with ResetOnSpawn = false (the first spawn empties PlayerGui
-- after client scripts ran), adorned to the disciple's cushion (the avatar loads later).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromHex("FFD34D")
local STAR_OFF = Color3.fromHex("4A3F55")
local PANEL = Color3.fromHex("1E1726")
local CARD_S = 5 -- seconds a tapped card stays
local NEAR = 9 -- studs: "near" on touch shows the closest disciple this close
local TAG_FAR = 60 -- studs: the star tags hide beyond this

local function mode()
	return workspace:GetAttribute("InspectMock") or "tap"
end

-- the Index attribute of a player: "Elder|lotus=3;..." -> { [key] = pulls }
local function readIndex(p)
	local out = {}
	for _, pair in string.split(p:GetAttribute("Index") or "", ";") do
		local key, n = string.match(pair, "^(.-)=(%d+)$")
		if key then
			out[key] = tonumber(n)
		end
	end
	return out
end

-- the player whose peak holds `model` (workspace.Sect.Peak<i>.Built.Disciples.Disciple<n>)
local function ownerOf(model)
	local peak = model:FindFirstAncestorWhichIsA("Folder")
	while peak and not peak.Name:match("^Peak%d+$") do
		peak = peak.Parent and peak.Parent:IsA("Folder") and peak.Parent or nil
	end
	local i = peak and tonumber(peak.Name:match("%d+"))
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("PlotIndex") == i then
			return p
		end
	end
	return nil
end

-- a seated disciple model from any part of it
local function discipleOf(inst)
	while inst and inst ~= workspace do
		if inst:IsA("Model") and inst:GetAttribute("Disciple") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

-- the stars and qi of one seated disciple model
local function infoOf(m)
	local key = m:GetAttribute("Disciple")
	local name, look = string.match(key or "", "^(.-)|(.+)$")
	local owner = ownerOf(m)
	local pulls = owner and readIndex(owner)[key] or 0
	local stars = Config.indexStars(pulls)
	local r = Config.rarity(name)
	return {
		rarity = r,
		look = Config.LOOK_NAMES[look] or look,
		stars = stars,
		bonus = r.bonus * Config.discipleStarMult(pulls),
		nextAt = Config.INDEX_STARS[stars + 1],
		pulls = pulls,
	}
end

-- every seated disciple (the server's Cultivator tag; a seated one carries its index key)
local function disciples()
	local list = {}
	for _, m in CollectionService:GetTagged("Cultivator") do
		if m:GetAttribute("Disciple") and m:FindFirstChild("Cushion") and m:IsDescendantOf(workspace) then
			table.insert(list, m)
		end
	end
	return list
end

local function billboard(m, size, offset)
	local b = Instance.new("BillboardGui")
	b.Name = "DiscipleInspect"
	b.ResetOnSpawn = false
	b.Adornee = m:FindFirstChild("Cushion")
	b.Size = size
	b.StudsOffsetWorldSpace = offset
	b.AlwaysOnTop = true
	b.LightInfluence = 0
	b.Parent = playerGui
	return b
end

local function starRow(parent, stars, size, order)
	local row = Toy.frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order })
	Toy.list(row, true, 0)
	if stars > 0 then
		Toy.text(row, string.rep("★", stars), size, GOLD, { LayoutOrder = 1 })
	end
	if stars < #Config.INDEX_STARS then
		Toy.text(row, string.rep("★", #Config.INDEX_STARS - stars), size, STAR_OFF, { LayoutOrder = 2 })
	end
	return row
end

-- the card: rarity + look, stars, the qi it adds (with the qi icon), and the next star
local function card(m)
	local info = infoOf(m)
	local b = billboard(m, UDim2.fromOffset(220, 120), Vector3.new(0, 7.5, 0))
	local box = Toy.frame(b, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 0.1, BackgroundColor3 = PANEL })
	Toy.corner(box, UDim.new(0, 12))
	local st = Instance.new("UIStroke")
	st.Color = info.stars >= #Config.INDEX_STARS and GOLD or info.rarity.color
	st.Thickness = 3
	st.Parent = box
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 8)
	pad.Parent = box
	Toy.list(box, false, 2)
	Toy.text(box, info.rarity.name .. " · " .. info.look, 17, info.rarity.color, { LayoutOrder = 1 })
	starRow(box, info.stars, 22, 2)
	local row, label = Toy.amount(box, "qi", 18, Color3.new(1, 1, 1), { LayoutOrder = 3 })
	label.Text = string.format("+%d%% qi", math.floor(info.bonus * 100 + 0.5))
	if info.nextAt then
		Toy.text(box, string.format("Next ★ at %d pulls (%d/%d)", info.nextAt, info.pulls, info.nextAt), 12, Color3.fromHex("C8C0D0"), { LayoutOrder = 4 })
	end
	-- pop in (D61 feel: a quick overshoot)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = box
	game:GetService("TweenService"):Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	return b, row
end

local shown, shownModel, shownAt = nil, nil, 0
local function hide()
	if shown then
		shown:Destroy()
	end
	shown, shownModel = nil, nil
end
local function show(m)
	if shownModel == m then
		return
	end
	hide()
	shown = card(m)
	shownModel, shownAt = m, os.clock()
end

-- "tag": a star row over every seated disciple, kept in step with the disciples and the stars
local tags = {}
local function refreshTags()
	local want = mode() == "tag"
	local seen = {}
	if want then
		for _, m in disciples() do
			seen[m] = true
			local stars = infoOf(m).stars
			local t = tags[m]
			if t and t:GetAttribute("Stars") ~= stars then
				t:Destroy()
				t = nil
			end
			if not t then
				t = billboard(m, UDim2.fromOffset(110, 30), Vector3.new(0, 6.2, 0))
				t.MaxDistance = TAG_FAR
				t:SetAttribute("Stars", stars)
				local pill = Toy.frame(t, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 0.25, BackgroundColor3 = PANEL })
				Toy.corner(pill, UDim.new(1, 0))
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
				pad.Parent = pill
				Toy.list(pill, true, 0)
				starRow(pill, stars, 16, 1)
				tags[m] = t
			end
		end
	end
	for m, t in tags do
		if not seen[m] or not m.Parent then
			t:Destroy()
			tags[m] = nil
		end
	end
end

local function pick(pos)
	local ray = workspace.CurrentCamera:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	return hit and discipleOf(hit.Instance)
end

-- "tap" / "tag": a tap or click on a disciple opens its card, again (or elsewhere) closes it
UserInputService.InputEnded:Connect(function(input, processed)
	if processed or mode() == "near" then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local m = pick(input.Position)
	if m and m ~= shownModel then
		show(m)
	elseif shown then
		hide()
	end
end)

local tick = 0
RunService.Heartbeat:Connect(function(dt)
	tick += dt
	if tick > 0.5 then
		tick = 0
		refreshTags()
	end
	if shownModel and not shownModel.Parent then
		hide()
	end
	if mode() == "near" then
		-- "near": the hovered disciple (mouse), else the closest within NEAR studs
		local m
		if UserInputService.MouseEnabled then
			m = pick(UserInputService:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset())
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not m and root then
			local best = NEAR
			for _, d in disciples() do
				local dist = (d.Cushion.Position - root.Position).Magnitude
				if dist < best then
					best, m = dist, d
				end
			end
		end
		if m then
			show(m)
		elseif shown then
			hide()
		end
	elseif shown and os.clock() - shownAt > CARD_S then
		hide()
	end
end)
