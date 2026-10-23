-- In-world text fades with distance (owner 2026-10-23: "Texts everywhere can be too much on screen,
-- maybe add opacity with distance? so it comes to full when closer"). One place for every label that
-- floats in the world: the pad price cards, the shop cards, the disciples' star crowns, the players'
-- titles, the idle chest's label and the name boards. Each is full strength near the avatar and
-- fades out farther away (the DevForum "Billboards getting dimmer" pattern: transparency from the
-- distance, clamped between a near and a far radius). Pad cards follow Pet Simulator 99's eggs: only
-- the nearest pad shows its card, the rest hide (owner pick B, 2026-10-23).
-- The owning scripts stay as they are: this only scales the transparencies they set, and leaves
-- alone any property another script animates (the crown twinkle).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PerfMark = require(Shared:WaitForChild("PerfMark"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- studs from the avatar: full strength inside `near`, gone at `far`
local RANGE = {
	pad = { 24, 60 },
	crown = { 16, 40 },
	title = { 26, 70 },
	chest = { 18, 45 },
	sign = { 40, 100 },
}
local NEAREST_R = 26 -- studs: the one pad card that shows
local STEP = 0.1 -- strengths snap to tenths, so a drifting avatar does not redraw every label

local PROPS = {
	TextLabel = { "TextTransparency", "TextStrokeTransparency", "BackgroundTransparency" },
	TextButton = { "TextTransparency", "TextStrokeTransparency", "BackgroundTransparency" },
	ImageLabel = { "ImageTransparency", "BackgroundTransparency" },
	ImageButton = { "ImageTransparency", "BackgroundTransparency" },
	Frame = { "BackgroundTransparency" },
	UIStroke = { "Transparency" },
}

local tracked = {} -- [gui] = { kind, at = BasePart, vis, parts = { [obj] = { [prop] = { base, wrote } } } }

local function kindOf(g)
	if g:IsA("BillboardGui") then
		if g.Name == "ShopCard" or g.Name == "PadCard" then
			return "pad"
		elseif g.Name == "DiscipleInspect" and g:GetAttribute("Stars") ~= nil then
			return "crown" -- (the tapped card has no Stars: it stays full)
		elseif g.Name == "StatusTitle" then
			return "title"
		elseif g.Parent and g.Parent.Name == "IdleChest" then
			return "chest"
		end
	elseif g:IsA("SurfaceGui") then
		if g:FindFirstChild("Name") or g:FindFirstChild("Owner") then
			return "sign" -- Kit.plaque and the entrance name board
		end
	end
	return nil
end

local function anchorOf(g)
	local a = g.Adornee or g.Parent
	if a and a:IsA("Model") then
		a = a.PrimaryPart or a:FindFirstChildWhichIsA("BasePart", true)
	end
	return a and a:IsA("BasePart") and a or nil
end

local function remember(rec, obj)
	local props = PROPS[obj.ClassName]
	if props and not rec.parts[obj] then
		local p = {}
		for _, prop in props do
			p[prop] = { base = obj[prop], wrote = obj[prop] }
		end
		rec.parts[obj] = p
	end
end

local function apply(rec, vis)
	for obj, p in rec.parts do
		if not obj.Parent then
			rec.parts[obj] = nil
			continue
		end
		for prop, s in p do
			local now = obj[prop]
			if now ~= s.wrote then
				s.base = now -- its own script changed it (a colour state, a twinkle): that is the new base
			end
			local v = 1 - (1 - s.base) * vis
			if math.abs(v - now) > 1e-3 then
				obj[prop] = v
			end
			s.wrote = obj[prop]
		end
	end
end

local function track(g)
	if tracked[g] then
		return
	end
	local kind = kindOf(g)
	if not kind then
		return
	end
	local rec = { kind = kind, vis = 1, parts = {} }
	for _, d in g:GetDescendants() do
		remember(rec, d)
	end
	rec.conn = g.DescendantAdded:Connect(function(d)
		remember(rec, d)
		rec.vis = -1 -- redo this label on the next pass
	end)
	tracked[g] = rec
end

local function watch(root)
	for _, d in root:GetDescendants() do
		if d:IsA("LayerCollector") then
			task.defer(track, d) -- after its script filled it in
		end
	end
	root.DescendantAdded:Connect(function(d)
		if d:IsA("LayerCollector") then
			task.defer(track, d)
		end
	end)
end
watch(playerGui)
watch(workspace)

local function fade(kind, d)
	local r = RANGE[kind]
	return 1 - math.clamp((d - r[1]) / (r[2] - r[1]), 0, 1)
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0
	local t0 = PerfMark.begin()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local from = hrp and hrp.Position or workspace.CurrentCamera.CFrame.Position
	-- the nearest pad card
	local best, bestD = nil, NEAREST_R
	local dist = {}
	for g, rec in tracked do
		if not g.Parent then
			rec.conn:Disconnect()
			tracked[g] = nil
			continue
		end
		local at = anchorOf(g)
		local d = at and (at.Position - from).Magnitude or math.huge
		dist[g] = d
		if rec.kind == "pad" and d < bestD then
			best, bestD = g, d
		end
	end
	for g, rec in tracked do
		local d = dist[g]
		local vis = fade(rec.kind, d)
		if rec.kind == "pad" then
			vis = g == best and 1 or 0
		end
		vis = math.floor(vis / STEP + 0.5) * STEP
		if vis ~= rec.vis then
			rec.vis = vis
			apply(rec, vis)
		end
	end
	PerfMark.finish("worldText", t0)
end)
