-- Dump the Flying Sword blades and blade auras into src/server/SwordData.luau (D76). Run ONCE in
-- Studio EDIT mode (command bar or execute_luau), by a session that may use Studio:
--   1. Load the assets (scripts deleted, R12) into ServerStorage._SwordAssets as S1 S2 S3 / A1 A2:
--      the STEP 1 block of tools/mock_swords_tiers.luau (mock branch) does it with game:GetObjects.
--   2. Run this file's text. It lays each sword flat exactly like the v9 mock (longest axis to the
--      nose, -Z; thinnest up; the hilt on the guard's side, FLIP per tier; scaled to LENGTH), reads
--      every visible part as plain data (a MeshPart becomes a mesh id + scale, drawn at runtime as a
--      Part with a FileMesh, which a game script may set) and the aura asset's ParticleEmitters
--      (scaled to a blade like the mock's aura()), and prints the whole module between
--      "-----SWORDDATA BEGIN" and "-----SWORDDATA END" (the data in 3,500-character lines).
--   3. Paste everything between the two markers, in order, one printed line per line, over
--      src/server/SwordData.luau and commit it. Delete the folder
--      after; never save the place with it (Ctrl+S is Matteo's, R5).
-- Lost on the way: SurfaceAppearance (PBR) maps, which a game script cannot create; the mesh's own
-- TextureID is kept.
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local assets = assert(ServerStorage:FindFirstChild("_SwordAssets"), "load the assets first (step 1)")
local LENGTH = 9 -- Config.SWORD_RIDE.length
local FLIP = { false, false, true } -- Studio 2026-10-23: the crystal sword lands hilt forward
local AURA = { -- the mock's per tier scaling of the aura emitters (size factor, total rate factor)
	{ size = 0.35, rate = 0.6 },
	{ size = 0.45, rate = 0.85 },
}

local function n(x)
	return math.floor(x * 1000 + 0.5) / 1000
end

local function lay(src, flip)
	local m = Instance.new("Model")
	for _, c in src:GetChildren() do
		c:Clone().Parent = m
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") then
			d:Destroy()
		end
	end
	m.Parent = workspace
	local box, size = m:GetBoundingBox()
	local axes = { { box.RightVector, size.X }, { box.UpVector, size.Y }, { box.LookVector, size.Z } }
	table.sort(axes, function(a, b)
		return a[2] > b[2]
	end)
	local long, mid, thin = axes[1][1], axes[2][1], axes[3][1]
	local centre, guardAt, widest = box.Position, nil, -1
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local o = p.CFrame:VectorToObjectSpace(mid)
			local w = math.abs(o.X * p.Size.X) + math.abs(o.Y * p.Size.Y) + math.abs(o.Z * p.Size.Z)
			if w > widest then
				widest, guardAt = w, p.Position
			end
		end
	end
	local hiltSign = (guardAt and (guardAt - centre):Dot(long) > 0) and 1 or -1
	if flip then
		hiltSign = -hiltSign
	end
	local back = long * hiltSign
	local up = thin
	local right = up:Cross(back).Unit
	m.WorldPivot = CFrame.fromMatrix(centre, right, up, back)
	m:ScaleTo(LENGTH / axes[1][2])
	m:PivotTo(CFrame.new())
	local _, size2 = m:GetBoundingBox()
	return m, size2
end

local function seq(s)
	local out = {}
	for _, k in s.Keypoints do
		table.insert(out, { n(k.Time), n(k.Value), n(k.Envelope) })
	end
	return out
end
local function cseq(s)
	local out = {}
	for _, k in s.Keypoints do
		table.insert(out, { n(k.Time), n(k.Value.R), n(k.Value.G), n(k.Value.B) })
	end
	return out
end

local data = {}
for tier = 1, 3 do
	local src = assets:FindFirstChild("S" .. tier)
	if src then
		local m, size = lay(src, FLIP[tier])
		local d = { length = n(size.Z), thickness = n(size.Y), parts = {} }
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local c = p.CFrame
				local e = {
					size = { n(p.Size.X), n(p.Size.Y), n(p.Size.Z) },
					cf = { n(c.X), n(c.Y), n(c.Z), select(4, c:GetComponents()) },
					color = { n(p.Color.R), n(p.Color.G), n(p.Color.B) },
					material = p.Material.Name,
					transparency = n(p.Transparency),
					reflectance = n(p.Reflectance),
				}
				for k = 4, 12 do
					e.cf[k] = n(e.cf[k])
				end
				if p:IsA("MeshPart") then
					e.mesh, e.tex = p.MeshId, p.TextureID
					local ms = p.MeshSize
					e.scale = { n(p.Size.X / ms.X), n(p.Size.Y / ms.Y), n(p.Size.Z / ms.Z) }
				else
					local sm = p:FindFirstChildOfClass("SpecialMesh")
					if sm and sm.MeshType == Enum.MeshType.FileMesh then
						e.mesh, e.tex = sm.MeshId, sm.TextureId
						e.scale = { n(sm.Scale.X), n(sm.Scale.Y), n(sm.Scale.Z) }
						e.vertexColor = { n(sm.VertexColor.X), n(sm.VertexColor.Y), n(sm.VertexColor.Z) }
					elseif p:IsA("Part") then
						e.shape = p.Shape.Name
					end
				end
				table.insert(d.parts, e)
			end
		end
		m:Destroy()
		local a, k = assets:FindFirstChild("A" .. tier), AURA[tier]
		if a and k then
			d.aura = {}
			local cap = math.max(size.X, 1) * 1.2
			for _, e in a:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					local sz = seq(e.Size)
					for _, kp in sz do
						kp[2] = n(math.min(kp[2] * k.size, cap))
						kp[3] = n(math.min(kp[3] * k.size, kp[2]))
					end
					table.insert(d.aura, {
						texture = e.Texture,
						color = cseq(e.Color),
						size = sz,
						transparency = seq(e.Transparency),
						lifetime = { n(math.min(e.Lifetime.Min, 1)), n(math.min(e.Lifetime.Max, 1.2)) },
						speed = { n(math.min(e.Speed.Min * k.size, 1)), n(math.min(e.Speed.Max * k.size, 2)) },
						rate = n(e.Rate * k.rate),
						spread = { n(e.SpreadAngle.X), n(e.SpreadAngle.Y) },
						lightEmission = n(e.LightEmission),
						rotSpeed = { n(e.RotSpeed.Min), n(e.RotSpeed.Max) },
						rotation = { n(e.Rotation.Min), n(e.Rotation.Max) },
						drag = n(e.Drag),
						zOffset = n(e.ZOffset),
					})
				end
			end
		end
		data[tier] = d
		print(string.format("[dump_swords] tier %d: %d parts, %d aura emitters, %.2f x %.2f x %.2f", tier, #d.parts, d.aura and #d.aura or 0, size.X, size.Y, size.Z))
	end
end

-- Luau source: a JSON blob decoded at require (one line of data, no hand edits). The blob is
-- printed in 3,500-character pieces (the output window cuts long lines); the module strips the line
-- breaks a paste puts between them (JSON itself has none), so the pieces just go one per line.
local NL = string.char(10)
local json = HttpService:JSONEncode(data)
print("-----SWORDDATA BEGIN (" .. #json .. " chars of data)")
print(table.concat({
	"-- Flying Sword blades and blade auras (D76), dumped by tools/dump_swords.luau in Studio Edit",
	"-- (" .. os.date("!%Y-%m-%d") .. "): S1 74897223654299, S2 13467141475, S3 5131677948, A1 8517247103,",
	"-- A2 17781650714; scripts deleted (R12). Do not hand edit: run the dump again.",
	"local raw = [==[",
}, NL))
for i = 1, #json, 3500 do
	print(string.sub(json, i, i + 3499))
end
print(table.concat({
	"]==]",
	'local data = game:GetService("HttpService"):JSONDecode((string.gsub(raw, string.char(10), "")))',
	"local out = {}",
	"for k, v in data do",
	"	out[tonumber(k) or k] = v",
	"end",
	"return out",
}, NL))
print("-----SWORDDATA END")
