-- The hub's ride shop (owner 2026-10-24: "we added paid products but are never showing those new
-- ones ... swords maybe? like their own avatar on them"; Pet Simulator 99's hoverboard booth and Adopt
-- Me's dealership copied: ride items stand where everyone walks). Three stands, one per Flying Sword
-- pass, each with its sword hovering over a lit plinth and a shop pad in front; every client puts
-- its OWN avatar on the swords (SwordStands.client, tag "SwordStand"). Beside them the Tide Bell hangs
-- in a red frame over its own pad. Pads are the world shop's (PadKind "shop", ShopKey): Shop's pad
-- loop prompts them and Shop.client draws their cards, like the peak's x2 / VIP pads.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local SwordLook = require(script.Parent:WaitForChild("SwordLook"))

local HubShop = {}

local P, PAL = Style.P, Style.PAL
local H = Color3.fromHex
local GOLD = H("FFD34D")
local BRONZE = H("8A6A3E")

HubShop.STAND_X = 7.5 -- studs between two stands
HubShop.HOVER = 3.4 -- studs from the plinth top to the blade top
HubShop.YAW = math.rad(55) -- the swords turned from the plaza, so a rider shows three quarters

-- a world shop pad: an invisible anchor that Build.client draws (same contract as Shop's shopPad)
local function pad(parent, at, key)
	local p = P(parent, Vector3.new(0.5, 4, 4), at * CFrame.new(0, 0.27, 0) * CFrame.Angles(0, 0, math.pi / 2), H("9B6BE0"), nil, Enum.PartType.Cylinder)
	p.Transparency = 1
	p.CastShadow = false
	p.CanCollide = false
	p.CanTouch = false
	p.Name = "ShopPad_" .. key
	p:SetAttribute("ShopKey", key)
	p:SetAttribute("PadKind", "shop")
	p:SetAttribute("Title", Config.shopItem(key).short or Config.shopItem(key).name)
	CollectionService:AddTag(p, "StepPad")
	return p
end

-- `cf` = the booth's centre on the ground, -Z toward the plaza
function HubShop.swords(parent, cf)
	local m = Instance.new("Model")
	m.Name = "SwordBooth"
	local W = HubShop.STAND_X * 3
	P(m, Vector3.new(W, 0.4, 9), cf * CFrame.new(0, 0.2, 1), PAL.stone)
	P(m, Vector3.new(W - 1, 0.3, 8), cf * CFrame.new(0, 0.55, 1), PAL.stoneLight)
	-- the frame behind: two red posts, a gold-capped beam and the sign
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.9, 9, 0.9), cf * CFrame.new(sx * (W / 2 - 0.6), 5.2, 4.6), Kit.RED)
	end
	P(m, Vector3.new(W + 1, 0.8, 1.2), cf * CFrame.new(0, 9.9, 4.6), Kit.RED)
	P(m, Vector3.new(W + 1.4, 0.3, 1.5), cf * CFrame.new(0, 10.45, 4.6), GOLD, Enum.Material.Metal)
	Kit.plaque(m, cf * CFrame.new(0, 8.6, 4.0) * CFrame.Angles(0, math.pi, 0), 9, 1.6, "Flying Swords")
	for tier, def in Config.SWORD_RIDE.tiers do
		local x = (tier - 2) * HubShop.STAND_X
		local h = 0.8 + 0.4 * tier -- the dearer, the higher
		local base = cf * CFrame.new(x, 0, 1)
		P(m, Vector3.new(h, 4.2, 4.2), base * CFrame.new(0, 0.7 + h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), PAL.stoneLight, nil, Enum.PartType.Cylinder)
		local rim = P(m, Vector3.new(0.25, 4.5, 4.5), base * CFrame.new(0, 0.7 + h, 0) * CFrame.Angles(0, 0, math.pi / 2), def.color, Enum.Material.Neon, Enum.PartType.Cylinder)
		rim.CastShadow = false
		-- the sword: the ride template, held still over the plinth
		local top = base * CFrame.new(0, 0.7 + h + HubShop.HOVER, 0) * CFrame.Angles(0, HubShop.YAW, 0)
		local sword = SwordLook.template(tier):Clone()
		sword.Name = "Sword" .. tier
		sword.PrimaryPart.Anchored = true
		sword:PivotTo(top * CFrame.new(0, -(sword:GetAttribute("Top") or 0) - (def.bladeTopOffset or 0), 0))
		sword.Parent = m
		-- where the rider's feet go (SwordStands.client builds the viewer's own avatar there)
		local spot = P(m, Vector3.new(1, 0.2, 1), top, GOLD)
		spot.Name = "RiderSpot"
		spot.Transparency = 1
		spot.CanCollide = false
		spot.CanQuery = false
		spot:SetAttribute("Tier", tier)
		CollectionService:AddTag(spot, "SwordStand")
		pad(m, cf * CFrame.new(x, 0, -5.4), def.key)
	end
	m.Parent = parent
	return m
end

-- the Tide Bell in a red frame, its pad under the bell's front; `cf` as above
function HubShop.bell(parent, cf)
	local m = Instance.new("Model")
	m.Name = "TideBell"
	P(m, Vector3.new(9, 0.5, 6), cf * CFrame.new(0, 0.25, 1), PAL.stone)
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.9, 9, 0.9), cf * CFrame.new(sx * 3.6, 4.9, 1), Kit.RED)
	end
	P(m, Vector3.new(9.4, 0.8, 1.1), cf * CFrame.new(0, 9.6, 1), Kit.RED)
	P(m, Vector3.new(9.8, 0.3, 1.4), cf * CFrame.new(0, 10.15, 1), GOLD, Enum.Material.Metal)
	-- the bell: a bronze cylinder with a lip and a knob, hung from the beam
	P(m, Vector3.new(0.3, 0.3, 1.6), cf * CFrame.new(0, 9, 1), BRONZE, Enum.Material.Metal)
	P(m, Vector3.new(3.6, 2.6, 2.6), cf * CFrame.new(0, 7.1, 1) * CFrame.Angles(0, 0, math.pi / 2), BRONZE, Enum.Material.Metal, Enum.PartType.Cylinder)
	P(m, Vector3.new(0.4, 3.2, 3.2), cf * CFrame.new(0, 5.2, 1) * CFrame.Angles(0, 0, math.pi / 2), BRONZE, Enum.Material.Metal, Enum.PartType.Cylinder)
	local glow = P(m, Vector3.new(0.12, 2.4, 2.4), cf * CFrame.new(0, 5.0, 1) * CFrame.Angles(0, 0, math.pi / 2), H("9FF5C8"), Enum.Material.Neon, Enum.PartType.Cylinder)
	glow.CastShadow = false
	Kit.plaque(m, cf * CFrame.new(0, 9.6, 0.3) * CFrame.Angles(0, math.pi, 0), 4.6, 0.7, "Tide Bell")
	pad(m, cf * CFrame.new(0, 0, -4.2), "tidebell")
	m.Parent = parent
	return m
end

return HubShop
