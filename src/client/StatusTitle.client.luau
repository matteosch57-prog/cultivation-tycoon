-- Status title over every player's head (owner 2026-10-22: "what are reincarnations worth if you
-- can't see any change, like social status"; research docs/research/2026-10-22_visible_progression.md):
-- the realm name in the realm colour (Config.realmColor) and, from the 2nd life, "3rd Life" and the
-- sect's skin grade under it. Drawn here from the player attributes Realm and Lives the server
-- already sets, so the server sends nothing new. Hidden past Config.TITLE_SEE and over your own head.
-- A VIP Sect owner (attribute Pass_vip, Shop.luau) gets the gold VIP icon before the realm name
-- (owner pick 2026-10-23, like Pet Simulator 99 / Bee Swarm's VIP tag; chat tag in VipTag.client).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))

local CREAM = Color3.fromHex("FFF1D6")
local VIP_GOLD = Color3.fromHex("FFCD32") -- the arch's VIP gold
local GLOW = "rbxassetid://" .. Config.AURA_TEX.glow

-- The VIP icon with its aura (owner 2026-10-23: "overhead could get some aura"): a gold glow that
-- breathes behind it and a white glint that sweeps across it every few seconds (Pet Simulator 99's
-- tag shine). Sizes and offsets only: WorldText owns every transparency here (its distance fade).
local function vipBadge(parent)
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromOffset(26, 26)
	box.LayoutOrder = 1
	local glow = Instance.new("ImageLabel")
	glow.Name = "VipGlow"
	glow.BackgroundTransparency = 1
	glow.Image = GLOW
	glow.ImageColor3 = VIP_GOLD
	glow.ImageTransparency = 0.25
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(46, 46)
	glow.ZIndex = 1
	glow.Parent = box
	local icon = Toy.icon(box, "vip", 26)
	local glint = icon:Clone()
	glint.Name = "VipGlint"
	glint.ImageColor3 = Color3.new(1, 1, 1)
	glint.ZIndex = 3
	local band = Instance.new("UIGradient")
	band.Rotation = 25
	band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	band.Offset = Vector2.new(-1, 0)
	band.Parent = glint
	glint.Parent = box
	TweenService:Create(glow, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Size = UDim2.fromOffset(62, 62),
	}):Play()
	TweenService:Create(band, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 2.3), {
		Offset = Vector2.new(1, 0),
	}):Play()
	box.Parent = parent
	return box
end

local function draw(plr, gui)
	gui:ClearAllChildren()
	local realm = plr:GetAttribute("Realm")
	if not realm then
		return
	end
	local lives = plr:GetAttribute("Lives") or 1
	Toy.list(gui, false, 0, { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom })
	if plr:GetAttribute("Pass_vip") then
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.AutomaticSize = Enum.AutomaticSize.XY
		row.Size = UDim2.new()
		row.LayoutOrder = 1
		Toy.list(row, true, 6)
		vipBadge(row)
		Toy.text(row, Config.realmName(realm), 20, Config.realmColor(realm), { LayoutOrder = 2 })
		row.Parent = gui
	else
		Toy.text(gui, Config.realmName(realm), 20, Config.realmColor(realm), { LayoutOrder = 1 })
	end
	if lives > 1 then
		Toy.text(gui, Config.ordinal(lives) .. " Life · " .. Config.skinName(realm, lives), 14, CREAM, { LayoutOrder = 2 })
	end
end

local function attach(plr, char)
	local head = char:WaitForChild("Head", 10)
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "StatusTitle"
	gui.Size = UDim2.fromOffset(340, 48)
	gui.SizeOffset = Vector2.new(0, 0.5) -- grow upward from the anchor, clear of Roblox's name tag
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = Config.TITLE_SEE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Adornee = head
	draw(plr, gui)
	gui.Parent = head
	local conns
	conns = {
		plr:GetAttributeChangedSignal("Realm"):Connect(function()
			draw(plr, gui)
		end),
		plr:GetAttributeChangedSignal("Lives"):Connect(function()
			draw(plr, gui)
		end),
		plr:GetAttributeChangedSignal("Pass_vip"):Connect(function()
			draw(plr, gui)
		end),
		gui.AncestryChanged:Connect(function()
			if not gui:IsDescendantOf(game) then
				for _, c in conns do
					c:Disconnect()
				end
			end
		end),
	}
end

local function watch(plr)
	if plr == Players.LocalPlayer then
		return -- only others see your title (like Roblox's own name tag): yours drew through the menus and +qi floats
	end
	plr.CharacterAdded:Connect(function(char)
		attach(plr, char)
	end)
	if plr.Character then
		task.spawn(attach, plr, plr.Character)
	end
end

for _, plr in Players:GetPlayers() do
	watch(plr)
end
Players.PlayerAdded:Connect(watch)
