-- Shop (MONETIZATION.md): game passes, developer products, the purple pads around the hub cauldron.
-- The server decides every prompt and grant (R9). Products are granted only through ProcessReceipt:
-- the PurchaseId is stored in the save with the grant and the save must land before
-- PurchaseGranted is returned, so a retried receipt (same server or a later one) grants once.
-- Main hands its state in through Shop.init(api).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local Shop = {}

local STUDIO = RunService:IsStudio()
local api -- { sessions, rate, publish, save, canSave, notify, passChanged, addDisciple, remotes, style, styleP, palette, cultivators }
-- rate(s, away) = qi/s of a session; save(s) -> true when the write landed

local function itemById(list, id)
	for _, it in list do
		if it.id ~= 0 and it.id == id then
			return it
		end
	end
	return nil
end

local function realm(s)
	return Telemetry.realmBucket(s and s.data.realm or 1)
end

-- Pass ownership lives in the session (s.passes), never in the save: Roblox is the record.
local function setPass(player, s, key)
	if s.passes[key] then
		return
	end
	s.passes[key] = true
	player:SetAttribute("Pass_" .. key, true)
	api.passChanged(player, s, key)
end

-- Yields: called on join before the offline qi, so the 2x pass counts on it.
function Shop.onJoin(player, s)
	s.passes = {}
	for _, it in Config.SHOP_PRODUCTS do
		if it.limit and ((s.data.shopBought or {})[it.key] or 0) >= it.limit then
			player:SetAttribute("Limit_" .. it.key, true)
		end
	end
	for _, it in Config.SHOP_PASSES do
		if it.id ~= 0 and player.Parent then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, it.id)
			if ok and owns then
				s.passes[it.key] = true
				player:SetAttribute("Pass_" .. it.key, true)
				if it.key == "vip" then
					s.plot.vip = true -- the arch is drawn by rebuild on join
				end
			elseif not ok then
				warn("[Tycoon][shop] pass check failed", it.key)
			end
		end
	end
end

-- Studio test hook (DebugSet "pass", key): own a pass without buying it
function Shop.debugPass(player, s, key)
	if STUDIO and Config.shopItem(key) then
		setPass(player, s, key)
	end
end

local function grantProduct(player, s, it)
	local d = s.data
	if it.key == "pill" then
		local now = workspace:GetServerTimeNow()
		d.boostUntil = math.max(now, d.boostUntil or 0) + Config.PILL_DURATION
		api.notify:FireClient(player, "shopPill", Config.PILL_DURATION)
	elseif it.rarity then
		-- bought disciples are permanent (D28): counted BEFORE seating, so the cap trim in
		-- addDisciple can never drop the one just paid for; a reincarnation must keep them too
		d.boughtDisciples = d.boughtDisciples or {}
		d.boughtDisciples[it.rarity] = (d.boughtDisciples[it.rarity] or 0) + 1
		local kept = api.addDisciple(s, it.rarity)
		Telemetry.custom(player, "DiscipleBought", it.key, realm(s), Telemetry.minuteBucket(d.playSec or 0))
		api.notify:FireClient(player, "shopDisciple", it.rarity, kept)
	elseif it.seconds then
		local gain = math.floor(api.rate(s, true) * it.seconds)
		d.qi += gain
		Telemetry.iapSource(player, d, gain, it.key)
		api.notify:FireClient(player, "shopQi", gain, it.name)
	end
end

