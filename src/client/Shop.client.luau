-- Shop screen (layout A, owner pick 2026-10-23, docs/art/mocks/2026-10-23_shop_layout_A2_featured.jpg):
-- one dark panel, round tabs down its left (Featured, Passes, Qi, Disciples), the page's cards in a
-- grid that scrolls down. Opened by the HUD's Shop button and by the Get Qi
-- offer (Player.ShopOpen, a BindableEvent fired with the source and an optional page key). The
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
local TILE = { gift = "FFD36B", x2 = "9FF5C8", auto = "9FD0FF", vip = "FFD36B", pill = "FFB3A8", pack1 = "C9FFE4", pack2 = "B9F0D6", pack3 = "A6E8C8", welcome = "FFD36B", starter = "FFB3A8", tidebell = "9FD0FF", swordJade = "B9F5DC", swordHeavenly = "FFE29A", swordCelestial = "BFE4FF" }
-- a disciple sold on its own (the Welcome Pouch and the Starter Pack also hold one, inside a bundle)
local function soldDisciple(it)
	return it ~= nil and it.rarity ~= nil and not it.qiBonus and not it.seconds
end
-- disciples for sale: a pale tile of their rarity colour
local function tileColor(key)
	local it = Config.shopItem(key)
	if soldDisciple(it) then
		return Config.rarity(it.rarity).color:Lerp(Color3.new(1, 1, 1), 0.55)
	end
	return Color3.fromHex(TILE[key] or "C9FFE4")
end

local openEvent = Instance.new("BindableEvent")
openEvent.Name = "ShopOpen"
openEvent.Parent = player -- not PlayerGui: the first LoadCharacter (Main onJoin) empties it, live joins spawn after this runs

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
local page = "featured"
-- where Roblox restricts paid random items the server sells no qi (QiSaleOff, Shop.luau): the Qi
-- packs, the Get Qi offer and the Starter Pack are not drawn
local function qiSaleOff()
	return player:GetAttribute("QiSaleOff") == true
end
local function sellsQi(it)
	return it.seconds ~= nil
end
local function onSale(it)
	return not (sellsQi(it) and qiSaleOff())
end
-- the once-per-player bundles show until they are bought
local function bundleShown(key)
	local it = Config.shopItem(key)
	return it ~= nil and not player:GetAttribute("Limit_" .. key) and onSale(it)
end
local function keys(list)
	local out = {}
	for _, k in list do
		local it = Config.shopItem(k)
		if it and onSale(it) then
			table.insert(out, it)
		end
	end
	return out
end
local function products(pick)
	return function()
		local list = {}
		for _, it in Config.SHOP_PRODUCTS do
			if pick(it) and onSale(it) then
				table.insert(list, it)
			end
		end
		return list
	end
end
-- Layout A (owner pick 2026-10-23, docs/art/mocks/2026-10-23_shop_layout_A2_featured.jpg, copying
-- Pet Simulator 99's store): round category tabs down the left of one panel, the page's cards in a
-- grid that scrolls down. Featured leads with the two once-only bundles as big cards, then the
-- free Daily Gift and the owner's picks.
local FEATURED_BIG = { "starter", "welcome" }
local FEATURED = { "swordCelestial", "tidebell", "primordial", "emperor", "auto" }
local PAGES = {
	{ key = "featured", name = "Featured", icon = "gift", items = function() return keys(FEATURED) end },
	{ key = "passes", name = "Passes", icon = "x2", items = function() return table.clone(Config.SHOP_PASSES) end },
	{ key = "qi", name = "Qi", icon = "qi", items = function() return keys({ "pill", "tidebell", "pack1", "pack2", "pack3" }) end },
	{ key = "disciples", name = "Disciples", icon = "elder", items = products(soldDisciple) },
}

local function isTouch()
	local forced = player:GetAttribute("HudDevice") -- "phone" / "pc" forces a layout (testing)
	return if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
end
local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	if isTouch() then
		return math.clamp(vp.Y / 390, 0.78, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

local close -- forward

local BEST = "pack3" -- the one "Best value" ribbon (the most qi per Robux)
local NEW = { tidebell = true, swordJade = true, swordHeavenly = true, swordCelestial = true } -- cards wearing the "New" tag (drop a key once the item is not new)
local ONCE = { welcome = true, starter = true }

local function stroke(parent, color, thick, transp)
	local st = Instance.new("UIStroke")
	st.Color = color
	st.Thickness = thick
	st.Transparency = transp or 0
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = parent
	return st
end
-- top-lit face: the colour at the top, a little darker at the bottom
local function faceShade(face, dark)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(dark, dark, dark))
	g.Parent = face
end

-- the tilted tag on a card corner: blue "New" on the left, red "Once" / "Best value" on the right
local function ribbon(holder, key)
	local label = (key == BEST and "Best value") or (ONCE[key] and "Once") or nil
	local isNew = NEW[key] and not label
	if not (label or isNew) then
		return
	end
	local rib = Toy.frame(holder, { AutomaticSize = Enum.AutomaticSize.XY, AnchorPoint = Vector2.new(isNew and 0 or 1, 0), Position = isNew and UDim2.new(0, -px(8), 0, -px(8)) or UDim2.new(1, px(8), 0, -px(8)), Rotation = isNew and -10 or 8, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex(isNew and "4FD7FF" or "FF6B5E"), ZIndex = 6 })
	Toy.corner(rib, UDim.new(0, px(8)))
	stroke(rib, Toy.INK, px(2))
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(6)), UDim.new(0, px(6))
	pad.Parent = rib
	text(rib, label or "New", px(12), Color3.new(1, 1, 1), { ZIndex = 7 })
