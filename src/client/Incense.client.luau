-- The incense button (owner 2026-10-24: "a button to incense easily with a count", pick A of
-- docs/art/mocks/2026-10-24_incense_button_ABC.jpg): a row of the HUD's right stack (Player.HudSlots.Right,
-- after the altar row, before the sword) with the sticks left today on an ember badge (Pet Sim 99 /
-- Bee Swarm's item count). One tap teleports you in front of the nearest neighbour's shrine you can
-- still bless (Remotes.Teleport "shrine", the server picks it: Bless.target); the blessing itself is
-- still the 3 s hold there (D57: the visit is the point). Shown only while another sect is on the
-- server; gold when a shrine is free, the HUD face when not (none free, or no incense left: then the
-- caption counts down to the UTC reset).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))

local px, text, frame = Toy.px, Toy.text, Toy.frame
local FACE = Color3.fromHex("3A2C44") -- the HUD's button face
local READY = Color3.fromHex("FFD36B") -- the gold of a ready button (the Shop, a ready gift)
local EMBER = Color3.fromHex("FF8A3C") -- the shrine's lit tips
local CHECK = 0.5 -- seconds between checks (shrines change rarely)

local gui = Instance.new("ScreenGui")
gui.Name = "Incense"
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

local function serverDay()
	return math.floor(workspace:GetServerTimeNow()) // 86400
end

-- the sticks left today (the server's count, or a full hand once its day is over)
local function left()
	local n = player:GetAttribute("IncenseLeft")
	if n == nil then
		return 0
	end
	return player:GetAttribute("IncenseDay") == serverDay() and n or Config.BLESS_GIVE_MAX
end

-- the server's sects: `others` = another player's peak (or a Studio test peak) is here, `free` = one
-- of them takes a blessing from you now (the same checks as Bless.target)
local function scan()
	local blessed = {}
	if player:GetAttribute("IncenseDay") == serverDay() then
		for id in string.gmatch(player:GetAttribute("BlessedTo") or "", "[^,]+") do
			blessed[id] = true
		end
	end
	local others, free = false, false
	for _, peak in (workspace:FindFirstChild("Sect") or workspace):GetChildren() do
		local shrine = peak:FindFirstChild("Shrine")
		if shrine then
			local owner = shrine:GetAttribute("OwnerId") or 0
			local test = owner == 0 and workspace:GetAttribute("BlessTest") == true -- Studio hook (Bless.luau)
			if test or (owner ~= 0 and owner ~= player.UserId) then
				others = true
				if (test or not blessed[tostring(owner)]) and (shrine:GetAttribute("Lit") or 0) < Config.BLESS_GET_MAX then
					free = true
				end
			end
		end
	end
	return others, free
end

-- the celadon pot with three lit sticks, drawn from frames in the icon sheet's sticker language (ink
-- outline, one light): the sheet has no incense cell
local function incenseGlyph(parent, size)
	local box = frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size), ZIndex = 3 })
	local line = math.max(1.5, size * 0.05)
	local function piece(x, y, w, h, color, round, rot)
		local f = frame(box, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			Rotation = rot or 0,
			BackgroundTransparency = 0,
			BackgroundColor3 = color,
			ZIndex = 3,
		})
		Toy.corner(f, round)
		local st = Instance.new("UIStroke")
		st.Color = Toy.INK
		st.Thickness = line
		st.Parent = f
		return f
	end
	for k, rot in { -12, 0, 12 } do
		local x = 0.5 + (k - 2) * 0.17
		local stick = piece(x, 0.4, 0.07, 0.46, Color3.fromHex("C0392B"), UDim.new(0.5, 0), rot)
		stick.ZIndex = 3
		local tip = piece(x + math.sin(math.rad(rot)) * 0.23, 0.17 - (k == 2 and 0.03 or 0), 0.11, 0.11, EMBER, UDim.new(0.5, 0))
		tip.ZIndex = 4
	end
	local pot = piece(0.5, 0.75, 0.68, 0.34, Color3.fromHex("7CCFB0"), UDim.new(0.45, 0))
	pot.ZIndex = 5
	local rim = piece(0.5, 0.6, 0.8, 0.12, Color3.fromHex("A6E6CC"), UDim.new(0.5, 0))
	rim.ZIndex = 6
	return box
