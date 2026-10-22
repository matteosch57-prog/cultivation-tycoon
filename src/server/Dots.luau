-- Red dots (owner 2026-10-22: "make them premium ... wire them from the HUD to the action always, no
-- red dot you can't clear. We can have a shop one once every X time"). The server decides which dots
-- are lit (it holds the state that changes: disciples, karma, lives, the group gift, the clock) and
-- publishes them as one JSON attribute `Dots`; the client draws them and, on opening a menu, fires
-- MenuOpened / ShopOpened, which mark that dot seen here (`data.dots`, saved). Gift and pill dots are
-- the client's own (their attributes already say "ready", and claiming clears them).
--
-- Every dot leads to a dot one level down (the HUD button, then the tab / the tile / the disciple)
-- and clears once its menu is opened; a standing condition (karma covers a node) lights again only
-- on a NEW edge (another node becomes affordable), never just because the condition still holds.
local HttpService = game:GetService("HttpService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Dots = {}

local function seenOf(d)
	d.dots = d.dots or {}
	return d.dots
end

-- disciples: how many of each name the player had when they last opened the list
local function counts(list)
	local c = {}
	for _, name in list do
		c[name] = (c[name] or 0) + 1
	end
	return c
end

-- karma: the node levels the player can buy right now ("echo:2" = Soul Echo's 2nd level)
local function affordable(d)
	local out = {}
	for _, node in Config.DAO do
		local lv = (d.dao or {})[node.key] or 0
		local cost = node.costs[lv + 1]
		if cost and (d.karma or 0) >= cost then
			table.insert(out, node.key .. ":" .. (lv + 1))
		end
	end
	return out
end

-- the Shop's free daily gift: claimable once per UTC day, after DOT_SHOP_FIRST s of play
function Dots.freeReady(d)
	return (d.playSec or 0) >= Config.DOT_SHOP_FIRST and d.shopFreeDay ~= os.time() // 86400
end

-- what is lit now: { disc = { [name] = newCount }, karma = { "seat:1", ... }, shop = "free",
-- group = true, reinc = true }
function Dots.compute(s)
	local d = s.data
	local seen = seenOf(d)
	local lit = {}
	-- disciples that arrived since the list was last opened
	local had = seen.disc or counts(d.disciples) -- first run: nothing is "new"
	seen.disc = had
	local new = {}
	local any = false
	for name, n in counts(d.disciples) do
		if n > (had[name] or 0) then
			new[name] = n - (had[name] or 0)
			any = true
		end
	end
	if any then
		lit.disc = new
	end
	-- karma nodes that became affordable since the Karma Shop was last opened
	local kseen = seen.karma or {}
	local knew = {}
	for _, k in affordable(d) do
		if not kseen[k] then
			table.insert(knew, k)
		end
	end
	if #knew > 0 then
		lit.karma = knew
	end
	-- a rebirth is affordable and this rebirth's screen was not opened yet
	if (d.qi or 0) >= Config.rebirthPrice((d.lives or 1) - 1) and seen.reinc ~= (d.lives or 1) then
		lit.reinc = true
	end
	-- the Sect Gift (group): unclaimed, at most once a day
	local now = os.time()
	if Config.GROUP_ID > 0 and not (s.inGroup and d.groupClaimed) and now - (seen.group or 0) >= Config.DOT_GROUP_SECONDS then
		lit.group = true
	end
	-- the Shop: its free daily gift is waiting (claiming it clears the dot, not opening the Shop)
	if Dots.freeReady(d) then
		lit.shop = "free"
	end
	return lit
end

function Dots.publish(player, s)
	local json = HttpService:JSONEncode(Dots.compute(s))
	if player:GetAttribute("Dots") ~= json then
		player:SetAttribute("Dots", json)
	end
	-- the free gift's tile: 0 = ready, else seconds until it can be claimed (the next UTC day, or the
	-- first DOT_SHOP_FIRST s of play)
	local d = s.data
	local wait = 0
	if not Dots.freeReady(d) then
		wait = if (d.playSec or 0) < Config.DOT_SHOP_FIRST then math.ceil(Config.DOT_SHOP_FIRST - (d.playSec or 0)) else 86400 - os.time() % 86400
	end
	if player:GetAttribute("ShopFreeIn") ~= wait then
		player:SetAttribute("ShopFreeIn", wait)
	end
end

-- a menu was opened (MenuOpened key, or "shop"): its dot is followed
function Dots.seen(player, s, key)
	local d = s.data
	local seen = seenOf(d)
	if key == "disciples" then
		seen.disc = counts(d.disciples)
	elseif key == "karma" then
		local kseen = seen.karma or {}
		for _, k in affordable(d) do
			kseen[k] = true
		end
		seen.karma = kseen
	elseif key == "reinc" then
		seen.reinc = d.lives or 1
	elseif key == "group" then
		seen.group = os.time()
	else
		return
	end
	Dots.publish(player, s)
end

return Dots
