-- Studio mock (2026-10-22, owner liked A and C): the Meditation Platform grown to its last level,
-- built in Play on a peak with real seated disciples, for screenshots only (nothing ships from here).
--   A = Lotus Terraces: three stepped rings, the strongest on a lotus dais at the top
--   C = Floating Lotus Discs: the platform plus three jade discs floating above it on gold chains
-- Run in the Server datamodel: local build = <this file>; build("A", frame, parent). `frame` = the
-- platform centre on the ground, front (+Z) toward the peak's avenue.
local SSS = game:GetService("ServerScriptService").Server
local RS = game:GetService("ReplicatedStorage").Shared
local Style = require(SSS.Style)
local Kit = require(SSS.Kit)
local Cultivators = require(SSS.Cultivators)
local Config = require(RS.Config)

local P, PAL = Style.P, Style.PAL
local LOTUS = { mesh = "rbxassetid://14340526628", tex = "rbxassetid://14340559072", native = Vector3.new(22.23, 28.65, 22.23) }
local BRONZE = Color3.fromHex("7A5A3A")
-- v2 (owner: "more impressive, nice clouds, find assets"): free Creator Store meshes, inserted in Edit
-- into ServerStorage._MockInspect only for this mock (scriptless): cloud 4862433614 (mesh 4862430258),
-- rock islet 5565039117 (mesh 5564853241), bronze ding 132759878349743 (mesh 84550079612246), palace
-- lantern 91953058256983 (mesh 131650726315765), pavilion 95647925586342 (staticleelee)
local LIB = game:GetService("ServerStorage"):FindFirstChild("_MockInspect")
local rng = Random.new(7)

-- a clone of the library MeshPart whose MeshId ends in `id`
local function mesh(parent, id, cf, size)
	local src
	for _, d in LIB:GetDescendants() do
		if d:IsA("MeshPart") and string.find(d.MeshId, id, 1, true) then
			src = d
			break
		end
	end
	local p = src:Clone()
	p:ClearAllChildren()
	p.Anchored, p.CanCollide = true, false
	p.Size = size or p.Size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- a puffy cloud mesh, `w` long, lavender-white like the sky's clouds
local function cloud(parent, cf, w)
	local p = mesh(parent, "4862430258", cf * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), Vector3.new(w * 0.56, w * 0.37, w))
	p.Color = Color3.fromRGB(255, 252, 255):Lerp(Color3.fromRGB(214, 206, 240), rng:NextNumber(0, 0.35))
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = false
	return p
end

local function bank(parent, F, n, r0, r1, y0, y1, w0, w1, skipFront)
	for i = 1, n do
		local a = rng:NextNumber(0, math.pi * 2)
		if not (skipFront and math.abs(math.sin(a) - 1) < 0.35) then
			local r = rng:NextNumber(r0, r1)
			cloud(parent, F * CFrame.new(math.cos(a) * r, rng:NextNumber(y0, y1), math.sin(a) * r), rng:NextNumber(w0, w1))
		end
	end
end

local function palaceLantern(parent, cf, h)
	local p = mesh(parent, "131650726315765", cf * CFrame.new(0, h / 2, 0), Vector3.new(4.66, 7.6, 4) * (h / 7.6))
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = Color3.fromRGB(255, 175, 95), h * 2.2, 1.4
	l.Parent = p
	return p
end

local function cyl(parent, h, d, cf, color, mat)
	return P(parent, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, Enum.PartType.Cylinder)
end

-- a giant lotus in bloom (the seat mesh the Dao Ancestor sits on), `d` wide, `squash` of its height
local function lotus(parent, cf, d, squash)
	local k = d / LOTUS.native.X
	local p = P(parent, Vector3.new(d, LOTUS.native.Y * k * squash, d), cf, Color3.new(1, 1, 1))
	p.CanCollide = false
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.FileMesh
	sm.MeshId = LOTUS.mesh
	sm.TextureId = LOTUS.tex
	sm.Scale = Vector3.new(k, k * squash, k)
	sm.Parent = p
	return p
end

