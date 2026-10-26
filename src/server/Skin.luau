-- Building skins (owner pick A, mocks docs/art/mocks/2026-10-22_skins_*.jpg; Config.SKIN_*):
-- the material follows the realm (Timber, Red Lacquer, Jade, Imperial Gold over the island's 4
-- opening realms), later lives top out in their own grade, and lives add lanterns and motes.
-- apply: a recolour pass after the build instead of a palette threaded through every builder. Kit
-- and Style draw from Style.PAL directly (and lerp from it), so each part is matched to its nearest
-- PAL colour and moved by the same offset, which keeps the shading steps the builders baked in.
-- Neon parts (glows) and colours far from every PAL entry are left alone.
-- extras: the light and aura a reset never takes back (stone lanterns round the Main Hall, motes
-- over big buildings). Not for the hidden proximity previews.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))
local SectStyle = require(script.Parent:WaitForChild("SectStyle"))

local Skin = {}

local NEAR = 0.09 -- summed RGB distance (0..3) inside which a part counts as that PAL colour
local NEAR_STYLE = 0.14 -- a Sect Style repaints the whole hall: the kit's off-palette shades too

local KEYS = {}
for k, c in Style.PAL do
	table.insert(KEYS, { key = k, color = c })
end

-- a Sect Style also catches the kit colours that sit off PAL (Play check 2026-10-25: the level 5 Main Hall
-- roof is Kit's gold tile, so it took the style's trim; tile ends, ridges and the painted frieze kept the
-- Imperial colours). `w` / `b` = how far the result is lightened / darkened, so the shading steps stay.
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local STYLE_KEYS = table.clone(KEYS)
for _, base in { Style.PAL.tile, Color3.fromHex("D9A43A"), Color3.fromHex("8C6A44") } do -- Kit: art tile, GOLD_TILE, the humble hall
	table.insert(STYLE_KEYS, { key = "tile", color = base })
	table.insert(STYLE_KEYS, { key = "tile", color = base:Lerp(WHITE, 0.15), w = 0.15 }) -- tile ends
	table.insert(STYLE_KEYS, { key = "tile", color = base:Lerp(BLACK, 0.3), b = 0.3 }) -- ridges
end
table.insert(STYLE_KEYS, { key = "vermilion", color = Color3.fromHex("8E2620"), b = 0.25 }) -- Kit.RED_DARK
table.insert(STYLE_KEYS, { key = "tileDark", color = Color3.fromHex("2F6F55") }) -- Kit.PAINT_GREEN frieze
table.insert(STYLE_KEYS, { key = "tileDark", color = Color3.fromHex("2E5A8C") }) -- Kit.PAINT_BLUE

local NATURAL = {}
for _, m in { "Rock", "Slate", "Ground", "Grass", "LeafyGrass", "Sand", "Mud", "Limestone", "Sandstone", "Pebble", "Salt", "CrackedLava", "Glacier", "Water" } do
	NATURAL[Enum.Material[m]] = true
end

local function nearest(c, keys, near)
	local best, bd = nil, near
	for _, e in keys do
		local d = math.abs(c.R - e.color.R) + math.abs(c.G - e.color.G) + math.abs(c.B - e.color.B)
		if d < bd then
			best, bd = e, d
		end
	end
	return best
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