end

-- the round green price button (D73) with the Robux icon; returns holder, button, label, icon
local function priceButton(parent, w, h, order)
	local holder, btn = Toy.button(parent, UDim2.fromOffset(w, h), BUY, math.floor(h / 2))
	holder.LayoutOrder = order or 0
	local row, label = Toy.amount(btn, "robux", h - px(10), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	return holder, btn, label, row:FindFirstChild("Currency")
end

-- the one short value line under a card's name, with its icon: a disciple's bonus, a pack's qi,
-- a sword's tier stars; nil for the rest (owner: less text)
local function valueLine(col, it, size)
	if soldDisciple(it) then
		local _, l = Toy.amount(col, "qi", size, Color3.fromHex("E6FFF4"), { LayoutOrder = 3 })
		l.Text = string.match(it.line, "^(%+[%d,]+%%)") or ""
		return nil
	elseif it.seconds then
		local _, l = Toy.amount(col, "qi", size, Color3.fromHex("E6FFF4"), { LayoutOrder = 3 })
		return l -- refresh writes the pack's qi (it follows the income)
	elseif it.ride then
		local row = Toy.frame(col, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
		Toy.list(row, true, 0)
		for i = 1, it.ride do
			Toy.starGem(row, GOLD, { TextSize = size + px(2), LayoutOrder = i, ZIndex = 3 })
		end
	end
	return nil
end

-- one item card: a toy face of the item's colour, its icon, name, value line and price
local function card(parent, it, order, w, h, isGift)
	local key = isGift and "gift" or it.key
	local holder, btn = Toy.button(parent, UDim2.fromOffset(w, h), tileColor(key), px(18))
	holder.LayoutOrder = order
	faceShade(btn, 0.8)
	local sc = Instance.new("UIScale")
	sc.Name = "Pop"
	sc.Parent = holder
	ribbon(holder, key)
	local bh = math.clamp(math.floor(h * 0.17), px(22), px(28))
	local nameSize = math.clamp(math.floor(w / 8.4), px(11), px(15))
	local hasLine = not isGift and (soldDisciple(it) or it.seconds ~= nil or it.ride ~= nil)
	local isz = math.floor(math.min(w * 0.7, h - (nameSize + px(4)) - (hasLine and px(14) or 0) - (bh + px(11)) - h * 0.06 - px(4)))
	Toy.icon(btn, key, isz, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, math.floor(h * 0.06)), ZIndex = 3 })
	local col = Toy.frame(btn, { AutomaticSize = Enum.AutomaticSize.XY, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -px(7)), ZIndex = 3 })
	Toy.list(col, false, px(1))
	local name = isGift and "Daily Gift" or (it.short or it.name)
	local nameColor = (not isGift and soldDisciple(it)) and Config.rarity(it.rarity).color or Color3.new(1, 1, 1)
	text(col, name, #name > 12 and nameSize - px(2) or nameSize, nameColor, { LayoutOrder = 2, ZIndex = 3 })
	local lineLabel = (not isGift) and valueLine(col, it, px(11)) or nil
	Toy.frame(col, { Size = UDim2.fromOffset(1, px(3)), LayoutOrder = 4 })
	local _, pBtn, label, icon = priceButton(col, math.floor(w * 0.8), bh, 5)
	return btn, pBtn, label, icon, lineLabel
end

local function itemCard(parent, it, order, w, h)
	local btn, pBtn, label, icon, lineLabel = card(parent, it, order, w, h, false)
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
	table.insert(ui.items, { it = it, label = label, icon = icon, button = pBtn, line = lineLabel })
end

-- the free daily gift (owner: "give a small free daily gift"): the Shop's red dot leads here, and
-- claiming it is what clears that dot. ShopFreeIn = 0 when ready, else the seconds to wait.
local function freeCard(parent, w, h)
	local btn, pBtn, label, icon = card(parent, nil, 0, w, h, true)
	icon:Destroy()
	label.Text = "Free"
	local dot = Toy.dot(btn, px(18), { Visible = false })
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
end

-- a featured bundle: a wide card with its big icon, name, what is inside and its price
local BIG = {
	starter = { color = "1FB98A", parts = { { "disciple", "Immortal" }, { "icon", "pack2" }, { "icon", "pill" } } },
	welcome = { color = "F0A532", parts = { { "disciple", "Elder" }, { "qi", "+10%" } } },
}
local function bigCard(parent, key, order, w, h)
	local it = Config.shopItem(key)
	local look = BIG[key]
	local holder, btn = Toy.button(parent, UDim2.fromOffset(w, h), Color3.fromHex(look.color), px(22))
	holder.LayoutOrder = order
	faceShade(btn, 0.72)
	local sc = Instance.new("UIScale")
	sc.Name = "Pop"
	sc.Parent = holder
	ribbon(holder, key)
	local row = Toy.frame(btn, { AutomaticSize = Enum.AutomaticSize.XY, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	Toy.list(row, true, px(10), { VerticalAlignment = Enum.VerticalAlignment.Center })
	local big = math.floor(h * 0.66)
	Toy.icon(row, key, big, { LayoutOrder = 1, ZIndex = 3 })
	local col = Toy.frame(row, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2, ZIndex = 3 })
	Toy.list(col, false, px(4), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
	text(col, it.name, w > px(330) and px(22) or px(18), Color3.new(1, 1, 1), { LayoutOrder = 1, ZIndex = 3 })
	local parts = Toy.frame(col, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2, ZIndex = 3 })
	Toy.list(parts, true, px(4), { VerticalAlignment = Enum.VerticalAlignment.Center })
	local s = px(30)
	for i, p in look.parts do
		if i > 1 then
			text(parts, "+", px(16), Color3.new(1, 1, 1), { LayoutOrder = i * 2 - 1, ZIndex = 3 })
		end
		if p[1] == "disciple" then
			Toy.disciple(parts, s, p[2], { LayoutOrder = i * 2, ZIndex = 3 })
		elseif p[1] == "icon" then
			Toy.icon(parts, p[2], s, { LayoutOrder = i * 2, ZIndex = 3 })
		else
			local _, l = Toy.amount(parts, "qi", px(16), Color3.new(1, 1, 1), { LayoutOrder = i * 2, ZIndex = 3 })
			l.Text = p[2]
		end
	end
	local _, pBtn, label, icon = priceButton(col, px(104), px(34), 3)
	local function buy()
		local _, canBuy = priceText(key)
		if canBuy then
			remotes.ShopBuy:FireServer(key)
		end
	end
	btn.Activated:Connect(buy)
	pBtn.Activated:Connect(buy)
	table.insert(ui.items, { it = it, label = label, icon = icon, button = pBtn })
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
	local wait = player:GetAttribute("ShopFreeIn") or 1
	for key, b in ui.tabs or {} do
		b.BackgroundColor3 = key == page and Color3.fromHex("FFD36B") or GREY
		ui.tabLabels[key].TextColor3 = key == page and GOLD or Color3.new(1, 1, 1)
	end
	if ui.tabDot then
		ui.tabDot.Visible = wait == 0 and page ~= "featured"
	end
	if ui.free then
		ui.free.dot.Visible = wait == 0
		ui.free.button.BackgroundColor3 = wait == 0 and BUY or GREY
		ui.free.label.Text = wait == 0 and "Free" or (wait >= 3600 and string.format("%dh%02d", wait // 3600, wait % 3600 // 60) or string.format("%d:%02d", wait // 60, wait % 60))
	end
end

local function pop()
	-- cards spring in one after another
	local i = 0
	for _, d in (ui.grid or gui):GetDescendants() do
		if d:IsA("UIScale") and d.Name == "Pop" then
			i += 1
			d.Scale = 0.3
			TweenService:Create(d, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, math.min(i, 12) * 0.03), { Scale = 1 }):Play()
		end
	end
end

-- the open page's cards, into the scrolling grid (rebuilt on every tab change)
local function fillPage()
	local scroll = ui.grid
	scroll:ClearAllChildren()
	scroll.CanvasPosition = Vector2.zero
	ui.items, ui.free = {}, nil
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(10)), UDim.new(0, px(16))
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(8)), UDim.new(0, px(8))
	pad.Parent = scroll
	Toy.list(scroll, false, px(14), { HorizontalAlignment = Enum.HorizontalAlignment.Left })
	local inner = ui.gridWidth - px(16)
	local g = px(12)
	if page == "featured" then
		local big = {}
		for _, k in FEATURED_BIG do
			if bundleShown(k) then
				table.insert(big, k)
			end
		end
		if #big > 0 then
			local r = Toy.frame(scroll, { Size = UDim2.fromOffset(inner, ui.bigH), LayoutOrder = 1 })
			Toy.list(r, true, g)
			local w = math.floor((inner - g * (#FEATURED_BIG - 1)) / #FEATURED_BIG)
			for i, k in big do
				bigCard(r, k, i, #big == 1 and inner or w, ui.bigH)
			end
		end
	end
	local grid = Toy.frame(scroll, { Size = UDim2.fromOffset(inner, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(ui.cardW, ui.cardH)
	layout.CellPadding = UDim2.fromOffset(g, g)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local n = 0
	if page == "featured" then
		freeCard(grid, ui.cardW, ui.cardH)
	end
	for _, pg in PAGES do
		if pg.key == page then
			for _, it in pg.items() do
				n += 1
				itemCard(grid, it, n, ui.cardW, ui.cardH)
			end
		end
	end
	refresh()
end

local function build()
	gui:ClearAllChildren()
	Toy.S = computeScale()
	local touch = isTouch()
	ui = { items = {}, tabs = {}, tabLabels = {} }
	local vp = workspace.CurrentCamera.ViewportSize
	local W, H = vp.X / Toy.S, vp.Y / Toy.S -- in px() units

	local veil = Instance.new("TextButton")
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 0.4
	veil.BorderSizePixel = 0
	veil.Parent = gui
	veil.Activated:Connect(function()
		close()
	end)

	-- the panel: dark glass with an ink rim and a thin gold line inside, clear of a phone's notch
	local side = touch and 44 or 0
	local pw = math.min(W - side * 2 - 30, 820)
	local ph = H - (touch and 52 or 84)
	local panelHolder = Toy.frame(gui, { Size = UDim2.fromOffset(px(pw), px(ph)), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, px(touch and 40 or 52)), ZIndex = 2 })
	local shadow = Toy.frame(panelHolder, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(6)), BackgroundTransparency = 0, BackgroundColor3 = Toy.INK })
	Toy.corner(shadow, UDim.new(0, px(26)))
	local panel = Instance.new("TextButton") -- swallows taps so they do not close the shop
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.BorderSizePixel = 0
	panel.Parent = panelHolder
	Toy.corner(panel, UDim.new(0, px(26)))
	local pg = Instance.new("UIGradient")
	pg.Rotation = 90
	pg.Color = ColorSequence.new(Color3.fromHex("2E2246"), Color3.fromHex("1A1328"))
	pg.Parent = panel
	stroke(panel, Toy.INK, px(4))
	local gold = Toy.frame(panel, { Size = UDim2.new(1, -px(6), 1, -px(6)), Position = UDim2.fromOffset(px(3), px(3)) })
	Toy.corner(gold, UDim.new(0, px(23)))
	stroke(gold, Color3.fromHex("FFD66B"), px(2), 0.5)

	text(gui, "Shop", px(34), GOLD, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, -px(pw / 2 - 14), 0, px(touch and 40 or 52) + px(14)), Rotation = -2, ZIndex = 4 })
	-- close: a round red X on the panel's top right corner (D73)
	local xHolder, xBtn = Toy.button(gui, UDim2.fromOffset(px(44), px(44)), Color3.fromHex("FF6B5E"), px(22))
	xHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	xHolder.Position = UDim2.new(0.5, px(pw / 2 - 8), 0, px(touch and 40 or 52) + px(6))
	xHolder.ZIndex = 4
	text(xBtn, "X", px(24), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 })
	xBtn.Activated:Connect(function()
		close()
	end)

	-- the rail: one round tab per page, its name under it
	local railW = 86
	local ts = touch and 44 or 52
	local rail = Toy.frame(panel, { Size = UDim2.new(0, px(railW), 1, -px(24)), Position = UDim2.fromOffset(0, px(touch and 14 or 22)), ZIndex = 3 })
	Toy.list(rail, false, px(touch and 6 or 12), { HorizontalAlignment = Enum.HorizontalAlignment.Center })
	Toy.frame(panel, { Size = UDim2.new(0, px(3), 1, -px(28)), Position = UDim2.fromOffset(px(railW), px(14)), BackgroundTransparency = 0.75, BackgroundColor3 = Color3.fromHex("FFD66B") })
	for i, p in PAGES do
		local col = Toy.frame(rail, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = i, ZIndex = 3 })
		Toy.list(col, false, px(2))
		local tHolder, tBtn = Toy.button(col, UDim2.fromOffset(px(ts), px(ts)), GREY, px(ts / 2))
		tHolder.LayoutOrder = 1
		Toy.icon(tBtn, p.icon, px(ts * 0.74), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		ui.tabs[p.key] = tBtn
		ui.tabLabels[p.key] = text(col, p.name, px(12), Color3.new(1, 1, 1), { LayoutOrder = 2, ZIndex = 3 })
		if p.key == "featured" then
			ui.tabDot = Toy.dot(tBtn, px(16), { Visible = false }) -- the free gift is waiting on Featured
		end
		tBtn.Activated:Connect(function()
			if page ~= p.key then
				page = p.key
				fillPage()
				pop()
			end
		end)
	end

	-- the page: a grid that scrolls down, a gold bar on the right
	local gx = railW + 14
	local gw = pw - gx - 22
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Grid"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(px(gx), px(touch and 8 or 14))
	scroll.Size = UDim2.new(0, px(gw + 14), 1, -px(touch and 16 or 28))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = px(6)
	scroll.ScrollBarImageColor3 = Color3.fromHex("FFD34D")
	scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	scroll.ElasticBehavior = Enum.ElasticBehavior.Always
	scroll.ZIndex = 3
	scroll.Parent = panel
	ui.grid = scroll
	ui.gridWidth = px(gw)
	local cols = touch and 5 or 6
	ui.cardW = math.floor((px(gw) - px(16) - px(12) * (cols - 1)) / cols)
	ui.cardH = math.floor(ui.cardW * 1.3)
	ui.bigH = px(touch and 128 or 150)
	fillPage()
end

-- `tab` = the page to land on (the Get Qi offer opens Qi); the HUD button opens Featured
local function open(source, tab)
	if gui.Enabled then
		return
	end
	page = "featured"
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
local WATCH = { "AwayRate", "Realm", "ShopFreeIn" }
for _, it in Config.SHOP_PASSES do
	table.insert(WATCH, "Pass_" .. it.key)
end
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
player:GetAttributeChangedSignal("QiSaleOff"):Connect(function()
	if gui.Enabled then
		build() -- the Qi packs and the Starter Pack come or go
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
	bb.ResetOnSpawn = false -- in PlayerGui: the first spawn would wipe it (live joins spawn late)
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
	if qiSaleOff() then
		return false
	end
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
	remotes.OfferShown:FireServer("welcome") -- the once-only offer counts as made only now
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

---------------------------------------------------------------------------------------------
-- The Sect Starter Pack offer card (owner pick "B night jade" 2026-10-23, mock
-- docs/art/mocks/starter_pack_B_jade.jpg): a gold frame round a night-jade panel, soft gold rays
-- and a glow behind the Immortal with its aura, a gold title, "Only once", the two other gifts as
-- chips, the green price button and "Not now". The server sends "starterOffer" once
-- (Config.STARTER_OFFER); the Boosts tab keeps a "Once" tile first until it is bought. No discount
-- is claimed: it shows what it gives.
local starterGui = Instance.new("ScreenGui")
starterGui.Name = "StarterOffer"
starterGui.ResetOnSpawn = false
starterGui.IgnoreGuiInset = true
starterGui.DisplayOrder = 6
starterGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
starterGui.Enabled = false
starterGui.Parent = playerGui

local JADE_TOP, JADE_MID, JADE_DEEP = Color3.fromHex("1F8F70"), Color3.fromHex("0D4A3D"), Color3.fromHex("06201C")
local CREAM = Color3.fromHex("FFE9B0")
local PALE_GOLD = Color3.fromHex("FFD34D")

-- a gold corner ornament: an L of two bars hugging corner (sx, sy) and a small ring inside its bend
local function ornament(parent, sx, sy)
	local ax, ay = sx > 0 and 1 or 0, sy > 0 and 1 or 0
	local box = Toy.frame(parent, { Size = UDim2.fromOffset(px(42), px(42)), AnchorPoint = Vector2.new(ax, ay), Position = UDim2.new(ax, -sx * px(9), ay, -sy * px(9)), ZIndex = 3 })
	for _, size in { UDim2.fromOffset(px(42), px(4)), UDim2.fromOffset(px(4), px(42)) } do
		local f = Toy.frame(box, { Size = size, AnchorPoint = Vector2.new(ax, ay), Position = UDim2.fromScale(ax, ay), BackgroundTransparency = 0, BackgroundColor3 = PALE_GOLD, ZIndex = 3 })
		Toy.corner(f, UDim.new(1, 0))
	end
	local ring = Toy.frame(box, { Size = UDim2.fromOffset(px(12), px(12)), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(ax, -sx * px(15), ay, -sy * px(15)), ZIndex = 3 })
	Toy.corner(ring, UDim.new(1, 0))
	local st = Instance.new("UIStroke")
	st.Color = PALE_GOLD
	st.Thickness = math.max(1, px(2.5))
	st.Parent = ring
end

-- one gift chip: its icon, a bold name and a cream line, on a dark plate with a soft gold edge
local function chip(parent, order, icon, name, line)
	local c = Toy.frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order, BackgroundTransparency = 0.65, BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 3 })
	Toy.corner(c, UDim.new(0, px(12)))
	local st = Instance.new("UIStroke")
	st.Color = PALE_GOLD
	st.Transparency = 0.45
	st.Thickness = px(2)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = c
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(5)), UDim.new(0, px(11))
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(3)), UDim.new(0, px(3))
	pad.Parent = c
	Toy.list(c, true, px(5), { VerticalAlignment = Enum.VerticalAlignment.Center })
	Toy.icon(c, icon, px(36), { LayoutOrder = 1, ZIndex = 4 })
	local words = Toy.frame(c, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2, ZIndex = 4 })
	Toy.list(words, false, 0, { HorizontalAlignment = Enum.HorizontalAlignment.Left })
	text(words, name, px(15), Color3.new(1, 1, 1), { LayoutOrder = 1, ZIndex = 4 })
	text(words, line, px(10), CREAM, { LayoutOrder = 2, ZIndex = 4 })