-- Roblox calls this until it returns PurchaseGranted (also on the buyer's next join).
local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local s = player and api.sessions[player]
	if not s or not s.loaded or s.released then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local d = s.data
	d.receipts = d.receipts or {}
	if table.find(d.receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- granted before (retry after a slow save)
	end
	local it = itemById(Config.SHOP_PRODUCTS, info.ProductId)
	if not it then
		warn("[Tycoon][shop] receipt for an unknown product", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grantProduct(player, s, it)
	d.shopBought = d.shopBought or {} -- [key] = times bought (enforces `limit`)
	d.shopBought[it.key] = (d.shopBought[it.key] or 0) + 1
	if it.limit and d.shopBought[it.key] >= it.limit then
		player:SetAttribute("Limit_" .. it.key, true) -- the shop shows it as owned
	end
	table.insert(d.receipts, info.PurchaseId)
	while #d.receipts > Config.RECEIPTS_KEPT do
		table.remove(d.receipts, 1)
	end
	api.publish(player)
	Telemetry.custom(player, "Shop", "bought", it.key, realm(s))
	print(string.format("[Tycoon][shop] granted %s to %d", it.key, player.UserId))
	if not api.canSave() then
		-- no DataStore: only Studio may grant without a saved record
		return STUDIO and Enum.ProductPurchaseDecision.PurchaseGranted or Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- the grant and the PurchaseId are in memory: if this save fails, the retry finds the id and
	-- grants nothing twice, and the next autosave or the leave save writes both
	if api.save(s) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	warn("[Tycoon][shop] receipt save failed, Roblox will retry", it.key)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- One prompt per player per second; the item must exist and not be owned.
local lastPrompt = {}
local function prompt(player, key)
	local s = api.sessions[player]
	if not s or type(key) ~= "string" or #key > 16 then
		return
	end
	local now = os.clock()
	if now - (lastPrompt[player] or 0) < 1 then
		return
	end
	local it, isPass = Config.shopItem(key)
	if not it or it.id == 0 or (isPass and s.passes[key]) then
		return
	end
	if it.minRealm and (s.data.best or s.data.realm) < it.minRealm then
		api.notify:FireClient(player, "shopGate", it.name, Config.realmName(it.minRealm))
		return
	end
	if it.limit and ((s.data.shopBought or {})[key] or 0) >= it.limit then
		api.notify:FireClient(player, "shopLimit", it.name)
		return
	end
	if it.rarity then
		-- never sell a disciple that could not stay: a full list of stronger ones
		local list = s.data.disciples
		local weakest = list[#list] and Config.rarity(list[#list]).bonus or 0
		if #list >= Config.DISCIPLE_CAP and weakest >= Config.rarity(it.rarity).bonus then
			api.notify:FireClient(player, "shopFull", it.name)
			return
		end
	end
	lastPrompt[player] = now
	Telemetry.custom(player, "Shop", "prompt", key, realm(s))
	if isPass then
		MarketplaceService:PromptGamePassPurchase(player, it.id)
	else
		MarketplaceService:PromptProductPurchase(player, it.id)
	end
end

local OPEN_SOURCES = { hud = true, pad = true, pill = true }
local lastOpen = {}

-- World shop: every peak has a small shop island (Config SHOP_ISLAND_*), built once at boot for each
-- plot and never cleared (Main's grounds rebuild clears terrain only inside the largest peak).
-- Pads are StepPads (the "Step-on pad juice" client may restyle them; the behaviour keys on
-- ShopKey); stepping onto one prompts its item, again only after stepping off. Shop.client draws the
-- icon and the card over each pad. No OwnerId: anyone may shop on any island.
local PAD_REACH = 2.6

-- an invisible anchor: Build.client draws the pad itself (tag "StepPad", D27)
local function shopPad(folder, at, key)
	local p = api.styleP(folder, Vector3.new(0.5, 4, 4), at * CFrame.new(0, 0.27, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromHex("9B6BE0"), nil, Enum.PartType.Cylinder)
	p.Transparency = 1
	p.CastShadow = false
	p.Name = "ShopPad_" .. key
	p.CanCollide = false
	p.CanTouch = false
	p:SetAttribute("ShopKey", key)
	-- step-on pad contract: no PriceText because the price is per player (regional pricing)
	p:SetAttribute("PadKind", "shop")
	p:SetAttribute("Title", Config.shopItem(key).name)
	CollectionService:AddTag(p, "StepPad")
	return p
end

-- The island's frame: centre at SHOP_ISLAND_AT in the peak's frame, +Z facing the peak.
function Shop.islandFrame(plotFrame)
	local c = plotFrame * Config.SHOP_ISLAND_AT
	return CFrame.lookAt(c, plotFrame.Position) * CFrame.Angles(0, math.pi, 0)
end

-- The point on the island's rim where the peak's bridge lands (world).
function Shop.islandEntry(plotFrame)
	return (Shop.islandFrame(plotFrame) * CFrame.new(0, 0, Config.SHOP_ISLAND_RADIUS - 1)).Position
end

function Shop.buildIsland(plot)
	local Style = api.style
	local R = Config.SHOP_ISLAND_RADIUS
	local f = Shop.islandFrame(plot.frame)
	local folder = Instance.new("Folder")
	folder.Name = "ShopIsland"
	-- lawn: everything inside 0.8 R stays clear (pads, cauldron, path); trees only on the rim
	Style.island(folder, f, R, 700 + plot.index, function(x, z)
		return Vector2.new(x, z).Magnitude < R * 0.8 or (math.abs(x) < 6 and z > 0)
	end, true)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2 + 0.3
		local x, z = math.cos(a) * (R - 3.5), math.sin(a) * (R - 3.5)
		if not (math.abs(x) < 9 and z > 0) then
			if k % 2 == 0 then
				Style.sakura(folder, f * CFrame.new(x, 0, z), plot.index * 70 + k)
			else
				Style.pine(folder, f * CFrame.new(x, 0, z), plot.index * 70 + k, 10 + (k % 3) * 2)
			end
		end
	end
	-- entrance gate with the market's name, then 2x Qi right inside it (the first thing seen)
	local sign = Style.archway(folder, f * CFrame.new(0, 0, R - 2), 9, 9)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.Fantasy
	label.TextColor3 = Color3.fromRGB(255, 225, 150)
	label.Text = "Sect Market"
	label.Parent = gui
	shopPad(folder, f * CFrame.new(0, 0, R - 8), "x2")
	Style.lantern(folder, f * CFrame.new(-4.5, 0, R - 6), 0.8)
	Style.lantern(folder, f * CFrame.new(4.5, 0, R - 6), 0.8)
	-- a bronze cauldron at the heart of the lawn (its fire is a real light)
	Style.cauldron(folder, f * CFrame.new(0, 0, -1), 0.8)
	-- the other items on the front arc, half a side, the first nearest the entrance
	local half = #Config.SHOP_ITEM_PADS // 2
	for i, key in Config.SHOP_ITEM_PADS do
		local side = i <= half and -1 or 1
		local k = i <= half and i or (#Config.SHOP_ITEM_PADS + 1 - i)
		local t = math.rad(35 + (k - 1) * 27)
		shopPad(folder, f * CFrame.new(side * math.sin(t) * 16, 0, math.cos(t) * 16), key)
	end
	-- the disciples for sale sit on the back arc facing the cauldron, each with its pad in front and
	-- a lantern between neighbours (cheapest on the left as you walk in)
	local n = #Config.SHOP_DISCIPLE_PADS
	for i, key in Config.SHOP_DISCIPLE_PADS do
		local t = math.rad(115 + (i - 1) * (130 / (n - 1)))
		local dx, dz = -math.sin(t), math.cos(t)
		local it = Config.shopItem(key)
		local seat = f * CFrame.lookAt(Vector3.new(dx * 20, 0, dz * 20), Vector3.zero) -- facing the cauldron
		local m = api.cultivators.build(folder, seat, i + 2, Config.rarity(it.rarity), Config.RARITIES)
		m.Name = "ForSale_" .. key
		shopPad(folder, f * CFrame.new(dx * 14, 0, dz * 14), key)
		if i < n then
			local tm = t + math.rad(65 / (n - 1))
			Style.lantern(folder, f * CFrame.new(-math.sin(tm) * 21, 0, math.cos(tm) * 21), 0.7)
		end
	end
	folder.Parent = plot.folder
	return folder
end

function Shop.init(a)
	api = a
	MarketplaceService.ProcessReceipt = processReceipt

	local buy = Instance.new("RemoteEvent")
	buy.Name = "ShopBuy"
	buy.Parent = api.remotes
	buy.OnServerEvent:Connect(function(player, key)
		prompt(player, key)
	end)
	local opened = Instance.new("RemoteEvent")
	opened.Name = "ShopOpened"
	opened.Parent = api.remotes
	opened.OnServerEvent:Connect(function(player, from)
		local s = api.sessions[player]
		local now = os.clock()
		if s and OPEN_SOURCES[from] and now - (lastOpen[player] or 0) >= 3 then
			lastOpen[player] = now
			Telemetry.custom(player, "Shop", "open", from, realm(s))
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local it = itemById(Config.SHOP_PASSES, passId)
		local s = api.sessions[player]
		if not it or not s then
			return
		end
		Telemetry.custom(player, "Shop", purchased and "bought" or "closed", it.key, realm(s))
		if purchased then
			setPass(player, s, it.key)
			api.notify:FireClient(player, "shopPass", it.name)
			print(string.format("[Tycoon][shop] pass %s bought by %d", it.key, player.UserId))
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		local player = Players:GetPlayerByUserId(userId)
		local it = itemById(Config.SHOP_PRODUCTS, productId)
		if player and it and not purchased then
			Telemetry.custom(player, "Shop", "closed", it.key, realm(api.sessions[player]))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPrompt[player] = nil
		lastOpen[player] = nil
	end)

	-- [player] = key of the pad they stand on, false = seen off every pad. A pad prompts only for a
	-- player seen OFF it first (a spawn or a teleport onto a pad never prompts).
	local onPad = {}
	task.spawn(function()
		while true do
			task.wait(0.15)
			for _, player in Players:GetPlayers() do
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local here = nil
				if hrp then
					for _, p in CollectionService:GetTagged("StepPad") do
						local d = hrp.Position - p.Position
						if p:GetAttribute("PadKind") == "shop" and Vector2.new(d.X, d.Z).Magnitude < PAD_REACH and d.Y > -1 and d.Y < 7 then
							here = p:GetAttribute("ShopKey")
							break
						end
					end
				end
				if here and onPad[player] ~= nil and onPad[player] ~= here then
					local s = api.sessions[player]
					local _, isPass = Config.shopItem(here)
					if s and isPass and s.passes[here] then
						api.notify:FireClient(player, "shopOwned", Config.shopItem(here).name)
					elseif s then
						Telemetry.custom(player, "Shop", "open", "pad", realm(s))
						prompt(player, here)
					end
				end
				onPad[player] = if hrp then (here or false) else nil
			end
			for player in onPad do
				if not player.Parent then
					onPad[player] = nil
				end
			end
		end
	end)
end

return Shop