-- move every part matched to a PAL key onto `map` (a grade's or, with `wide`, a Sect Style's)
function Skin.recolour(model, map, wide)
	if next(map) == nil then
		return
	end
	local keys, near = wide and STYLE_KEYS or KEYS, wide and NEAR_STYLE or NEAR
	for _, p in model:GetDescendants() do
		-- a style leaves nature alone (Play check: the lotus isles' rock took the roof colour)
		if p:IsA("BasePart") and p.Material ~= Enum.Material.Neon and not (wide and NATURAL[p.Material]) then
			local e = nearest(p.Color, keys, near)
			local t = e and map[e.key]
			if t then
				local c = typeof(t) == "table" and t[1] or t
				if e.w then
					c = c:Lerp(WHITE, e.w)
				elseif e.b then
					c = c:Lerp(BLACK, e.b)
				end
				local o = p.Color
				p.Color = Color3.new(clamp01(c.R + o.R - e.color.R), clamp01(c.G + o.G - e.color.G), clamp01(c.B + o.B - e.color.B))
				if typeof(t) == "table" and t[2] then
					p.Material = t[2]
				end
			end
		end
	end
end

-- `style` = the Sect Style the sect wears (Config.wornStyle; nil = the D53 realm / life grade)
function Skin.apply(model, realm, lives, style)
	if style then
		model:SetAttribute("Skin", style.name)
		SectStyle.dress(model, style, function(m, map)
			Skin.recolour(m, map, true)
		end)
		-- the lotus isles' grass tops wear the style's ground like the lawn (Play check 2026-10-26)
		if model.Name:match("^lotus%d") then
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") and (p.Material == Enum.Material.Grass or p.Material == Enum.Material.LeafyGrass) then
					p.Material = style.ground[1]
					p.Color = style.ground[2]
				end
			end
		end
		return
	end
	local grade = Config.skinFor(realm, lives)
	model:SetAttribute("Skin", Config.SKIN_GRADES[grade].name)
	Skin.recolour(model, Config.SKIN_GRADES[grade].map)
end

local function ghost(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false -- never a new obstacle on a path the player already walks
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

-- slow motes over the roof (sunlit sparkles, LightEmission 0: R3)
local function motes(model, cf, size, grade, level)
	local box = Instance.new("Part")
	box.Name = "SkinMotes"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = Vector3.new(size.X, 1, size.Z)
	box.CFrame = cf * CFrame.new(0, size.Y * 0.2, 0)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Config.SKIN_MOTE_COLOR[grade] or Color3.new(1, 1, 1))
	pe.LightEmission = 0
	pe.LightInfluence = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(4, 6)
	pe.Speed = NumberRange.new(0.5, 1.2)
	pe.SpreadAngle = Vector2.new(20, 20)
	pe.Acceleration = Vector3.new(0, 0.6, 0)
	pe.Rate = math.min(Config.SKIN_MOTE_MAX, Config.SKIN_MOTE_RATE * (level - Config.SKIN_MOTE_FROM + 1))
	pe.Parent = box
	box.Parent = model
end

-- lanterns down both sides of the Main Hall, front first, just outside its footprint
local function lanterns(model, cf, size, n)
	for i = 1, n do
		local side = i % 2 == 1 and -1 or 1
		local row = math.ceil(i / 2) - 1
		local at = cf * CFrame.new(side * (size.X / 2 + 3), -size.Y / 2, size.Z / 2 - 2 - row * math.max(6, size.Z / 4))
		ghost(Style.lantern(model, at, 1))
	end
end

-- the Main Hall grows with the life (Config.SKIN_HALL_SCALE), about the middle of its front edge
function Skin.scale(model, pad, lives, frame)
	if not pad.id:match("^mainhall%d$") then
		return
	end
	local k = Config.SKIN_HALL_SCALE[math.min(lives or 1, #Config.SKIN_HALL_SCALE)]
	if k == 1 or not model:FindFirstChildWhichIsA("BasePart", true) then
		return
	end
	local at = frame * CFrame.new(pad.x or 0, 0, pad.z or 0)
	model.WorldPivot = at
	local cf, size = model:GetBoundingBox()
	local front = at:PointToObjectSpace(cf.Position).Z + size.Z / 2
	model.WorldPivot = at * CFrame.new(0, 0, front)
	model:ScaleTo(k)
end

-- `frame` = the peak frame (+Z faces the hub); the Main Hall stands at its pad facing +Z
function Skin.extras(model, pad, realm, lives, frame)
	local level = Config.skinLevel(realm, lives)
	if not model:FindFirstChildWhichIsA("BasePart", true) then
		return -- expansions build nothing
	end
	model.WorldPivot = frame * CFrame.new(pad.x or 0, 0, pad.z or 0) -- the box below follows this yaw
	local cf, size = model:GetBoundingBox()
	local grade = Config.skinFor(realm, lives)
	if level >= Config.SKIN_MOTE_FROM and math.min(size.X, size.Z) >= Config.SKIN_MOTE_MIN then
		motes(model, cf, size, grade, level)
	end
	if pad.id:match("^mainhall%d$") then
		local n = Config.SKIN_LANTERNS[math.min(lives or 1, #Config.SKIN_LANTERNS)]
		if n > 0 then
			lanterns(model, cf, size, n)
		end
	end
end

return Skin
