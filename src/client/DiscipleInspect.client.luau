-- Look at a seated disciple and see its stars (owner 2026-10-22: "stars should count on their
-- performance too. And they could show when you look at them"; pick B 2026-10-23: "Ok for B but let's
-- use something better like the beads on the other thread but as stars"). Every seated disciple wears
-- a small crown of five star gems over its head, styled like the player's life beads (PlayerAura):
-- glowing gems for its index stars, dark glass for the rest. Like the beads its stars go on past five
-- (owner 2026-10-23): red gems fill in over the gold for stars 6-10, then blue for 11-15
-- (Config.starRow); a twinkle on each full row. Tap or click
-- one and its card takes the crown's place (Bee Swarm Simulator's bee card): the rarity and look in
-- the rarity's colour, the stars, the qi it adds now (its rarity's bonus raised by its stars,
-- Config.discipleStarMult, the server's discipleMult) and the next star. Tap again, elsewhere, or
-- wait CARD_S seconds to close it. Works on every peak: the owner's Index attribute replicates, so a
-- visitor sees a friend's stars too.
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

local PANEL = Color3.fromHex("1E1726")
local CARD_S = 5 -- seconds a tapped card stays
local CROWN_FAR = 60 -- studs: the crowns hide beyond this
local ARC = { -68, -34, 0, 34, 68 } -- degrees: the five stars on an arc over the head

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

-- the card: rarity + look, stars, the qi it adds (with the qi icon), and the next star
local function card(m)
	local info = infoOf(m)
	local b = billboard(m, UDim2.fromOffset(220, 120), Vector3.new(0, 7.5, 0))
	local box = Toy.frame(b, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 0.1, BackgroundColor3 = PANEL })
	Toy.corner(box, UDim.new(0, 12))
	local st = Instance.new("UIStroke")
	st.Color = Config.STAR_COLORS[math.min(info.stars // Config.STAR_ROW, #Config.STAR_COLORS)] or info.rarity.color
	st.Thickness = 3
	st.Parent = box
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 8)
	pad.Parent = box
	Toy.list(box, false, 2)
	Toy.text(box, info.rarity.name .. " · " .. info.look, 17, info.rarity.color, { LayoutOrder = 1 })
	Toy.stars(box, info.stars, 22, { LayoutOrder = 2 })
	local _, label = Toy.amount(box, "qi", 18, Color3.new(1, 1, 1), { LayoutOrder = 3 })
	label.Text = string.format("+%d%% qi", math.floor(info.bonus * 100 + 0.5))
	if info.nextAt then
		Toy.text(box, string.format("Next ★ at %d pulls (%d/%d)", info.nextAt, info.pulls, info.nextAt), 12, Color3.fromHex("C8C0D0"), { LayoutOrder = 4 })
	end
	-- pop in (D61 feel: a quick overshoot)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = box
	game:GetService("TweenService"):Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	return b
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

-- one star gem of a crown (Toy.starGem) at `x`, `y` (scale of the crown), `size` (scale of its
-- height), lit in `color` (nil = dark glass); a lit one glows like the beads' neon
local function gem(parent, x, y, size, color)
	if color then
		local glow = Instance.new("TextLabel")
		glow.BackgroundTransparency = 1
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(x, y)
		glow.Size = UDim2.fromScale(size * 0.9, size * 1.6)
		glow.FontFace = Toy.FONT
		glow.Text = "★"
		glow.TextScaled = true
		glow.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.25)
		glow.TextTransparency = 0.6
		glow.Parent = parent
	end
	return Toy.starGem(parent, color, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(size * 0.6, size), TextScaled = true, ZIndex = 2 })
end

-- the crown over every seated disciple, kept in step with the disciples and the stars
local crowns = {}
local function refreshCrowns()
	local seen = {}
	for _, m in disciples() do
		seen[m] = true
		local stars = infoOf(m).stars
		local t = crowns[m]
		if t and t:GetAttribute("Stars") ~= stars then
			t:Destroy()
			t = nil
		end
		if not t then
			-- sized in studs (scale), so it reads like a halo in the world, not a screen label
			t = billboard(m, UDim2.fromScale(2.8, 1.5), Vector3.new(0, 5.9, 0))
			t.MaxDistance = CROWN_FAR
			t:SetAttribute("Stars", stars)
			local row = Config.starRow(stars)
			for i, deg in ARC do
				local a = math.rad(deg)
				gem(t, 0.5 + math.sin(a) * 0.36, 0.86 - math.cos(a) * 0.58, i == 3 and 0.42 or 0.36, row[i])
			end
			if stars >= Config.STAR_ROW then
				-- a full row: a twinkle over the crown
				local tw = Instance.new("TextLabel")
				tw.BackgroundTransparency = 1
				tw.AnchorPoint = Vector2.new(0.5, 0.5)
				tw.Position = UDim2.fromScale(0.62, 0.12)
				tw.Size = UDim2.fromScale(0.16, 0.26)
				tw.FontFace = Toy.FONT
				tw.Text = "✦"
				tw.TextScaled = true
				tw.TextColor3 = Color3.new(1, 1, 1)
				tw.ZIndex = 3
				tw.Parent = t
				game:GetService("TweenService"):Create(tw, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { TextTransparency = 1 }):Play()
			end
			crowns[m] = t
		end
		t.Enabled = m ~= shownModel -- the open card takes the crown's place
	end
	for m, t in crowns do
		if not seen[m] or not m.Parent then
			t:Destroy()
			crowns[m] = nil
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

-- a tap or click on a disciple opens its card, again (or elsewhere) closes it
UserInputService.InputEnded:Connect(function(input, processed)
	if processed then
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
	refreshCrowns()
end)

local tick = 0
RunService.Heartbeat:Connect(function(dt)
	tick += dt
	if (shownModel and not shownModel.Parent) or (shown and os.clock() - shownAt > CARD_S) then
		hide()
		refreshCrowns()
	end
	if tick > 0.5 then
		tick = 0
		refreshCrowns()
	end
end)