-- a bronze incense burner (ding): bowl, three legs, two handles, three sticks with a smoke wisp
local function ding(parent, cf)
	if LIB then
		local p = mesh(parent, "84550079612246", cf * CFrame.new(0, 2.05 * 1.1, 0), Vector3.new(4, 5.46, 4) * 0.75)
		p.Material = Enum.Material.Metal
		p.Color = Color3.fromHex("6E7F5E")
		return
	end
	cyl(parent, 1.3, 2.2, cf * CFrame.new(0, 1.35, 0), BRONZE, Enum.Material.Metal)
	cyl(parent, 0.25, 2.5, cf * CFrame.new(0, 2.05, 0), PAL.gold, Enum.Material.Metal)
	for i = 0, 2 do
		local a = math.rad(i * 120)
		P(parent, Vector3.new(0.3, 0.9, 0.3), cf * CFrame.new(math.cos(a) * 0.8, 0.45, math.sin(a) * 0.8), BRONZE, Enum.Material.Metal)
	end
	for _, sx in { -1, 1 } do
		P(parent, Vector3.new(0.2, 0.7, 0.6), cf * CFrame.new(sx * 1.25, 2.4, 0), BRONZE, Enum.Material.Metal)
	end
	for i = -1, 1 do
		local stick = P(parent, Vector3.new(0.1, 1.2, 0.1), cf * CFrame.new(i * 0.3, 2.7, 0), Color3.fromHex("8B3A2B"))
		if i == 0 then
			local tip = Instance.new("Attachment")
			tip.Position = Vector3.new(0, 0.6, 0)
			tip.Parent = stick
			local w = Instance.new("ParticleEmitter")
			w.Texture = "rbxasset://textures/particles/smoke_main.dds"
			w.Color = ColorSequence.new(Color3.fromRGB(225, 222, 232))
			w.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.9) })
			w.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.55), NumberSequenceKeypoint.new(1, 1) })
			w.Lifetime = NumberRange.new(2.5, 3.5)
			w.Rate = 4
			w.Speed = NumberRange.new(0.8, 1.1)
			w.SpreadAngle = Vector2.new(6, 6)
			w.Parent = tip
		end
	end
end

-- a round tier: stone drum, gold band, light deck, a carved jade frieze round the wall, a railing
-- round the deck edge open at the front stair; returns the deck CFrame
local function tier(parent, F, r, h, stairW)
	cyl(parent, h, r * 2, F * CFrame.new(0, h / 2, 0), PAL.stone, Enum.Material.Limestone)
	cyl(parent, 0.3, r * 2 + 0.3, F * CFrame.new(0, h * 0.55, 0), PAL.gold, Enum.Material.Metal)
	cyl(parent, 0.35, r * 2 - 0.4, F * CFrame.new(0, h + 0.17, 0), PAL.stoneLight, Enum.Material.Limestone)
	-- frieze: jade panels round the wall under the band
	local n = math.floor(r * 2 * math.pi / 2.2)
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local at = F * CFrame.Angles(0, a, 0) * CFrame.new(0, h * 0.27, -r - 0.02)
		P(parent, Vector3.new(1.5, h * 0.32, 0.15), at, PAL.jade, Enum.Material.Marble)
	end
	local deck = F * CFrame.new(0, h + 0.35, 0)
	-- stair at the front (+Z)
	local steps = math.max(2, math.round(h / 0.55))
	for i = 1, steps do
		local sh = (h + 0.35) * i / steps
		P(parent, Vector3.new(stairW, sh, 1.1), F * CFrame.new(0, sh / 2, r + (steps - i + 0.5) * 1.1 - 0.4), PAL.stoneLight, Enum.Material.Limestone)
	end
	-- railing segments on the deck rim, leaving the stair open
	local rr, gap = r - 0.6, math.asin(math.min(1, (stairW / 2 + 0.8) / (r - 0.6)))
	local segs = math.max(6, math.floor(r * 1.2))
	local from, to = math.pi / 2 + gap, math.pi / 2 + math.pi * 2 - gap
	local function at(a)
		return (deck * CFrame.new(math.cos(a) * rr, 0, math.sin(a) * rr)).Position
	end
	for i = 0, segs - 1 do
		Kit.railing(parent, at(from + (to - from) * i / segs), at(from + (to - from) * (i + 1) / segs), 1.6)
	end
	return deck
end

local function seat(parent, deck, a, r, rarity, look)
	local x, z = math.cos(a) * r, math.sin(a) * r
	local cf = deck * CFrame.new(x, 0, z) * CFrame.Angles(0, math.atan2(x, z) + math.pi, 0) -- facing out, toward the visitor
	cyl(parent, 0.3, 2.4, cf * CFrame.new(0, 0.15, 0), Color3.fromHex("6D2E3E"), Enum.Material.Fabric) -- cushion
	return Cultivators.build(parent, cf * CFrame.new(0, 0.3, 0), look, rarity, Config.RARITIES, {})
end

