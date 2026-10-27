-- Rebirth screen (Muscle Legends' rebirth, docs/research/2026-10-22_rebirth_standard.md): the price in
-- qi, the boost now and after, the karma it pays, one button. Opened by the HUD's Rebirth button
-- (Player.ReincOpen, a BindableEvent). Same language as the Shop: no board, toy pieces over a
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
local Screens = require(Shared:WaitForChild("Screens"))

local px, text = Toy.px, Toy.text
local GOLD = Color3.fromHex("FFE36B")
local JADE = Color3.fromHex("59D39F")
local CONFIRM = Color3.fromHex("FF8A5C")
local LOCKED = Color3.fromHex("C9C2D3")
local KARMA = Color3.fromHex("D9B8FF")
local TILE = { fortune = "9FF5C8", luck = "9FD0FF", seat = "FFD36B", magnet = "FFC9A6", steps = "FFF0A6", elixir = "FFB3A8", meditation = "C9C2FF", echo = "E6C9FF", hands = "FFF0A6", isles = "FFD1EA" }
local TILT = { -2, 1.5, -1, 2, 1, -1.5, 2, -1, 1.5, -2 }
local PER_ROW = 5 -- Karma Shop tiles per row (ten lines, PS99 Upgrades)

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
openEvent.Parent = player -- not PlayerGui: the first LoadCharacter (Main onJoin) empties it, live joins spawn after this runs

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
local page = "road" -- "road" | "karma" | "styles"
local STYLE_ROW = 7 -- Styles page tiles per row

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
local refreshStyles -- forward (the Styles page)
local styleIcon -- forward (a Sect Style's icon)

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
		local cost = Config.daoCost(t.node, lv)
		if t.node.lines then -- the line names what the NEXT level gives
			t.line.Text = t.node.lines[math.min(lv + 1, #t.node.lines)]
		elseif lv > #t.node.costs then -- an endless line past its pips (Config.DAO `more`) shows its level
			t.line.Text = t.node.line .. "  Lv " .. lv
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
	if page == "styles" then
		refreshStyles()
		return
	end
	local qi = player:GetAttribute("Qi") or 0
	local price = player:GetAttribute("RebirthPrice") or Config.rebirthPrice(0)
	local ready = qi >= price and player:GetAttribute("RebirthOpen") == true
	ui.title.Text = "Rebirth " .. ((player:GetAttribute("Rebirths") or 0) + 1)
	ui.now.Text = mult(player:GetAttribute("RebirthMult") or 1)
	ui.after.Text = mult(player:GetAttribute("NextRebirthMult") or 1)
	ui.price.Text = compact(math.min(qi, price)) .. " / " .. compact(price)
	ui.fill.Size = UDim2.fromScale(math.clamp(qi / math.max(price, 1), 0, 1), 1)
	ui.fill.BackgroundColor3 = ready and JADE or GOLD
	ui.gain.Text = "+" .. commas(player:GetAttribute("RebirthKarma") or 0)
	-- the leftover recruits (Config.leftoverRecruits): the server spends the qi over the price first
	local _, extra = Config.leftoverRecruits(player:GetAttribute("Realm") or 1, player:GetAttribute("RealmRecruits") or 0, qi - price)
	ui.leftover.Visible = ready and extra > 0
	ui.leftover.Text = "+" .. commas(extra) .. " recruits from leftover qi"

	-- the next realm waits for rebirths (Config.REBIRTH_REALMS): say which one this opens
	local need = player:GetAttribute("RealmNeedsRebirths") or 0
	local done = player:GetAttribute("Rebirths") or 0
	local realm = player:GetAttribute("Realm") or 1
	ui.opens.Visible = need > done and need == done + 1
	ui.opens.Text = "Opens Realm " .. (realm + 1) .. ": " .. Config.realmName(realm + 1) -- the number too (owner 2026-10-23)
	-- the Sect Style this rebirth unlocks (Build Your Backrooms lists each rebirth's unlocks)
	local nextStyle = Config.styleAt(done + 1)
	ui.style.Visible = nextStyle ~= nil
	if nextStyle then
		ui.styleName.Text = "New style: " .. nextStyle.name
		if ui.styleIconFor ~= nextStyle.id then
			ui.styleIconBox:ClearAllChildren()
			styleIcon(ui.styleIconBox, px(30), nextStyle)
			ui.styleIconFor = nextStyle.id
		end
	end

	-- closed: what it waits for, on the button and spelled out under it (Config.rebirthNeed)
	local kind, n = string.match(player:GetAttribute("RebirthNeed") or "", "^(%a+):(%d+)$")
	n = tonumber(n)
	local needText = kind == "realm" and "Reach Realm " .. n or kind == "build" and "Build " .. n .. " more" or nil
	ui.need.Visible = needText ~= nil
	if kind == "realm" then
		ui.need.Text = "Opens in Realm " .. n .. ": " .. Config.realmName(n)
	elseif kind == "build" then
		ui.need.Text = n == 1 and "Build the last building of this realm" or "Build every building of this realm"
	end
	if needText then
		ui.opens.Visible = false
	end

	-- the button
	local armed = os.clock() < armedUntil
	if not ready then
		ui.btn.BackgroundColor3 = LOCKED
		-- closed until the next realm waits for a rebirth (Config.rebirthOpen): say what opens it
		ui.btnLabel.Text = player:GetAttribute("RebirthOpen") and "Rebirth!" or needText or "Not needed yet"
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
	if p == "karma" or p == "styles" then
		remotes.MenuOpened:FireServer(p) -- analytics Menu (DATA.md)
	end
end

-- a link to the Styles page: its icon, then "Sect Styles" (the Rebirth page, the Karma Shop; owner
-- 2026-10-27: "Sect styles need icon too + a link in karma shop and settings")
local STYLE_PINK = Color3.fromHex("FF9EC0")
local function stylesLink(parent, order, rot)
	local holder, btn = Toy.button(parent, UDim2.fromOffset(px(176), px(38)), STYLE_PINK, px(11))
	holder.LayoutOrder = order
	holder.Rotation = rot or 0
	local row = Toy.frame(btn, { AutomaticSize = Enum.AutomaticSize.XY, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	Toy.list(row, true, px(6), { VerticalAlignment = Enum.VerticalAlignment.Center })
	Toy.icon(row, "styles", px(30), { LayoutOrder = 1, ZIndex = 3 })
	text(row, "Sect Styles", px(16), Color3.new(1, 1, 1), { LayoutOrder = 2, ZIndex = 3 })
	btn.Activated:Connect(function()
		goTo("styles")
	end)
	return holder
end

local function head(body, title)
	local h = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1, Rotation = -2 })
	Toy.list(h, true, px(14))
	if page ~= "road" then
		local bHolder, bBtn = Toy.button(h, UDim2.fromOffset(px(34), px(34)), JADE, px(10))
		bHolder.LayoutOrder = -1
		text(bBtn, "<", px(20), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		bBtn.Activated:Connect(function()
			goTo("road")
		end)
	end
	if page == "styles" then
		Toy.icon(h, "styles", px(40), { LayoutOrder = 0 })
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

-- a style's colour chip: its roof colour with a stripe of its trim
local function swatch(parent, size, st)
	local chip = Toy.frame(parent, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 0, BackgroundColor3 = st and st.swatch[1] or Color3.fromHex("3E4656"), ClipsDescendants = true })
	Toy.corner(chip, UDim.new(1, 0))
	local trim = Toy.frame(chip, { Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.7), BackgroundTransparency = 0, BackgroundColor3 = st and st.swatch[2] or Color3.fromHex("B8352B") })
	local stroke = Instance.new("UIStroke")
	stroke.Color = Toy.INK
	stroke.Thickness = px(2)
	stroke.Parent = chip
	return chip, trim
end

-- a style's own icon (icon sheet cells "style_<id>", owner 2026-10-27 "missing icons"); its colour chip
-- until the sheet with those cells is live. Returns the icon (or chip) and the chip's trim (nil for an icon)
styleIcon = function(parent, size, st)
	local key = "style_" .. (st and st.id or "classic")
	if Config.ICON_ATLAS.keys[key] then
		return Toy.icon(parent, key, size), nil
	end
	return swatch(parent, size, st)
end

refreshStyles = function()
	local done = player:GetAttribute("Rebirths") or 0
	local worn = player:GetAttribute("SectStyle") or "classic"
	for _, t in ui.styleTiles do
		local open = t.st == nil or t.st.rebirth <= done
		local id = t.st and t.st.id or "classic"
		if t.trim then
			t.chip.BackgroundTransparency = open and 0 or 0.6
			t.trim.BackgroundTransparency = open and 0 or 0.6
		else -- a locked style's icon is a dark silhouette (the index's not-found look)
			t.chip.ImageColor3 = open and Color3.new(1, 1, 1) or Color3.fromHex("5E5274")
			t.chip.ImageTransparency = open and 0 or 0.1
		end
		if id == worn then
			t.label.Text = "Wearing"
			t.button.BackgroundColor3 = GOLD
		elseif open then
			t.label.Text = "Wear"
			t.button.BackgroundColor3 = JADE
		else
			t.label.Text = "Rebirth " .. t.st.rebirth
			t.button.BackgroundColor3 = LOCKED
		end
	end
end

-- the Styles page: every Sect Style (Config.SECT_STYLES) and Classic; tap an unlocked one to wear it
local function buildStyles(body)
	head(body, "Sect Styles")
	text(body, "Every rebirth unlocks a new look for your whole sect", px(14), Color3.fromHex("C9FFE4"), { LayoutOrder = 2 })
	ui.styleTiles = {}
	local list = { false }
	for _, st in Config.SECT_STYLES do
		table.insert(list, st)
	end
	local rows = {}
	for i, st in list do
		local r = math.ceil(i / STYLE_ROW)
		if not rows[r] then
			rows[r] = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 + r })
			Toy.list(rows[r], true, px(12), { VerticalAlignment = Enum.VerticalAlignment.Top })
		end
		st = st or nil
		local col = Toy.frame(rows[r], { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = i, Rotation = TILT[(i - 1) % #TILT + 1] or 0 })
		Toy.list(col, false, px(3))
		local chip, trim = styleIcon(col, px(52), st)
		chip.LayoutOrder = 1
		text(col, st and st.name or "Classic", px(12), Color3.new(1, 1, 1), { LayoutOrder = 2 })
		local bHolder, bBtn = Toy.button(col, UDim2.fromOffset(px(76), px(24)), JADE, px(8))
		bHolder.LayoutOrder = 3
		local label = text(bBtn, "", px(12), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		bBtn.Activated:Connect(function()
			local id = st and st.id or "classic"
			if busy or id == player:GetAttribute("SectStyle") or (st and st.rebirth > (player:GetAttribute("Rebirths") or 0)) then
				Sfx.play("deny")
				return
			end
			busy = true
			local ok, res = pcall(function()
				return remotes.SetSectStyle:InvokeServer(id)
			end)
			busy = false
			Sfx.play(ok and res and "buyChime" or "deny")
			refreshStyles()
		end)
		table.insert(ui.styleTiles, { st = st, chip = chip, trim = trim, label = label, button = bBtn })
	end
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
	-- the Styles page from the Karma Shop too (owner 2026-10-27)
	stylesLink(body, 20, -1)
end

local function buildPage()
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

	local body = Toy.frame(gui, { Active = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY })
	Toy.list(body, false, px(8))
	ui.body = body
	if page == "karma" then
		buildKarma(body)
		refresh()
		return
	end
	if page == "styles" then
		buildStyles(body)
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

	-- the Sect Style it unlocks: its chip and name
	ui.style = Toy.frame(body, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 10, Rotation = -1, Visible = false })
	Toy.list(ui.style, true, px(8))
	ui.styleIconBox = Toy.frame(ui.style, { Size = UDim2.fromOffset(px(30), px(30)), LayoutOrder = 1 })
	ui.styleName = text(ui.style, "", px(18), Color3.fromHex("FFD6E4"), { LayoutOrder = 2 })

	ui.leftover = text(body, "", px(18), Color3.fromHex("C9FFE4"), { LayoutOrder = 11, Visible = false })
	ui.need = text(body, "", px(18), Color3.fromHex("FFB3A8"), { LayoutOrder = 12, Visible = false })
	Toy.frame(body, { Size = UDim2.fromOffset(1, px(4)), LayoutOrder = 14 })
	local bHolder, bBtn = Toy.button(body, UDim2.fromOffset(px(230), px(48)), JADE, px(14))
	bHolder.LayoutOrder = 15
	ui.btn = bBtn
	if snap.reinc then
		Toy.dot(bBtn, px(20))
	end
	ui.btnLabel = text(bBtn, "", px(22), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	bBtn.Activated:Connect(function()
		if busy or not player:GetAttribute("RebirthOpen") or (player:GetAttribute("Qi") or 0) < (player:GetAttribute("RebirthPrice") or math.huge) then
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
	-- the Styles page, beside the Karma Shop
	stylesLink(body, 17, 1.5)
	refresh()
end

-- a page taller than the screen shrinks to fit (phone, 2026-10-27: the Karma Shop's "Sect Styles" link sat
-- under the screen's bottom edge): one UIScale "Fit" on the body, also the one the opening pop tweens
local fitTween = false
local function fitBody()
	local body = ui.body
	if not body then
		return
	end
	local sc = body:FindFirstChild("Fit")
	if not sc then
		sc = Instance.new("UIScale")
		sc.Name = "Fit"
		sc.Parent = body
	end
	local natural = body.AbsoluteSize.Y / math.max(sc.Scale, 0.01)
	local avail = gui.AbsoluteSize.Y - px(20)
	local fit = natural > avail and math.max(0.5, avail / natural) or 1
	-- writing the scale changes the body's AbsoluteSize, which calls this again: only a real change is
	-- written, else pixel rounding bounced the scale back and forth until Roblox cut the loop (live
	-- 2026-10-27, "Maximum event re-entrancy depth exceeded")
	if ui.fit and math.abs(fit - ui.fit) < 0.01 then
		return
	end
	ui.fit = fit
	if not fitTween then
		sc.Scale = fit
	end
end

build = function()
	buildPage()
	fitBody()
	ui.body:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBody)
end

-- `toPage` = "karma" lands on the Karma Shop (the HUD's Karma button); else the road
local function open(toPage)
	if gui.Enabled then
		return
	end
	armedUntil = 0
	page = (toPage == "karma" or toPage == "styles") and toPage or "road"
	snap = litDots()
	build()
	gui.Enabled = true
	remotes.MenuOpened:FireServer(page == "road" and "reinc" or page) -- analytics Menu (DATA.md)
	Sfx.play("toast")
	local sc = ui.body:FindFirstChild("Fit")
	if sc then
		fitTween = true
		sc.Scale = ui.fit * 0.85
		local pop = TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = ui.fit })
		pop.Completed:Connect(function()
			fitTween = false
			fitBody()
		end)
		pop:Play()
	end
end

close = function()
	gui.Enabled = false
end

openEvent.Event:Connect(open)
-- the gold Rebirth pad on the peak (Main refreshPads, a rebirth gate realm) opens this screen
remotes:WaitForChild("Notify").OnClientEvent:Connect(function(kind)
	if kind == "rebirthAsk" then
		open()
	end
end)
-- the first rebirths (Config.REBIRTH_TIP_TIMES) open this screen by themselves once the price is held,
-- after any other card (thread "Keep new players past 10 minutes": players stopped at a full realm 2
-- with the price held and nothing pointing at the Rebirth seal)
local autoOpened -- the life (rebirths done) whose screen already opened by itself
task.spawn(function()
	while true do
		task.wait(1)
		local life = player:GetAttribute("Rebirths") or 0
		local held = player:GetAttribute("RebirthOpen") and (player:GetAttribute("Qi") or 0) >= (player:GetAttribute("RebirthPrice") or math.huge)
		if held and autoOpened ~= life and life < Config.REBIRTH_TIP_TIMES and not gui.Enabled then
			autoOpened = life
			Screens.waitClear(playerGui, "Reincarnation", 2)
			if player:GetAttribute("RebirthOpen") and (player:GetAttribute("Rebirths") or 0) == life then
				open()
			end
		end
	end
end)
local watched = { "Qi", "Realm", "RealmRecruits", "Karma", "Lives", "Rebirths", "SectStyle", "RebirthPrice", "RebirthMult", "NextRebirthMult", "RebirthKarma", "RealmNeedsRebirths", "RebirthOpen" }
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
