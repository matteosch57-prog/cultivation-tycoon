-- The Flying Sword button (D76): a row of the HUD's right stack (Player.HudSlots.Right, after the gift,
-- the pill and the altar row; the left rail wraps at 4 rows on a 749 x 381 phone, Studio 2026-10-23),
-- shown once the player owns a sword pass. Tap: ride the last sword (SwordPick); tap again to step
-- off. Owning several: the first tap opens a small picker of the owned swords (the last one ridden
-- first, in gold). Jumping also steps off. The server mounts, checks and switches it off (R9,
-- src/server/SwordRide.luau); this only asks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))

local px, text, frame = Toy.px, Toy.text, Toy.frame
local FACE = Color3.fromHex("3A2C44") -- the HUD's button face
local RIDING = Color3.fromHex("6FE0B4")
local GOLD = Color3.fromHex("FFD34D")
local TIERS = Config.SWORD_RIDE.tiers

local gui = Instance.new("ScreenGui")
gui.Name = "SwordRide"
gui.ResetOnSpawn = false -- R19: never a gui that the first spawn wipes
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 1
gui.Parent = playerGui

local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice") -- "phone" / "pc" forces a layout (testing)
	local touch = if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
	if touch then
		return math.clamp(vp.Y / 390, 0.78, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

local function owned()
	local list = {}
	for _, t in TIERS do
		if player:GetAttribute("Pass_" .. t.key) then
			table.insert(list, t.key)
		end
	end
	return list
end

local function nameOf(key)
	local it = Config.shopItem(key)
	return it and it.name or key
end

local root -- the button's column (a row of the left rail)
local placeRow -- forward
local picker -- the open picker row, if any
local shown

local function closePicker()
	if picker then
		picker:Destroy()
		picker = nil
	end
end

local function ride(key)
	closePicker()
	remotes.SwordRide:FireServer(key)
end

-- the picker: one toy tile per owned sword beside the button, the last ridden first and gold-rimmed.
-- It floats in this script's own gui at the button's left (Studio 2026-10-23: inside a rail it
-- widened the row and pushed the HUD's other buttons 160 px over)
local function openPicker(list, anchor)
	closePicker()
	local pick = player:GetAttribute("SwordPick")
	table.sort(list, function(a, b)
		if a == pick or b == pick then
			return a == pick
		end
		return a < b
	end)
	local at = anchor.AbsolutePosition - gui.AbsolutePosition
	picker = frame(gui, {
		AutomaticSize = Enum.AutomaticSize.XY,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromOffset(at.X - px(12), at.Y + anchor.AbsoluteSize.Y / 2),
		ZIndex = 5,
	})
	Toy.list(picker, true, px(8))
	for i, key in list do
		local col = frame(picker, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = i, ZIndex = 5 })
		Toy.list(col, false, px(1))
		local holder, btn = Toy.button(col, UDim2.fromOffset(px(42), px(42)), key == pick and GOLD or FACE, px(11))
		holder.LayoutOrder = 1
		Toy.icon(btn, key, px(31), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 6 })
		text(col, nameOf(key), px(11), Color3.new(1, 1, 1), { LayoutOrder = 2, ZIndex = 6 })
		btn.Activated:Connect(function()
			ride(key)
		end)
	end
end

local function draw()
	local list = owned()
	local riding = player:GetAttribute("Riding")
	local key = table.concat(list, ",") .. "|" .. tostring(riding) .. "|" .. Toy.S
	if key == shown then
		return
	end
	shown = key
	closePicker()
	if root then
		root:Destroy()
		root = nil
	end
	if #list == 0 then
		return
	end
	root = frame(gui, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 5 })
	root.Name = "SwordRow"
	Toy.list(root, false, px(1))
	local face = riding and RIDING or FACE
	local holder, btn = Toy.button(root, UDim2.fromOffset(px(42), px(42)), face, px(11))
	holder.LayoutOrder = 1
	btn.Name = "SwordButton"
	local pick = player:GetAttribute("SwordPick")
	local iconKey = riding or (table.find(list, pick) and pick) or list[#list]
	Toy.icon(btn, iconKey, px(31), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	text(root, riding and "Off" or "Ride", px(12), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	btn.Activated:Connect(function()
		if player:GetAttribute("Riding") then
			ride(false)
		elseif #list == 1 then
			ride(list[1])
		elseif picker then
			closePicker()
		else
			openPicker(table.clone(list), btn)
		end
	end)
	placeRow()
end

-- the row lives in the HUD's right stack (Player.HudSlots, D54); its own corner only if the HUD is missing
local function rightStack()
	local slots = player:FindFirstChild("HudSlots")
	local right = slots and slots:FindFirstChild("Right")
	return right and right.Value
end
placeRow = function()
	if not root then
		return
	end
	local rail = rightStack()
	if rail then
		if root.Parent ~= rail then
			root.AnchorPoint = Vector2.new(0, 0)
			root.Position = UDim2.new()
			root.Parent = rail
		end
	elseif root.Parent ~= gui then
		root.AnchorPoint = Vector2.new(1, 0)
		root.Position = UDim2.new(1, -px(16), 0, GuiService.TopbarInset.Max.Y + px(200))
		root.Parent = gui
	end
end
task.spawn(function()
	local slots = player:WaitForChild("HudSlots", 30)
	if slots then
		slots:WaitForChild("Rebuilt").Event:Connect(function()
			closePicker() -- it floats beside a button that is about to move
			task.defer(placeRow)
		end)
	end
end)

local function rescale()
	Toy.S = computeScale()
	shown = nil
	draw()
end

for _, t in TIERS do
	player:GetAttributeChangedSignal("Pass_" .. t.key):Connect(draw)
end
player:GetAttributeChangedSignal("Riding"):Connect(draw)
player:GetAttributeChangedSignal("SwordPick"):Connect(draw)
player:GetAttributeChangedSignal("HudDevice"):Connect(rescale)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

-- a jump steps off the sword (keys, gamepad and the phone's jump button all raise JumpRequest)
UserInputService.JumpRequest:Connect(function()
	if player:GetAttribute("Riding") then
		remotes.SwordRide:FireServer(false)
	end
end)
