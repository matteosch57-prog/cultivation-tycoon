-- Cultivation Tycoon HUD (mock C, docs/mocks/hud_C_*): no panels, chunky outlined numbers,
-- toy buttons. Icons come from the shared icon sheet (Toy.icon). The layout follows the
-- device: phone sizes from a 390px-tall reference, computer ~1.3x, and it steers around
-- Roblox's own topbar, thumbstick and jump button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sfx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sfx"))
local HttpService = game:GetService("HttpService")
local PerfMark = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PerfMark"))
local Toy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Toy"))

local INK = Color3.fromHex("1B1420")
local JADE = Color3.fromHex("59D39F")
local JADE_LIGHT = Color3.fromHex("C9FFE4")
local GOLD = Color3.fromHex("FFE36B")
local PINK = Color3.fromHex("FFB3A8")
local TIDE = Color3.fromHex("9FD0FF")
local TIDE_LIGHT = Color3.fromHex("CFE6FF")
local KARMA = Color3.fromHex("E2CCFF")
-- one face for every HUD button (owner pick B, mock docs/art/mocks/hud_menus_B.jpg): the icon carries
-- the colour; only the Shop is gold, and a button that wants a tap (gift / pill ready) lights gold
local FACE = Color3.fromHex("3A2C44")
local FACE_READY = Color3.fromHex("FFD36B")
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

---------------------------------------------------------------------------------------------
-- number formatting
local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
local function short(n)
	n = math.floor(n or 0)
	if n < 1e6 then
		return commas(n)
	end
	local units = { "M", "B", "T", "Qa", "Qi" }
	local v, i = n / 1e6, 1
	while v >= 1000 and i < #units do
		v /= 1000
		i += 1
	end
	local digits = v < 10 and 2 or (v < 100 and 1 or 0)
	local f = 10 ^ digits
	return string.format("%." .. digits .. "f%s", math.floor(v * f) / f, units[i])
end
local function compact(n) -- for small price tags: 3.5K
	n = math.floor(n or 0)
	if n < 1000 then
		return tostring(n)
	end
	local units = { "K", "M", "B", "T", "Qa" }
	local v, i = n / 1000, 1
	while v >= 1000 and i < #units do
		v /= 1000
		i += 1
	end
	local digits = v < 10 and 1 or 0
	local f = 10 ^ digits
	return string.format("%." .. digits .. "f%s", math.floor(v * f) / f, units[i])
end
-- an amount piece for a toast: its currency icon, then the number (R18)
local function amt(currency, n, sign)
	return { icon = currency, text = (sign or "") .. compact(n) }
end

---------------------------------------------------------------------------------------------
-- device + scale
local S = 1
-- player attribute HudDevice = "pc" / "phone" forces a layout (testing from an emulator)
local function jumpButton()
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	if jump and jump.Visible and jump.AbsoluteSize.X > 0 then
		return jump
	end
	return nil
end
local touchSeen = false
local function isPhone()
	local forced = player:GetAttribute("HudDevice")
	if forced then
		return forced == "phone"
	end
	-- Roblox's own touch controls on screen are the truth (emulators and touch laptops also
	-- report a keyboard, so TouchEnabled/KeyboardEnabled alone guess wrong)
	-- once seen, a touch screen stays a phone layout: an iPad with a keyboard hides the jump
	-- button whenever a key is pressed, and each flip rebuilt the HUD and lost its toasts (audit)
	if jumpButton() then
		touchSeen = true
		return true
	end
	if touchSeen and UserInputService.TouchEnabled then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end
local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	if isPhone() then
		return math.clamp(vp.Y / 390, 0.78, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7) -- 720p -> 1.3, 1080p -> 1.7
end
local function px(v)
	return math.floor(v * S + 0.5)
end

---------------------------------------------------------------------------------------------
-- primitives
local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	for k, v in props or {} do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r
	c.Parent = parent
	return c
end

