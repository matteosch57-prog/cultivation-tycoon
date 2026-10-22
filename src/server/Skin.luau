-- Building skins (Config.SKIN_GRADES / SKIN_GILD / skinFor): recolours a freshly built model so the
-- peak shows its owner's realm and life. A pass after the build instead of a palette threaded
-- through every builder: Kit and Style draw from Style.PAL directly (and lerp from it), so each
-- part is matched to its nearest PAL colour and moved by the same offset, which keeps the shading
-- steps the builders baked in. Neon parts (glows) and colours far from every PAL entry are left
-- alone. Mocked on the real Great Hall: docs/art/mocks/2026-10-22_skins_*.jpg.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local Skin = {}

local NEAR = 0.09 -- summed RGB distance (0..3) inside which a part counts as that PAL colour

local KEYS = {}
for k, c in Style.PAL do
	table.insert(KEYS, { key = k, color = c })
end

local function nearest(c)
	local best, bd = nil, NEAR
	for _, e in KEYS do
		local d = math.abs(c.R - e.color.R) + math.abs(c.G - e.color.G) + math.abs(c.B - e.color.B)
		if d < bd then
			best, bd = e, d
		end
	end
	return best
end

-- the grade's map with the gild level laid over it (key -> colour or { colour, material })
local cache = {}
local function mapFor(grade, gild)
	local id = grade .. "/" .. gild
	if not cache[id] then
		local m = {}
		for k, v in Config.SKIN_GRADES[grade].map do
			m[k] = v
		end
		if gild > 0 then
			for k, v in Config.SKIN_GILD[gild] do
				m[k] = v
			end
		end
		cache[id] = m
	end
	return cache[id]
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

function Skin.apply(model, realm, lives)
	local grade, gild = Config.skinFor(realm, lives)
	local map = mapFor(grade, gild)
	if next(map) == nil then
		return
	end
	model:SetAttribute("Skin", Config.SKIN_GRADES[grade].name)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Material ~= Enum.Material.Neon then
			local e = nearest(p.Color)
			local t = e and map[e.key]
			if t then
				local c = typeof(t) == "table" and t[1] or t
				local o = p.Color
				p.Color = Color3.new(clamp01(c.R + o.R - e.color.R), clamp01(c.G + o.G - e.color.G), clamp01(c.B + o.B - e.color.B))
				if typeof(t) == "table" and t[2] then
					p.Material = t[2]
				end
			end
		end
	end
end

return Skin