end

local root -- the button's column (a row of the right stack)
local ui = {}
local shown -- what the button was last drawn for

-- the row lives in the HUD's right stack (Player.HudSlots, D54); its own corner only if the HUD is missing
local function rightStack()
	local slots = player:FindFirstChild("HudSlots")
	local right = slots and slots:FindFirstChild("Right")
	return right and right.Value
end
local function placeRow()
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
		root.Position = UDim2.new(1, -px(16), 0, GuiService.TopbarInset.Max.Y + px(260))
		root.Parent = gui
	end
end

local note = 0 -- os.clock() until which the caption shows a refusal ("Nobody free")
local function go()
	local _, free = scan()
	if left() > 0 and free then
		local slots = player:FindFirstChild("HudSlots")
		local travel = slots and slots:FindFirstChild("Travel")
		if travel then
			travel:Fire("shrine") -- the HUD's jade wipe, then Remotes.Teleport
		end
	else
		note = os.clock() + 2
	end
end

local function build()
	if root then
		root:Destroy()
	end
	ui = {}
	root = frame(gui, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 4 })
	root.Name = "IncenseRow"
	Toy.list(root, false, px(2))
	local holder, btn = Toy.button(root, UDim2.fromOffset(px(40), px(40)), FACE, px(20))
	holder.LayoutOrder = 1
	btn.Name = "IncenseButton"
	incenseGlyph(btn, px(30))
	Toy.teleportTag(btn, px(13))
	-- the count: an ember pill on the top-right corner (where a red dot sits on the other buttons)
	local badge = frame(holder, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -px(3), 0, px(3)),
		Size = UDim2.fromOffset(px(19), px(19)),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		BackgroundColor3 = EMBER,
		ZIndex = 8,
	})
	Toy.corner(badge, UDim.new(1, 0))
	local bs = Instance.new("UIStroke")
	bs.Color = Toy.INK
	bs.Thickness = px(2)
	bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bs.Parent = badge
	local bp = Instance.new("UIPadding")
	bp.PaddingLeft = UDim.new(0, px(4))
	bp.PaddingRight = bp.PaddingLeft
	bp.Parent = badge
	ui.count = text(badge, "0", px(13), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 9 })
	ui.cap = text(root, "Bless", px(12), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	local pad = Instance.new("UIPadding") -- the caption steps down out from under the tag
	pad.PaddingTop = UDim.new(0, px(5))
	pad.Parent = ui.cap
	ui.btn = btn
	ui.badge = badge
	btn.Activated:Connect(go)
	placeRow()
end

local function update()
	local others, free = scan()
	if not others then
		if root then
			root:Destroy()
			root = nil
			shown = nil
		end
		return
	end
	if not root then
		build()
	end
	local n = left()
	local caption = "Bless"
	if n <= 0 then
		local s = 86400 - math.floor(workspace:GetServerTimeNow()) % 86400 -- to the UTC reset
		caption = string.format("%d:%02d", s // 3600, s // 60 % 60)
	elseif os.clock() < note then
		caption = "Nobody free"
	end
	local ready = n > 0 and free
	local key = n .. "|" .. caption .. "|" .. tostring(ready)
	if key == shown then
		return
	end
	shown = key
	ui.count.Text = tostring(n)
	ui.badge.BackgroundColor3 = n > 0 and EMBER or Color3.fromHex("6B5A72")
	ui.btn.BackgroundColor3 = ready and READY or FACE
	ui.cap.Text = caption
end

local function rescale()
	Toy.S = computeScale()
	if root then
		build()
		shown = nil
		update()
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
player:GetAttributeChangedSignal("HudDevice"):Connect(rescale)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
Toy.S = computeScale()

while true do
	update()
	task.wait(CHECK)
end
