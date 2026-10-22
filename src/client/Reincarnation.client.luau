-- Rebirth screen (Muscle Legends' rebirth, docs/research/2026-10-22_rebirth_standard.md): the price in
-- qi, the boost now and after, the karma it pays, one button. Opened by the HUD's Rebirth button
-- (PlayerGui.ReincOpen, a BindableEvent). Same language as the Shop: no board, toy pieces over a
-- dark veil. The server decides (R9): the button only asks; a second tap confirms.
-- A second page, the Karma Shop (Config.DAO), spends karma on permanent nodes.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local px, text = Toy.px, Toy.text
local GOLD = Color3.fromHex("FFE36B")
local JADE = Color3.fromHex("59D39F")
local CONFIRM = Color3.fromHex("FF8A5C")
local LOCKED = Color3.fromHex("C9C2D3")
local KARMA = Color3.fromHex("D9B8FF")
local TILE = { sworn = "9FD0FF", seat = "FFD36B", foundation = "9FF5C8", rebirth = "FFC9A6", elixir = "FFB3A8", meditation = "C9C2FF", echo = "E6C9FF", hands = "FFF0A6" }
local TILT = { -2, 1.5, -1, 2, 1, -1.5, 2, -1 }
local PER_ROW = 4

-- the red dots lit when this screen opened (server Dots.luau): a snapshot, so they stay on while the
-- screen is open although the server clears its own as soon as MenuOpened arrives
local snap = {}
local function litDots()
	local ok, t = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Dots") or "{}")
	return ok and type(t) == "table" and t or {}
end
local function karmaNew(key, level)
	return table.find(snap.karma or {}, key .. ":" .. level) ~= nil
end

local openEvent = Instance.new("BindableEvent")
openEvent.Name = "ReincOpen"
openEvent.Parent = playerGui

local gui = Instance.new("ScreenGui")
gui.Name = "Reincarnation"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5 -- over the HUD
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = playerGui

local ui = {}
local armedUntil = 0 -- second tap within this time confirms
local busy = false
local page = "road" -- "road" | "karma"

local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice")
	local touch = if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
	if touch then
		return math.clamp(vp.Y / 390, 0.78, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

local function commas(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- 12.3K, 4.5M ... (the qi counter's style)
local function compact(n)
	local units, i = { "K", "M", "B", "T", "Qa", "Qn" }, 0
	while n >= 1000 and i < #units do
		n /= 1000
		i += 1
	end
	if i == 0 then
		return commas(n)
	end
	return string.format(n < 10 and "%.1f%s" or "%d%s", n, units[i])
end

-- x1.05, x1.5, x12 (a boost that adds 5% a rebirth needs its decimals)
local function mult(m)
	local t = string.format("%.2f", m):gsub("0+$", ""):gsub("%.$", "")
	return "x" .. t
end

local close -- forward

-- an amount of a currency: its icon, then the number (owner: every currency always shows its icon)
local function amount(parent, key, size, color, props)
	local row = Toy.frame(parent, { AutomaticSize = Enum.AutomaticSize.XY })
	for k, v in props or {} do
		row[k] = v
	end
	Toy.list(row, true, math.floor(size * 0.2))
	Toy.icon(row, key, math.floor(size * 1.25), { LayoutOrder = 1 })
	local t = text(row, "", size, color, { LayoutOrder = 2 })
	return t, row
end

local function refreshKarma()
	local have = player:GetAttribute("Karma") or 0
	ui.karma.Text = commas(have)
	for _, t in ui.tiles do
		local lv = player:GetAttribute("Dao_" .. t.node.key) or 0
		local cost = t.node.costs[lv + 1]
		if t.node.lines then -- the line names what the NEXT level gives
			t.line.Text = t.node.lines[math.min(lv + 1, #t.node.lines)]
		end
		for i, pip in t.pips do
			pip.BackgroundColor3 = i <= lv and GOLD or Color3.fromHex("3A2D40")
		end
		t.priceIcon.Visible = cost ~= nil
		if not cost then
			t.price.Text = "Max"
			t.button.BackgroundColor3 = LOCKED
		else
			t.price.Text = commas(cost)
			t.button.BackgroundColor3 = have >= cost and JADE or LOCKED
		end
	end
end

local function refresh()
	if not ui.body then
		return
	end
	if page == "karma" then
		refreshKarma()
		return
	end
	local qi = player:GetAttribute("Qi") or 0
	local price = player:GetAttribute("RebirthPrice") or Config.rebirthPrice(0)
	local ready = qi >= price
	ui.title.Text = "Rebirth " .. ((player:GetAttribute("Rebirths") or 0) + 1)
	ui.now.Text = mult(player:GetAttribute("RebirthMult") or 1)
	ui.after.Text = mult(player:GetAttribute("NextRebirthMult") or 1)
	ui.price.Text = compact(math.min(qi, price)) .. " / " .. compact(price)
	ui.fill.Size = UDim2.fromScale(math.clamp(qi / math.max(price, 1), 0, 1), 1)
	ui.fill.BackgroundColor3 = ready and JADE or GOLD
	ui.gain.Text = "+" .. commas(player:GetAttribute("RebirthKarma") or 0)

	-- the next realm waits for rebirths (Config.REBIRTH_REALMS): say which one this opens
	local need = player:GetAttribute("RealmNeedsRebirths") or 0
	local done = player:GetAttribute("Rebirths") or 0
	local realm = player:GetAttribute("Realm") or 1
	ui.opens.Visible = need > done and need == done + 1
	ui.opens.Text = "Opens " .. Config.realmName(realm + 1)

	-- the button
	local armed = os.clock() < armedUntil
	if not ready then
		ui.btn.BackgroundColor3 = LOCKED
		ui.btnLabel.Text = "Rebirth!"
	elseif armed then
		ui.btn.BackgroundColor3 = CONFIRM
		ui.btnLabel.Text = "Sure? Tap again"
	else
		ui.btn.BackgroundColor3 = JADE
		ui.btnLabel.Text = "Rebirth!"
	end
end

local build -- forward
local function goTo(p)
	page = p
	armedUntil = 0
	snap = litDots()
	build()
	if p == "karma" then
		remotes.MenuOpened:FireServer("karma") -- analytics Menu (DATA.md)
	end
end

local function head(body, title)
	local h = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1, Rotation = -2 })
	Toy.list(h, true, px(14))
	if page == "karma" then
		local bHolder, bBtn = Toy.button(h, UDim2.fromOffset(px(34), px(34)), JADE, px(10))
		bHolder.LayoutOrder = 0
		text(bBtn, "<", px(20), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		bBtn.Activated:Connect(function()
			goTo("road")
		end)
	end
	local titleLabel = text(h, title, px(32), page == "karma" and KARMA or GOLD, { LayoutOrder = 1 })
	local xHolder, xBtn = Toy.button(h, UDim2.fromOffset(px(34), px(34)), Color3.fromHex("FF6B5E"), px(10))
	xHolder.LayoutOrder = 2
	text(xBtn, "X", px(20), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	xBtn.Activated:Connect(function()
		close()
	end)
	return titleLabel
end

-- the Karma Shop page: one tile per node (icon, name, a short line, level pips, price)
local function buildKarma(body)
	head(body, "Karma Shop")
	ui.karma = amount(body, "karma", px(22), KARMA, { LayoutOrder = 2 })
	ui.tiles = {}
	local rows = {}
	for i = 1, 2 do
		rows[i] = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 + i })
		Toy.list(rows[i], true, px(18), { VerticalAlignment = Enum.VerticalAlignment.Top })
	end
	for i, node in Config.DAO do
		local col = Toy.frame(rows[i <= PER_ROW and 1 or 2], { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = i, Rotation = TILT[i] or 0 })
		Toy.list(col, false, px(2))
		local holder, btn = Toy.button(col, UDim2.fromOffset(px(58), px(58)), Color3.fromHex(TILE[node.key] or "C9FFE4"), px(16))
		holder.LayoutOrder = 1
		local iconProps = { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }
		Toy.icon(btn, node.key, px(44), iconProps) -- the shared icon sheet
		local newDot = karmaNew(node.key, (player:GetAttribute("Dao_" .. node.key) or 0) + 1) and Toy.dot(btn, px(18)) or nil
		text(col, node.name, px(14), Color3.new(1, 1, 1), { LayoutOrder = 2 })
		local lineLabel = text(col, node.line, px(11), Color3.fromHex("C9FFE4"), { LayoutOrder = 3 })
		local pipRow = Toy.frame(col, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 4 })
		Toy.list(pipRow, true, px(3))
		local pips = {}
		for l = 1, #node.costs do
			local pip = Toy.frame(pipRow, { Size = UDim2.fromOffset(px(9), px(9)), BackgroundTransparency = 0, LayoutOrder = l })
			Toy.corner(pip, UDim.new(1, 0))
			local st = Instance.new("UIStroke")
			st.Color = Toy.INK
			st.Thickness = px(2)
			st.Parent = pip
			pips[l] = pip
		end
		Toy.frame(col, { Size = UDim2.fromOffset(1, px(3)), LayoutOrder = 5 }) -- the pips clear the button
		local pHolder, pBtn = Toy.button(col, UDim2.fromOffset(px(70), px(26)), JADE, px(9))
		pHolder.LayoutOrder = 6
		local price, priceRow = amount(pBtn, "karma", px(14), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		local priceIcon = priceRow:FindFirstChildWhichIsA("ImageLabel") or priceRow:FindFirstChildWhichIsA("Frame") -- sheet icons are ImageLabels (D51)
		local function buy()
			if busy then
				return
			end
			busy = true
			local ok, done = pcall(function()
				return remotes.DaoBuy:InvokeServer(node.key)
			end)
			busy = false
			Sfx.play(ok and done and "buyChime" or "deny")
			if ok and done and newDot then
				newDot.Visible = false -- followed: bought
			end
			refreshKarma()
		end
		btn.Activated:Connect(buy)
		pBtn.Activated:Connect(buy)
		table.insert(ui.tiles, { node = node, pips = pips, price = price, priceIcon = priceIcon, button = pBtn, line = lineLabel })
	end
end

build = function()
	gui:ClearAllChildren()
	Toy.S = computeScale()
	ui = {}

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
	Toy.list(body, false, px(8))
	ui.body = body
	if page == "karma" then
		buildKarma(body)
		refresh()
		return
	end
	ui.title = head(body, "Rebirth")

	-- the boost: x now -> x after
	local boost = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	Toy.list(boost, true, px(12))
	ui.now = amount(boost, "qi", px(26), Color3.fromHex("C9FFE4"), { LayoutOrder = 1 })
	text(boost, "->", px(24), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	ui.after = text(boost, "", px(36), GOLD, { LayoutOrder = 3 })

	-- the price: a bar that fills with the qi you hold
	local bar = Toy.frame(body, { Size = UDim2.fromOffset(px(300), px(30)), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("3A2D40"), LayoutOrder = 5, ClipsDescendants = true })
	Toy.corner(bar, UDim.new(1, 0))
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = px(3)
	st.Parent = bar
	ui.fill = Toy.frame(bar, { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = GOLD })
	Toy.corner(ui.fill, UDim.new(1, 0))
	ui.price = amount(bar, "qi", px(16), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })

	local gains = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 9, Rotation = 1.5 })
	Toy.list(gains, true, px(22))
	ui.gain = amount(gains, "karma", px(22), KARMA, { LayoutOrder = 1 })
	ui.opens = text(gains, "", px(18), GOLD, { LayoutOrder = 2 })

	Toy.frame(body, { Size = UDim2.fromOffset(1, px(4)), LayoutOrder = 14 })
	local bHolder, bBtn = Toy.button(body, UDim2.fromOffset(px(230), px(48)), JADE, px(14))
	bHolder.LayoutOrder = 15
	ui.btn = bBtn
	if snap.reinc then
		Toy.dot(bBtn, px(20))
	end
	ui.btnLabel = text(bBtn, "", px(22), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	bBtn.Activated:Connect(function()
		if busy or (player:GetAttribute("Qi") or 0) < (player:GetAttribute("RebirthPrice") or math.huge) then
			Sfx.play("deny")
			return
		end
		if os.clock() >= armedUntil then
			armedUntil = os.clock() + 4
			refresh()
			task.delay(4.1, refresh)
			return
		end
		armedUntil = 0
		busy = true
		local ok, res = pcall(function()
			return remotes.Reincarnate:InvokeServer()
		end)
		busy = false
		if ok and res then
			close()
		else
			refresh()
		end
	end)
	-- the Karma Shop: what karma is for
	local kHolder, kBtn = Toy.button(body, UDim2.fromOffset(px(160), px(34)), KARMA, px(11))
	kHolder.LayoutOrder = 16
	kHolder.Rotation = -1.5
	if snap.karma then
		Toy.dot(kBtn, px(18))
	end
	text(kBtn, "Karma Shop", px(16), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	kBtn.Activated:Connect(function()
		goTo("karma")
	end)
	refresh()
end

-- `toPage` = "karma" lands on the Karma Shop (the HUD's Karma button); else the road
local function open(toPage)
	if gui.Enabled then
		return
	end
	armedUntil = 0
	page = toPage == "karma" and "karma" or "road"
	snap = litDots()
	build()
	gui.Enabled = true
	remotes.MenuOpened:FireServer(page == "karma" and "karma" or "reinc") -- analytics Menu (DATA.md)
	Sfx.play("toast")
	local sc = Instance.new("UIScale")
	sc.Scale = 0.85
	sc.Parent = ui.body
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

close = function()
	gui.Enabled = false
end

openEvent.Event:Connect(open)
local watched = { "Qi", "Realm", "Karma", "Lives", "Rebirths", "RebirthPrice", "RebirthMult", "NextRebirthMult", "RebirthKarma", "RealmNeedsRebirths" }
for _, n in Config.DAO do
	table.insert(watched, "Dao_" .. n.key)
end
for _, a in watched do
	player:GetAttributeChangedSignal(a):Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)
end
