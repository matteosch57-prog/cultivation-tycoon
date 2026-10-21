-- Shop screen (mock B, docs/art/mocks/shop_B_phone.jpg, D24): no board, toy tiles floating over a
-- dark veil. Boosts (passes + Instant Pill) on one row, Qi packs on the next; a phone that cannot
-- fit both rows gets a "More Qi" tile that flips to the packs. Opened by the HUD's Shop button
-- (PlayerGui.ShopOpen, a BindableEvent fired with the source). The server prompts and grants
-- (R9): a tap only sends the item key. Also draws the cards over the purple pads on the hub.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local PadLook = require(Shared:WaitForChild("PadLook"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local px, text = Toy.px, Toy.text
local GOLD = Color3.fromHex("FFE36B")
local BUY = Color3.fromHex("47D16C")
local GREY = Color3.fromHex("C9C2D3")
local TILE = { x2 = "9FF5C8", auto = "9FD0FF", vip = "FFD36B", pill = "FFB3A8", pack1 = "C9FFE4", pack2 = "B9F0D6", pack3 = "A6E8C8", more = "C9FFE4", back = "9FF5C8" }
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

-- "Owned" / "Soon" (no id yet) / the price
local function priceText(key)
	local it, isPass = Config.shopItem(key)
	if isPass and player:GetAttribute("Pass_" .. key) then
		return "Owned", false
	elseif not it or it.id == 0 then
		return "Soon", false
	end
	return Toy.ROBUX .. " " .. (prices[key] and tostring(prices[key]) or "..."), true
end

local function packQi(it)
	local q = math.floor((player:GetAttribute("AwayRate") or 0) * it.seconds)
	local s = tostring(q):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "+" .. s .. " Qi"
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

local function tile(parent, key, order, name, line)
	local col = Toy.frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order, Rotation = TILT[(order - 1) % #TILT + 1] })
	Toy.list(col, false, px(2))
	local holder, btn = Toy.button(col, UDim2.fromOffset(px(92), px(92)), Color3.fromHex(TILE[key] or "C9FFE4"), px(20))
	holder.LayoutOrder = 1
	Toy.icon(btn, key == "more" and "pack2" or (key == "back" and "x2" or key), px(68), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local sc = Instance.new("UIScale")
	sc.Name = "Pop"
	sc.Parent = col
	text(col, name, px(17), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	local lineLabel = line and text(col, line, px(12), Color3.fromHex("C9FFE4"), { LayoutOrder = 3 }) or nil
	return col, btn, lineLabel
end

local function itemTile(parent, it, order)
	local col, btn, lineLabel = tile(parent, it.key, order, it.name, it.line)
	Toy.frame(col, { Size = UDim2.fromOffset(1, px(3)), LayoutOrder = 4 })
	local pHolder, pBtn = Toy.button(col, UDim2.fromOffset(px(96), px(32)), BUY, px(10))
	pHolder.LayoutOrder = 5
	local label = text(pBtn, "", px(16), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
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
	table.insert(ui.items, { it = it, label = label, button = pBtn, line = lineLabel })
	return col
end

local function row(parent, order)
	local r = Toy.frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order })
	Toy.list(r, true, px(24), { VerticalAlignment = Enum.VerticalAlignment.Top })
	return r
end

local function refresh()
	if not ui.items then
		return
	end
	for _, rec in ui.items do
		local str, canBuy = priceText(rec.it.key)
		rec.label.Text = str
		rec.button.BackgroundColor3 = canBuy and BUY or GREY
		if rec.it.seconds and rec.line then
			rec.line.Text = packQi(rec.it)
		end
	end
	if ui.boosts then
		ui.boosts.Visible = ui.both or page == "boosts"
		ui.packs.Visible = ui.both or page == "qi"
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
	local vp = workspace.CurrentCamera.ViewportSize
	-- room for both rows (computers), else two pages (phones)
	ui.both = vp.Y >= px(520) and player:GetAttribute("HudDevice") ~= "phone"

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
	-- title + close
	local head = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1, Rotation = -2 })
	Toy.list(head, true, px(14))
	text(head, "Shop", px(34), GOLD, { LayoutOrder = 1 })
	local xHolder, xBtn = Toy.button(head, UDim2.fromOffset(px(34), px(34)), Color3.fromHex("FF6B5E"), px(10))
	xHolder.LayoutOrder = 2
	text(xBtn, "X", px(20), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	xBtn.Activated:Connect(function()
		close()
	end)

	ui.boosts = row(body, 2)
	for i, it in Config.SHOP_PASSES do
		itemTile(ui.boosts, it, i)
	end
	itemTile(ui.boosts, Config.shopItem("pill"), #Config.SHOP_PASSES + 1)
	ui.packs = row(body, 3)
	local n = 0
	for _, it in Config.SHOP_PRODUCTS do
		if it.seconds then
			n += 1
			itemTile(ui.packs, it, n)
		end
	end
	if not ui.both then
		-- page flips: "More Qi" on the boosts row, "Boosts" back on the packs row
		local _, moreBtn = tile(ui.boosts, "more", 10, "More Qi")
		moreBtn.Activated:Connect(function()
			page = "qi"
			refresh()
			pop()
		end)
		local _, backBtn = tile(ui.packs, "back", 10, "Boosts")
		backBtn.Activated:Connect(function()
			page = "boosts"
			refresh()
			pop()
		end)
	end
	refresh()
end

local function open(source)
	if gui.Enabled then
		return
	end
	page = "boosts"
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
for _, a in { "AwayRate", "Pass_x2", "Pass_auto", "Pass_vip" } do
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
-- world shop: a card over each purple pad on the hub (same language as the build pad cards)
local cards = {}
local function padCard(pad)
	local key = pad:GetAttribute("ShopKey")
	local it = key and Config.shopItem(key)
	if not it or cards[pad] then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "ShopCard"
	bb.Adornee = pad
	bb.Size = UDim2.fromOffset(260, 92)
	bb.StudsOffset = Vector3.new(0, 5.5, 0)
	bb.MaxDistance = 110
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
	line(1, 22, PadLook.TEXT.title, it.name)
	line(2, 15, PadLook.TEXT.line, it.line)
	cards[pad] = { bb = bb, price = line(3, 26, PadLook.TEXT.shop, ""), key = key }
	bb.Parent = playerGui
end

local function refreshCards()
	for pad, c in cards do
		if not pad.Parent then
			c.bb:Destroy()
			cards[pad] = nil
		else
			local str, canBuy = priceText(c.key)
			c.price.Text = str
			c.price.TextColor3 = canBuy and PadLook.TEXT.shop or Color3.fromHex("C8C0D0") -- grey: owned, or not on sale yet
		end
	end
end

task.spawn(function()
	local hub = workspace:WaitForChild("Sect"):WaitForChild("Hub")
	for _, d in hub:GetChildren() do
		padCard(d)
	end
	hub.ChildAdded:Connect(function(d)
		padCard(d)
		refreshCards()
	end)
	refreshCards()
	fetchPrices(refreshCards)
	for _, a in { "Pass_x2", "Pass_auto", "Pass_vip" } do
		player:GetAttributeChangedSignal(a):Connect(refreshCards)
	end
end)
