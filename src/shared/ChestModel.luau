-- The idle chest as a 3D model (owner: "make the animation of the chest better, choose a good 3d
-- model"). Shared so the peak (server) and the return screen's ViewportFrame (client) draw the same
-- chest. A Chinese lacquer chest: dark red body on short gold feet, brass corner caps and bands, a
-- jade lock plate with a ring, and a stepped flat lid (closed on every side) on its back hinge.
-- ChestModel.build(parent, cf) -> model, lid (Model), hinge (CFrame in world space at build time)
-- ChestModel.setLid(lid, hinge, degrees) opens the lid (0 = shut, about 110 = wide open).
local ChestModel = {}

local LACQUER = Color3.fromHex("8E1F1A")
local LACQUER_DARK = Color3.fromHex("5E1411")
local GOLD = Color3.fromHex("D4A445")
local BRASS = Color3.fromHex("B88A3A")
local JADE = Color3.fromHex("6FD6AE")
local INSIDE = Color3.fromHex("2A0E0C")

local W, D, H = 4.2, 2.9, 2.1 -- body width (X), depth (Z), height (Y) in studs

local function part(parent, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if size.X < 1 and size.Y < 1 or size.Y < 1 and size.Z < 1 then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

function ChestModel.build(parent, cf)
	local m = Instance.new("Model")
	m.Name = "ChestModel"
	local feetY = 0.25
	-- four short gold feet with a carved step
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local at = cf * CFrame.new(sx * (W / 2 - 0.35), feetY / 2, sz * (D / 2 - 0.3))
			part(m, Vector3.new(0.55, feetY, 0.55), at, GOLD, Enum.Material.Metal)
		end
	end
	local base = feetY
	-- body: the lacquer box, a darker plinth band, gold bands top and middle
	local body =
		part(m, Vector3.new(W, H, D), cf * CFrame.new(0, base + H / 2, 0), LACQUER, Enum.Material.SmoothPlastic)
	body.Name = "Body"
	part(m, Vector3.new(W + 0.12, 0.28, D + 0.12), cf * CFrame.new(0, base + 0.14, 0), LACQUER_DARK)
	part(m, Vector3.new(W + 0.1, 0.18, D + 0.1), cf * CFrame.new(0, base + H - 0.09, 0), GOLD, Enum.Material.Metal)
	part(m, Vector3.new(W + 0.06, 0.12, D + 0.06), cf * CFrame.new(0, base + H * 0.45, 0), GOLD, Enum.Material.Metal)
	-- brass corner caps (vertical) and two straps over the front
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				m,
				Vector3.new(0.3, H + 0.04, 0.3),
				cf * CFrame.new(sx * W / 2, base + H / 2, sz * D / 2),
				BRASS,
				Enum.Material.Metal
			)
		end
		part(
			m,
			Vector3.new(0.34, H, 0.08),
			cf * CFrame.new(sx * W * 0.28, base + H / 2, -D / 2 - 0.03),
			BRASS,
			Enum.Material.Metal
		)
	end
	-- the jade lock plate with its ring (front = -Z)
	part(
		m,
		Vector3.new(0.9, 0.9, 0.12),
		cf * CFrame.new(0, base + H - 0.55, -D / 2 - 0.06),
		JADE,
		Enum.Material.SmoothPlastic
	)
	part(m, Vector3.new(0.5, 0.5, 0.1), cf * CFrame.new(0, base + H - 0.55, -D / 2 - 0.12), GOLD, Enum.Material.Metal)
	local ring = part(
		m,
		Vector3.new(0.12, 0.55, 0.55),
		cf * CFrame.new(0, base + H - 1.05, -D / 2 - 0.14) * CFrame.Angles(0, math.pi / 2, 0),
		GOLD,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	ring.Transparency = 0
	-- the dark inside, seen when the lid opens
	part(m, Vector3.new(W - 0.3, 0.06, D - 0.3), cf * CFrame.new(0, base + H + 0.01, 0), INSIDE)

	-- the lid: a solid stepped lacquer lid like a Chinese document chest (closed on every side), a
	-- gold rim moulding, brass corner caps, a raised gold cloud panel and a jade pearl on top. Hinge
	-- at the back top edge.
	local lid = Instance.new("Model")
	lid.Name = "Lid"
	local hingeLocal = CFrame.new(0, base + H, D / 2) -- back top edge
	local top = cf * CFrame.new(0, base + H, 0)
	local LW, LD = W + 0.2, D + 0.2 -- the lid overhangs the body a little on every side
	part(lid, Vector3.new(LW, 0.32, LD), top * CFrame.new(0, 0.16, 0), LACQUER_DARK) -- skirt
	part(lid, Vector3.new(LW + 0.06, 0.1, LD + 0.06), top * CFrame.new(0, 0.37, 0), GOLD, Enum.Material.Metal) -- rim moulding
	part(lid, Vector3.new(LW - 0.2, 0.3, LD - 0.2), top * CFrame.new(0, 0.57, 0), LACQUER) -- first step
	part(lid, Vector3.new(LW - 0.7, 0.24, LD - 0.7), top * CFrame.new(0, 0.84, 0), LACQUER) -- second step
	part(lid, Vector3.new(LW - 0.66, 0.05, LD - 0.66), top * CFrame.new(0, 0.73, 0), GOLD, Enum.Material.Metal) -- step line
	-- the gold cloud panel on top: a long plate with two rounded ends
	part(lid, Vector3.new(LW - 1.6, 0.06, LD - 1.5), top * CFrame.new(0, 0.98, 0), GOLD, Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		local cap = part(
			lid,
			Vector3.new(0.06, LD - 1.5, LD - 1.5),
			top * CFrame.new(sx * (LW - 1.6) / 2, 0.98, 0) * CFrame.Angles(0, 0, math.pi / 2),
			GOLD,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		cap.Name = "CloudEnd"
	end
	part(lid, Vector3.new(LW - 2.0, 0.07, LD - 1.9), top * CFrame.new(0, 0.99, 0), LACQUER_DARK) -- the panel's inset
	-- brass corner caps folded over the lid edge
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				lid,
				Vector3.new(0.42, 0.44, 0.42),
				top * CFrame.new(sx * (LW / 2 - 0.15), 0.2, sz * (LD / 2 - 0.15)),
				BRASS,
				Enum.Material.Metal
			)
			part(
				lid,
				Vector3.new(0.5, 0.08, 0.5),
				top * CFrame.new(sx * (LW / 2 - 0.2), 0.44, sz * (LD / 2 - 0.2)),
				BRASS,
				Enum.Material.Metal
			)
		end
	end
	-- the hasp: a gold tongue hanging over the jade lock plate on the front
	part(lid, Vector3.new(0.36, 0.5, 0.08), top * CFrame.new(0, -0.1, -LD / 2 - 0.02), GOLD, Enum.Material.Metal)
	-- a jade pearl on top
	part(
		lid,
		Vector3.new(0.42, 0.42, 0.42),
		top * CFrame.new(0, 1.18, 0),
		JADE,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	part(
		lid,
		Vector3.new(0.6, 0.1, 0.6),
		top * CFrame.new(0, 1.03, 0),
		GOLD,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	).CFrame = top
		* CFrame.new(0, 1.03, 0)
		* CFrame.Angles(0, 0, math.pi / 2)
	lid.Parent = m
	m.Parent = parent
	return m, lid, cf * hingeLocal
end

-- pivot the lid about its hinge: every lid part keeps its offset from the hinge at build time
function ChestModel.setLid(lid, hinge, degrees)
	if not lid:GetAttribute("Built") then
		for _, p in lid:GetChildren() do
			if p:IsA("BasePart") then
				p:SetAttribute("Rel", hinge:ToObjectSpace(p.CFrame))
			end
		end
		lid:SetAttribute("Built", true)
	end
	local turn = hinge * CFrame.Angles(math.rad(degrees), 0, 0)
	for _, p in lid:GetChildren() do
		local rel = p:GetAttribute("Rel")
		if rel then
			p.CFrame = turn * rel
		end
	end
end

return ChestModel
