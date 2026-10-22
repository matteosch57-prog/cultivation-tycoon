-- Status title over every player's head (owner 2026-10-22: "what are reincarnations worth if you
-- can't see any change, like social status"; research docs/research/2026-10-22_visible_progression.md):
-- the realm name in the realm colour (Config.realmColor) and, from the 2nd life, "3rd Life" and the
-- sect's skin grade under it. Drawn here from the player attributes Realm and Lives the server
-- already sets, so the server sends nothing new. Hidden past Config.TITLE_SEE.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))

local CREAM = Color3.fromHex("FFF1D6")

local function draw(plr, gui)
	gui:ClearAllChildren()
	local realm = plr:GetAttribute("Realm")
	if not realm then
		return
	end
	local lives = plr:GetAttribute("Lives") or 1
	Toy.list(gui, false, 0, { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom })
	Toy.text(gui, Config.realmName(realm), 20, Config.realmColor(realm), { LayoutOrder = 1 })
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
