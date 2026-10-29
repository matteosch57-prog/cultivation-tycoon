-- First-time tips (D50, owner pick A, mock docs/art/mocks/tips_A.jpg): a small cream bubble with
-- one line, shown once per save at the first qi orb ("Walk into it"), the first idle chest pad
-- ("Step on the green pad") and the first pill ready ("Tap: 2x qi"). A world tip floats over its
-- target with a bobbing gold arrow and takes over the jade guide trail (local attribute TipTarget,
-- Guide.client); the pill tip sits beside the HUD's pill button and points at it. The server
-- marks a tip done when the player does the thing (data.tips, player attribute Tips); nothing here
-- is saved or granted. Waits for the launch screen (LaunchDone) and the Heavenly Gift. The recruit
-- tutorial (2026-10-24) points at the HUD's Recruit button while the Disciple Hall's free recruit
-- waits, then over the Meditation Platform (the trail leads there) until the player walks to it.
-- Owner 2026-10-24: the orb tip stays for the first Config.ORB_TIP_TIMES orbs (the server counts),
-- and the first Config.REBIRTH_TIP_TIMES rebirths get a bubble over the Rebirth seal once the price
-- is held, until that rebirth's screen is opened (the seal's red dot, Dots.luau).
local HttpService = game:GetService("HttpService")
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
	-- the recruit tutorial (owner 2026-10-24): the Disciple Hall's free recruit, then a walk to the
	-- Meditation Platform to see the newcomer seated (FreeRecruits / SeeDisciple from the server)
	recruit = { title = "Free recruit!", line = "Tap Recruit" },
	see = { title = "Your new disciple!", line = "Meditates here for qi" },
	-- the line names the boost the next rebirth brings (NextRebirthMult), set when drawn
	rebirth = { title = "Rebirth ready!", line = function()
		return string.format("Tap: x%s qi forever", tostring(player:GetAttribute("NextRebirthMult") or Config.rebirthMult(1)))
	end },
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
	local l = TIPS[key].line
	local line = text(card, type(l) == "function" and l() or l, px(15), INK, { LayoutOrder = 2 })
	line.UIStroke.Enabled = false
	return card
end

-- the HUD's gold arrow (the "goal" icon of the sheet), turned by `rot`; its slot sits in a list,
-- so the bob moves the drawing inside it
local function arrow(parent, size, rot)
	local slot = frame(parent, { Size = UDim2.fromOffset(size, size) })
	return slot, Toy.icon(slot, "goal", size, { Rotation = rot })
end

-- world tips: a BillboardGui over the target
local board = Instance.new("BillboardGui")
board.Name = "Tip"
board.ResetOnSpawn = false -- in PlayerGui: the first spawn would wipe it (live joins spawn late)
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
local HUD_TIPS = { pill = true, recruit = true, rebirth = true } -- drawn on the HUD, beside a button
-- `side` = "right" puts the pill bubble right of its button, "left" left of it (the button may sit
-- in the HUD's left or right stack)
local function draw(key, side)
	shownKey, shownScale, shownSide = key, Toy.S, side
	board:ClearAllChildren()
	hudTip:ClearAllChildren()
	if key == "rebirth" then
		-- the seal sits bottom centre: the bubble stands over it, the arrow points down at it
		hudCol = frame(hudTip, { AutomaticSize = Enum.AutomaticSize.XY, AnchorPoint = Vector2.new(0.5, 1) })
		local l = Toy.list(hudCol, false, px(2))
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		bubble(hudCol, key).LayoutOrder = 1
		local slot
		slot, hudArrow = arrow(hudCol, px(26), 90)
		slot.LayoutOrder = 2
	elseif key == "pill" or key == "recruit" then
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

-- the recruit reveal is on screen (the walk tip waits for it)
local function revealing()
	local g = playerGui:FindFirstChild("RecruitReveal")
	return g ~= nil and g.Enabled
end

-- this life's rebirth is held and its screen not opened yet (the seal's red dot), for the first rebirths
local function rebirthReady()
	if (player:GetAttribute("Rebirths") or 0) >= Config.REBIRTH_TIP_TIMES or not player:GetAttribute("RebirthOpen") then
		return false
	end
	if (player:GetAttribute("Qi") or 0) < (player:GetAttribute("RebirthPrice") or math.huge) then
		return false
	end
	local ok, lit = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Dots") or "{}")
	return ok and type(lit) == "table" and lit.reinc == true
end

-- which tip, if any, and its target (a part, or the pill or Recruit button)
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
	if (player:GetAttribute("FreeRecruits") or 0) > 0 then -- the hall's, or the platform's (FREE_RECRUIT_AT_PLATFORM)
		local hud = playerGui:FindFirstChild("Hud")
		local btn = hud and hud:FindFirstChild("RecruitSeal", true)
		if btn and shown(btn) then
			return "recruit", btn
		end
	end
	if player:GetAttribute("SeeDisciple") and not revealing() then
		local platform = built and built:FindFirstChild("platform")
		local at = platform and (platform.PrimaryPart or platform:FindFirstChildWhichIsA("BasePart", true))
		if at then
			return "see", at
		end
	end
	if rebirthReady() then
		local hud = playerGui:FindFirstChild("Hud")
		local btn = hud and hud:FindFirstChild("RebirthSeal", true)
		if btn and shown(btn) then
			return "rebirth", btn
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
			if HUD_TIPS[key] and key ~= "rebirth" and target.AbsolutePosition.X > hudTip.AbsoluteSize.X / 2 then
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
	if HUD_TIPS[key] then
		hudTip.Enabled = true
		board.Enabled = false
		local inset = hudTip.AbsolutePosition -- the HUD may draw under the top bar inset
		local a, s = target.AbsolutePosition - inset, target.AbsoluteSize
		if key == "rebirth" then
			hudCol.Position = UDim2.fromOffset(a.X + s.X / 2, a.Y - px(4) + bob)
		else
			local x = if shownSide == "left" then a.X - px(8) - bob else a.X + s.X + px(8) + bob
			hudCol.Position = UDim2.fromOffset(x, a.Y + s.Y / 2)
		end
		if player:GetAttribute("TipTarget") then
			player:SetAttribute("TipTarget", nil)
		end
	else
		hudTip.Enabled = false
		board.Adornee = target
		board.Enabled = true
		board.StudsOffsetWorldSpace = Vector3.new(0, (key == "orb" and 3.5 or key == "see" and 9 or 4.5), 0)
		if boardArrow then
			boardArrow.Position = UDim2.fromOffset(0, bob)
		end
		player:SetAttribute("TipTarget", target.Position) -- the jade trail leads to it (Guide.client)
	end
end)
