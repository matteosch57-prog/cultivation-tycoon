-- The Flying Sword button (D76): a row of the HUD's right stack (Player.HudSlots.Right, after the gift,
-- the pill and the altar row; the left rail wraps at 4 rows on a 749 x 381 phone, Studio 2026-10-23),
-- shown once the player owns a sword pass. One tap flies the picked sword (SwordPick), one tap lands
-- (owner 2026-10-24: "remove the swords small menu, one click to fly and unfly"). Owning several: a
-- small round swap button (two arrows) on the button's corner moves to the next owned sword, at
-- once while flying. The icon is the sword's own store icon (Toy.icon, the pass thumbnail). Jumping
-- does NOT land (it rises: SwordFly.client flies). The server mounts, checks and switches it off
-- (R9, src/server/SwordRide.luau); this only asks.
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
local SWAP = Color3.fromHex("7A5A96")
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

local root -- the button's column (a row of the right stack)
local placeRow -- forward
local shown

local function ride(key)
	remotes.SwordRide:FireServer(key)
end

-- the sword the next tap flies: the last pick if still owned, else the best owned
local function current(list)
	local pick = player:GetAttribute("SwordPick")
	return table.find(list, pick) and pick or list[#list]
end

-- two white arrows, one each way, drawn from frames (the icon sheet has no swap glyph)
local function swapIcon(parent, size)
	local box = frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size), ZIndex = 8 })
	local t = math.max(2, math.floor(size * 0.14))
	local L = size * 0.34
	local function bar(cx, cy, len, rot)
		local f = frame(box, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(len, t),
			Rotation = rot,
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 8,
		})
		Toy.corner(f, UDim.new(1, 0))
	end
	local c = math.cos(math.rad(45)) * L / 2
	for _, a in { { y = 0.3, dir = 1 }, { y = 0.7, dir = -1 } } do
		local y = size * a.y
		local tipX = a.dir == 1 and size * 0.9 or size * 0.1
		bar(size / 2, y, size * 0.8, 0)
		bar(tipX - a.dir * c, y - c, L, a.dir * 45)
		bar(tipX - a.dir * c, y + c, L, -a.dir * 45)
	end
	return box
end

local function draw()
	local list = owned()
	local riding = player:GetAttribute("Riding")
	local key = table.concat(list, ",") .. "|" .. tostring(riding) .. "|" .. tostring(player:GetAttribute("SwordPick")) .. "|" .. Toy.S
	if key == shown then
		return
	end
	shown = key
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
	local holder, btn = Toy.button(root, UDim2.fromOffset(px(42), px(42)), face, px(21))
	holder.LayoutOrder = 1
	btn.Name = "SwordButton"
	Toy.icon(btn, riding or current(list), px(36), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	text(root, riding and "Land" or "Fly", px(12), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	btn.Activated:Connect(function()
		if player:GetAttribute("Riding") then
			ride(false)
		else
			ride(current(list))
		end
	end)
	if #list > 1 then
		-- the swap: the next owned sword (flying: switch now; on foot: the next one to fly)
		local sHolder, sBtn = Toy.button(holder, UDim2.fromOffset(px(22), px(22)), SWAP, px(11))
		sHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		sHolder.Position = UDim2.fromOffset(px(2), px(2))
		sHolder.ZIndex = 6
		sBtn.ZIndex = 6
		sBtn.Name = "SwordSwap"
		swapIcon(sBtn, px(14))
		sBtn.Activated:Connect(function()
			local now = player:GetAttribute("Riding") or current(list)
			local i = table.find(list, now) or 0
			local nextKey = list[i % #list + 1]
			if player:GetAttribute("Riding") then
				ride(nextKey)
			else
				remotes.SwordRide:FireServer(nextKey, true)
			end
		end)
	end
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