end

-- The real disciple (as the Streak and Gifts cards draw it): a copy of the one standing in this
-- peak's Disciple Garden (Shop.luau, ForSale_<key>) facing the camera in a viewport, over the rarity's
-- UI aura; the atlas figure in its well if the garden has not streamed in.
local function heroFigure(parent, size, rarity, props)
	local key = Config.shopKeyOf(rarity)
	local sect = workspace:FindFirstChild("Sect")
	local peak = sect and sect:FindFirstChild("Peak" .. tostring(player:GetAttribute("PlotIndex")))
	local garden = peak and peak:FindFirstChild("DiscipleGarden", true)
	local src = garden and key and garden:FindFirstChild("ForSale_" .. key, true)
	local copy
	if src and src:IsA("Model") then
		local old = src.Archivable
		src.Archivable = true
		copy = src:Clone()
		src.Archivable = old
	end
	if not copy then
		return Toy.disciple(parent, size, rarity, props)
	end
	local holder = Toy.frame(parent, { Size = UDim2.fromOffset(size, size) })
	for k, v in props or {} do
		holder[k] = v
	end
	Toy.aura(holder, Config.rarityIndex(rarity), size)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.ZIndex = (props and props.ZIndex or 1) + 2
	vp.Ambient = Color3.fromRGB(170, 165, 175)
	vp.LightColor = Color3.fromRGB(255, 245, 230)
	vp.LightDirection = Vector3.new(-0.3, -1, 0.5)
	vp.Parent = holder
	for _, d in copy:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	copy:PivotTo(CFrame.identity) -- the seat faces its LookVector: -Z here
	copy.Parent = vp
	local cf, ext = copy:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 28
	local focus = cf.Position + Vector3.new(0, ext.Y * 0.12, 0)
	cam.CFrame = CFrame.lookAt(focus + Vector3.new(0, ext.Y * 0.08, -ext.Y * 2.3), focus)
	cam.Parent = vp
	vp.CurrentCamera = cam
	return holder
