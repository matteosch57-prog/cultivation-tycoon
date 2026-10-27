-- Rainbow relics on the Relic Terrace (RelicHall tierLook, copies Pet Simulator 99's Rainbow pets): every
-- part tagged "RelicRainbow" (or inside a tagged model) runs through the rainbow. `RainbowSpread` on the
-- tag = hue per stud of height (0: the whole relic is one colour). Ten relics at most per peak, 10 Hz.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local tagged = {} -- inst -> { parts, base Y, spread }

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
	tagged[inst] = { parts = parts, low = low, spread = inst:GetAttribute("RainbowSpread") or 0 }
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
	for inst, e in tagged do
		if not inst.Parent then
			tagged[inst] = nil
		else
			for _, p in e.parts do
				p.Color = Color3.fromHSV((t + (p.Position.Y - e.low) * e.spread) % 1, 0.65, 1)
			end
		end
	end
end)