local function ring(parent, deck, n, r, ranks, skipFront)
	local looks = Cultivators.LOOKS
	local j = 0
	for i = 0, n - 1 do
		local a = math.pi / 2 + (i + 0.5) / n * math.pi * 2
		if skipFront then -- leave the stair clear: spread the seats over the rest of the circle
			a = math.pi / 2 + 0.55 + (math.pi * 2 - 1.1) * i / (n - 1)
		end
		j += 1
		seat(parent, deck, a, r, Config.RARITIES[ranks[(j - 1) % #ranks + 1]], looks[(j - 1) % #looks + 1])
	end
end

local function build(option, F, parent)
	local folder = Instance.new("Folder")
	folder.Name = "MockFloors_" .. option
	folder.Parent = parent
	local R = #Config.RARITIES
	local low, mid, high = { 1, 2, 3, 2 }, { 3, 4, 5 }, { R - 2, R - 1, R }
	if option == "A" then
		local d1 = tier(folder, F, 17.5, 1.6, 7)
		local d2 = tier(folder, d1, 11.5, 3.6, 5)
		-- the strongest meditate in a pavilion on the top terrace
		local pav = LIB.pavilion:Clone()
		pav:ScaleTo(0.22)
		local ext = pav:GetExtentsSize()
		local box = pav:GetBoundingBox()
		pav:PivotTo(d2 * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, ext.Y / 2, 0) * box:ToObjectSpace(pav:GetPivot()))
		pav.Parent = folder
		for _, d in pav:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		-- its floor: a ray down from under the roof
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { pav }
		local from = (d2 * CFrame.new(0, ext.Y * 0.35, 0)).Position
		local hit = workspace:Raycast(from, Vector3.new(0, -ext.Y, 0), params)
		local floor = d2 * CFrame.new(0, hit and (hit.Position.Y - d2.Position.Y) or 1, 0)
		ring(folder, d1, 8, 14.6, low, true)
		ring(folder, d2, 6, 9.2, mid, true)
		ring(folder, floor, 4, 2.6, high, false)
		for k = 0, 3 do
			local a = math.rad(45 + k * 90)
			ding(folder, d1 * CFrame.new(math.cos(a) * 15.6, 0, math.sin(a) * 15.6))
		end
		for _, sx in { -1, 1 } do
			palaceLantern(folder, F * CFrame.new(sx * 6, 0, 23), 7)
		end
		-- clouds pooled round the foot of the terraces, wisps drifting high behind
		bank(folder, F, 30, 17.5, 21, 0, 1.6, 7, 11, true)
		bank(folder, F * CFrame.new(0, 0, -22), 6, 4, 16, 14, 24, 12, 20, false) -- behind only
	else
		local d1 = tier(folder, F, 13, 1.2, 7)
		cyl(folder, 0.12, 6.6, d1 * CFrame.new(0, 0.06, 0), PAL.timberDark)
		ring(folder, d1, 8, 9.2, low, true)
		for k = 0, 3 do
			local a = math.rad(45 + k * 90)
			ding(folder, d1 * CFrame.new(math.cos(a) * 11.6, 0, math.sin(a) * 11.6))
		end
		local discs = { { -17, 12, 3, mid }, { 17, 16, -3, mid }, { 0, 24, -14, high } }
		for _, s in discs do
			local c = F * CFrame.new(s[1], s[2], s[3])
			-- a floating rock islet under a lotus in bloom, the jade deck in its heart
			mesh(folder, "5564853241", c * CFrame.new(0, -6.2, 0), Vector3.new(16, 13, 16)).Material = Enum.Material.Slate
			lotus(folder, c * CFrame.new(0, 0.6, 0), 21, 0.28)
			cyl(folder, 0.6, 14, c * CFrame.new(0, 1.4, 0), PAL.jade, Enum.Material.Marble)
			cyl(folder, 0.25, 14.5, c * CFrame.new(0, 1.2, 0), PAL.gold, Enum.Material.Metal)
			local deck = c * CFrame.new(0, 1.7, 0)
			ring(folder, deck, 4, 4.4, s[4], false)
			palaceLantern(folder, deck, 3.2)
			-- clouds hugging the islet's rim and trailing under it
			bank(folder, c, 7, 6.5, 9.5, -2, 0.2, 7, 12, false)
			bank(folder, c, 3, 2, 5, -9, -6, 8, 12, false)
		end
		for _, sx in { -1, 1 } do
			palaceLantern(folder, F * CFrame.new(sx * 6, 0, 19), 7)
		end
	end
	return folder
end

return build
