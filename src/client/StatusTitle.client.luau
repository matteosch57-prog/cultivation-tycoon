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
-- VIP Sect title (owner pick B 2026-10-23, mock /mnt/project-files/vip/2026-10-23_vip_overhead_mocks.png;
-- Blox Fruits-style title): the crown before the realm name and the name in gold, a lighter band
-- sweeping across the letters every few seconds. Gradient offset only: WorldText owns transparency.
local GOLD_SHINE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FFA41C")),
	ColorSequenceKeypoint.new(0.4, Color3.fromHex("FFD86B")),
	ColorSequenceKeypoint.new(0.5, Color3.fromHex("FFF8D8")),
	ColorSequenceKeypoint.new(0.6, Color3.fromHex("FFD86B")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("FFA41C")),
})

local function vipTitle(parent, realm)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.Size = UDim2.new()
	row.LayoutOrder = 1
	Toy.list(row, true, 5)
	Toy.icon(row, "vip", 28, { LayoutOrder = 1 })
	local t = Toy.text(row, Config.realmName(realm), 22, Color3.new(1, 1, 1), { LayoutOrder = 2 })
	local g = Instance.new("UIGradient")
	g.Color = GOLD_SHINE
	g.Rotation = 10
	g.Offset = Vector2.new(-0.6, 0)
	g.Parent = t
	local shine = TweenService:Create(g, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 1.2), {
		Offset = Vector2.new(0.6, 0),
	})
	shine:Play()
	g.Destroying:Connect(function()
		shine:Cancel() -- an endless tween: stop it with its title (each redraw and respawn makes a new one)
	end)
	row.Parent = parent
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
		vipTitle(gui, realm)
	else
		Toy.text(gui, Config.realmName(realm), 20, Config.realmColor(realm), { LayoutOrder = 1 })
	end
	if lives > 1 then
		local style = Config.sectStyle(plr:GetAttribute("SectStyle") or "") -- the Sect Style worn, else the D53 grade
		Toy.text(gui, Config.ordinal(lives) .. " Life · " .. (style and style.name or Config.skinName(realm, lives)), 14, CREAM, { LayoutOrder = 2 })
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
		plr:GetAttributeChangedSignal("SectStyle"):Connect(function()
			draw(plr, gui)
		end),
		gui.AncestryChanged:Connect(function()
			if not gui:IsDescendantOf(game) then
				for _, c in conns do
					c:Disconnect()
				end
				-- an old character is only unparented, never destroyed, on other clients: destroy the
				-- title so its shine tween stops (Destroying in vipTitle) and the old title is freed
				task.defer(gui.Destroy, gui)
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
