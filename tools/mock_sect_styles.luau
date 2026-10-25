-- Mock for 2026-10-25_rebirth_new_looks (option A, Sect Styles): six Main Hall level 5 builds in a row,
-- each dressed in one rebirth style (recolour + roof ornaments + ground props + ambience particles).
-- Run in Studio EDIT through run_code; builds workspace.MockSectStyles far from the game (x = 4000) and
-- returns camera spots. Delete the folder after the captures; never save the place with it.
local SSS = game:GetService("ServerScriptService")
local Server = SSS:WaitForChild("Server")
local Kit = require(Server:WaitForChild("Kit"))
local Style = require(Server:WaitForChild("Style"))
local PAL = Style.PAL
local hex = Color3.fromHex

local old = workspace:FindFirstChild("MockSectStyles")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "MockSectStyles"
root.Parent = workspace

local function P(parent, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- recolour like Skin.apply: nearest PAL key (Kit.RED counts as vermilion), keep the baked shading offset
local KEYS = {}
for k, c in PAL do
	table.insert(KEYS, { key = k, color = c })
end
table.insert(KEYS, { key = "vermilion", color = Kit.RED })
table.insert(KEYS, { key = "vermilionDark", color = Kit.RED_DARK })
local function recolour(model, map)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Material ~= Enum.Material.Neon then
			local best, bd = nil, 0.09
			for _, e in KEYS do
				local d = math.abs(p.Color.R - e.color.R) + math.abs(p.Color.G - e.color.G) + math.abs(p.Color.B - e.color.B)
				if d < bd then
					best, bd = e, d
				end
			end
			local t = best and map[best.key]
			if t then
				local c = typeof(t) == "table" and t[1] or t
				local o = p.Color
				p.Color = Color3.new(math.clamp(c.R + o.R - best.color.R, 0, 1), math.clamp(c.G + o.G - best.color.G, 0, 1), math.clamp(c.B + o.B - best.color.B, 0, 1))
				if typeof(t) == "table" and t[2] then
					p.Material = t[2]
				end
			end
		end
	end
end

local function roofParts(model)
	local out = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Material == Enum.Material.ClayRoofTiles then
			table.insert(out, p)
		end
	end
	return out
end

-- ridge spots of one roofed sub-model: centre top and the two ridge ends (from the roof's bounding box)
local function ridges(model)
	local out = {}
	local subs = {}
	for _, c in model:GetDescendants() do
		if c:IsA("Model") then
			table.insert(subs, c)
		end
	end
	if #subs == 0 then
		subs = { model }
	end
	for _, sub in subs do
		local tiles = {}
		for _, p in sub:GetChildren() do
			if p:IsA("BasePart") and p.Material == Enum.Material.ClayRoofTiles then
				table.insert(tiles, p)
			end
		end
		if #tiles > 0 then
			-- top roof only: the parts within 3 studs of the highest
			local top = -math.huge
			for _, p in tiles do
				top = math.max(top, p.Position.Y)
			end
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, p in tiles do
				if p.Position.Y > top - 3 then
					minX, maxX = math.min(minX, p.Position.X), math.max(maxX, p.Position.X)
					minZ, maxZ = math.min(minZ, p.Position.Z), math.max(maxZ, p.Position.Z)
				end
			end
			local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
			local half = math.max(0, ((maxX - minX) - (maxZ - minZ)) / 2)
			table.insert(out, { c = Vector3.new(cx, top + 0.6, cz), a = Vector3.new(cx - half, top + 0.6, cz), b = Vector3.new(cx + half, top + 0.6, cz) })
		end
	end
	return out
end

local function particles(parent, at, size, opts)
	local box = P(parent, size, CFrame.new(at), Color3.new(1, 1, 1))
	box.Transparency = 1
	box.CanCollide = false
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = opts.texture or "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(opts.color)
	pe.LightEmission = opts.light or 0
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, opts.size or 0.6), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(5, 8)
	pe.Speed = NumberRange.new(opts.speed or 1, (opts.speed or 1) * 2)
	pe.Acceleration = opts.accel or Vector3.new(0, -1, 0)
	pe.SpreadAngle = Vector2.new(30, 30)
	pe.Rate = opts.rate or 20
	pe.Parent = box
	-- pre-warm so a still capture shows them
	pe:Emit(opts.rate and opts.rate * 4 or 80)
end

-- ornaments ------------------------------------------------------------------------------------
local function chiwen(parent, at, facing, color) -- ridge beast: a curled tail block stack facing inward
	local cf = CFrame.lookAt(at, at + facing)
	P(parent, Vector3.new(1, 2.4, 1.6), cf * CFrame.new(0, 1.2, 0), color, Enum.Material.Metal)
	P(parent, Vector3.new(1, 1, 1.4), cf * CFrame.new(0, 2.6, 0.6) * CFrame.Angles(-0.5, 0, 0), color, Enum.Material.Metal)
	P(parent, Vector3.new(0.8, 0.9, 1), cf * CFrame.new(0, 1.9, -1.1), color, Enum.Material.Metal) -- head
end
local function pearl(parent, at, color, mat, d)
	P(parent, Vector3.new(d, d, d), CFrame.new(at + Vector3.new(0, d / 2 + 0.6, 0)), color, mat or Enum.Material.Glass, Enum.PartType.Ball)
	P(parent, Vector3.new(0.6, 1.2, 0.6), CFrame.new(at + Vector3.new(0, 0.3, 0)), PAL.gold, Enum.Material.Metal)
end
local function crystal(parent, at, color, h)
	local p = P(parent, Vector3.new(h * 0.35, h, h * 0.35), CFrame.new(at + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, math.rad(45), math.rad(8)), color, Enum.Material.Glass)
	p.Transparency = 0.15
	return p
end
local function crescent(parent, at, color)
	local cf = CFrame.new(at + Vector3.new(0, 2.4, 0))
	for i = 0, 8 do
		local a = math.rad(-110 + i * 27.5)
		P(parent, Vector3.new(0.5, 0.9, 0.5), cf * CFrame.Angles(0, 0, a) * CFrame.new(0, 2, 0), color, Enum.Material.Metal)
	end
	P(parent, Vector3.new(0.4, 2.4, 0.4), CFrame.new(at + Vector3.new(0, 1.2, 0)), color, Enum.Material.Metal)
end
local function rod(parent, at, color, glow)
	P(parent, Vector3.new(0.35, 4.5, 0.35), CFrame.new(at + Vector3.new(0, 2.25, 0)), color, Enum.Material.Metal)
	for k = 1, 3 do
		P(parent, Vector3.new(1.4 - k * 0.3, 0.2, 1.4 - k * 0.3), CFrame.new(at + Vector3.new(0, 1 + k * 1.1, 0)), color, Enum.Material.Metal)
	end
	P(parent, Vector3.new(0.7, 0.7, 0.7), CFrame.new(at + Vector3.new(0, 4.8, 0)), glow, Enum.Material.Neon, Enum.PartType.Ball)
end

local function snowCaps(model)
	for _, p in roofParts(model) do
		local cap = P(model, Vector3.new(p.Size.X * 0.96, 0.3, p.Size.Z * 0.85), p.CFrame * CFrame.new(0, 0.42, -p.Size.Z * 0.05), hex("F7FBFF"), Enum.Material.Snow)
		cap.Name = "SnowCap"
	end
end

local function cracks(model, color)
	local cf, size = model:GetBoundingBox()
	local y = cf.Position.Y - size.Y / 2 + 0.15
	local rng = Random.new(7)
	for _ = 1, 14 do
		local x = rng:NextNumber(-size.X / 2, size.X / 2)
		local z = size.Z / 2 + rng:NextNumber(2, 10)
		local len = rng:NextNumber(3, 7)
		P(model, Vector3.new(0.3, 0.12, len), CFrame.new(cf.Position.X + x, y, cf.Position.Z + z) * CFrame.Angles(0, rng:NextNumber(-1, 1), 0), color, Enum.Material.Neon)
	end
end

-- the six styles: rebirth N unlocks STYLES[N] --------------------------------------------------
local STYLES = {
	{
		name = "Snow Lotus",
		ground = hex("EEF4FA"),
		groundMat = Enum.Material.Snow,
		map = { tile = hex("8FB8D8"), tileDark = hex("6D93B3"), vermilion = hex("DDE8F2"), vermilionDark = hex("B9CCDD"), plaster = hex("FFFFFF"), gold = hex("CFE6FF"), stone = { hex("E3ECF4"), Enum.Material.Marble }, stoneLight = hex("F2F6FA"), timber = hex("8FA6BA"), timberDark = hex("5C7389") },
		dress = function(m, spots)
			snowCaps(m)
			for _, s in spots do
				crystal(m, s.c, hex("A8E4FF"), 4)
				crystal(m, s.a, hex("A8E4FF"), 2.4)
				crystal(m, s.b, hex("A8E4FF"), 2.4)
			end
		end,
		fx = { texture = "rbxasset://textures/particles/sparkles_main.dds", color = hex("FFFFFF"), rate = 30, speed = 1, accel = Vector3.new(0.4, -2, 0), size = 0.5 },
	},
	{
		name = "Volcano Forge",
		ground = hex("2B2523"),
		groundMat = Enum.Material.Basalt,
		map = { tile = { hex("2F2A2A"), Enum.Material.ClayRoofTiles }, tileDark = hex("1E1A1A"), vermilion = hex("7A1F14"), vermilionDark = hex("4E140D"), plaster = { hex("3A3330"), Enum.Material.Basalt }, gold = hex("FF8A2A"), stone = { hex("3B3634"), Enum.Material.Basalt }, stoneLight = hex("4A4441"), timber = hex("2A1E19"), timberDark = hex("1A120E") },
		dress = function(m, spots)
			cracks(m, hex("FF6A1A"))
			for _, s in spots do
				pearl(m, s.c, hex("FF6A1A"), Enum.Material.Neon, 2)
				chiwen(m, s.a, (s.c - s.a).Unit, hex("2A2422"))
				chiwen(m, s.b, (s.c - s.b).Unit, hex("2A2422"))
			end
		end,
		fx = { color = hex("FF8A2A"), rate = 25, speed = 1.5, accel = Vector3.new(0, 2.5, 0), size = 0.4, light = 1 },
	},
	{
		name = "Sakura Spring",
		ground = hex("8FBF6A"),
		groundMat = Enum.Material.Grass,
		map = { tile = hex("E79AB4"), tileDark = hex("C27390"), vermilion = hex("F4EDE6"), vermilionDark = hex("D9CFC4"), plaster = hex("FFFFFF"), gold = hex("F2C9A0"), timber = hex("7A4E3A") },
		dress = function(m, spots)
			local cf, size = m:GetBoundingBox()
			local y = cf.Position.Y - size.Y / 2
			for _, sx in { -1, 1 } do
				for _, sz in { 0.5, 1 } do
					Style.sakura(m, CFrame.new(cf.Position.X + sx * (size.X / 2 + 4), y, cf.Position.Z + sz * size.Z / 2), sx * 3 + sz * 7)
				end
			end
			for _, s in spots do
				pearl(m, s.c, hex("FFD6E4"), Enum.Material.Glass, 1.6)
			end
		end,
		fx = { color = hex("FFC4D8"), rate = 25, speed = 1, accel = Vector3.new(0.8, -1.2, 0), size = 0.5 },
	},
	{
		name = "Moon Palace",
		ground = hex("C9D2E0"),
		groundMat = Enum.Material.Marble,
		map = { tile = hex("2D3E73"), tileDark = hex("1E2A52"), vermilion = hex("E9EEF6"), vermilionDark = hex("C3CCDA"), plaster = { hex("FFFFFF"), Enum.Material.Marble }, gold = hex("D8E2F0"), stone = { hex("E4E9F1"), Enum.Material.Marble }, stoneLight = hex("F2F5F9"), timber = hex("5A6788"), timberDark = hex("323C58") },
		dress = function(m, spots)
			for _, s in spots do
				crescent(m, s.c, hex("E8EEF8"))
				pearl(m, s.a, hex("BFD4FF"), Enum.Material.Glass, 1.2)
				pearl(m, s.b, hex("BFD4FF"), Enum.Material.Glass, 1.2)
			end
		end,
		fx = { color = hex("CFE0FF"), rate = 15, speed = 0.5, accel = Vector3.new(0, 0.4, 0), size = 0.6 },
	},
	{
		name = "Thunder Peak",
		ground = hex("4A4E57"),
		groundMat = Enum.Material.Slate,
		map = { tile = { hex("3A3550"), Enum.Material.ClayRoofTiles }, tileDark = hex("272338"), vermilion = hex("4B3C7A"), vermilionDark = hex("33285A"), plaster = { hex("8B8FA0"), Enum.Material.Slate }, gold = hex("F5D04A"), stone = { hex("5C606B"), Enum.Material.Slate }, stoneLight = hex("6E727D") },
		dress = function(m, spots)
			for _, s in spots do
				rod(m, s.c, hex("F5D04A"), hex("B9A8FF"))
				rod(m, s.a, hex("F5D04A"), hex("B9A8FF"))
				rod(m, s.b, hex("F5D04A"), hex("B9A8FF"))
			end
		end,
		fx = { color = hex("C8B8FF"), rate = 20, speed = 3, accel = Vector3.new(0, 0, 0), size = 0.5, light = 1 },
	},
	{
		name = "Dragon Emperor",
		ground = hex("B89A6A"),
		groundMat = Enum.Material.Sandstone,
		map = { tile = { hex("E0A82E"), Enum.Material.ClayRoofTiles }, tileDark = hex("B07E18"), vermilion = hex("A3221B"), plaster = hex("F3DFB0"), gold = { hex("FFD24A"), Enum.Material.Foil }, stone = hex("E2D2A8") },
		dress = function(m, spots)
			for _, s in spots do
				pearl(m, s.c, hex("FFE27A"), Enum.Material.Foil, 2.2)
				chiwen(m, s.a, (s.c - s.a).Unit, hex("2F8F5A"))
				chiwen(m, s.b, (s.c - s.b).Unit, hex("2F8F5A"))
			end
		end,
		fx = { color = hex("FFE07A"), rate = 15, speed = 0.8, accel = Vector3.new(0, 0.6, 0), size = 0.5 },
	},
}

local BASE = Vector3.new(4000, 300, 0)
local GAP = 120
local spots = {}
for i, st in STYLES do
	local at = CFrame.new(BASE + Vector3.new((i - 1) * GAP, 0, 0))
	local plot = Instance.new("Model")
	plot.Name = string.format("%d %s", i, st.name)
	plot.Parent = root
	P(plot, Vector3.new(100, 2, 100), at * CFrame.new(0, -1, 0), st.ground, st.groundMat)
	local hall = Kit.mainHall(plot, at, 5, st.name)
	recolour(hall, st.map)
	st.dress(hall, ridges(hall))
	local pav = Kit.pavilion(plot, at * CFrame.new(-30, 0, 30), 8, 7)
	recolour(pav, st.map)
	st.dress(pav, ridges(pav))
	local _, size = hall:GetBoundingBox()
	particles(plot, at.Position + Vector3.new(0, size.Y + 6, 10), Vector3.new(90, 1, 70), st.fx)
	spots[i] = { name = st.name, camFrom = at.Position + Vector3.new(38, 26, 70), lookAt = at.Position + Vector3.new(0, 10, -6) }
end
return spots
