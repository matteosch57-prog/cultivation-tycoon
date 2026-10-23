-- Quick travel (owner 2026-10-22: "quick TP to other islands, too long to walk otherwise"): a portal
-- beside every bridge mouth on the hub goes to that bridge's island, and one by every island's
-- bridge goes back to the hub. A portal is a walk-on pad like the rest of the game: the client sees
-- you step on it (Hud, tag "Portal") and asks Remotes.Teleport for its `Where`; the server checks
-- you stand on that portal and picks the landing spot (Main, R9).
local CollectionService = game:GetService("CollectionService")
local Style = require(script.Parent:WaitForChild("Style"))

local Portals = {}

local P, PAL = Style.P, Style.PAL
local GLOW = Color3.fromHex("8FF3CF")

local GOLD_LIGHT = Color3.fromHex("FFE29A")
local COLUMN_H = 20

-- `cf` = the pad's centre on the ground, its +Z toward whoever walks up; returns the name label.
-- `opts.column`: the hub's portals (owner pick B 2026-10-23, docs/art/mocks/altar_tp_pads.jpg) also
-- raise a column of light with gold arrows climbing it, so a pad reads as "this takes you away" from
-- across the hub. The column never collides and goes dark with the pad (setOpen).
function Portals.pad(parent, cf, where, title, opts)
	local m = Instance.new("Model")
	m.Name = "Portal"
	local flat = CFrame.Angles(0, 0, math.pi / 2)
	P(m, Vector3.new(0.5, 7.6, 7.6), cf * CFrame.new(0, 0.25, 0) * flat, PAL.stone, nil, Enum.PartType.Cylinder)
	P(m, Vector3.new(0.6, 6.6, 6.6), cf * CFrame.new(0, 0.3, 0) * flat, PAL.gold, Enum.Material.Metal, Enum.PartType.Cylinder)
	local pad = P(m, Vector3.new(0.7, 5.6, 5.6), cf * CFrame.new(0, 0.35, 0) * flat, GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
	pad.Name = "PortalPad"
	pad.Transparency = 0.15
	pad:SetAttribute("Where", where)
	CollectionService:AddTag(pad, "Portal")
	-- R3: the glow is a real lamp
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 12
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = pad
	local motes = Instance.new("ParticleEmitter")
	motes.Color = ColorSequence.new(GLOW)
	motes.LightEmission = 0.6
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	motes.Lifetime = NumberRange.new(1.4, 2)
	motes.Rate = 6
	motes.Speed = NumberRange.new(2, 3)
	motes.SpreadAngle = Vector2.new(12, 12)
	motes.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis (X) points up
	motes.Parent = pad
	if opts and opts.column then
		local col = Instance.new("Folder")
		col.Name = "Column"
		col.Parent = m
		local function glow(size, at, color, alpha, shape)
			local p = P(col, size, at, color, Enum.Material.Neon, shape)
			p.Transparency = alpha
			p:SetAttribute("Alpha", alpha)
			p.CanCollide, p.CanQuery, p.CastShadow = false, false, false
			return p
		end
		glow(Vector3.new(COLUMN_H, 5, 5), cf * CFrame.new(0, 0.7 + COLUMN_H / 2, 0) * flat, GLOW, 0.82, Enum.PartType.Cylinder)
		glow(Vector3.new(COLUMN_H, 1.4, 1.4), cf * CFrame.new(0, 0.7 + COLUMN_H / 2, 0) * flat, Color3.new(1, 1, 1), 0.55, Enum.PartType.Cylinder)
		-- up-arrows standing round the column at three heights, each a "^" of two bars
		for h = 0, 2 do
			for k = 0, 3 do
				local a = k / 4 * math.pi * 2 + h * 0.4
				local at = cf * CFrame.new(math.cos(a) * 3.2, 3 + h * 4, math.sin(a) * 3.2) * CFrame.Angles(0, -a + math.pi / 2, 0)
				for _, sx in { -1, 1 } do
					glow(Vector3.new(0.3, 1.5, 0.3), at * CFrame.new(sx * 0.45, 0, 0) * CFrame.Angles(0, 0, sx * math.rad(45)), GOLD_LIGHT, 0)
				end
			end
		end
	end
	-- a little gate behind the pad carrying where it goes
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.6, 6.2, 0.6), cf * CFrame.new(sx * 2.9, 3.1, -3.4), PAL.vermilion)
	end
	P(m, Vector3.new(7.2, 0.5, 1), cf * CFrame.new(0, 6.4, -3.4), PAL.tile)
	P(m, Vector3.new(6.4, 0.3, 0.8), cf * CFrame.new(0, 6.05, -3.4), PAL.gold, Enum.Material.Metal)
	local plaque = P(m, Vector3.new(5.2, 1.3, 0.3), cf * CFrame.new(0, 5.1, -3.4), PAL.timberDark)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- the plaque's +Z side, toward the pad
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = plaque
	local label = Instance.new("TextLabel")
	label.Name = "Where"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.Fantasy
	label.TextColor3 = Color3.fromRGB(255, 225, 150)
	label.Text = title
	label.Parent = gui
	m.Parent = parent
	return label, pad
end

-- an empty island's portal goes dark and says so; it lights up again when someone claims the peak
function Portals.setOpen(label, pad, open, title)
	label.Text = title
	pad:SetAttribute("Off", not open or nil)
	pad.Transparency = open and 0.15 or 0.6
	pad.PointLight.Enabled = open
	pad.ParticleEmitter.Enabled = open
	local col = pad.Parent and pad.Parent:FindFirstChild("Column")
	if col then
		for _, p in col:GetChildren() do
			p.Transparency = open and p:GetAttribute("Alpha") or 1
		end
	end
end

return Portals
