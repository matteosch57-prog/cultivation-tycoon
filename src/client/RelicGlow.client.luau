-- Rainbow relics on the Relic Terrace (RelicHall tierLook, copies Pet Simulator 99's Rainbow pets): every
-- part tagged "RelicRainbow" (or inside a tagged model) runs through the rainbow. `RainbowSpread` on the
-- tag = hue per stud of height (0: the whole relic is one colour). Ten relics at most per peak, 10 Hz.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local tagged = {} -- inst -> { parts, base Y, spread }
local FAR = 250 -- studs: a relic farther from the camera is not animated

local function add(inst)
	local parts = {}
	if inst:IsA("BasePart") then
		table.insert(parts, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(parts, d)
		end
	end
	local low = math.huge
	for _, p in parts do
		low = math.min(low, p.Position.Y)
	end
	local e = { parts = parts, low = low, spread = inst:GetAttribute("RainbowSpread") or 0 }
	tagged[inst] = e
	-- parts that stream in later (Play check: some of a relic's parts came after the tag and stayed gold)
	inst.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d.Transparency < 1 and tagged[inst] == e then
			table.insert(e.parts, d)
			e.low = math.min(e.low, d.Position.Y) -- (left at huge, a relic whose parts all came late went NaN black)
		end
	end)
end

CollectionService:GetInstanceAddedSignal("RelicRainbow"):Connect(function(inst)
	task.defer(add, inst) -- the relic's parts land with it
end)
CollectionService:GetInstanceRemovedSignal("RelicRainbow"):Connect(function(inst)
	tagged[inst] = nil
end)
for _, inst in CollectionService:GetTagged("RelicRainbow") do
	add(inst)
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 or next(tagged) == nil then
		return
	end
	acc = 0
	local t = os.clock() * 0.12
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position
	for inst, e in tagged do
		if not inst.Parent then
			tagged[inst] = nil
		elseif eye and e.parts[1] and (e.parts[1].Position - eye).Magnitude > FAR then
			continue -- another peak's terrace, out of sight: no colour writes
		else
			for _, p in e.parts do
				local h = e.spread == 0 and 0 or (p.Position.Y - e.low) * e.spread
				p.Color = Color3.fromHSV((t + h) % 1, 0.65, 1)
			end
		end
	end
end)
