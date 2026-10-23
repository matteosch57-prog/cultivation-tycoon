-- Shop (MONETIZATION.md): game passes, developer products, the world shop's purple pads.
-- The server decides every prompt and grant (R9). Products are granted only through ProcessReceipt:
-- the PurchaseId is stored in the save with the grant and the save must land before
-- PurchaseGranted is returned, so a retried receipt (same server or a later one) grants once.
-- Main hands its state in through Shop.init(api).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Guard = require(script.Parent:WaitForChild("Guard"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local PolicyService = game:GetService("PolicyService")

local Shop = {}

local STUDIO = RunService:IsStudio()
local api -- { sessions, rate, publish, save, canSave, notify, passChanged, addDisciple, tideBell, remotes, style, styleP, palette, cultivators }
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

-- Paid random items (Roblox policy, owner pick 2026-10-23): qi buys random recruits and qi is sold
-- for Robux, so where Roblox restricts paid random items the items that sell qi (`seconds`: the Qi
-- packs and the Starter Pack) are not sold. Qi there is only earned and recruits stay legal; nothing
-- else changes. Unknown = restricted (fail closed: never sell where it may be illegal); a failed check
-- is asked again. Player attribute QiSaleOff (Shop.client hides the Qi page, the Get Qi offer and the
-- Starter Pack tile).
local POLICY_RETRY = 30
local function checkPolicy(player, s)
	for _ = 1, 3 do
		if not player.Parent or api.sessions[player] ~= s then
			return
		end
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if ok and type(info) == "table" then
			s.qiSaleOff = info.ArePaidRandomItemsRestricted == true
			player:SetAttribute("QiSaleOff", s.qiSaleOff)
			if s.qiSaleOff then
				print(string.format("[Tycoon][shop] paid random items restricted for %d: no qi sold", player.UserId))
			end
			return
		end
		warn("[Tycoon][shop] policy check failed") -- constant text (Error Report); qi stays off sale
		task.wait(POLICY_RETRY)
	end
end

local function sellsQi(it)
	return it.seconds ~= nil
end

-- Yields: called on join before the offline qi, so the 2x pass counts on it.
function Shop.onJoin(player, s)
	s.passes = {}
	s.qiSaleOff = true -- until PolicyService answers
	player:SetAttribute("QiSaleOff", true)
	task.spawn(checkPolicy, player, s)
	for _, it in Config.SHOP_PRODUCTS do
		if it.limit and ((s.data.shopBought or {})[it.key] or 0) >= it.limit then
			player:SetAttribute("Limit_" .. it.key, true)
		end
	end
	local failed = {}
	for _, it in Config.SHOP_PASSES do
		if it.id ~= 0 and player.Parent then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, it.id)
			if ok and owns then
				s.passes[it.key] = true
				player:SetAttribute("Pass_" .. it.key, true)
				if it.key == "vip" and player.Parent and s.plot.owner == player then
					s.plot.vip = true -- the arch is drawn by rebuild on join (not if they left: the next owner's peak)
				end
			elseif not ok then
				warn("[Tycoon][shop] pass check failed", it.key)
				table.insert(failed, it)
			end
		end
	end
	-- a failed check is asked again once the join is done: an owner must not play a session without it
	if #failed > 0 then
		task.delay(10, function()
			for _, it in failed do
				if api.sessions[player] ~= s or not player.Parent then
					return
				end
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, it.id)
				if ok and owns and api.sessions[player] == s then
					setPass(player, s, it.key)
				end
			end
		end)
	end
end

-- Studio test hook (DebugSet "pass", key): own a pass without buying it
function Shop.debugPass(player, s, key)
	if STUDIO and Config.shopItem(key) then
		setPass(player, s, key)
	end
end

-- One item may grant several things (the Sect Starter Pack: a disciple, qi and 2x time); each field
-- is handled on its own. The qi is counted before the disciple joins (the income it was bought at).
local function grantProduct(player, s, it)
	local d = s.data
	local now = workspace:GetServerTimeNow()
	if it.key == "pill" then
		d.boostUntil = math.max(now, d.boostUntil or 0) + Config.PILL_DURATION
		api.notify:FireClient(player, "shopPill", Config.PILL_DURATION)
		return
	elseif it.key == "tidebell" then
		api.tideBell(player) -- a Spirit Tide for the whole server, the buyer's name on the banner
		return
	end
	local gain = 0
	if it.seconds then
		gain = math.floor(api.rate(s, true) * it.seconds)
		d.qi += gain
		Telemetry.iapSource(player, d, gain, it.key)
	end
	if it.pill then
		d.boostUntil = math.max(now, d.boostUntil or 0) + it.pill -- like the Instant Pill: adds to a running one
	end
	if it.rarity then
		-- bought disciples are permanent (D28): counted BEFORE seating, so the cap trim in
		-- addDisciple can never drop the one just paid for; a reincarnation must keep them too
		d.boughtDisciples = d.boughtDisciples or {}
		d.boughtDisciples[it.rarity] = (d.boughtDisciples[it.rarity] or 0) + 1
		local kept = api.addDisciple(s, it.rarity)
		Telemetry.custom(player, "DiscipleBought", it.key, realm(s), Telemetry.minuteBucket(d.playSec or 0))
		if it.qiBonus then
			-- the Welcome Pouch: qi forever on top of its disciple (Main's rate reads data.qiBonus)
			d.qiBonus = (d.qiBonus or 0) + it.qiBonus
			d.welcomeAt = d.welcomeAt or d.playSec or 0 -- the Starter Pack offer waits STARTER_OFFER.after from here
			api.notify:FireClient(player, "shopWelcome", it.rarity, kept, it.qiBonus)
		elseif it.seconds or it.pill then
			-- the Starter Pack: the recruit reveal shows its disciple, then the qi and the 2x
			api.notify:FireClient(player, "shopStarter", it.rarity, kept, gain, it.pill or 0)
		else
			api.notify:FireClient(player, "shopDisciple", it.rarity, kept)
		end
	elseif it.seconds then
		api.notify:FireClient(player, "shopQi", gain, it.name, it.key)
	end
end

-- data.shopBought[key] = times bought (enforces `limit`)
local function countBuy(player, s, it)
	local d = s.data
	d.shopBought = d.shopBought or {}
	d.shopBought[it.key] = (d.shopBought[it.key] or 0) + 1
	if it.limit and d.shopBought[it.key] >= it.limit then
		player:SetAttribute("Limit_" .. it.key, true) -- the shop shows it as owned
	end
end

-- Roblox calls this until it returns PurchaseGranted (also on the buyer's next join).
local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local s = player and api.sessions[player]
	-- s.ready: the join is done (passes known, offline time read, peak built); Roblox retries until then
	if not s or not s.loaded or s.released or not s.ready then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local d = s.data
	d.receipts = d.receipts or {}
	if table.find(d.receipts, info.PurchaseId) then
		-- granted before, but maybe never saved: only a landed save tells Roblox to stop retrying
		if not api.canSave() then
			return STUDIO and Enum.ProductPurchaseDecision.PurchaseGranted or Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return api.save(s) and Enum.ProductPurchaseDecision.PurchaseGranted or Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local it = itemById(Config.SHOP_PRODUCTS, info.ProductId)
	if not it then
		warn("[Tycoon][shop] receipt for an unknown product", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- a once-only item paid for again (two prompts, two servers): the extra pays its `overLimit` Qi
	-- pack instead, so the Pouch's +10% never stacks (owner 2026-10-23)
	local bought = (d.shopBought or {})[it.key] or 0
	local swap = it.limit and bought >= it.limit and it.overLimit and Config.shopItem(it.overLimit)
	if swap then
		Telemetry.custom(player, "Shop", "overLimit", it.key, realm(s))
	end
	grantProduct(player, s, swap or it)
	countBuy(player, s, it)
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

-- The Welcome Pouch offer (Config.WELCOME): once per player, after a building stands. Main calls it
-- after every build; the card is drawn by Shop.client and buys through the usual prompt.
function Shop.maybeWelcome(player, s, pad)
	local d = s.data
	local it = Config.shopItem("welcome")
	if not it or d.welcomeOffered or (it.id == 0 and not STUDIO) then
		return
	end
	if ((d.shopBought or {}).welcome or 0) >= (it.limit or 1) then
		return
	end
	local played = d.playSec or 0
	if played < Config.WELCOME.after or (not pad.feature and played < Config.WELCOME.late) then
		return
	end
	-- sent once a session; saved as offered only when the card draws (OfferShown, owner 2026-10-23):
	-- a player who leaves before the card shows gets it next session
	s.offerSent = s.offerSent or {}
	if s.offerSent.welcome then
		return
	end
	s.offerSent.welcome = true
	api.notify:FireClient(player, "welcomeOffer")
end

-- The Sect Starter Pack offer (Config.STARTER_OFFER): once per player, the first time a building with
-- a `feature` is bought once the Welcome Pouch was bought or its card was shown, at least `after` s of
-- play after that. Main calls it after every build, right after maybeWelcome.
function Shop.maybeStarter(player, s, pad)
	local d = s.data
	local it = Config.shopItem("starter")
	if not it or d.starterOffered or not pad.feature or (it.id == 0 and not STUDIO) or s.qiSaleOff then
		return
	end
	local bought = d.shopBought or {}
	if (bought.starter or 0) >= (it.limit or 1) then
		return
	end
	if not (d.welcomeOffered or (bought.welcome or 0) > 0) then
		return
	end
	-- saves from before the Starter Pack have no welcomeAt: their Welcome card is long past
	if (d.playSec or 0) < (d.welcomeAt or 0) + Config.STARTER_OFFER.after then
		return
	end
	s.offerSent = s.offerSent or {}
	if s.offerSent.starter then
		return
	end
	s.offerSent.starter = true -- saved as offered when the card draws (OfferShown)
	api.notify:FireClient(player, "starterOffer")
end

-- why the Tide Bell cannot ring now (nil = it can): a tide is running, or the Heavenly Altar is open
-- or about to open (its heads-up is out; the altar never shares the sky with a tide)
local function tideBellBlocked()
	local now = workspace:GetServerTimeNow()
	if (workspace:GetAttribute("TideUntil") or 0) > now then
		return "tide"
	end
	if (workspace:GetAttribute("AltarUntil") or 0) > now or (workspace:GetAttribute("AltarNext") or math.huge) - now <= Config.ALTAR_WARN then
		return "altar"
	end
	return nil
end

-- The checks before a prompt (and the Studio debug buy): false = refused, the player was told why.
local function mayBuy(player, s, it)
	local key = it.key
	if it.minRealm and (s.data.best or s.data.realm) < it.minRealm then
		api.notify:FireClient(player, "shopGate", it.name, Config.realmName(it.minRealm))
		return false
	end
	if it.limit and ((s.data.shopBought or {})[key] or 0) >= it.limit then
		api.notify:FireClient(player, "shopLimit", it.name)
		return false
	end
	if sellsQi(it) and s.qiSaleOff then
		api.notify:FireClient(player, "shopRegion", it.name)
		return false
	end
	if key == "tidebell" then
		local why = tideBellBlocked()
		if why then
			api.notify:FireClient(player, "tideBellNo", why)
			return false
		end
	end
	if it.rarity then
		-- never sell a disciple that could not stay: a full list of stronger ones, or a list already
		-- holding DISCIPLE_CAP bought ones (they are never trimmed, so this bounds the list and the
		-- save now that disciples have no buy limit)
		local list = s.data.disciples
		local weakest = list[#list] and Config.discBonus(list[#list], (s.data.discShiny or {})[#list]) or 0
		local paid = 0
		for _, n in s.data.boughtDisciples or {} do
			paid += n
		end
		if (#list >= Config.DISCIPLE_CAP and weakest >= Config.rarity(it.rarity).bonus) or paid >= Config.DISCIPLE_CAP then
			api.notify:FireClient(player, "shopFull", it.name)
			return false
		end
	end
	return true
end

-- Studio test hook (DebugSet "buy", key): the prompt's checks, then the receipt's grant, with no
-- purchase (the ids may still be 0). Returns true when it was granted.
function Shop.debugBuy(player, s, key)
	local it, isPass = Config.shopItem(key)
	if not STUDIO or not it or isPass or not mayBuy(player, s, it) then
		return false
	end
	grantProduct(player, s, it)
	countBuy(player, s, it)
	api.publish(player)
	Telemetry.custom(player, "Shop", "bought", it.key, realm(s))
	print(string.format("[Tycoon][shop] debug granted %s to %d", it.key, player.UserId))
	return true
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
	if not it or it.id == 0 or (isPass and s.passes[key]) or not mayBuy(player, s, it) then
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

local OPEN_SOURCES = { hud = true, pad = true, pill = true, short = true } -- short = the Get Qi offer on a pad out of reach
local lastOpen = {}
local MENUS = { disciples = true, reinc = true, karma = true, group = true, index = true } -- MenuOpened keys
local lastMenu = {} -- [player] = { [menu] = os.clock() }

-- World shop (D33, research 2026-10-21_shop_placement): every item stands where it acts. The
-- passes and the pill stand on the owner's peak (Config.SHOP_PEAK_PADS, Shop.refreshPeak); the
-- disciples for sale walk the peak's side island, the Disciple Garden (Shop.buildIsland, built once
-- at boot and never cleared). Pads are StepPads (the step-on pad client draws them; the behaviour
-- keys on ShopKey); stepping onto one prompts its item, again only after stepping off. Shop.client
-- draws the icon and the card over each pad. No OwnerId: a visitor may buy on any peak.
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

-- The peak's shop pads: one per SHOP_PEAK_PADS entry whose building stands, at its spot for the
-- current island size. Only what changed is added or removed (a rebuilt pad re-pops its card).
-- Called from Main's refreshPads (every build, breakthrough, expansion and join).
function Shop.refreshPeak(s)
	local plot = s.plot
	local folder = plot.folder:FindFirstChild("ShopPads")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ShopPads"
		folder.Parent = plot.folder
	end
	local radius = plot.radius or Config.islandRadius(s.data.owned)
	local wanted = {}
	for _, e in Config.SHOP_PEAK_PADS do
		if not e.needs or s.data.owned[e.needs] then
			local x, z = Config.shopPeakSpot(e, radius)
			wanted["ShopPad_" .. e.key] = { e = e, x = x, z = z }
		end
	end
	for _, p in folder:GetChildren() do
		local w = wanted[p.Name]
		if w and p:GetAttribute("SpotX") == w.x and p:GetAttribute("SpotZ") == w.z then
			wanted[p.Name] = nil -- already standing at the right spot
		else
			p:Destroy()
		end
	end
	for _, w in wanted do
		local p = shopPad(folder, plot.frame * CFrame.new(w.x, 0, w.z), w.e.key)
		p:SetAttribute("SpotX", w.x)
		p:SetAttribute("SpotZ", w.z)
	end
end

-- the peak goes back to unclaimed: its shop pads leave with the owner
function Shop.clearPeak(plot)
	local folder = plot.folder:FindFirstChild("ShopPads")
	if folder then
		folder:ClearAllChildren()
	end
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

-- the Garden walk in the island's frame: from the bridge (+Z) to the back, a gentle S
local function walkAt(t)
	local R = Config.SHOP_ISLAND_RADIUS
	return Vector2.new(math.sin(t * math.pi * 1.5) * 5, (R - 2) - t * (2 * R - 11))
end

function Shop.buildIsland(plot)
	local Style = api.style
	local R = Config.SHOP_ISLAND_RADIUS
	local f = Shop.islandFrame(plot.frame)
	local folder = Instance.new("Folder")
	folder.Name = "DiscipleGarden"
	-- lawn: the walk and its stations stay clear; trees only on the rim
	Style.island(folder, f, R, 700 + plot.index, function(x, z)
		return Vector2.new(x, z).Magnitude < R * 0.8 or (math.abs(x) < 6 and z > 0)
	end, true)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2 + 0.3
		local x, z = math.cos(a) * (R - 3.5), math.sin(a) * (R - 3.5)
		if not (math.abs(x) < 9 and (z > 0 or z < -15)) then -- clear of the gate and the pavilion
			if k % 2 == 0 then
				Style.sakura(folder, f * CFrame.new(x, 0, z), plot.index * 70 + k)
			else
				Style.pine(folder, f * CFrame.new(x, 0, z), plot.index * 70 + k, 10 + (k % 3) * 2)
			end
		end
	end
	api.kit.gate(folder, f * CFrame.new(0, 0, R - 2), 11, 15, "Disciple Garden") -- taller gate (owner 2026-10-21)
	-- the walk: flat stones from the gate to the pavilion at the back
	local steps = 14
	for i = 0, steps do
		local a, b = walkAt(i / steps), walkAt(math.min(1, (i + 1) / steps))
		local mid = (a + b) / 2
		local look = Vector3.new(b.X - a.X, 0, b.Y - a.Y)
		local cf = f * CFrame.lookAt(Vector3.new(mid.X, 0.1, mid.Y), Vector3.new(mid.X, 0.1, mid.Y) + (look.Magnitude > 0 and look or Vector3.zAxis))
		api.styleP(folder, Vector3.new(4, 0.25, 3.2), cf, api.palette.stoneLight, Enum.Material.Slate).CastShadow = false
	end
	-- stations: five beside the walk on alternate sides (cheapest nearest the gate), each a
	-- cultivator on its cushion facing the walk with its pad between them and the stones; the last
	-- (Primordial) sits under a pavilion at the walk's end, its pad in front
	local n = #Config.SHOP_DISCIPLE_PADS
	for i, key in Config.SHOP_DISCIPLE_PADS do
		local it = Config.shopItem(key)
		local seat, padAt
		if i < n then
			local w = walkAt((i - 0.4) / n)
			local side = i % 2 == 1 and -1 or 1
			local onWalk = Vector3.new(w.X, 0, w.Y)
			seat = f * CFrame.lookAt(onWalk + Vector3.new(side * 10, 0, 0), onWalk)
			padAt = f * CFrame.new(onWalk + Vector3.new(side * 5, 0, 0))
			-- its lantern stands on its own side, toward the gate (clear of the next station's pad)
			Style.lantern(folder, f * CFrame.new(onWalk + Vector3.new(side * 7.5, 0, 3.5)), 0.7)
		else
			local w = walkAt(1)
			local _, h = api.kit.pavilion(folder, f * CFrame.new(w.X, 0, w.Y - 3), 7, 8)
			seat = f * CFrame.new(w.X, h, w.Y - 3) -- facing the gate (+Z)
			seat = seat * CFrame.Angles(0, math.pi, 0)
			padAt = f * CFrame.new(w.X, 0, w.Y + 4.5)
		end
		local m = api.cultivators.build(folder, seat, i + 2, Config.rarity(it.rarity), Config.RARITIES)
		m.Name = "ForSale_" .. key
		shopPad(folder, padAt, key)
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
		if Guard.allow(player, "ShopBuy") then
			prompt(player, key)
		end
	end)
	local opened = Instance.new("RemoteEvent")
	opened.Name = "ShopOpened"
	opened.Parent = api.remotes
	opened.OnServerEvent:Connect(function(player, from)
		local s = api.sessions[player]
		local now = os.clock()
		if not (s and Guard.allow(player, "ShopOpened") and OPEN_SOURCES[from]) then
			return
		end
		if now - (lastOpen[player] or 0) >= 3 then
			lastOpen[player] = now
			Telemetry.custom(player, "Shop", "open", from, realm(s))
		end
	end)

	-- an offer card drew on the client (Shop.client showOffer / showStarter): only now is the once-only
	-- offer saved as made, and only for an offer this session sent
	local shown = Instance.new("RemoteEvent")
	shown.Name = "OfferShown"
	shown.Parent = api.remotes
	shown.OnServerEvent:Connect(function(player, key)
		local s = api.sessions[player]
		if not s or not Guard.allow(player, "OfferShown") or (key ~= "welcome" and key ~= "starter") then
			return
		end
		if not (s.offerSent and s.offerSent[key]) then
			return
		end
		local d = s.data
		if key == "welcome" then
			if d.welcomeOffered then
				return
			end
			d.welcomeOffered = true
			d.welcomeAt = d.welcomeAt or d.playSec or 0 -- the Starter Pack offer waits STARTER_OFFER.after from here
		else
			if d.starterOffered then
				return
			end
			d.starterOffered = true
		end
		Telemetry.custom(player, "Shop", "offer", key, realm(s))
	end)

	-- the Shop's free daily gift (its red dot leads here; Dots.freeReady): SHOP_FREE_SECONDS of income
	local free = Instance.new("RemoteFunction")
	free.Name = "ClaimShopFree"
	free.Parent = api.remotes
	free.OnServerInvoke = function(player)
		local s = api.sessions[player]
		if not s or not Guard.allow(player, "ClaimShopFree") or not api.freeReady(s.data) then
			return nil
		end
		local gain = math.floor(api.rate(s, true) * Config.SHOP_FREE_SECONDS)
		s.data.shopFreeDay = os.time() // 86400
		s.data.qi += gain
		Telemetry.custom(player, "Shop", "free", "", realm(s))
		api.publish(player)
		return gain
	end

	-- the HUD's own menus and panels (DATA.md): the client names one from MENUS, the server notes it
	-- once per 3 s per menu (analytics event Menu, which the journal keeps as Menu:<key>)
	local menu = Instance.new("RemoteEvent")
	menu.Name = "MenuOpened"
	menu.Parent = api.remotes
	menu.OnServerEvent:Connect(function(player, key)
		local s = api.sessions[player]
		if not s or not Guard.allow(player, "MenuOpened") or type(key) ~= "string" or not MENUS[key] then
			return
		end
		api.dotSeen(player, s, key) -- that menu's red dot is followed (Dots.luau)
		local seen = lastMenu[player] or {}
		lastMenu[player] = seen
		local now = os.clock()
		if now - (seen[key] or 0) >= 3 then
			seen[key] = now
			Telemetry.custom(player, "Menu", key, realm(s))
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
			api.notify:FireClient(player, "shopPass", it.name, it.key)
			print(string.format("[Tycoon][shop] pass %s bought by %d", it.key, player.UserId))
		elseif not s.passes[it.key] then
			-- Roblox answers "already owned" with purchased = false: an owner whose join check failed
			task.spawn(function()
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
				if ok and owns and api.sessions[player] == s then
					setPass(player, s, it.key)
				end
			end)
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
		lastMenu[player] = nil
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
				if hrp and not player:GetAttribute("Riding") then -- a sword rider never buys (D76)
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