-- outlined chunky text
local function text(parent, str, size, color, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.Text = str
	t.TextSize = size
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.AutomaticSize = Enum.AutomaticSize.XY
	t.Size = UDim2.new()
	for k, v in props or {} do
		t[k] = v
	end
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = math.max(1.5, size * 0.11)
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.Parent = t
	t.Parent = parent
	return t
end

-- Icons come from the shared icon sheet (Toy.icon, Config.ICON_ATLAS)
local function qiIcon(parent, size, props)
	return Toy.icon(parent, "qi", size, props)
end

local function discipleIcon(parent, size, props)
	return Toy.icon(parent, "disciple", size, props)
end

-- the Spirit Tide: a blue wave crest
local function tideIcon(parent, size, props)
	return Toy.icon(parent, "tide", size, props)
end

-- a little hall (buildings owned, on the realm bar)
local function hallIcon(parent, size, props)
	return Toy.icon(parent, "hall", size, props)
end

-- returns (slot, spinner): the slot sits in the layout, the spinner inside it is what rotates
local function arrowIcon(parent, size, props)
	local slot = frame(parent, { Size = UDim2.fromOffset(size, size) })
	for k, v in props or {} do
		slot[k] = v
	end
	return slot, Toy.icon(slot, "goal", size)
end

-- the gap between the buttons of a rail (owner 2026-10-22: "put a bit of space between the items,
-- they're super close"; was 6 left, 8 right)
local RAIL_GAP = 14

-- toy button: solid shadow + outlined face + its light (Toy.shine: glass cap, dome on a circle). Returns (holder, button).
local function toy(parent, size, color, radius)
	local holder = frame(parent, { Size = size })
	local shadow = frame(holder, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(4)), BackgroundTransparency = 0, BackgroundColor3 = INK })
	corner(shadow, UDim.new(0, radius))
	local btn = Instance.new("TextButton")
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.Parent = holder
	corner(btn, UDim.new(0, radius))
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = px(3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = btn
	Toy.shine(btn, size, radius)
	Toy.feel(btn, { scale = holder, squash = { btn, shadow } }) -- sound, buzz and jelly (shared with every screen)
	return holder, btn
end

---------------------------------------------------------------------------------------------
-- state
local refreshStatic -- forward: the recruit selector (built earlier) redraws the seal through it
local state = {
	shownQi = player:GetAttribute("Qi") or 0,
	lastQi = player:GetAttribute("Qi") or 0,
	discOpen = false,
}
local ui = {} -- rebuilt on viewport change

-- the red dots the server lit (attribute Dots, server Dots.luau): { disc = { [name] = n }, karma = {..},
-- shop = key, group = true, reinc = true }
local function litDots()
	local ok, t = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Dots") or "{}")
	return ok and type(t) == "table" and t or {}
end

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function myPads()
	local list = {}
	local sect = workspace:FindFirstChild("Sect")
	if not sect then
		return list
	end
	for _, peak in sect:GetChildren() do
		local built = peak:FindFirstChild("Built")
		if built then
			for _, p in built:GetChildren() do
				if p.Name:sub(1, 4) == "Pad_" and p:GetAttribute("OwnerId") == player.UserId then
					table.insert(list, p)
				end
			end
		end
	end
	return list
end

---------------------------------------------------------------------------------------------
-- build
local toastLayer
local rebuildAll -- forward
local popGain -- forward
local toast -- forward (it used to live on `ui`, which build() replaces: the recruit button
-- then called a nil toast, errored, and stayed locked after the first recruit)
local goalPad -- the pad the "Next" card names (set per frame; Heavenly Hands builds it)

-- the Base / Ranks chips: a jade wipe closes over the screen, the server moves the avatar under it
-- (Remotes.Teleport, the server picks the spot), then the wipe opens (mock 2026-10-22_teleport_and_buy)
local travelAt = -math.huge
local travelling = false
local function teleportTo(where)
	if travelling then
		return
	end
	travelling = true
	-- a tap inside the cooldown goes once it ends instead of being dropped (owner 2026-10-24: "arena
	-- tp doesnt work sometimes")
	local left = Config.TELEPORT_COOLDOWN - (os.clock() - travelAt)
	if left > 0 then
		task.wait(left)
	end
	travelAt = os.clock()
	-- ask now, from where you stand: the server checks you are on the portal, then waits TELEPORT_VEIL
	-- (the wipe's close) before the move and bumps Travelled once it is done
	local done = player:GetAttribute("Travelled") or 0
	remotes.Teleport:FireServer(where)
	local wipeGui = Instance.new("ScreenGui")
	wipeGui.Name = "TravelWipe"
	wipeGui.IgnoreGuiInset = true
	wipeGui.DisplayOrder = 50
	wipeGui.ResetOnSpawn = false
	wipeGui.Parent = playerGui
	local vp = workspace.CurrentCamera.ViewportSize
	local d = math.sqrt(vp.X * vp.X + vp.Y * vp.Y) * 1.1
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromOffset(0, 0)
	disc.BackgroundColor3 = Color3.new(1, 1, 1)
	disc.BorderSizePixel = 0
	disc.Parent = wipeGui
	corner(disc, UDim.new(1, 0))
	local g = Instance.new("UIGradient") -- pale jade at the heart, deep jade at the rim
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("EAFFF6")),
		ColorSequenceKeypoint.new(0.45, Color3.fromHex("8FF3CF")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("23B98A")),
	})
	g.Rotation = 90
	g.Parent = disc
	Sfx.play("rise")
	local close = TweenService:Create(disc, TweenInfo.new(Config.TELEPORT_VEIL, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(d, d) })
	close:Play()
	close.Completed:Wait()
	local t = os.clock()
	while (player:GetAttribute("Travelled") or 0) == done and os.clock() - t < 1.5 do
		task.wait()
	end
	local moved = (player:GetAttribute("Travelled") or 0) ~= done
	task.wait(0.15) -- the move replicates and the camera settles behind the veil
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if moved and where ~= "home" and root then
		-- turn the camera the way the server faced you: level with the ranking wall (owner: boards
		-- hard to read), into the island, onto the altar or toward the plaza after a portal
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.5 then
			look = look.Unit
			local cam = workspace.CurrentCamera
			cam.CFrame = CFrame.lookAt(root.Position - look * 12 + Vector3.new(0, 2.2, 0), root.Position + Vector3.new(0, 3.4, 0))
		end
	end
	local open = TweenService:Create(disc, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	open:Play()
	travelling = false
	open.Completed:Wait()
	wipeGui:Destroy()
end

-- the Rankings screen's "Go to the wall" (Ranks.client) travels with the same wipe
local travelEvent = Instance.new("BindableEvent")
travelEvent.Name = "TravelTo"
travelEvent.Parent = player -- not PlayerGui: the first LoadCharacter empties it
travelEvent.Event:Connect(function(where)
	if where == "ranks" or where == "home" then
		teleportTo(where)
	end
end)

-- Portals (server Portals.luau): stepping onto one travels to its `Where`; you step off and on again
-- to go back, so landing beside a portal never bounces you
task.spawn(function()
	local CollectionService = game:GetService("CollectionService")
	local onPortal
	while true do
		task.wait(0.15)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local here
		if root then
			for _, pad in CollectionService:GetTagged("Portal") do
				local d = root.Position - pad.Position
				if Vector3.new(d.X, 0, d.Z).Magnitude < 2.8 and d.Y > -1 and d.Y < 5 then
					here = pad
					break
				end
			end
		end
		if here ~= onPortal then
			if here and not here:GetAttribute("Off") then
				if travelling or os.clock() - travelAt < Config.TELEPORT_COOLDOWN then
					continue -- still cooling down: asks again next tick while you stand on it
				end
				task.spawn(teleportTo, here:GetAttribute("Where"))
			end
			onPortal = here
		end
	end
end)

local function build()
	-- rows other scripts put in the right stack (HudSlots) step out before the clear, or it would
	-- destroy them; they re-parent on Rebuilt
	for _, rail in { ui.left, ui.right } do
		for _, c in rail:GetChildren() do
			if not c:GetAttribute("HudOwn") and not c:IsA("UIListLayout") then
				c.Parent = nil
			end
		end
	end
	gui:ClearAllChildren()
	ui = {}
	state.phoneMode = isPhone()
	S = computeScale()
	local root = frame(gui, { Size = UDim2.fromScale(1, 1) })
	ui.root = root

	-- top centre: the qi counter between the two teleport chips (owner pick A, mock
	-- docs/art/mocks/2026-10-22_teleport_and_buy.html): Base on its left, Ranks on its right
	local top = frame(root, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, px(8)), AutomaticSize = Enum.AutomaticSize.XY })
	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	topLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topLayout.Padding = UDim.new(0, px(RAIL_GAP))
	topLayout.Parent = top
	ui.top = top
	local counter = frame(top, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, px(6))
	row.Parent = counter
	qiIcon(counter, px(46), { LayoutOrder = 1 })
	local col = frame(counter, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	local colLayout = Instance.new("UIListLayout")
	colLayout.Padding = UDim.new(0, px(1))
	colLayout.Parent = col
	ui.qi = text(col, short(state.shownQi), px(38), Color3.new(1, 1, 1), { LayoutOrder = 1 })
	ui.rate = text(col, "+0/s", px(16), Color3.fromHex("9FF5C8"), { LayoutOrder = 2 })
	-- Spirit Tide line (mock tycoon_ideas idea 3 A): countdown, then the 2x timer
	local tideRow = frame(col, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3, Visible = false })
	local trl = Instance.new("UIListLayout")
	trl.FillDirection = Enum.FillDirection.Horizontal
	trl.VerticalAlignment = Enum.VerticalAlignment.Center
	trl.Padding = UDim.new(0, px(3))
	trl.Parent = tideRow
	tideIcon(tideRow, px(15), { LayoutOrder = 1 })
	ui.tide = text(tideRow, "", px(12), TIDE_LIGHT, { LayoutOrder = 2 })
	ui.tideRow = tideRow
	ui.counter = counter
	counter.Name = "Counter" -- Juice flies qi drops into it
	-- karma beside the qi (every currency shows with its icon), once the player has any or a past life
	local kRow = frame(counter, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3, Visible = false })
	local krl = Instance.new("UIListLayout")
	krl.FillDirection = Enum.FillDirection.Horizontal
	krl.VerticalAlignment = Enum.VerticalAlignment.Center
	krl.Padding = UDim.new(0, px(3))
	krl.Parent = kRow
	local kPad = Instance.new("UIPadding")
	kPad.PaddingLeft = UDim.new(0, px(8))
	kPad.PaddingBottom = UDim.new(0, px(20)) -- level with the qi number, not its rate line
	kPad.Parent = kRow
	Toy.icon(kRow, "karma", px(26), { LayoutOrder = 1 })
	ui.karma = text(kRow, "0", px(22), KARMA, { LayoutOrder = 2 })
	ui.karmaRow = kRow

	-- Owner pick B (2026-10-22, mock docs/art/mocks/hud_menus_B.jpg): the left column holds what you
	-- OPEN (Shop, Disciples, Karma); the right stack under the next goal holds what TICKS (gift, pill,
	-- and other scripts' rows through Player.HudSlots). layout() fits the left column between
	-- Roblox's top bar and the thumbstick (a column too tall for that band wraps into a second one).
	local left = frame(root, { Position = UDim2.fromOffset(px(12), px(60)), Size = UDim2.fromOffset(0, px(300)), AutomaticSize = Enum.AutomaticSize.X })
	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, px(RAIL_GAP))
	leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	leftLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	leftLayout.Wraps = true
	leftLayout.Parent = left
	-- one button with its caption under it (a count, a timer: no words where a number says it)
	local function sideButton(parent, order, size, face, round)
		local col = frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order })
		col:SetAttribute("HudOwn", true) -- the HUD's own row (others' rows step out on a rebuild)
		local l = Instance.new("UIListLayout")
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Padding = UDim.new(0, px(2))
		l.Parent = col
		local holder, btn = toy(col, UDim2.fromOffset(px(size), px(size)), face, round and px(size / 2) or px(size * 0.26))
		holder.LayoutOrder = 1
		return col, btn
	end
	-- Shop (mock shop B, D24): always shown, on top, the one gold button; opens Shop.client's screen
	local _, sBtn = sideButton(left, 0, 42, Color3.fromHex("FFD36B"))
	Toy.icon(sBtn, "shop", px(31), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	sBtn.Name = "ShopButton"
	ui.shopDot = Toy.dot(sBtn, px(17), { Visible = false })
	sBtn.Activated:Connect(function()
		local ev = player:FindFirstChild("ShopOpen")
		if ev then
			ev:Fire("hud")
		end
	end)
	-- Disciples: the label is the count (less text, mock less_text A)
	local dCol, dBtn = sideButton(left, 1, 42, FACE)
	discipleIcon(dBtn, px(31), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	dBtn.Name = "DisciplesButton"
	ui.discDot = Toy.dot(dBtn, px(17), { Visible = false })
	ui.dLabel = text(dCol, "0", px(12), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	ui.dCol = dCol
	-- Karma: straight to the Karma Shop page of the reincarnation screen (owner: no direct way in before)
	local kCol, kBtn = sideButton(left, 2, 42, FACE)
	Toy.icon(kBtn, "karma", px(31), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	kBtn.Name = "KarmaButton"
	ui.karmaDot = Toy.dot(kBtn, px(17), { Visible = false })
	kBtn.Activated:Connect(function()
		local ev = player:FindFirstChild("ReincOpen")
		if ev then
			ev:Fire("karma")
		end
	end)
	ui.kCol = kCol

	-- the teleport chips beside the counter: the server picks the spot (Remotes.Teleport)
	local function travelChip(order, key, caption, face, where)
		local c, b = sideButton(top, order, 40, face, true)
		Toy.icon(b, key, px(30), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		b.Name = caption .. "Button"
		text(c, caption, px(12), Color3.new(1, 1, 1), { LayoutOrder = 2 })
		b.Activated:Connect(function()
			local screen = where == "ranks" and player:FindFirstChild("RanksOpen")
			if screen then
				screen:Fire()
			else
				teleportTo(where)
			end
		end)
		return c
	end
	travelChip(1, "hall", "Base", Color3.fromHex("6FE0B4"), "home")
	-- Ranks opens the Rankings screen (Ranks.client, owner pick C 2026-10-23); its "Go to the wall"
	-- comes back to teleportTo through TravelTo
	travelChip(3, "trophy", "Ranks", Color3.fromHex("FFD36B"), "ranks")

	-- right stack: under the next goal, right-aligned (layout() places it, or lays it in a row when
	-- the space down to the Recruit seal is short)
	local right = frame(root, { AnchorPoint = Vector2.new(1, 0), AutomaticSize = Enum.AutomaticSize.XY })
	right.Name = "RightStack"
	local rightLayout = Instance.new("UIListLayout")
	rightLayout.Padding = UDim.new(0, px(RAIL_GAP))
	rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rightLayout.Parent = right
	ui.right = right
	ui.rightLayout = rightLayout
	-- Playtime gift (daily ladder D49, owner 2026-10-22: "always show the next reward", then "way more
	-- explicit with the reward, attractive, click it opens a juicy page with all timed rewards"): the
	-- next prize sits on the button's corner and under it in its own words and colour, then the
	-- countdown; ready = gold + red dot; all claimed today = the time to the reset. A tap opens the
	-- Free Gifts page (Gifts.client, mock timed_gift C), where the claim happens.
	local gCol, gBtn = sideButton(right, 1, 40, FACE, true)
	gBtn.Name = "GiftButton"
	Toy.icon(gBtn, "gift", px(28), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local gDot = Toy.dot(gBtn, px(16), { Visible = false })
	ui.giftBadge = frame(gBtn, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.9, 0.9), Size = UDim2.fromOffset(px(22), px(22)), ZIndex = 4 })
	ui.giftPrize = text(gCol, "", px(12), JADE_LIGHT, { LayoutOrder = 2 })
	ui.giftLabel = text(gCol, "", px(12), Color3.new(1, 1, 1), { LayoutOrder = 3 })
	ui.gCol = gCol
	ui.giftBtn = gBtn
	ui.giftDot = gDot
	gBtn.Activated:Connect(function()
		local ev = player:FindFirstChild("GiftsOpen")
		if ev then
			ev:Fire()
		end
	end)
	-- Pill (Alchemy Furnace): brewing countdown -> ready (gold, wobbles) -> active 2x timer
	local pCol, pBtn = sideButton(right, 2, 40, FACE, true)
	Toy.icon(pBtn, "pill", px(28), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	ui.pillLabel = text(pCol, "Pill", px(12), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	ui.pCol = pCol
	ui.pillBtn = pBtn
	ui.pillDot = Toy.dot(pBtn, px(16), { Visible = false })
	pBtn.Name = "PillButton" -- the first-pill tip points at it (Tips.client)
	pBtn.Activated:Connect(function()
		if player:GetAttribute("PillReady") then
			local ok, used = pcall(function()
				return remotes.UsePill:InvokeServer()
			end)
			if ok and used then
				toast("2x Qi!", GOLD, 2)
			end
		else
			local s = player:GetAttribute("PillIn") or 0
			toast(string.format("Brewing %d:%02d", s // 60, s % 60), PINK, 1.6)
		end
	end)
	ui.left = left
	ui.dBtn = dBtn

	-- disciples card (opens beside the button)
	-- (no panel, R4: disciples in their rarity colours, 4 to a row, their bonus under each)
	-- `card` = the box (placed and shown by layout(), holds the close X); ui.card = the list in it
	-- (refreshStatic redraws the list's children)
	local card = frame(root, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, px(80), 0.45, 0), Size = UDim2.fromOffset(px(4 * 52), 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = state.discOpen })
	local list = frame(card, { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y })
	local cLayout = Instance.new("UIListLayout")
	cLayout.FillDirection = Enum.FillDirection.Horizontal
	cLayout.Wraps = true
	cLayout.Padding = UDim.new(0, px(4))
	cLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cLayout.Parent = list
	ui.card = list
	ui.cardBox = card
	local function toggleDisciples()
		state.discOpen = not state.discOpen
		card.Visible = state.discOpen
		-- the new ones keep their dot while the list stays open (a snapshot: the server clears its own
		-- now, on MenuOpened)
		state.discNew = state.discOpen and (litDots().disc or {}) or nil
		refreshStatic()
		if state.discOpen then
			remotes.MenuOpened:FireServer("disciples") -- analytics Menu (DATA.md); marks the dot seen
		end
	end
	-- the disciples button opens the Disciples book on My Sect (owner 2026-10-23: "not the small pop
	-- up anymore"); the small card stays only as the fallback while the book is not loaded
	dBtn.Activated:Connect(function()
		local book = player:FindFirstChild("OpenRoster")
		if not book then
			toggleDisciples()
			return
		end
		if state.discOpen then
			toggleDisciples() -- shut the old card if it was open
		end
		remotes.MenuOpened:FireServer("disciples") -- analytics Menu (DATA.md); marks the dot seen
		book:Fire("sect")
	end)
	-- a small X on the box's top-right corner closes it too (owner 2026-10-22)
	local xHolder, xBtn = toy(card, UDim2.fromOffset(px(24), px(24)), Color3.fromHex("FF7A6B"), px(7))
	xHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	xHolder.Position = UDim2.new(1, px(18), 0, px(6)) -- outside the box: on its corner it covered the 4th face
	xHolder.ZIndex = 4
	text(xBtn, "X", px(14), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4 })
	xBtn.Activated:Connect(toggleDisciples)

	-- realm progress: bottom centre (mock A docs/art/mocks/hud_bar_A.jpg, owner pick 2026-10-22: "A
	-- better, but slightly smaller or pushed down"). Top to bottom: the next step (built further down,
	-- LayoutOrder 1), the realm name over the bar, the Rebirth seal locked on the bar's right end.
	local prog = frame(root, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -px(10)), AutomaticSize = Enum.AutomaticSize.XY })
	local pLayout = Instance.new("UIListLayout")
	pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pLayout.Padding = UDim.new(0, px(4))
	pLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pLayout.Parent = prog
	local BAR_W, BAR_H, ORB = px(230), px(22), px(46)
	local LABEL_H = px(17)
	-- the bar's area: the realm name, then the bar; the seal hangs over the bar's right end and rises
	-- above it (its bottom sits a little under the bar's, its label on its lower rim)
	local barArea = frame(prog, { Size = UDim2.fromOffset(BAR_W + math.floor(ORB * 0.7), LABEL_H + BAR_H), LayoutOrder = 2 })
	ui.realm = text(barArea, "", px(13), Color3.fromHex("FFE9A8"), { Position = UDim2.fromOffset(px(12), 0) })
	local barHolder = frame(barArea, { Size = UDim2.fromOffset(BAR_W, BAR_H), Position = UDim2.fromOffset(0, LABEL_H) })
	local barShadow = frame(barHolder, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(3)), BackgroundTransparency = 0, BackgroundColor3 = INK })
	corner(barShadow, UDim.new(1, 0))
	local track = frame(barHolder, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("3A2D40"), ClipsDescendants = true })
	corner(track, UDim.new(1, 0))
	local tst = Instance.new("UIStroke")
	tst.Color = INK
	tst.Thickness = px(3)
	tst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tst.Parent = track
	ui.fill = frame(track, { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = JADE })
	corner(ui.fill, UDim.new(1, 0))
	local progRow = frame(track, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 3 })
	local prl2 = Instance.new("UIListLayout")
	prl2.FillDirection = Enum.FillDirection.Horizontal
	prl2.VerticalAlignment = Enum.VerticalAlignment.Center
	prl2.Padding = UDim.new(0, px(4))
	prl2.Parent = progRow
	ui.progIcon = hallIcon(progRow, px(15), { LayoutOrder = 1 })
	ui.progText = text(progRow, "", px(13), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	-- the Rebirth seal (road to reincarnation, opens Reincarnation.client): a round toy button with the
	-- karma orb and the round buttons' dome light (Toy.shine)
	local orbHolder = frame(barArea, { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(ORB, ORB), Position = UDim2.fromOffset(BAR_W + math.floor(ORB * 0.2), LABEL_H + BAR_H + px(4)), ZIndex = 4 })
	local orbShadow = frame(orbHolder, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(4)), BackgroundTransparency = 0, BackgroundColor3 = INK, ZIndex = 4 })
	corner(orbShadow, UDim.new(0.5, 0))
	local chipBtn = Instance.new("TextButton")
	chipBtn.Name = "RebirthSeal"
	chipBtn.Text = ""
	chipBtn.AutoButtonColor = false
	chipBtn.Size = UDim2.fromScale(1, 1)
	chipBtn.BackgroundColor3 = Color3.fromHex("B06BFF")
	chipBtn.BorderSizePixel = 0
	chipBtn.ZIndex = 4
	chipBtn.Parent = orbHolder
	corner(chipBtn, UDim.new(0.5, 0))
	local ost2 = Instance.new("UIStroke")
	ost2.Color = INK
	ost2.Thickness = px(3)
	ost2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ost2.Parent = chipBtn
	Toy.shine(chipBtn, UDim2.fromOffset(ORB, ORB), ORB / 2)
	Toy.icon(chipBtn, "karma", math.floor(ORB * 0.6), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), ZIndex = 5 })
	ui.rebirth = text(orbHolder, "", px(12), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.95), ZIndex = 6 })
	ui.rebirthBtn = chipBtn
	ui.reincDot = Toy.dot(chipBtn, px(15), { Visible = false })
	Toy.feel(chipBtn, { scale = orbHolder, squash = { chipBtn, orbShadow } })
	chipBtn.Activated:Connect(function()
		local ev = player:FindFirstChild("ReincOpen")
		if ev then
			ev:Fire()
		end
	end)
	ui.prog = prog

	-- recruit: the formation seal (mock docs/art/mocks/recruit_button_c.gif, owner pick 2026-10-22: "C,
	-- but needs to look as good as your mock"), bottom right, placed by layout(). A round button with
	-- a qi orb charging through the rarity colours inside a turning ring, rays and a glow behind; the
	-- soft pieces are the uploaded aura atlas (Toy.atlasPiece), moved in the frame loop. Still and dim
	-- when a recruit is out of reach.
	local SEAL = px(84) -- (owner pick A, phone calm pass: was 104)
	local rHolder = frame(root, { AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(SEAL, SEAL + px(44)) })
	local seal = frame(rHolder, { Size = UDim2.fromOffset(SEAL, SEAL) })
	local sealScale = Instance.new("UIScale")
	sealScale.Parent = seal
	local rays = Toy.atlasPiece(seal, "rays12", SEAL * 2.1, SEAL * 2.1, Color3.new(1, 1, 1), 0.4)
	local glow = Toy.atlasPiece(seal, "glow", SEAL * 2, SEAL * 2, JADE, 0)
	local shadow = frame(seal, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(4)), BackgroundTransparency = 0, BackgroundColor3 = INK })
	corner(shadow, UDim.new(0.5, 0))
	local rBtn = Instance.new("TextButton")
	rBtn.Name = "RecruitSeal" -- the recruit reveal's orb starts here
	rBtn.Text = ""
	rBtn.AutoButtonColor = false
	rBtn.Size = UDim2.fromScale(1, 1)
	rBtn.BackgroundColor3 = Color3.fromHex("A070F0")
	rBtn.BorderSizePixel = 0
	rBtn.Parent = seal
	corner(rBtn, UDim.new(0.5, 0))
	local rst = Instance.new("UIStroke")
	rst.Color = INK
	rst.Thickness = px(3)
	rst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rst.Parent = rBtn
	-- the face's soft light (a radial lift from the glow piece). No glass cap on this round seal
	-- (owner 2026-10-22: the cap "looks weird on round shape"); the square toy buttons keep theirs.
	Toy.atlasPiece(rBtn, "glow", SEAL * 0.95, SEAL * 0.95, Color3.fromHex("D9B8FF"), 0.35, { Position = UDim2.fromScale(0.5, 0.42) })
	local ring = Toy.atlasPiece(rBtn, "ring", SEAL - px(12), SEAL - px(12), Color3.new(1, 1, 1), 0.1)
	-- the orb: a glow, the ball, its highlight, four motes circling
	local ORB = px(44)
	local orbGlow = Toy.atlasPiece(rBtn, "glow", ORB * 1.9, ORB * 1.9, JADE, 0.1)
	local orb = frame(rBtn, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(ORB, ORB), BackgroundTransparency = 0, BackgroundColor3 = JADE })
	corner(orb, UDim.new(0.5, 0))
	local ost = Instance.new("UIStroke")
	ost.Color = INK
	ost.Thickness = px(3)
	ost.Parent = orb
	-- the ball's shading: light from the top left into its colour (the mock's radial sphere)
	orb.BackgroundColor3 = Color3.new(1, 1, 1)
	local orbShade = Instance.new("UIGradient")
	orbShade.Rotation = 50
	orbShade.Parent = orb
	Toy.atlasPiece(orb, "mote", ORB * 0.9, ORB * 0.9, Color3.new(1, 1, 1), 0.55, { Position = UDim2.fromScale(0.42, 0.38) })
	local hi = frame(orb, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.35, 0.3), Size = UDim2.fromScale(0.26, 0.26), BackgroundTransparency = 0.05, BackgroundColor3 = Color3.new(1, 1, 1) })
	corner(hi, UDim.new(0.5, 0))
	local motes = {}
	for i = 1, 4 do
		motes[i] = Toy.atlasPiece(rBtn, "mote", px(10), px(10), Color3.new(1, 1, 1), 0)
	end
	-- "Recruit" and its price under the seal
	local rText = frame(rHolder, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, SEAL + px(2)), AutomaticSize = Enum.AutomaticSize.XY })
	local rtl = Instance.new("UIListLayout")
	rtl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rtl.Padding = UDim.new(0, px(1))
	rtl.SortOrder = Enum.SortOrder.LayoutOrder
	rtl.Parent = rText
	ui.recruitLabel = text(rText, "Recruit", px(20), Color3.new(1, 1, 1), { LayoutOrder = 1 })
	local priceRow = frame(rText, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	local prl = Instance.new("UIListLayout")
	prl.FillDirection = Enum.FillDirection.Horizontal
	prl.VerticalAlignment = Enum.VerticalAlignment.Center
	prl.Padding = UDim.new(0, px(3))
	prl.Parent = priceRow
	qiIcon(priceRow, px(16), { LayoutOrder = 1 })
	ui.recruitCost = text(priceRow, "", px(14), JADE_LIGHT, { LayoutOrder = 2 })
	ui.recruit = rHolder
	ui.recruitBtn = rBtn
	-- how many one press recruits (owner: an x1 / x10 / x50 selector shows above the seal on a press
	-- or a hover, even without the qi; the pick sticks to the seal). Each chip shows its batch price
	-- and greys out while it is out of reach (the frame loop paints them).
	local pick = frame(rHolder, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 0, -px(8)), AutomaticSize = Enum.AutomaticSize.XY, Visible = false }) -- right-aligned: the seal sits at the screen's edge
	local pl = Instance.new("UIListLayout")
	pl.FillDirection = Enum.FillDirection.Horizontal
	pl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	pl.Padding = UDim.new(0, px(6))
	pl.SortOrder = Enum.SortOrder.LayoutOrder
	pl.Parent = pick
	ui.recruitPick = pick
	ui.recruitChips = {}
	-- hidden RECRUIT_PICK_SECONDS after the last press, pick or hover (never while hovered)
	local function hidePickLater()
		state.pickToken = (state.pickToken or 0) + 1
		local my = state.pickToken
		task.delay(Config.RECRUIT_PICK_SECONDS, function()
			if state.pickToken == my and not state.pickHover then
				pick.Visible = false
			end
		end)
	end
	local function showPick()
		pick.Visible = true
		hidePickLater()
	end
	local function hover(gui)
		gui.MouseEnter:Connect(function()
			state.pickHover = true
			showPick()
		end)
		gui.MouseLeave:Connect(function()
			state.pickHover = false
			hidePickLater()
		end)
	end
	ui.showRecruitPick = showPick
	for i, n in Config.RECRUIT_COUNTS do
		local col = frame(pick, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = i })
		local cl = Instance.new("UIListLayout")
		cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		cl.Padding = UDim.new(0, px(1))
		cl.Parent = col
		local holder, b = toy(col, UDim2.fromOffset(px(48), px(36)), Color3.fromHex("3A2C44"), px(18))
		holder.LayoutOrder = 1
		local label = text(b, "x" .. n, px(17), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		local cRow = frame(col, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
		local crl = Instance.new("UIListLayout")
		crl.FillDirection = Enum.FillDirection.Horizontal
		crl.VerticalAlignment = Enum.VerticalAlignment.Center
		crl.Padding = UDim.new(0, px(2))
		crl.Parent = cRow
		qiIcon(cRow, px(12), { LayoutOrder = 1 })
		local price = text(cRow, "", px(12), JADE_LIGHT, { LayoutOrder = 2 })
		ui.recruitChips[n] = { btn = b, label = label, price = price }
		hover(b)
		b.Activated:Connect(function()
			state.recruitN = n
			refreshStatic()
			hidePickLater()
		end)
	end
	-- the odds (R8, Roblox's paid random item rule) and the pity bars: a "%" chip at the end of the
	-- picker opens them (RecruitOdds.client, later the Disciples book's Odds tab, via Player.OpenOdds)
	do
		local col = frame(pick, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = #Config.RECRUIT_COUNTS + 1 })
		local cl = Instance.new("UIListLayout")
		cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		cl.Parent = col
		local holder, b = toy(col, UDim2.fromOffset(px(36), px(36)), GOLD, px(18))
		holder.LayoutOrder = 1
		text(b, "%", px(18), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		hover(b)
		b.Activated:Connect(function()
			local ev = player:FindFirstChild("OpenOdds")
			if ev then
				ev:Fire()
			end
			hidePickLater()
		end)
	end
	hover(rBtn)
	ui.seal = { scale = sealScale, rays = rays, glow = glow, ring = ring, orbGlow = orbGlow, orb = orb, shade = orbShade, motes = motes, orbSize = ORB }
	-- press feel, like the toy buttons
	Toy.feel(rBtn, { squash = { rBtn, shadow }, hover = false })

	-- next goal: bottom centre, over the realm bar (owner 2026-10-22: "the arrow on next step in middle
	-- bottom"); one line: the turning arrow, the pad's name, its qi price
	local goal = frame(ui.prog, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	local gl = Instance.new("UIListLayout")
	gl.FillDirection = Enum.FillDirection.Horizontal
	gl.VerticalAlignment = Enum.VerticalAlignment.Center
	gl.Padding = UDim.new(0, px(6))
	gl.Parent = goal
	local _, spinner = arrowIcon(goal, px(26), { LayoutOrder = 1 })
	ui.arrow = spinner
	ui.goalName = text(goal, "", px(15), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	-- the price shows its qi drop (R18)
	local gcRow = frame(goal, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	local gcl = Instance.new("UIListLayout")
	gcl.FillDirection = Enum.FillDirection.Horizontal
	gcl.VerticalAlignment = Enum.VerticalAlignment.Center
	gcl.Padding = UDim.new(0, px(3))
	gcl.Parent = gcRow
	qiIcon(gcRow, px(14), { LayoutOrder = 1 })
	ui.goalCost = text(gcRow, "", px(14), PINK, { LayoutOrder = 2 })
	ui.goal = goal
	-- Heavenly Hands (Karma Shop): a gold hand that builds the Next pad from anywhere (mock A)
	local hHolder, hBtn = toy(goal, UDim2.fromOffset(px(40), px(34)), Color3.fromHex("FFD34D"), px(10))
	hHolder.LayoutOrder = 4
	hHolder.Visible = false
	Toy.icon(hBtn, "hands", px(26), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	hBtn.Activated:Connect(function()
		local id = goalPad and goalPad.Parent and goalPad:GetAttribute("PadId")
		local ok, done = pcall(function()
			return remotes.HandsBuild:InvokeServer(id)
		end)
		if not (ok and done) then
			Sfx.play("deny")
		end
	end)
	ui.hands = hHolder

	toastLayer = frame(root, { Size = UDim2.fromScale(1, 1), ZIndex = 20 })
	-- every list follows LayoutOrder (the default sorts by Name, which put the price above "Recruit")
	for _, d in root:GetDescendants() do
		if d:IsA("UIListLayout") then
			d.SortOrder = Enum.SortOrder.LayoutOrder
		end
	end

	rBtn.Activated:Connect(function()
		if state.recruiting then
			return
		end
		state.recruiting = true
		local free = (player:GetAttribute("FreeRecruits") or 0) > 0
		if not free then -- the tutorial's free recruit is one, with no choice to make
			ui.showRecruitPick() -- the first press shows the x1 / x10 / x50 choice, qi or not
		end
		local ok, res = pcall(function()
			return remotes.Recruit:InvokeServer(state.recruitN or 1)
		end)
		state.recruiting = false -- always release, whatever happens below
		if ok and res and res.ok then
			-- the orb reveal on screen (RecruitReveal) and the light column on the platform (Juice);
			-- the reveal names the disciple, so no toast
			local fxEvent = player:FindFirstChild("RecruitFx")
			if fxEvent then
				fxEvent:Fire(res.rarity, res.kept, res.results) -- x10 / x50: every orb opens, then the best
			end
		elseif ok and res then
			toast(res.reason, PINK, 1.5)
		end
	end)
end

---------------------------------------------------------------------------------------------
-- toasts and the little "+N" that pops off the counter

-- one line of pieces (strings, or amt() pieces) laid out left to right
local function line(parent, pieces, size, color, props)
	local row = frame(parent, { AutomaticSize = Enum.AutomaticSize.XY })
	for k, v in props or {} do
		row[k] = v
	end
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, math.floor(size * 0.18))
	l.Parent = row
	for i, p in type(pieces) == "table" and pieces or { pieces } do
		if type(p) == "table" then
			local cell = frame(row, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = i })
			local cl = Instance.new("UIListLayout")
			cl.FillDirection = Enum.FillDirection.Horizontal
			cl.VerticalAlignment = Enum.VerticalAlignment.Center
			cl.SortOrder = Enum.SortOrder.LayoutOrder
			cl.Padding = UDim.new(0, math.max(1, math.floor(size * 0.08)))
			cl.Parent = cell
			Toy.icon(cell, p.icon, math.floor(size * 1.15), { LayoutOrder = 1, ZIndex = row.ZIndex })
			text(cell, p.text, size, color, { LayoutOrder = 2, ZIndex = row.ZIndex })
		else
			text(row, p, size, color, { LayoutOrder = i, ZIndex = row.ZIndex })
		end
	end
	return row
end

-- fades everything a line drew (text, outlines, icon shapes) over `t` seconds
local function fadeOut(root, t)
	local info = TweenInfo.new(t)
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		elseif d:IsA("ImageLabel") then
			TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
		end
	end
end

-- toast(pieces, color, hold): a string, or a list of strings and amt() pieces
toast = function(pieces, color, hold)
	if not toastLayer then
		return
	end
	local t = line(toastLayer, pieces, px(22), color or Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), ZIndex = 21 })
	local sc = Instance.new("UIScale")
	sc.Scale = 0.4
	sc.Parent = t
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Sfx.play("toast")
	task.delay(hold or 2.5, function()
		TweenService:Create(t, TweenInfo.new(0.5), { Position = UDim2.fromScale(0.5, 0.27) }):Play()
		fadeOut(t, 0.5)
		task.wait(0.55)
		t:Destroy()
	end)
end

-- The Tide Bell banner (mock docs/art/mocks/tide_bell_banner.jpg, owner pick 2026-10-23): a blue toy
-- plate under the counter, the bell, "<name> rang the Tide Bell!" and a live countdown of the tide.
-- Shown BANNER_HOLD s on everyone's screen (the buyer too), then it shrinks into the HUD's tide row,
-- which keeps the countdown. Its own ScreenGui over everything (the launch screen, a menu, the HUD
-- stepping aside), kept across spawns (R19).
local BANNER_HOLD = 4
local bannerGui = Instance.new("ScreenGui")
bannerGui.Name = "TideBanner"
bannerGui.ResetOnSpawn = false
bannerGui.DisplayOrder = 110 -- over the launch screen (100)
bannerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
bannerGui.Parent = playerGui
local banner
local function tideBanner(name)
	if banner then
		banner:Destroy()
	end
	-- at the top, just under the qi counter and its rate line (mock), never over the middle of the screen
	local at = UDim2.new(0.5, 0, 0, px(150))
	local counter = ui.counter
	if counter and counter.AbsoluteSize.Y > 0 then
		local below = counter.AbsolutePosition.Y + counter.AbsoluteSize.Y - bannerGui.AbsolutePosition.Y
		at = UDim2.new(0.5, 0, 0, below + px(8)) -- the counter block holds the rate and tide lines
	end
	local plate = frame(bannerGui, { AutomaticSize = Enum.AutomaticSize.XY, AnchorPoint = Vector2.new(0.5, 0), Position = at, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("4C9BFF"), ZIndex = 21 })
	banner = plate
	Toy.corner(plate, UDim.new(0, px(16)))
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = px(3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = plate
	local grad = Instance.new("UIGradient") -- light from the top, like the toy buttons
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromHex("8FC8FF"), Color3.fromHex("3E86F0"))
	grad.Parent = plate
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(12)), UDim.new(0, px(18))
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(6)), UDim.new(0, px(7))
	pad.Parent = plate
	local row = frame(plate, { AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 22 })
	Toy.list(row, true, px(10), { VerticalAlignment = Enum.VerticalAlignment.Center })
	Toy.icon(row, "tidebell", px(46), { LayoutOrder = 1, ZIndex = 22 })
	local words = frame(row, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2, ZIndex = 22 })
	Toy.list(words, false, 0)
	text(words, name .. " rang the Tide Bell!", px(22), Color3.new(1, 1, 1), { LayoutOrder = 1, ZIndex = 22 })
	local sub = text(words, "", px(14), Color3.new(1, 1, 1), { LayoutOrder = 2, ZIndex = 22 })
	local function tick()
		local left = math.max(0, (workspace:GetAttribute("TideUntil") or 0) - workspace:GetServerTimeNow())
		sub.Text = string.format("Spirit Tide x2 Qi for everyone · %d:%02d", left // 60, math.floor(left % 60))
	end
	tick()
	local sc = Instance.new("UIScale")
	sc.Scale = 0.4
	sc.Parent = plate
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Sfx.play("toast")
	task.spawn(function()
		local t0 = os.clock()
		while plate.Parent and os.clock() - t0 < BANNER_HOLD do
			tick()
			task.wait(0.25)
		end
		if plate.Parent then
			-- settle into the tide row (its countdown carries on there), or rise and fade
			local row = ui.tideRow
			local goal = at - UDim2.fromOffset(0, px(20))
			if row and row.Visible and row.AbsoluteSize.X > 0 then
				local c = row.AbsolutePosition + row.AbsoluteSize / 2 - bannerGui.AbsolutePosition
				goal = UDim2.fromOffset(c.X, c.Y)
			end
			TweenService:Create(plate, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = goal }):Play()
			TweenService:Create(sc, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.25 }):Play()
			fadeOut(plate, 0.5)
			task.wait(0.55)
			plate:Destroy()
		end
	end)
end

popGain = function(amount, big)
	if not ui.counter or amount <= 0 then
		return
	end
	-- the counter bumps every time qi lands (bigger for orbs and grants)
	local bump = ui.counter:FindFirstChild("Bump") or Instance.new("UIScale")
	bump.Name = "Bump"
	bump.Parent = ui.counter
	bump.Scale = big and 1.22 or 1.08
	TweenService:Create(bump, TweenInfo.new(big and 0.5 or 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- it pops off the counter's bottom-right corner (its right side holds the Ranks chip)
	local abs = ui.counter.AbsolutePosition - ui.root.AbsolutePosition
	local t = line(ui.root, { amt("qi", amount, "+") }, px(18), GOLD, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(abs.X + ui.counter.AbsoluteSize.X + px(8), abs.Y + ui.counter.AbsoluteSize.Y - px(4)),
		Rotation = -8,
		ZIndex = 10,
	})
	TweenService:Create(t, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Position = t.Position - UDim2.fromOffset(0, px(22)) }):Play()
	fadeOut(t, 0.9)
	task.delay(0.95, function()
		t:Destroy()
	end)
end

---------------------------------------------------------------------------------------------
-- layout: place things around Roblox's own controls (called on any change)
-- a full-screen screen (Shop, Reincarnation) is open: the HUD steps aside (toasts stay), so nothing
-- peeks out from under that screen's veil or under its title on a phone (phone check 2026-10-21)
-- the HUD hides under every full screen (owner 2026-10-23: Disciples, Gifts, Daily Blessing,
-- Breakthrough, Odds, the return chest and the Friends card too). Gifts and Streak stay Enabled and
-- empty their children when closed, so a screen counts while it is Enabled AND draws something; the
-- Friends gui always holds its HUD row, so only its card counts (Friends.client names it "Card")
local MODALS = { "Shop", "Reincarnation", "WelcomeOffer", "StarterOffer", "Index", "Disciples", "Gifts", "Streak", "Breakthrough", "RecruitOdds", "IdleChest", "Friends", "Settings", "Rankings" }
local MODAL_PART = { Friends = "Card" }
local function modalOpen()
	for _, name in MODALS do
		local g = playerGui:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then
			local part = MODAL_PART[name]
			if part then
				if g:FindFirstChild(part) then
					return true
				end
			elseif #g:GetChildren() > 0 then
				return true
			end
		end
	end
	return false
end

local function layout()
	if not ui.root then
		return
	end
	if isPhone() ~= state.phoneMode then
		-- the touch controls appeared or went away (late spawn, touch laptop): resize everything
		task.defer(rebuildAll)
		return
	end
	local inset = GuiService.TopbarInset
	-- left buttons: the band under the top bar and above the thumbstick (bottom-left on a phone)
	local rootScale = ui.root:FindFirstChildOfClass("UIScale") -- (a phone check scales the root)
	local rootH = ui.root.AbsoluteSize.Y / (rootScale and rootScale.Scale or 1)
	local top = inset.Max.Y + px(8)
	local bottom = state.phoneMode and rootH * 0.72 or rootH - px(24)
	ui.left.Position = UDim2.fromOffset(px(12), top)
	ui.left.Size = UDim2.fromOffset(0, math.max(px(80), bottom - top))
	ui.cardBox.Position = UDim2.new(0, px(12) + ui.left.AbsoluteSize.X / (rootScale and rootScale.Scale or 1) + px(12), 0.45, 0)
	local hasHall = player:GetAttribute("HasHall") == true
	local hasFurnace = player:GetAttribute("HasFurnace") == true
	ui.dCol.Visible = true -- always there (owner 2026-10-23), the Disciple Hall or not: the book and the sect to look at
	ui.pCol.Visible = hasFurnace
	ui.gCol.Visible = true -- the gift always shows its next reward (owner pick B)
	ui.karmaRow.Visible = (player:GetAttribute("Karma") or 0) > 0 or (player:GetAttribute("Lives") or 1) > 1
	local modal = modalOpen()
	state.modal = modal
	ui.recruit.Visible = hasHall and not modal and not player:GetAttribute("AltarPalm") -- Palm Strike takes its spot on the altar
	ui.prog.Visible = not modal
	ui.top.Visible = not modal
	ui.left.Visible = not modal -- the Shop button is always there otherwise
	ui.right.Visible = not modal
	ui.cardBox.Visible = state.discOpen and not modal
	-- recruit: left of the phone jump button, or above it when the progress bar is in the way
	-- (positions in the root's own units: a phone check scales the root, AbsolutePosition does not)
	local unscale = rootScale and rootScale.Scale or 1
	local rootW = ui.root.AbsoluteSize.X / unscale
	local recruitW, recruitH = ui.recruit.Size.X.Offset, ui.recruit.Size.Y.Offset
	local jump = player:GetAttribute("HudDevice") ~= "pc" and jumpButton() or nil
	local rootPos = ui.root.AbsolutePosition
	local sealRight, sealBottom -- the seal's bottom-right corner (it hangs from AnchorPoint 1,1)
	if jump then
		local jx = (jump.AbsolutePosition.X - rootPos.X) / unscale
		local jy = (jump.AbsolutePosition.Y - rootPos.Y) / unscale
		local jh = jump.AbsoluteSize.Y / unscale
		-- left of the jump button; lifted above the realm bar when it reaches over the bar's end
		-- (stacking it above the jump button instead put it over the next goal on big touch screens)
		local barRight = (ui.prog.AbsolutePosition.X - rootPos.X + ui.prog.AbsoluteSize.X) / unscale
		local barTop = (ui.prog.AbsolutePosition.Y - rootPos.Y) / unscale
		sealRight, sealBottom = jx - px(12), jy + jh
		if sealRight - recruitW < barRight + px(8) then
			sealBottom = math.min(sealBottom, barTop - px(6))
		end
	else
		sealRight, sealBottom = rootW - px(20), rootH - px(20)
	end
	ui.recruit.Position = UDim2.fromOffset(sealRight, sealBottom)
	-- right stack: under the next goal, at the right edge. It must stay clear of the Recruit seal and
	-- the x10 / x50 picker that pops above it: a column if it ends above them, else a row if that
	-- does; else (the seal sits high, above the jump button) it moves left of the seal.
	local stackTop = inset.Max.Y + px(8) -- (the next goal moved to the bottom centre)
	local floor = state.phoneMode and rootH * 0.72 or rootH - px(24)
	local need, rowH, n = 0, 0, 0
	for _, c in ui.right:GetChildren() do
		if c:IsA("GuiObject") and c.Visible then
			local h = c.AbsoluteSize.Y / unscale
			need += h
			rowH = math.max(rowH, h)
			n += 1
		end
	end
	need += math.max(0, n - 1) * px(RAIL_GAP)
	local edge = rootW - px(14)
	local clearBottom = floor
	local sealLeft = sealRight - recruitW
	if ui.recruit.Visible and sealLeft < edge then
		clearBottom = math.min(floor, sealBottom - recruitH - px(50))
	end
	local column, right = true, edge
	if stackTop + need <= clearBottom then
		column = true
	elseif stackTop + rowH <= clearBottom then
		column = false
	else
		right = sealLeft - px(10)
		column = stackTop + need <= floor
	end
	ui.rightLayout.FillDirection = column and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
	ui.rightLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	ui.right.Position = UDim2.fromOffset(right, stackTop)
end

---------------------------------------------------------------------------------------------
-- data -> UI
-- the rebirth price in qi (Muscle Legends' rebirth): "Rebirth!" once it is held, else how far
local function rebirthChip()
	if not ui.rebirth then
		return
	end
	local price = player:GetAttribute("RebirthPrice") or Config.rebirthPrice(0)
	local held = player:GetAttribute("Qi") or 0
	if not player:GetAttribute("RebirthOpen") then
		-- closed: say what it waits for (Config.rebirthNeed, server attribute RebirthNeed)
		local kind, n = string.match(player:GetAttribute("RebirthNeed") or "", "^(%a+):(%d+)$")
		ui.rebirth.Text = kind == "realm" and "Realm " .. n or kind == "build" and "Build " .. n or "Rebirth"
		return
	end
	ui.rebirth.Text = held >= price and "Rebirth!" or string.format("%d%%", math.floor(100 * held / math.max(price, 1)))
end

refreshStatic = function()
	if not ui.root then
		return
	end
	ui.rate.Text = "+" .. compact(player:GetAttribute("Rate") or 0) .. "/s"
	ui.realm.Text = player:GetAttribute("RealmName") or ""
	local lit = litDots()
	ui.shopDot.Visible = lit.shop ~= nil
	-- a new disciple, or a new disciple index star (D60, local IndexNew): the index's own dot is on its button in the card
	ui.discDot.Visible = (lit.disc ~= nil or player:GetAttribute("IndexNew") == true) and not state.discOpen
	ui.karmaDot.Visible = lit.karma ~= nil
	ui.reincDot.Visible = lit.reinc == true
	ui.karma.Text = short(player:GetAttribute("Karma") or 0)
	local realmNow = player:GetAttribute("Realm") or 1
	rebirthChip()
	-- the price of each press size (all or nothing, Config.recruitBatchCost): the seal shows the pick's
	local n = state.recruitN or 1
	local rr = player:GetAttribute("RealmRecruits") or 0
	state.recruitTotals = {}
	for _, c in Config.RECRUIT_COUNTS do
		state.recruitTotals[c] = Config.recruitBatchCost(realmNow, rr, c)
		local chip = ui.recruitChips and ui.recruitChips[c]
		if chip then
			chip.price.Text = compact(state.recruitTotals[c])
		end
	end
	local free = (player:GetAttribute("FreeRecruits") or 0) > 0 -- the recruit tutorial (Tips.client)
	ui.recruitCost.Text = free and "Free" or compact(state.recruitTotals[n] or 0)
	ui.recruitLabel.Text = (n == 1 or free) and "Recruit" or ("Recruit x" .. n)
	local raw = player:GetAttribute("Disciples") or ""
	local list = raw == "" and {} or string.split(raw, ",")
	local looksRaw = player:GetAttribute("DiscLooks") or ""
	local looks = looksRaw == "" and {} or string.split(looksRaw, ",")
	local shinyRaw = player:GetAttribute("DiscShiny") or "" -- "1,0,...": Shiny marks, as DiscLooks
	local shiny = shinyRaw == "" and {} or string.split(shinyRaw, ",")
	local pulls = {} -- the index (D60): "key=pulls;..."; a disciple's own stars raise its bonus
	for _, pair in string.split(player:GetAttribute("Index") or "", ";") do
		local key, n = string.match(pair, "^(.-)=(%d+)$")
		if key then
			pulls[key] = tonumber(n)
		end
	end
	local pulledRaw = player:GetAttribute("Pulled") or ""
	local pulled = pulledRaw == "" and {} or string.split(pulledRaw, ",")
	for _, c in ui.card:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	local max = player:GetAttribute("MaxDisciples") or Config.MAX_DISCIPLES
	ui.dLabel.Text = string.format("%d/%d", math.min(#list, max), max)
	local newLeft = {} -- how many of each new name still get their dot
	for i, name in list do
		local r = Config.rarity(name)
		if i > max then
			-- the rest wait for more Quarters: one grey "+N"
			text(ui.card, "+" .. (#list - max), px(16), Color3.fromHex("C8C0D0"), { LayoutOrder = i })
			break
		end
		local cell = frame(ui.card, { Size = UDim2.fromOffset(px(48), 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i })
		local cl = Instance.new("UIListLayout")
		cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		cl.SortOrder = Enum.SortOrder.LayoutOrder
		cl.Parent = cell
		local face = Toy.disciple(cell, px(46), name, { LayoutOrder = 1 }, false, looks[i], shiny[i] == "1") -- its face and its rarity's moving aura
		-- a tap opens the Disciples book on My Sect (Roster.client)
		local tapFace = Instance.new("TextButton")
		tapFace.Text = ""
		tapFace.BackgroundTransparency = 1
		tapFace.Size = UDim2.fromScale(1, 1)
		tapFace.ZIndex = 8
		tapFace.Parent = face
		tapFace.Activated:Connect(function()
			local ev = player:FindFirstChild("OpenRoster")
			if ev then
				ev:Fire("sect")
			end
		end)
		if state.discNew and (state.discNew[name] or 0) > 0 then
			newLeft[name] = (newLeft[name] or state.discNew[name]) - 1
			if newLeft[name] >= 0 then
				Toy.dot(face, px(11), { Position = UDim2.new(1, px(1), 0, -px(1)) }) -- small, off the face's corner
			end
		end
		-- a sold rarity the player also rolled carries its "first pulled" mark: a gold dot
		if table.find(pulled, name) and Config.shopItem(Config.shopKeyOf(name)) then
			local dot = frame(face, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.8, 0.2), Size = UDim2.fromOffset(px(10), px(10)), BackgroundTransparency = 0, BackgroundColor3 = GOLD, ZIndex = 5 })
			corner(dot, UDim.new(1, 0))
			local ds = Instance.new("UIStroke")
			ds.Color = INK
			ds.Thickness = px(2)
			ds.Parent = dot
		end
		local own = looks[i] and pulls[Config.indexKey(name, looks[i])]
		text(cell, string.format("+%d%%", math.floor(Config.discBonus(name, shiny[i] == "1") * Config.discipleStarMult(own) * 100 + 0.5)), px(11), r.color, { LayoutOrder = 2 })
	end
	-- the disciple index (D60, IndexBook.client): a gold book button at the end of the card, with a red
	-- dot while a star is new (local attribute IndexNew, set by IndexBook where the stars change)
	local iHolder, iBtn = toy(ui.card, UDim2.fromOffset(px(48), px(48)), GOLD, px(12))
	iHolder.LayoutOrder = 100
	local iCol = frame(iBtn, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 3 })
	Toy.list(iCol, false, 0)
	text(iCol, "★", px(18), Color3.new(1, 1, 1), { LayoutOrder = 1, ZIndex = 3 })
	text(iCol, "Index", px(12), Color3.new(1, 1, 1), { LayoutOrder = 2, ZIndex = 3 })
	if player:GetAttribute("IndexNew") then
		Toy.dot(iHolder, px(17))
	end
	iBtn.Activated:Connect(function()
		-- the Disciples book's Index tab (Roster.client); IndexBook's own window until the book loads
		local book = player:FindFirstChild("OpenRoster")
		local ev = book or player:FindFirstChild("IndexOpen")
		if ev then
			ev:Fire(book and "index" or nil)
		end
	end)
	-- Buy more (owner 2026-10-23): straight to the Shop's Disciples page
	local bHolder, bBtn = toy(ui.card, UDim2.fromOffset(px(48), px(48)), Color3.fromHex("47D16C"), px(24))
	bHolder.LayoutOrder = 101
	local bCol = frame(bBtn, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 3 })
	Toy.list(bCol, false, 0)
	text(bCol, "+", px(20), Color3.new(1, 1, 1), { LayoutOrder = 1, ZIndex = 3 })
	text(bCol, "Buy", px(12), Color3.new(1, 1, 1), { LayoutOrder = 2, ZIndex = 3 })
	bBtn.Activated:Connect(function()
		local shop = player:FindFirstChild("ShopOpen")
		if shop then
			shop:Fire("disciples", "disciples")
		end
	end)
	-- realm progress = buildings owned this realm (published by the server)
	local owned = player:GetAttribute("Built") or 0
	local total = Config.requiredPads(player:GetAttribute("Realm") or 1) -- this realm's island (D48); paths and groves optional
	ui.progText.Text = string.format("%d/%d", math.min(owned, total), total) -- the next step above says Breakthrough
	TweenService:Create(ui.fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(owned / total, 0.04, 1), 1) }):Play()
	ui.fill.BackgroundColor3 = owned >= total and GOLD or JADE
end

-- Player.HudSlots: other scripts add a row to the right stack (the altar chip) or the left rail
-- (the Friends button), and Travel teleports like the Base / Ranks chips. The HUD rebuilds itself on a viewport change, so it points `Right` / `Left`
-- at the current rails and fires `Rebuilt`: a row re-parents itself there on every Rebuilt
-- (LayoutOrder: right = gift 1, pill 2, then yours; left = Shop 0, Disciples 1, Karma 2, then yours).
local slots = Instance.new("Folder")
slots.Name = "HudSlots"
local slotRight = Instance.new("ObjectValue")
slotRight.Name = "Right"
slotRight.Parent = slots
local slotLeft = Instance.new("ObjectValue")
slotLeft.Name = "Left"
slotLeft.Parent = slots
local slotRebuilt = Instance.new("BindableEvent")
slotRebuilt.Name = "Rebuilt"
slotRebuilt.Parent = slots
local slotTravel = Instance.new("BindableEvent") -- Travel:Fire(where): the jade-wipe teleport (the altar "!" uses it)
slotTravel.Name = "Travel"
slotTravel.Event:Connect(function(where) task.spawn(teleportTo, where) end)
slotTravel.Parent = slots
slots.Parent = player -- not PlayerGui: the first LoadCharacter (Main onJoin) empties it, live joins spawn after this runs

rebuildAll = function()
	build()
	refreshStatic()
	slotRight.Value = ui.right
	slotLeft.Value = ui.left
	slotRebuilt:Fire(ui.right)
	task.defer(layout)
end

rebuildAll()
for _, a in { "Rate", "RealmName", "RecruitCost", "RealmRecruits", "Disciples", "DiscLooks", "DiscShiny", "Index", "Built", "Pulled", "Dots", "IndexNew", "RebirthPrice", "RebirthOpen", "RebirthNeed", "FreeRecruits" } do
	player:GetAttributeChangedSignal(a):Connect(refreshStatic)
end
player:GetAttributeChangedSignal("HasHall"):Connect(function()
	refreshStatic()
	layout()
end)
player:GetAttributeChangedSignal("HasFurnace"):Connect(layout)
player:GetAttributeChangedSignal("AltarPalm"):Connect(layout) -- Altar.client: Palm Strike takes the Recruit seal's spot
for _, a in { "Karma", "Lives" } do
	player:GetAttributeChangedSignal(a):Connect(function()
		refreshStatic()
		layout()
	end)
end
player:GetAttributeChangedSignal("MaxDisciples"):Connect(refreshStatic)
player:GetAttributeChangedSignal("Qi"):Connect(function()
	local q = player:GetAttribute("Qi") or 0
	local gain = q - state.lastQi
	state.lastQi = q
	rebirthChip()
	if gain > 0 and gain <= (player:GetAttribute("Rate") or 0) * 1.6 + 1 then
		if not modalOpen() then -- no "+qi" floating over a full screen (Play check 2026-10-23)
			popGain(gain) -- passive income tick (not a purchase refund or a big grant)
		end
	end
end)

local lastVp = workspace.CurrentCamera.ViewportSize
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	local vp = workspace.CurrentCamera.ViewportSize
	if (vp - lastVp).Magnitude > 8 then
		lastVp = vp
		rebuildAll()
	end
end)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
player:GetAttributeChangedSignal("HudDevice"):Connect(rebuildAll)
local function watchModal(g)
	if table.find(MODALS, g.Name) and g:IsA("ScreenGui") then
		g:GetPropertyChangedSignal("Enabled"):Connect(layout)
		g.ChildAdded:Connect(function()
			task.defer(layout)
		end)
		g.ChildRemoved:Connect(function()
			task.defer(layout)
		end)
	end
end
for _, g in playerGui:GetChildren() do
	watchModal(g)
end
playerGui.ChildAdded:Connect(watchModal)
playerGui.ChildAdded:Connect(function(c)
	if c.Name == "TouchGui" then
		task.wait(0.5)
		layout()
	end
end)
task.delay(2, layout) -- TouchGui settles a moment after spawn

-- a property write only when the value changed (R16 rule 4: a write can redraw the GUI)
local function put(obj, prop, value)
	if obj[prop] ~= value then
		obj[prop] = value
	end
end

---------------------------------------------------------------------------------------------
-- per frame: smooth count-up, next-goal arrow, recruit wobble when affordable
local goalAcc = 0
local rebirthToasted -- the life (rebirths done) whose "Rebirth ready!" toast already showed
RunService.RenderStepped:Connect(function(dt)
	if not ui.root then
		return
	end
	local t0 = PerfMark.begin()
	local target = player:GetAttribute("Qi") or 0
	local diff = target - state.shownQi
	if math.abs(diff) < 1 then
		state.shownQi = target
	else
		state.shownQi += diff * math.min(1, dt * 8)
	end
	put(ui.qi, "Text", short(state.shownQi))

	goalAcc += dt
	if goalAcc > 0.5 then
		goalAcc = 0
		-- Roblox's touch controls appear and resize late (and on rotation): re-place around them
		layout()
		goalPad = Config.guidePick(myPads()) -- the recruiting building first, else the cheapest
	end
	if goalPad and goalPad.Parent then
		put(ui.goal, "Visible", not state.modal)
		local cost = goalPad:GetAttribute("Cost") or 0
		local title = goalPad:GetAttribute("Title") or ""
		put(ui.goalName, "Text", title:match("^(.-):") or title) -- "Breakthrough: X" says just Breakthrough
		put(ui.goalCost, "Text", compact(cost))
		put(ui.goalCost, "TextColor3", target >= cost and Color3.fromHex("9FF5C8") or PINK)
		put(ui.hands, "Visible", (player:GetAttribute("Dao_hands") or 0) > 0)
		local cam = workspace.CurrentCamera
		local rel = cam.CFrame:PointToObjectSpace(goalPad.Position)
		put(ui.arrow, "Rotation", math.deg(math.atan2(rel.Z, rel.X))) -- 0 = right, 90 = toward the camera
	else
		put(ui.goal, "Visible", false)
	end

	-- Spirit Tide line under the counter; the rate turns tide blue while it runs
	local now = workspace:GetServerTimeNow()
	local tideLeft = (workspace:GetAttribute("TideUntil") or 0) - now
	local tideIn = (workspace:GetAttribute("TideNext") or 0) - now
	local tideText = ""
	if tideLeft > 0 then
		tideText = string.format("2x %d:%02d", tideLeft // 60, math.floor(tideLeft % 60))
	elseif tideIn > 0 then
		tideText = string.format("%d:%02d", tideIn // 60, math.floor(tideIn % 60))
	end
	if ui.tide.Text ~= tideText then
		put(ui.tide, "Text", tideText)
		put(ui.tideRow, "Visible", tideText ~= "")
		put(ui.tide, "TextColor3", tideLeft > 0 and TIDE or TIDE_LIGHT)
		put(ui.tide, "TextSize", tideLeft > 0 and px(13) or px(12))
		put(ui.rate, "TextColor3", tideLeft > 0 and TIDE or Color3.fromHex("9FF5C8"))
	end

	-- the Rebirth seal wobbles gold once the rebirth price is held; the first rebirths also say so
	-- once, in a gold toast (owner 2026-10-24; Tips.client points at the seal)
	local rebirthHeld = player:GetAttribute("RebirthOpen") and (player:GetAttribute("Qi") or 0) >= (player:GetAttribute("RebirthPrice") or math.huge)
	if player:GetAttribute("LaunchDone") and (player:GetAttribute("WelcomeQi") or 0) <= 0 then
		local life = player:GetAttribute("Rebirths") or 0
		if rebirthHeld and rebirthToasted ~= life and life < Config.REBIRTH_TIP_TIMES then
			toast("Rebirth ready!", GOLD, 4)
		end
		if rebirthHeld then
			rebirthToasted = life
		end
	end
	if rebirthHeld then
		ui.rebirthBtn.Rotation = math.sin(os.clock() * 6) * 4
		ui.rebirthBtn.BackgroundColor3 = GOLD
	else
		ui.rebirthBtn.Rotation = 0
		ui.rebirthBtn.BackgroundColor3 = Color3.fromHex("B06BFF")
	end

	if ui.gCol.Visible then
		-- the daily ladder (GiftIn / GiftNext / GiftQi / GiftResetIn, Economy); GiftIn -1 = all
		-- claimed today: the prize hides and the label counts down to the reset
		local g = player:GetAttribute("GiftIn") or -1
		local done = g < 0
		put(ui.giftDot, "Visible", g == 0)
		put(ui.giftBadge, "Visible", not done)
		put(ui.giftPrize, "Visible", not done)
		local n = player:GetAttribute("GiftNext") or 0
		local prize = Config.giftPrize(n)
		if prize then
			-- the prize in words: the disciple's rarity, the pill, the summons, else the qi
			local word, color
			if prize.rarity then
				word, color = prize.rarity, Config.rarity(prize.rarity).color
			elseif prize.pill > 0 then
				word, color = "2x Qi", Color3.fromHex("FF9A8C")
			elseif prize.summons > 0 then
				word, color = "+" .. prize.summons .. " summon" .. (prize.summons > 1 and "s" or ""), Color3.fromHex("D9B8FF")
			else
				word, color = "+" .. compact(player:GetAttribute("GiftQi") or 0), JADE_LIGHT
			end
			put(ui.giftPrize, "Text", word)
			put(ui.giftPrize, "TextColor3", color)
			if ui.giftBadgeOf ~= n then -- redraw the corner picture when the next gift changes
				ui.giftBadgeOf = n
				ui.giftBadge:ClearAllChildren()
				local at = { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 }
				if prize.rarity then
					Toy.disciple(ui.giftBadge, px(22), prize.rarity, at)
				elseif prize.pill > 0 then
					Toy.icon(ui.giftBadge, "pill", px(22), at)
				elseif prize.summons > 0 then
					discipleIcon(ui.giftBadge, px(22), at)
				else
					qiIcon(ui.giftBadge, px(18), at)
				end
			end
		end
		if g == 0 then
			put(ui.giftLabel, "Text", "")
			put(ui.giftBtn, "BackgroundColor3", FACE_READY)
		else
			local s = done and (player:GetAttribute("GiftResetIn") or 0) or g
			put(ui.giftLabel, "Text", s >= 3600 and string.format("%dh%02d", s // 3600, (s % 3600) // 60) or string.format("%d:%02d", s // 60, s % 60))
			put(ui.giftLabel, "TextColor3", done and Color3.fromHex("C8C0D0") or Color3.new(1, 1, 1))
			put(ui.giftBtn, "BackgroundColor3", FACE)
		end
	end

	if ui.pCol.Visible then
		local left = (player:GetAttribute("BoostUntil") or 0) - workspace:GetServerTimeNow()
		if left > 0 then
			put(ui.pillLabel, "Text", string.format("2x %d:%02d", left // 60, math.floor(left % 60)))
			put(ui.pillLabel, "TextColor3", GOLD)
			put(ui.pillDot, "Visible", false)
			put(ui.pillBtn, "BackgroundColor3", FACE)
		elseif player:GetAttribute("PillReady") then
			put(ui.pillLabel, "Text", "Use!")
			put(ui.pillLabel, "TextColor3", GOLD)
			put(ui.pillDot, "Visible", true)
			put(ui.pillBtn, "BackgroundColor3", FACE_READY)
		else
			local s = player:GetAttribute("PillIn") or 0
			put(ui.pillLabel, "Text", string.format("%d:%02d", s // 60, s % 60))
			put(ui.pillLabel, "TextColor3", Color3.fromHex("C8C0D0"))
			put(ui.pillDot, "Visible", false)
			put(ui.pillBtn, "BackgroundColor3", FACE)
		end
	end

	if ui.recruit.Visible then
		-- the Recruit seal: while a recruit is affordable the orb charges through the first five
		-- rarity colours (a step every 0.6 s), the ring and rays turn and it breathes; else still, dim
		local totals = state.recruitTotals or {}
		local can = target >= (totals[state.recruitN or 1] or math.huge) or (player:GetAttribute("FreeRecruits") or 0) > 0
		-- the chips: the pick is gold, a size out of reach is grey (dim gold when it is the pick)
		if ui.recruitPick.Visible then
			for c, chip in ui.recruitChips do
				local ok = target >= (totals[c] or math.huge)
				local picked = c == (state.recruitN or 1)
				put(chip.btn, "BackgroundColor3", picked and (ok and Color3.fromHex("FFD34D") or Color3.fromHex("B8A878")) or (ok and Color3.fromHex("3A2C44") or Color3.fromHex("5A5262")))
				put(chip.label, "TextColor3", ok and Color3.new(1, 1, 1) or Color3.fromHex("C8C0D0"))
				put(chip.price, "TextColor3", ok and JADE_LIGHT or PINK)
			end
		end
		local sl = ui.seal
		local t = os.clock()
		put(ui.recruitBtn, "BackgroundColor3", can and Color3.fromHex("A070F0") or Color3.fromHex("8C72A8"))
		put(sl.rays, "Visible", can)
		put(sl.glow, "Visible", can)
		put(sl.orbGlow, "Visible", can)
		if can then
			local col = Config.RARITIES[math.floor(t / 0.6) % 5 + 1].color
			if sl.col ~= col then
				sl.col = col
				sl.shade.Color = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.55), col)
			end
			put(sl.glow, "ImageColor3", col)
			put(sl.orbGlow, "ImageColor3", col)
			sl.rays.Rotation = t * 30
			sl.ring.Rotation = t * 60
			sl.scale.Scale = 1 + 0.06 * math.sin(t * math.pi * 2.4)
			for i, m in sl.motes do
				local a = t * math.pi * 4 / 3 + i * math.pi / 2
				m.Visible = true
				m.Position = UDim2.new(0.5, math.cos(a) * sl.orbSize * 0.72, 0.5, math.sin(a) * sl.orbSize * 0.72)
			end
		else
			if sl.col ~= false then
				sl.col = false
				sl.shade.Color = ColorSequence.new(Color3.fromHex("D8D2E2"), Color3.fromHex("A8A0B8"))
			end
			put(sl.scale, "Scale", 1)
			for _, m in sl.motes do
				put(m, "Visible", false)
			end
		end
	end
	PerfMark.finish("hud", t0)
end)

remotes.Notify.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "orb" then
		popGain(a, true)
		toast({ amt("qi", a, "+") }, Color3.fromHex("9FF5D0"), 1.2)
		return
	elseif kind == "pill" then
		toast("Pill ready!", GOLD, 2.5)
		return
	elseif kind == "indexStep" then -- the disciple index paid a step (D60): `a` free summons
		toast(string.format("Index step! +%d free summons", a), GOLD, 3)
		return
	elseif kind == "expand" then
		toast("More land!", Color3.fromHex("9FF5C8"), 3)
		return
	elseif kind == "tideSoon" then
		toast(string.format("Spirit Tide in %ds", a), Color3.fromHex("9FD0FF"), 3)
		return
	elseif kind == "shopPass" or kind == "shopPill" then
		return -- BuyMoment.client shows it
	elseif kind == "shopQi" then
		-- BuyMoment.client pours the drops in; the counter bumps when they land (a skip lands them sooner)
		task.delay(Config.buyArrive(), function()
			popGain(a, true)
		end)
		return
	elseif kind == "shopWelcome" then
		-- after the recruit reveal of its disciple: the forever bonus (`c` = 0.1)
		task.delay(Config.revealBurst(a) + Config.REVEAL.hold + 1, function()
			toast({ "+" .. math.floor((c or 0) * 100 + 0.5) .. "%", { icon = "qi", text = "forever!" } }, GOLD, 3)
		end)
		return
	elseif kind == "shopDisciple" then
		-- the recruit reveal shows it (Shop.client); only a disciple with no free seat gets a line after
		if not b then
			task.delay(Config.revealBurst(a) + Config.REVEAL.hold + 1, function()
				toast(a .. " (resting)", Config.rarity(a).color, 3)
			end)
		end
		return
	elseif kind == "shopGate" then
		toast(a .. " opens at " .. b, PINK, 2.5)
		return
	elseif kind == "shopLimit" then
		toast("Already yours", Color3.fromHex("9FF5C8"), 2)
		return
	elseif kind == "shopRegion" then -- Qi is not sold where Roblox restricts paid random items (Shop.luau)
		toast("Not sold in your region", PINK, 2.5)
		return
	elseif kind == "shopFull" then
		toast("Sect full", PINK, 2)
		return
	elseif kind == "shopOwned" then
		toast("Already yours", Color3.fromHex("9FF5C8"), 1.6)
		return
	elseif kind == "realmLook" then
		toast(a, GOLD, 4) -- what this realm changed on the peak (Config.realmLookLine)
		return
	elseif kind == "tide" then
		if b then
			tideBanner(b) -- `b` = who rang the Tide Bell
		else
			toast("Spirit Tide! 2x Qi", Color3.fromHex("9FD0FF"), 4)
		end
		return
	elseif kind == "swordOff" or kind == "swordNo" then -- the sword ride stopped or was refused (D76): `a` = why
		local why = { pad = "Swords rest near pads", altar = "No swords on the Altar", speed = "Too fast for this sword", bridge = "Open its bridge first", void = "Fly over land to step off" }
		toast(why[a] or "Off the sword", PINK, 2)
		return
	elseif kind == "tideBellNo" then -- the Tide Bell was refused: `a` = "tide" | "altar"
		toast(a == "tide" and "The Spirit Tide is already here" or "The Heavenly Altar is opening", PINK, 2.5)
		return
	elseif kind == "shopStarter" then
		-- after the recruit reveal of its Immortal: the qi (`c`) and the 2x (`d` s)
		task.delay(Config.revealBurst(a) + Config.REVEAL.hold + 1, function()
			popGain(c or 0, true)
			toast({ amt("qi", c or 0, "+"), "and 2x Qi for " .. math.floor((d or 0) / 60) .. " min" }, GOLD, 3.5)
		end)
		return
	elseif kind == "blessed" then -- a visitor blessed this sect (Bless.luau); b = qi gained (0: none)
		if b and b > 0 then
			popGain(b, true)
			toast({ a .. " blessed your sect", amt("qi", b, "+") }, Color3.fromHex("9FF5D0"), 4)
		else
			toast(a .. " blessed your sect", Color3.fromHex("9FF5D0"), 4)
		end
		return
	elseif kind == "blessGave" then -- a = qi gained, b = the sect's owner
		popGain(a, true)
		toast({ "Blessed " .. b, amt("qi", a, "+") }, Color3.fromHex("9FF5D0"), 3)
		return
	elseif kind == "blessNo" then
		toast(a, PINK, 2)
		return
	end
	if kind == "built" then
		toast(a .. "!", Color3.fromHex("9FF5C8"), 1.6)
	elseif kind == "offline" then
		toast({ "Away", { icon = "qi", text = "+" .. short(a) } }, Color3.fromHex("9FD0FF"), 5)
	elseif kind == "breakthrough" then
		toast(a == player.DisplayName and (b .. "!") or (a .. ": " .. b .. "!"), GOLD, 4)
	elseif kind == "reincarnate" then
		toast(a == player.DisplayName and string.format("Life %d!", b) or string.format("%s: life %d!", a, b), Color3.fromHex("D9B8FF"), 4)
	end
end)
