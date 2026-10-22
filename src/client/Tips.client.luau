-- First-time tips (D50, owner pick A, mock docs/art/mocks/tips_A.jpg): a small cream bubble with
-- one line, shown once per save at the first qi orb ("Walk into it"), the first idle chest pad
-- ("Step on the green pad") and the first pill ready ("Tap: 2x qi"). A world tip floats over its
-- target with a bobbing gold arrow and takes over the jade guide trail (local attribute TipTarget,
-- Guide.client); the pill tip sits beside the HUD's pill button and points at it. The server
-- marks a tip done when the player does the thing (data.tips, player attribute Tips); nothing here
-- is saved or granted. Waits for the launch screen (LaunchDone) and the Heavenly Gift.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Toy = require(Shared:WaitForChild("Toy"))
local Config = require(Shared:WaitForChild("Config"))

local px, text, frame = Toy.px, Toy.text, Toy.frame
local CREAM = Color3.fromHex("FFF8E6")
local GOLD = Color3.fromHex("FFD34D")
local INK = Toy.INK
local PILL_MULT = 2 -- the pill's boost, shown in its line ("2x")

local TIPS = {
	chest = { title = "Idle chest", line = "Step on the green pad" },
	orb = { title = "Qi orb!", line = "Walk into it" },
	pill = { title = "Pill ready!", line = string.format("Tap: %dx qi for %d s", PILL_MULT, Config.PILL_DURATION) },
}

local function done(key)
	return table.find(string.split(player:GetAttribute("Tips") or "", ","), key) ~= nil
end

local function myBuilt()
	local sect = workspace:FindFirstChild("Sect")
	local peak = sect and sect:FindFirstChild("Peak" .. tostring(player:GetAttribute("PlotIndex")))
	return peak and peak:FindFirstChild("Built")
end

-- the bubble: gold title, one ink line, a cream card with the toy outline
local function bubble(parent, key)
	local card = frame(parent, {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 0,
		BackgroundColor3 = CREAM,
		Name = "Bubble",
	})
	Toy.corner(card, UDim.new(0, px(12)))
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = px(3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(12)), UDim.new(0, px(12))
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(5)), UDim.new(0, px(6))
	pad.Parent = card
	Toy.list(card, false, px(1))
	text(card, TIPS[key].title, px(20), GOLD, { LayoutOrder = 1 })
	local line = text(card, TIPS[key].line, px(15), INK, { LayoutOrder = 2 })
	line.UIStroke.Enabled = false
	return card
end

-- the HUD's gold arrow (Hud arrowIcon: shaft + head pointing right), turned by `rot`; its slot
-- sits in a list, so the bob moves the drawing inside it
local function arrow(parent, size, rot)
	local slot = frame(parent, { Size = UDim2.fromOffset(size, size) })
	local ic = Toy.Icon.new(slot, size, { Rotation = rot })
	ic:rect(24, 32, 30, 14, GOLD, 3)
	ic:rect(42, 32, 26, 26, GOLD, 3, 45)
	return slot, ic.box
end

-- world tips: a BillboardGui over the target
local board = Instance.new("BillboardGui")
board.Name = "Tip"
board.AlwaysOnTop = true
board.Size = UDim2.fromOffset(260, 120)
board.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
board.LightInfluence = 0
board.MaxDistance = 300
board.Enabled = false
board.Parent = playerGui
local boardCol, boardArrow

-- the pill tip: on the HUD's own layer, right of the pill button
local hudTip = Instance.new("ScreenGui")
hudTip.Name = "TipHud"
hudTip.ResetOnSpawn = false
hudTip.DisplayOrder = 6 -- just over the HUD, under its menus
hudTip.Enabled = false
hudTip.Parent = playerGui
local hudCol, hudArrow

