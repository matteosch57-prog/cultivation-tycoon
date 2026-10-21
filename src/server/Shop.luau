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
local api -- { sessions, rate, publish, save, canSave, notify, passChanged, remotes, styleP, palette }
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

-- World shop: purple pads in a ring around the hub cauldron. The look is only buildPads (the
-- "Step-on pad juice" work may restyle every step-on pad); the behaviour keys on ShopKey. Stepping onto one prompts its item
-- once (again only after stepping off). Every client draws the card (Shop.client).
local PAD_REACH = 2.6
local function buildPads(folder, baseY)
	local pads = {}
	local P = api.styleP
	local purple = Color3.fromHex("9B6BE0")
	for i, key in Config.SHOP_PADS do
		-- between the bridge mouths (bridges leave at multiples of 360/PLOT_COUNT degrees)
		local a = (i - 0.5) / Config.PLOT_COUNT * math.pi * 2
		local at = CFrame.new(math.cos(a) * Config.SHOP_PAD_RADIUS, baseY, math.sin(a) * Config.SHOP_PAD_RADIUS)
		-- an invisible anchor: Build.client draws the pad (tag "StepPad")
		local p = P(folder, Vector3.new(0.5, 4, 4), at * CFrame.new(0, 0.27, 0) * CFrame.Angles(0, 0, math.pi / 2), purple, nil, Enum.PartType.Cylinder)
		p.Transparency = 1
		p.CastShadow = false
		p.Name = "ShopPad_" .. key
		p.CanCollide = false
		p.CanTouch = false
		p:SetAttribute("ShopKey", key)
		-- step-on pad contract (the pad juice client draws every "StepPad"): no OwnerId = anyone;
		-- no PriceText because the price is per player (regional pricing), Shop.client draws it
		p:SetAttribute("PadKind", "shop")
		p:SetAttribute("Title", Config.shopItem(key).name)
		CollectionService:AddTag(p, "StepPad")
		table.insert(pads, p)
	end
	return pads
end

function Shop.init(a, hubFolder, baseY)
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

	local pads = buildPads(hubFolder, baseY)
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
					for _, p in pads do
						local d = hrp.Position - p.Position
						if Vector2.new(d.X, d.Z).Magnitude < PAD_REACH and d.Y > -1 and d.Y < 7 then
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