end

local function showStarter()
	local it = Config.shopItem("starter")
	if not it or player:GetAttribute("Limit_starter") then
		return
	end
	remotes.OfferShown:FireServer("starter") -- the once-only offer counts as made only now
	starterGui:ClearAllChildren()
	Toy.S = computeScale()
	local veil = Instance.new("TextButton")
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("06040F")
	veil.BackgroundTransparency = 0.34
	veil.BorderSizePixel = 0
	veil.Parent = starterGui
	-- the gold frame (ink rim and drop like every toy plate), the jade panel inside it
	local holder = Toy.frame(starterGui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(px(452), px(346)) })
	local drop = Toy.frame(holder, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(6)), BackgroundTransparency = 0, BackgroundColor3 = Toy.INK })
	Toy.corner(drop, UDim.new(0, px(22)))
	local rim = Toy.frame(holder, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 1 })
	Toy.corner(rim, UDim.new(0, px(22)))
	local gold = Instance.new("UIGradient")
	gold.Rotation = 70
	gold.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("FFF4C2")),
		ColorSequenceKeypoint.new(0.3, Color3.fromHex("E9A92C")),
		ColorSequenceKeypoint.new(0.52, Color3.fromHex("8E520A")),
		ColorSequenceKeypoint.new(0.75, Color3.fromHex("F6C040")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("FFF0B0")),
	})
	gold.Parent = rim
	local ink = Instance.new("UIStroke")
	ink.Color = Toy.INK
	ink.Thickness = px(4)
	ink.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ink.Parent = rim
	local panel = Instance.new("CanvasGroup") -- clips the rays to the rounded panel
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -px(12), 1, -px(12))
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.ZIndex = 2
	panel.Parent = holder
	Toy.corner(panel, UDim.new(0, px(17)))
	-- night jade on its own back plate: a UIGradient on the CanvasGroup itself would tint everything
	-- drawn in it (the title, the chips, the button)
	local back = Toy.frame(panel, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 1 })
	local shade = Instance.new("UIGradient") -- lighter round the hero, deep at the foot
	shade.Rotation = 90
	shade.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, JADE_MID), ColorSequenceKeypoint.new(0.35, JADE_TOP), ColorSequenceKeypoint.new(0.7, JADE_MID), ColorSequenceKeypoint.new(1, JADE_DEEP) })
	shade.Parent = back
	-- soft gold rays turning slowly and a warm glow behind the hero
	local heroY = px(124)
	Toy.atlasPiece(panel, "glow", px(380), px(300), Color3.fromHex("3FD6A8"), 0.35, { Position = UDim2.new(0.5, 0, 0, heroY), ZIndex = 2 })
	local rays = Toy.atlasPiece(panel, "rays12", px(560), px(560), Color3.fromHex("FFDC78"), 0.55, { Position = UDim2.new(0.5, 0, 0, heroY), ZIndex = 2 })
	Toy.atlasPiece(panel, "glow", px(250), px(250), Color3.fromHex("FFE28C"), 0.2, { Position = UDim2.new(0.5, 0, 0, heroY), ZIndex = 2 })
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			ornament(panel, sx, sy)
		end
	end
	for _, s in { { 0.27, 0.27, 16 }, { 0.71, 0.21, 22 }, { 0.68, 0.5, 12 }, { 0.3, 0.52, 11 } } do
		Toy.atlasPiece(panel, "sparkle", px(s[3]), px(s[3]), Color3.fromHex("FFF7D0"), 0, { Position = UDim2.fromScale(s[1], s[2]), ZIndex = 3 })
	end
	local body = Toy.frame(panel, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	Toy.list(body, false, px(4))
	local top = Instance.new("UIPadding")
	top.PaddingTop = UDim.new(0, px(6))
	top.Parent = body
	local title = text(body, it.name, px(32), Color3.new(1, 1, 1), { LayoutOrder = 1, ZIndex = 4 })
	local tg = Instance.new("UIGradient")
	tg.Rotation = 90
	tg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("FFFBE0")), ColorSequenceKeypoint.new(0.55, PALE_GOLD), ColorSequenceKeypoint.new(1, Color3.fromHex("E08A12")) })
	tg.Parent = title
	text(body, "Only once", px(14), CREAM, { LayoutOrder = 2, ZIndex = 4 })
	-- the hero: the real Immortal with its aura, its bonus under it
	local r = Config.rarity(it.rarity)
	heroFigure(body, px(128), it.rarity, { LayoutOrder = 3, ZIndex = 4 })
	text(body, string.format("%s +%d%%", it.rarity, math.floor(r.bonus * 100 + 0.5)), px(20), PALE_GOLD, { LayoutOrder = 4, ZIndex = 4 })
	local chips = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 5, ZIndex = 3 })
	Toy.list(chips, true, px(12), { VerticalAlignment = Enum.VerticalAlignment.Center })
	local hours = math.floor(it.seconds / 3600 + 0.5)
	chip(chips, 1, "pack2", "Qi Chest", string.format("%d hour%s of income", hours, hours == 1 and "" or "s"))
	chip(chips, 2, "pill", "2x Qi", string.format("%d minutes", math.floor(it.pill / 60 + 0.5)))
	Toy.frame(body, { Size = UDim2.fromOffset(1, px(2)), LayoutOrder = 6 })
	-- the price button (a light stripe across it) and "Not now" beside it
	local buyRow = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 7, ZIndex = 3 })
	Toy.list(buyRow, true, px(16), { VerticalAlignment = Enum.VerticalAlignment.Center })
	local bHolder, bBtn = Toy.button(buyRow, UDim2.fromOffset(px(150), px(46)), BUY, px(14))
	bHolder.LayoutOrder = 1
	bBtn.ClipsDescendants = true
	Toy.frame(bBtn, { Name = "Shine", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.66, 0.5), Size = UDim2.new(0, px(18), 1.8, 0), Rotation = 20, BackgroundTransparency = 0.6, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2 })
	local priceRow, label = Toy.amount(bBtn, "robux", px(26), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	local function paint()
		local t, canBuy = priceText("starter")
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
	notNow.LayoutOrder = 2
	notNow.ZIndex = 4
	notNow.Parent = buyRow
	text(notNow, "Not now", px(15), CREAM, { ZIndex = 4 })
	Toy.feel(notNow)
	local function closeCard()
		starterGui.Enabled = false
	end
	notNow.Activated:Connect(closeCard)
	veil.Activated:Connect(closeCard)
	bBtn.Activated:Connect(function()
		local _, canBuy = priceText("starter")
		if canBuy then
			remotes.ShopBuy:FireServer("starter")
		end
	end)
	starterGui.Enabled = true
	Sfx.play("toast")
	local sc = Instance.new("UIScale")
	sc.Scale = 0.85
	sc.Parent = holder
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- the rays turn while the card is up (one looping tween, cancelled with the card: R16)
	local spin = TweenService:Create(rays, TweenInfo.new(40, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 })
	spin:Play()
	starterGui:GetPropertyChangedSignal("Enabled"):Once(function()
		spin:Cancel()
	end)
end

-- An offer card waits until nothing covers it: the launch screen's tap (LaunchDone), the Heavenly Gift
-- intro (WelcomeQi back to 0, its Intro gui closed), the Shop screen and the other offer card. The
-- server sends each offer once, so it is queued here, never dropped.
-- The Intro, the Daily Blessing (Streak), the Free Gifts and the idle chest screens stay Enabled and
-- empty their children when closed, so "up" = Enabled AND drawing something; a missing gui is clear.
local COVERS = { "Intro", "Streak", "Gifts", "IdleChest" }
local function coverUp()
	for _, name in COVERS do
		local g = playerGui:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled and #g:GetChildren() > 0 then
			return true
		end
	end
	return false
end

local function whenClear(show)
	task.spawn(function()
		while true do
			local covered = not player:GetAttribute("LaunchDone")
				or (player:GetAttribute("WelcomeQi") or 0) > 0
				or coverUp()
				or gui.Enabled
				or offerGui.Enabled
				or starterGui.Enabled
			if not covered then
				show()
				return
			end
			task.wait(0.5)
		end
	end)
end

-- Studio test hook: local player attribute StarterCard = true draws the card (no offer, no purchase)
player:GetAttributeChangedSignal("StarterCard"):Connect(function()
	if player:GetAttribute("StarterCard") then
		showStarter()
	end
end)

remotes.Notify.OnClientEvent:Connect(function(kind, rarity, kept)
	if kind == "welcomeOffer" then
		whenClear(showOffer)
	elseif kind == "starterOffer" then
		whenClear(showStarter)
	elseif kind == "shopWelcome" or kind == "shopDisciple" or kind == "shopStarter" then
		-- bought: close the card and the shop, and let the recruit reveal show the disciple arrive
		-- (owner 2026-10-22: every Robux disciple plays the recruit reveal)
		offerGui.Enabled = false
		starterGui.Enabled = false
		close()
		local fx = player:FindFirstChild("RecruitFx")
		if fx then
			fx:Fire(rarity, kept)
		end
	end
end)
