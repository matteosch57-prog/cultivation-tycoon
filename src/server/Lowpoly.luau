-- Low-poly stand-ins for small Ball and Cylinder parts (B01 step 3, phone performance).
-- A Ball part draws 432 triangles and a Cylinder 96; a full peak has ~1,260 small balls (roof
-- hip joints, finials) and ~1,500 small cylinders (hip rods, columns' collars), ~690k of its
-- ~750k triangles. One uploaded mesh of each (art/meshes, tools/lowpoly_meshes.py) is cloned
-- for every small one: the same box, so the look stays, and clones of one mesh draw instanced.
-- Off until Config.LOWPOLY_BALL / LOWPOLY_CYLINDER hold the uploaded mesh ids.
local AssetService = game:GetService("AssetService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Lowpoly = {}

local templates: { [Enum.PartType]: MeshPart } = {}

local function load(id: string?, shape: Enum.PartType)
	if not id or id == "" then
		return
	end
	local ok, mp = pcall(AssetService.CreateMeshPartAsync, AssetService, id, {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Automatic,
	})
	if ok and mp then
		mp.Anchored = true
		templates[shape] = mp
	else
		warn("[Tycoon][perf] event=lowpoly_load_failed") -- falls back to plain parts
		print("[Tycoon][perf] lowpoly", shape.Name, id, mp)
	end
end
load(Config.LOWPOLY_BALL, Enum.PartType.Ball)
load(Config.LOWPOLY_CYLINDER, Enum.PartType.Cylinder)

-- Studio test hook: measure the swap before the meshes are uploaded (an EditableMesh template).
function Lowpoly.setTemplate(shape: Enum.PartType, mp: MeshPart?)
	templates[shape] = mp
end

-- Pond boulders (Config.ROCK_MESH, tools/rock_meshes.py): 80 triangles, unit box like the others.
local rocks: { MeshPart } = {}
for i, id in Config.ROCK_MESH or {} do
	if id ~= "" then
		local ok, mp = pcall(AssetService.CreateMeshPartAsync, AssetService, id, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
		if ok and mp then
			mp.Anchored = true
			rocks[i] = mp
		else
			warn("[Tycoon][perf] event=rock_load_failed")
			print("[Tycoon][perf] rock", i, id, mp)
		end
	end
end

-- Boulder `i` (1..4) as a fresh MeshPart, or nil until all four meshes are loaded.
function Lowpoly.rock(i: number): MeshPart?
	if #rocks < 4 then
		return nil
	end
	return rocks[(i - 1) % 4 + 1]:Clone()
end

-- Koi for the koi pond (owner 2026-10-22: "just find a model"): a free Creator Store fish mesh,
-- ids in Config.KOI; nil until it loads (the pond then has no fish).
local koi: MeshPart? = nil
local K = Config.KOI
if K and K.mesh ~= "" then
	local ok, mp = pcall(AssetService.CreateMeshPartAsync, AssetService, K.mesh, {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Automatic,
	})
	if ok and mp then
		mp.Anchored = true
		mp.TextureID = K.texture
		mp.Size = mp.Size * (K.length / math.max(mp.Size.X, mp.Size.Y, mp.Size.Z))
		mp.CFrame = K.turn
		koi = mp
	else
		warn("[Tycoon][perf] event=koi_load_failed")
		print("[Tycoon][perf] koi", K.mesh, mp)
	end
end
function Lowpoly.koi(): MeshPart?
	return koi and koi:Clone()
end

-- Studio test hook: preview the boulders before the upload (EditableMesh templates, art/preview/rocks.json).
function Lowpoly.setRock(i: number, mp: MeshPart?)
	rocks[i] = mp :: MeshPart
end

-- A fresh part for `shape` at `size`: a mesh clone when the shape is small enough, else a Part.
-- Small = a Ball under LOWPOLY_MAX on every side; a Cylinder under LOWPOLY_MAX across (any length).
function Lowpoly.part(shape: Enum.PartType?, size: Vector3): BasePart
	local t = shape and templates[shape]
	if t then
		local across = if shape == Enum.PartType.Cylinder then math.max(size.Y, size.Z) else math.max(size.X, size.Y, size.Z)
		if across < Config.LOWPOLY_MAX then
			return t:Clone()
		end
	end
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	return p
end

-- The low-poly mesh at any size (soft round canopies, Nature.luau): 80 triangles for a ball of
-- any size against a Ball part's 432. Falls back to a true part before the meshes load.
function Lowpoly.mesh(shape: Enum.PartType): BasePart
	local t = templates[shape]
	if t then
		return t:Clone()
	end
	local p = Instance.new("Part")
	p.Shape = shape
	return p
end

return Lowpoly