local shownKey, shownScale, shownSide
-- `side` = "right" puts the pill bubble right of its button, "left" left of it (the button may sit
-- in the HUD's left or right stack)
local function draw(key, side)
	shownKey, shownScale, shownSide = key, Toy.S, side
	board:ClearAllChildren()
	hudTip:ClearAllChildren()
	if key == "pill" then
		local left = side == "left"
		hudCol = frame(hudTip, { AutomaticSize = Enum.AutomaticSize.XY, AnchorPoint = Vector2.new(left and 1 or 0, 0.5) })
		Toy.list(hudCol, true, px(2))
		local slot
		slot, hudArrow = arrow(hudCol, px(26), left and 0 or 180)
		slot.LayoutOrder = left and 2 or 1
		bubble(hudCol, key).LayoutOrder = left and 1 or 2
	else
		boardCol = frame(board, { Size = UDim2.fromScale(1, 1) })
		local l = Toy.list(boardCol, false, px(2))
		l.VerticalAlignment = Enum.VerticalAlignment.Bottom
		bubble(boardCol, key).LayoutOrder = 1
		local slot
		slot, boardArrow = arrow(boardCol, px(26), 90)
		slot.LayoutOrder = 2
	end
end

local function hideAll()
	board.Enabled = false
	board.Adornee = nil
	hudTip.Enabled = false
	if player:GetAttribute("TipTarget") then
		player:SetAttribute("TipTarget", nil)
	end
end

-- is a gui object drawn (every ancestor up to its ScreenGui visible)?
local function shown(obj)
	while obj and obj:IsA("GuiObject") do
		if not obj.Visible then
			return false
		end
		obj = obj.Parent
	end
	return obj ~= nil and obj:IsA("ScreenGui") and obj.Enabled
end

-- which tip, if any, and its target (a part, or the pill button)
local function pick()
	if not player:GetAttribute("LaunchDone") or (player:GetAttribute("WelcomeQi") or 0) > 0 then
		return nil -- the launch screen or the Heavenly Gift is up
	end
	local built = myBuilt()
	if built and not done("chest") then
		for _, p in built:GetChildren() do
			if p.Name == "Chest" and p:GetAttribute("PadId") == "chest" and p:GetAttribute("OwnerId") == player.UserId then
				return "chest", p
			end
		end
	end
	if built and not done("orb") then
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local best, bestD
		for _, o in built:GetChildren() do
			if o.Name == "QiOrb" and o:IsA("BasePart") then
				local d = hrp and (o.Position - hrp.Position).Magnitude or 0
				if not best or d < bestD then
					best, bestD = o, d
				end
			end
		end
		if best then
			return "orb", best
		end
	end
	if player:GetAttribute("PillReady") and not done("pill") then
		local hud = playerGui:FindFirstChild("Hud")
		local btn = hud and hud:FindFirstChild("PillButton", true)
		if btn and shown(btn) then
			return "pill", btn
		end
	end
	return nil
end

local key, target
local scan = 0
RunService.RenderStepped:Connect(function(dt)
	scan += dt
	if scan > 0.3 then
		scan = 0
		key, target = pick()
		if not key then
			hideAll()
		else
			local side = "right"
			if key == "pill" and target.AbsolutePosition.X > hudTip.AbsoluteSize.X / 2 then
				side = "left"
			end
			if key ~= shownKey or Toy.S ~= shownScale or side ~= shownSide then
				draw(key, side)
			end
		end
	end
	if not key or not target or not target.Parent then
		return
	end
	local bob = math.sin(os.clock() * 5) * px(4)
	if key == "pill" then
		hudTip.Enabled = true
		board.Enabled = false
		local inset = hudTip.AbsolutePosition -- the HUD may draw under the top bar inset
		local a, s = target.AbsolutePosition - inset, target.AbsoluteSize
		local x = if shownSide == "left" then a.X - px(8) - bob else a.X + s.X + px(8) + bob
		hudCol.Position = UDim2.fromOffset(x, a.Y + s.Y / 2)
		if player:GetAttribute("TipTarget") then
			player:SetAttribute("TipTarget", nil)
		end
	else
		hudTip.Enabled = false
		board.Adornee = target
		board.Enabled = true
		board.StudsOffsetWorldSpace = Vector3.new(0, (key == "orb" and 3.5 or 4.5), 0)
		if boardArrow then
			boardArrow.Position = UDim2.fromOffset(0, bob)
		end
		player:SetAttribute("TipTarget", target.Position) -- the jade trail leads to it (Guide.client)
	end
end)
