-- Shop screen (mock B, docs/art/mocks/shop_B_phone.jpg, D24): no board, toy tiles floating over a
-- dark veil, one row per page: Boosts (passes + Instant Pill), Qi packs, Disciples, picked with
-- toy tabs (with their icons) under the title. Opened by the HUD's Shop button and by the Get Qi
-- offer (PlayerGui.ShopOpen, a BindableEvent fired with the source and an optional page key). The
-- server prompts and grants (R9): a tap only sends the item key. Also draws the cards over the world
-- shop's purple pads (D33) and the quiet Get Qi offer on a build pad the player cannot afford.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local PadLook = require(Shared:WaitForChild("PadLook"))
local PerfMark = require(Shared:WaitForChild("PerfMark"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local px, text = Toy.px, Toy.text
local GOLD = Color3.fromHex("FFE36B")
local BUY = Color3.fromHex("47D16C")
local GREY = Color3.fromHex("C9C2D3")
local TILE = { x2 = "9FF5C8", auto = "9FD0FF", vip = "FFD36B", pill = "FFB3A8", pack1 = "C9FFE4", pack2 = "B9F0D6", pack3 = "A6E8C8", welcome = "FFD36B" }
-- disciples for sale: a pale tile of their rarity colour
local function tileColor(key)
	local it = Config.shopItem(key)
	if it and it.rarity and not it.qiBonus then
		return Config.rarity(it.rarity).color:Lerp(Color3.new(1, 1, 1), 0.55)
	end
	return Color3.fromHex(TILE[key] or "C9FFE4")
end
local TILT = { -2, 1.5, -1, 2 }

local openEvent = Instance.new("BindableEvent")
openEvent.Name = "ShopOpen"
openEvent.Parent = playerGui

---------------------------------------------------------------------------------------------
-- prices: read from Roblox (regional pricing makes them per player); nil = not loaded yet
local prices = {}
local function fetchPrices(onDone)
	for _, list in { Config.SHOP_PASSES, Config.SHOP_PRODUCTS } do
		for _, it in list do
			if it.id ~= 0 and not prices[it.key] then
				task.spawn(function()
					local infoType = list == Config.SHOP_PASSES and Enum.InfoType.GamePass or Enum.InfoType.Product
					local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, it.id, infoType)
					if ok and info and info.PriceInRobux then
						prices[it.key] = info.PriceInRobux
						onDone()
					end
				end)
			end
		end
	end
end

-- "Owned" / "Soon" (no id yet) / the price in Robux (canBuy = true: drawn after a Robux icon)
local function priceText(key)
	local it, isPass = Config.shopItem(key)
	if it and it.minRealm and (player:GetAttribute("Realm") or 1) < it.minRealm then
		return "Realm " .. it.minRealm, false -- D28 gate (the card says which realm)
	elseif (isPass and player:GetAttribute("Pass_" .. key)) or player:GetAttribute("Limit_" .. key) then
		return "Owned", false
	elseif not it or it.id == 0 then
		return "Soon", false
	end
	return prices[key] and tostring(prices[key]) or "...", true
end

local function packQi(it)
	local q = math.floor((player:GetAttribute("AwayRate") or 0) * it.seconds)
	local s = tostring(q):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "+" .. s
end

---------------------------------------------------------------------------------------------
-- the screen
local gui = Instance.new("ScreenGui")
gui.Name = "Shop"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5 -- over the HUD
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = playerGui

local ui = {}
local page = "boosts"
local function products(pick)
	return function()
		local list = {}
		for _, it in Config.SHOP_PRODUCTS do
			if pick(it) then
				table.insert(list, it)
			end
		end
		return list
	end
end
local PAGES = {
	{
		key = "boosts",
		name = "Boosts",
		icon = "x2",
		items = function()
			local list = table.clone(Config.SHOP_PASSES)
			table.insert(list, (Config.shopItem("pill")))
			-- the Welcome Pouch leads the row until it is bought (it is once per player)
			if not player:GetAttribute("Limit_welcome") then
				table.insert(list, 1, (Config.shopItem("welcome")))
			end
			return list
		end,
	},
	{ key = "qi", name = "Qi", icon = "pack2", items = products(function(it) return it.seconds ~= nil end) },
	{ key = "disciples", name = "Disciples", icon = "celestial", items = products(function(it) return it.rarity ~= nil and not it.qiBonus end) },
}

local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice") -- "phone" / "pc" forces a layout (testing)
	local touch = if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
	if touch then
		return math.clamp(vp.Y / 390, 0.78, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

local close -- forward

local BEST = "pack3" -- the one "Best value" ribbon (the most qi per Robux)

local function tile(parent, key, order, name, line)
	local col = Toy.frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order, Rotation = TILT[(order - 1) % #TILT + 1] })
	Toy.list(col, false, px(2))
	local holder, btn = Toy.button(col, UDim2.fromOffset(px(92), px(92)), tileColor(key), px(20))
	holder.LayoutOrder = 1
	Toy.icon(btn, key, px(68), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local ribbon = (key == BEST and "Best value") or (key == "welcome" and "Once") or nil
	if ribbon then
		local rib = Toy.frame(holder, { AutomaticSize = Enum.AutomaticSize.XY, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, px(12), 0, -px(2)), Rotation = 8, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("FF6B5E"), ZIndex = 5 })
		Toy.corner(rib, UDim.new(0, px(8)))
		local st = Instance.new("UIStroke")
		st.Color = Toy.INK
		st.Thickness = px(2)
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = rib
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(7)), UDim.new(0, px(7))
		pad.Parent = rib
		text(rib, ribbon, px(12), Color3.new(1, 1, 1), { ZIndex = 6 })
	end
	local sc = Instance.new("UIScale")
	sc.Name = "Pop"
	sc.Parent = col
	-- a disciple's name in its rarity colour (the Index and recruit language)
	local it = Config.shopItem(key)
	local nameColor = it and it.rarity and not it.qiBonus and Config.rarity(it.rarity).color or Color3.new(1, 1, 1)
	text(col, name, px(17), nameColor, { LayoutOrder = 2 })
	local lineLabel
	if key ~= "more" and Config.shopItem(key) and Config.shopItem(key).seconds then
		-- a Qi pack's amount, after the qi icon
		local _, l = Toy.amount(col, "qi", px(12), Color3.fromHex("C9FFE4"), { LayoutOrder = 3 })
		lineLabel = l
	elseif line then
		lineLabel = text(col, line, px(12), Color3.fromHex("C9FFE4"), { LayoutOrder = 3 })
	end
	return col, btn, lineLabel
end

local function itemTile(parent, it, order)
	local col, btn, lineLabel = tile(parent, it.key, order, it.name, it.line)
	Toy.frame(col, { Size = UDim2.fromOffset(1, px(3)), LayoutOrder = 4 })
	local pHolder, pBtn = Toy.button(col, UDim2.fromOffset(px(96), px(32)), BUY, px(10))
	pHolder.LayoutOrder = 5
	local priceRow, label = Toy.amount(pBtn, "robux", px(16), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	local function buy()
		local _, canBuy = priceText(it.key)
		if canBuy then
			remotes.ShopBuy:FireServer(it.key)
		elseif label.Text == "Owned" then
			Sfx.play("toast")
		end
	end
	btn.Activated:Connect(buy)
	pBtn.Activated:Connect(buy)
	table.insert(ui.items, { it = it, label = label, icon = priceRow:FindFirstChild("Currency"), button = pBtn, line = lineLabel })
	return col
end

-- the free daily gift (owner: "give a small free daily gift"): the Shop's red dot leads here, and
-- claiming it is what clears that dot. ShopFreeIn = 0 when ready, else the seconds to wait.
local function freeTile(parent)
	local col, btn = tile(parent, "gift", 0, "Daily Gift", "Free every day")
	Toy.frame(col, { Size = UDim2.fromOffset(1, px(3)), LayoutOrder = 4 })
	local pHolder, pBtn = Toy.button(col, UDim2.fromOffset(px(96), px(32)), BUY, px(10))
	pHolder.LayoutOrder = 5
	local label = text(pBtn, "Free", px(16), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	local dot = Toy.dot(btn, px(22), { Visible = false })
	local busy = false
	local function claim()
		if busy or (player:GetAttribute("ShopFreeIn") or 1) ~= 0 then
			Sfx.play("deny")
			return
		end
		busy = true
		local ok, gain = pcall(function()
			return remotes.ClaimShopFree:InvokeServer()
		end)
		busy = false
		if ok and gain then
			Toy.reward(pBtn)
		else
			Sfx.play("deny")
		end
	end
	btn.Activated:Connect(claim)
	pBtn.Activated:Connect(claim)
	ui.free = { label = label, button = pBtn, dot = dot }
	return col
end

local function row(parent, order)
	local r = Toy.frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order })
	Toy.list(r, true, px(16), { VerticalAlignment = Enum.VerticalAlignment.Top })
	return r
end

local function refresh()
	if not ui.items then
		return
	end
	for _, rec in ui.items do
		local str, canBuy = priceText(rec.it.key)
		rec.label.Text = str
		rec.icon.Visible = canBuy -- Owned / Soon / Realm N carry no price
		rec.button.BackgroundColor3 = canBuy and BUY or GREY
		if rec.it.seconds and rec.line then
			rec.line.Text = packQi(rec.it)
		end
	end
	for key, r in ui.rows or {} do
		r.Visible = key == page
		ui.tabs[key].BackgroundColor3 = key == page and Color3.fromHex("FFD36B") or GREY
	end
	if ui.free then
		local wait = player:GetAttribute("ShopFreeIn") or 1
		ui.free.dot.Visible = wait == 0
		ui.tabDot.Visible = wait == 0 and page ~= "boosts"
		ui.free.button.BackgroundColor3 = wait == 0 and BUY or GREY
		ui.free.label.Text = wait == 0 and "Free" or (wait >= 3600 and string.format("%dh%02d", wait // 3600, wait % 3600 // 60) or string.format("%d:%02d", wait // 60, wait % 60))
	end
end

local function pop()
	-- tiles spring in one after another
	local i = 0
	for _, d in gui:GetDescendants() do
		if d:IsA("UIScale") and d.Name == "Pop" and d.Parent.Visible ~= false and d.Parent.Parent.Visible then
			i += 1
			d.Scale = 0.3
			TweenService:Create(d, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, i * 0.035), { Scale = 1 }):Play()
		end
	end
end

local function build()
	gui:ClearAllChildren()
	Toy.S = computeScale()
	ui = { items = {} }

	local veil = Instance.new("TextButton")
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 0.32
	veil.BorderSizePixel = 0
	veil.Parent = gui
	veil.Activated:Connect(function()
		close()
	end)

	local body = Toy.frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY })
	Toy.list(body, false, px(14))
	text(body, "Shop", px(34), GOLD, { LayoutOrder = 1, Rotation = -2 })
	-- close: a big X in the screen's top right corner (where a thumb looks for it), inside the safe area
	local xHolder, xBtn = Toy.button(gui, UDim2.fromOffset(px(44), px(44)), Color3.fromHex("FF6B5E"), px(12))
	xHolder.AnchorPoint = Vector2.new(1, 0)
	xHolder.Position = UDim2.new(1, -px(22), 0, px(16) + game:GetService("GuiService"):GetGuiInset().Y)
	xHolder.ZIndex = 2 -- over the veil
	text(xBtn, "X", px(24), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	xBtn.Activated:Connect(function()
		close()
	end)

	-- three pages, one row each (six tiles fit a phone at px(16) gaps), picked by toy tabs
	local tabs = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	Toy.list(tabs, true, px(10))
	ui.rows, ui.tabs = {}, {}
	for i, pg in PAGES do
		local r = row(body, 2 + i)
		ui.rows[pg.key] = r
		local n = 0
		if pg.key == "boosts" then
			freeTile(r)
		end
		for _, it in pg.items() do
			n += 1
			itemTile(r, it, n)
		end
		local tHolder, tBtn = Toy.button(tabs, UDim2.fromOffset(px(132), px(36)), GREY, px(12))
		tHolder.LayoutOrder = i
		local tRow = Toy.frame(tBtn, { AutomaticSize = Enum.AutomaticSize.XY, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		Toy.list(tRow, true, px(5), { VerticalAlignment = Enum.VerticalAlignment.Center })
		Toy.icon(tRow, pg.icon, px(26), { LayoutOrder = 1 })
		text(tRow, pg.name, px(16), Color3.new(1, 1, 1), { LayoutOrder = 2, ZIndex = 3 })
		ui.tabs[pg.key] = tBtn
		if pg.key == "boosts" then
			ui.tabDot = Toy.dot(tBtn, px(18), { Visible = false }) -- the free gift is waiting on Boosts
		end
		tBtn.Activated:Connect(function()
			if page ~= pg.key then
				page = pg.key
				refresh()
				pop()
			end
		end)
	end
	refresh()
end

-- `tab` = the page to land on (the Get Qi offer opens Qi); the HUD button opens Boosts
local function open(source, tab)
	if gui.Enabled then
		return
	end
	page = "boosts"
	for _, pg in PAGES do
		if pg.key == tab then
			page = tab
		end
	end
	build()
	gui.Enabled = true
	pop()
	Sfx.play("toast")
	remotes.ShopOpened:FireServer(source or "hud")
	fetchPrices(refresh)
end

close = function()
	gui.Enabled = false
end

openEvent.Event:Connect(open)
local WATCH = { "AwayRate", "Realm", "Pass_x2", "Pass_auto", "Pass_vip", "ShopFreeIn" }
for _, it in Config.SHOP_PRODUCTS do
	if it.limit then
		table.insert(WATCH, "Limit_" .. it.key)
	end
end
for _, a in WATCH do
	player:GetAttributeChangedSignal(a):Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	if gui.Enabled then
		build()
	end
end)

---------------------------------------------------------------------------------------------
-- world shop: a card over each purple pad (peak and Disciple Garden), same language as the build pad cards
local cards = {}
local function padCard(pad)
	local key = pad:GetAttribute("ShopKey")
	local it = key and Config.shopItem(key)
	if not it or cards[pad] then
		return
	end
	-- a small tag low over the pad, name and price only (mock card_text_shop A, owner 2026-10-22:
	-- the text hid the disciples, "the models are enough"). Only the passes at the gate, which have
	-- no model of their own, keep a small icon.
	local iconSize = (key == "x2" or key == "vip") and 40 or nil
	local bb = Instance.new("BillboardGui")
	bb.Name = "ShopCard"
	bb.Adornee = pad
	bb.Size = UDim2.fromOffset(260, iconSize and 90 or 50)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 80 -- every island has ten cards: only the near ones draw
	bb.AlwaysOnTop = true -- same as the build pad cards (Build.client)
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	local f = Toy.frame(bb, { Size = UDim2.fromScale(1, 1) })
	Toy.list(f, false, 0, { VerticalAlignment = Enum.VerticalAlignment.Bottom })
	local function line(order, size, color, str)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AutomaticSize = Enum.AutomaticSize.XY
		t.Size = UDim2.new()
		t.FontFace = Toy.FONT
		t.TextSize = size
		t.TextColor3 = color
		t.LayoutOrder = order
		t.Text = str
		local st = Instance.new("UIStroke")
		st.Color = Toy.INK
		st.Thickness = math.max(2, size * 0.14)
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = t
		t.Parent = f
		return t
	end
	local bob
	if iconSize then
		local holder = Toy.frame(f, { Size = UDim2.fromOffset(iconSize, iconSize), LayoutOrder = 0 })
		bob = Toy.icon(holder, key, iconSize)
	end
	line(1, 16, PadLook.TEXT.title, it.name)
	local priceRow, price = Toy.amount(f, "robux", 17, PadLook.TEXT.shop, { LayoutOrder = 3 })
	cards[pad] = { bb = bb, price = price, robux = priceRow:FindFirstChild("Currency"), key = key, icon = bob, phase = pad.Position.X * 0.37 }
	bb.Parent = playerGui
end

local function refreshCards()
	for pad, c in cards do
		if not pad.Parent then
			c.bb:Destroy()
			cards[pad] = nil
		else
			local str, canBuy = priceText(c.key)
			local it = Config.shopItem(c.key)
			if it.minRealm and (player:GetAttribute("Realm") or 1) < it.minRealm then
				str = "Opens at " .. Config.realmName(it.minRealm) -- the pad has room for the name
			end
			c.price.Text = str
			c.robux.Visible = canBuy
			c.price.TextColor3 = canBuy and PadLook.TEXT.shop or Color3.fromHex("C8C0D0") -- grey: owned, or not on sale yet
		end
	end
end

-- shop pads stream in with each peak's shop island (StepPads of PadKind "shop")
local function onPad(d)
	if d:GetAttribute("PadKind") == "shop" then
		padCard(d)
		refreshCards()
	end
end
CollectionService:GetInstanceAddedSignal("StepPad"):Connect(onPad)
CollectionService:GetInstanceRemovedSignal("StepPad"):Connect(refreshCards)
-- the icons bob gently over their pads: only the near ones the camera sees (R16)
RunService.RenderStepped:Connect(function()
	local t0 = PerfMark.begin()
	local t = os.clock()
	local cam = workspace.CurrentCamera
	local eye = cam.CFrame.Position
	for pad, c in cards do
		local at = pad.Position
		if c.icon and (at - eye).Magnitude < c.bb.MaxDistance and PerfMark.onScreen(cam, at, 8) then
			c.icon.Position = UDim2.fromOffset(0, math.sin(t * 2 + c.phase) * 4)
		end
	end
	PerfMark.finish("shopCards", t0)
end)
task.spawn(function()
	for _, d in CollectionService:GetTagged("StepPad") do
		onPad(d)
	end
	fetchPrices(refreshCards)
	for _, a in WATCH do
		player:GetAttributeChangedSignal(a):Connect(refreshCards)
	end
end)

---------------------------------------------------------------------------------------------
-- Get Qi (research 2026-10-21_shop_placement, mock shop_layout_short.png): standing on a pad of
-- your own that you cannot afford yet shows one quiet offer under it for a few seconds; a tap opens
-- the Qi page. Once per step onto a pad, never a prompt by itself, and only while a pack is on sale.
local NUDGE_SECONDS = 4
local NUDGE_KINDS = { build = true, hire = true, breakthrough = true }
local nudgeGui = Instance.new("ScreenGui")
nudgeGui.Name = "ShopNudge"
nudgeGui.ResetOnSpawn = false
nudgeGui.IgnoreGuiInset = true
nudgeGui.DisplayOrder = 4 -- under the shop screen
nudgeGui.Enabled = false
nudgeGui.Parent = playerGui
local nudgeShown = 0

local function packOnSale()
	for _, it in Config.SHOP_PRODUCTS do
		if it.seconds and it.id ~= 0 then
			return true
		end
	end
	return RunService:IsStudio() -- Studio shows it with the ids still at 0 (the page then reads Soon)
end

local function commas(n)
	return (tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function showNudge(short)
	nudgeGui:ClearAllChildren()
	Toy.S = computeScale()
	local offer = Toy.frame(nudgeGui, { AutomaticSize = Enum.AutomaticSize.XY, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.84) })
	Toy.list(offer, true, px(12))
	text(offer, "Need", px(18), Color3.new(1, 1, 1), { LayoutOrder = 1 })
	local _, amount = Toy.amount(offer, "qi", px(18), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	amount.Text = commas(short)
	text(offer, "more", px(18), Color3.new(1, 1, 1), { LayoutOrder = 3 })
	local holder, btn = Toy.button(offer, UDim2.fromOffset(px(118), px(38)), BUY, px(12))
	holder.LayoutOrder = 4
	local inner = Toy.frame(btn, { AutomaticSize = Enum.AutomaticSize.XY, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	Toy.list(inner, true, px(5))
	Toy.icon(inner, "pack1", px(26), { LayoutOrder = 1 })
	text(inner, "Get Qi", px(17), Color3.new(1, 1, 1), { LayoutOrder = 2, ZIndex = 3 })
	btn.Activated:Connect(function()
		nudgeGui.Enabled = false
		open("short", "qi")
	end)
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = offer
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	nudgeGui.Enabled = true
	nudgeShown = os.clock()
end

task.spawn(function()
	local lastPad = nil -- the pad the offer was shown for (again only after stepping off it)
	while true do
		task.wait(0.25)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local here = nil
		if hrp then
			for _, p in CollectionService:GetTagged("StepPad") do
				if NUDGE_KINDS[p:GetAttribute("PadKind")] and p:GetAttribute("OwnerId") == player.UserId then
					local d = hrp.Position - p.Position
					if Vector2.new(d.X, d.Z).Magnitude < 2.6 and d.Y > -1 and d.Y < 7 then
						here = p
						break
					end
				end
			end
		end
		if here and here ~= lastPad then
			local short = (here:GetAttribute("Cost") or 0) - (player:GetAttribute("Qi") or 0)
			if short > 0 and not gui.Enabled and packOnSale() then
				showNudge(short)
			end
		end
		lastPad = here
		if nudgeGui.Enabled and (os.clock() - nudgeShown > NUDGE_SECONDS or gui.Enabled) then
			nudgeGui.Enabled = false
		end
	end
end)

---------------------------------------------------------------------------------------------
-- The Welcome Pouch offer card (mock docs/art/mocks/welcome_pouch_a.jpg, owner pick 2026-10-21):
-- the server sends "welcomeOffer" once (Config.WELCOME); the card shows what it gives and buys
-- through the usual prompt. "Not now" closes it; the Boosts tile stays until it is bought. A bought
-- Pouch plays the recruit reveal for its Elder.
local offerGui = Instance.new("ScreenGui")
offerGui.Name = "WelcomeOffer"
offerGui.ResetOnSpawn = false
offerGui.IgnoreGuiInset = true
offerGui.DisplayOrder = 6
offerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
offerGui.Enabled = false
offerGui.Parent = playerGui

local function showOffer()
	local it = Config.shopItem("welcome")
	if not it or player:GetAttribute("Limit_welcome") then
		return
	end
	offerGui:ClearAllChildren()
	Toy.S = computeScale()
	local veil = Instance.new("TextButton")
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 0.45
	veil.BorderSizePixel = 0
	veil.Parent = offerGui
	local body = Toy.frame(offerGui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY })
	Toy.list(body, false, px(8))
	local head = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	Toy.list(head, true, px(8))
	Toy.icon(head, "bag", px(46), { LayoutOrder = 1 })
	text(head, it.name, px(34), GOLD, { LayoutOrder = 2 })
	-- what it gives: the Elder (with its aura) + more qi forever
	local gives = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	Toy.list(gives, true, px(20), { VerticalAlignment = Enum.VerticalAlignment.Bottom })
	local r = Config.rarity(it.rarity)
	local left = Toy.frame(gives, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	Toy.list(left, false, px(1))
	Toy.disciple(left, px(86), it.rarity, { LayoutOrder = 1 })
	text(left, it.rarity, px(20), r.color, { LayoutOrder = 2 })
	text(left, string.format("+%d%%", math.floor(r.bonus * 100 + 0.5)), px(14), Color3.new(1, 1, 1), { LayoutOrder = 3 })
	local plusCol = Toy.frame(gives, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	Toy.list(plusCol, false, 0)
	text(plusCol, "+", px(30), GOLD, { LayoutOrder = 1 })
	Toy.frame(plusCol, { Size = UDim2.fromOffset(1, px(34)), LayoutOrder = 2 })
	local right = Toy.frame(gives, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	Toy.list(right, false, px(1))
	local drop = Toy.frame(right, { Size = UDim2.fromOffset(px(86), px(86)), LayoutOrder = 1 })
	Toy.icon(drop, "qi", px(60), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local pct = string.format("%d%%", math.floor(it.qiBonus * 100 + 0.5))
	text(drop, pct, px(22), GOLD, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, px(4), 1, -px(6)), ZIndex = 4 })
	text(right, "+" .. pct .. " Qi", px(20), Color3.fromHex("9FF5C8"), { LayoutOrder = 2 })
	text(right, "forever", px(14), Color3.new(1, 1, 1), { LayoutOrder = 3 })
	-- the price button, then "Not now"
	local bHolder, bBtn = Toy.button(body, UDim2.fromOffset(px(150), px(52)), BUY, px(14))
	bHolder.LayoutOrder = 3
	local priceRow, label = Toy.amount(bBtn, "robux", px(26), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	local function paint()
		local t, canBuy = priceText("welcome")
		label.Text = t
		local icon = priceRow:FindFirstChild("Currency")
		if icon then
			icon.Visible = canBuy
		end
	end
	paint()
	fetchPrices(paint)
	local notNow = Instance.new("TextButton")
	notNow.BackgroundTransparency = 1
	notNow.AutomaticSize = Enum.AutomaticSize.XY
	notNow.Size = UDim2.new()
	notNow.Text = ""
	notNow.LayoutOrder = 4
	notNow.Parent = body
	text(notNow, "Not now", px(15), Color3.fromHex("D9D0E8"))
	Toy.feel(notNow)
	local function closeOffer()
		offerGui.Enabled = false
	end
	notNow.Activated:Connect(closeOffer)
	veil.Activated:Connect(closeOffer)
	bBtn.Activated:Connect(function()
		local _, canBuy = priceText("welcome")
		if canBuy then
			remotes.ShopBuy:FireServer("welcome")
		end
	end)
	offerGui.Enabled = true
	Sfx.play("toast")
	local sc = Instance.new("UIScale")
	sc.Scale = 0.85
	sc.Parent = body
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

remotes.Notify.OnClientEvent:Connect(function(kind, rarity, kept)
	if kind == "welcomeOffer" then
		if not gui.Enabled then
			showOffer()
		end
	elseif kind == "shopWelcome" then
		-- bought: close the card and the shop, and let the recruit reveal show the Elder arrive
		offerGui.Enabled = false
		close()
		local fx = playerGui:FindFirstChild("RecruitFx")
		if fx then
			fx:Fire(rarity, kept)
		end
	end
end)
