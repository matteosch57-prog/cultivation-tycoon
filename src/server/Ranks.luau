-- Hub rankings (owner 2026-10-22: "we need this for people to see easily whose better", "a country
-- ranking filter too", "3 different rankings: biggest qi/s too and maybe weekly ... playtime";
-- research docs/research/2026-10-22_progression_pushes.md gap 1, DevForum global-board threads).
-- Config.RANKS lists the boards; each has a global OrderedDataStore and one per country
-- (LocalizationService), one key per player:
--   sects: realms climbed in every life * 1000 + lives (`data.climbed`, one per breakthrough,
--          monotonic: a reset can never raise it, lesson "index on the monotonic peak")
--   qi:    the best steady qi per second ever reached (`data.peakSteady`, monotonic; owner
--          2026-10-23: no pill, Spirit Tide or friends bonus, so a short stack sets no record)
--   week:  seconds played this week (`data.weekSec` for `data.week`); a new week is a new store
-- Writes: a changed score is saved at most once per RANK_WRITE_GAP s per player, and on leave
-- (audit 2026-10-23: every 60 s wrote 6 per player per minute, over Roblox's 5). Reads: the top
-- RANK_READ of each board once per RANK_REFRESH s (global + each country with a player here), only
-- with request budget to spare (ServerHealth watches GetSorted / SetSorted). The hub wall shows the
-- top RANK_TOP (Ranks.top / Ranks.changed); the Rankings screen (Ranks.client, owner pick C
-- 2026-10-23, mock docs/art/mocks/ranks_C.jpg) asks Ranks.fetch through Remotes.Rankings for
-- Global, Country or Friends. Friends' scores are GetAsync on the global store, cached per server.
-- Studio with the mock save (Config.MOCK_DATASTORE) ranks only the players on this server.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Ranks = {}
Ranks.top = {} -- [key] = global rows, best first, cut to RANK_TOP (the wall)
local changed = Instance.new("BindableEvent")
Ranks.changed = changed.Event -- (key, rows) when the top of a global board changes

local mock = Config.MOCK_DATASTORE and RunService:IsStudio()
local suffix = RunService:IsStudio() and "_studio" or ""
local MAX_SCORE = 2 ^ 53 -- OrderedDataStore values are integers

-- the score a board ranks `d` by (an integer, higher is better)
local function score(key, d)
	if key == "sects" then
		return (d.climbed or 0) * 1000 + math.clamp(d.lives or 1, 1, 999)
	elseif key == "qi" then
		return math.floor(math.clamp(d.peakSteady or 0, 0, MAX_SCORE))
	elseif key == "week" then
		return d.week == Config.rankWeek() and math.floor(d.weekSec or 0) or 0
	end
	return 0
end
Ranks.score = score

-- stores[key .. "/" .. scope] = { store, name, rows = last page read { { userId, score } } }
local stores = {}
local function board(key, scope)
	local def = Config.RANKS[key]
	local name = def.store
		.. (def.weekly and ("_w" .. Config.rankWeek()) or "")
		.. (scope == "" and "" or "_" .. scope)
		.. suffix
	local id = key .. "/" .. scope
	local b = stores[id]
	if not b or b.name ~= name then -- a new week opens a new store
		b = { name = name, rows = {} }
		if not mock then
			local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
			b.store = ok and result or nil
			if not ok then
				warn("[Tycoon][ranks] store unavailable")
			end
		end
		stores[id] = b
	end
	return b
end

local pending = {} -- [userId] = { [key] = score not yet written }
local written = {} -- [userId] = { [key] = last score written }
local wroteAt = {} -- [userId] = os.clock() of the last write round that saved something
local names = {} -- [userId] = display name (GetUserInfosByUserIdsAsync, batched)
local countries = {} -- [userId] = "FR" or false (players met on this server)
local here = {} -- [userId] = { [key] = live score } of players on this server
local merged = {} -- [key .. "/" .. scope] = { { userId, score } } best first, cut to RANK_READ

local function budget(rt)
	return DataStoreService:GetRequestBudgetForRequestType(rt) >= Config.RANK_MIN_BUDGET
end

-- fetch the display names of `ids` that have none yet, up to 200 a call (one web call, not one each)
local function learnNames(ids)
	local missing = {}
	for _, id in ids do
		if names[id] == nil and id > 0 then
			local plr = Players:GetPlayerByUserId(id)
			if plr then
				names[id] = plr.DisplayName
			elseif #missing < 200 then
				table.insert(missing, id)
			end
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
	if ok and type(infos) == "table" then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	end
	for _, id in missing do
		names[id] = names[id] or false -- unknown: shown as "Sect <id>", never asked again
	end
end

local function nameOf(userId)
	return names[userId] or ("Sect " .. userId)
end

local function countryOf(player)
	if countries[player.UserId] == nil then
		local ok, cc = pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, player)
		countries[player.UserId] = ok and type(cc) == "string" and cc:match("^%u%u$") or false
	end
	return countries[player.UserId] or nil
end

-- a session reports its scores (join, breakthrough, reincarnation, the play tick, leave)
function Ranks.submit(player, d)
	local id = player.UserId
	here[id] = here[id] or {}
	written[id] = written[id] or {}
	names[id] = player.DisplayName
	task.spawn(countryOf, player)
	for key in Config.RANKS do
		local s = score(key, d)
		here[id][key] = s
		if written[id][key] ~= s and s > 0 then
			pending[id] = pending[id] or {}
			pending[id][key] = s
		end
	end
end

-- save `userId`'s pending scores; not within RANK_WRITE_GAP of the last save unless `now` (leave)
local function write(userId, now)
	local p = pending[userId]
	if not p or mock then
		return
	end
	if not now and os.clock() - (wroteAt[userId] or -math.huge) < Config.RANK_WRITE_GAP then
		return
	end
	wroteAt[userId] = os.clock()
	for key, s in p do
		if not budget(Enum.DataStoreRequestType.SetIncrementSortedAsync) then
			return -- the rest waits for the next round
		end
		local ok = true
		for _, scope in { "", countries[userId] or nil } do
			local b = board(key, scope)
			if b.store then
				ok = pcall(b.store.SetAsync, b.store, tostring(userId), s) and ok
			end
		end
		if ok then
			p[key] = nil
			written[userId] = written[userId] or {}
			written[userId][key] = s
		else
			warn("[Tycoon][ranks] write failed")
		end
	end
	if next(p) == nil then
		pending[userId] = nil
	end
end

-- keep a leaver's latest score in the cached pages until the next read brings the stored row
local function keep(key, scope, userId, s)
	local rows = board(key, scope).rows
	for _, r in rows do
		if r.userId == userId then
			r.score = math.max(r.score, s)
			return
		end
	end
	table.insert(rows, { userId = userId, score = s })
end

function Ranks.leave(player, d)
	Ranks.submit(player, d)
	local id = player.UserId
	for key, s in here[id] or {} do
		if s > 0 then
			keep(key, "", id, s)
			if countries[id] then
				keep(key, countries[id], id, s)
			end
		end
	end
	here[id] = nil
	task.spawn(function()
		write(id, true)
		if not Players:GetPlayerByUserId(id) then -- gone: drop the per-player tables (names stay for the rows)
			written[id], wroteAt[id] = nil, nil
			if not pending[id] then
				countries[id] = nil
			end
		end
	end)
end

-- the row a client or the wall draws
local function row(key, userId, s, rank)
	local r = { userId = userId, name = nameOf(userId), rank = rank }
	if key == "sects" then
		r.value, r.extra = s // 1000, s % 1000 -- realms climbed, lives
	else
		r.value = s
	end
	return r
end

-- cached page + the live scores of players here (of that country), best first, cut to RANK_READ
local function merge(key, scope)
	local rows, at = {}, {}
	for _, r in board(key, scope).rows do
		table.insert(rows, { userId = r.userId, score = r.score })
		at[r.userId] = rows[#rows]
	end
	for id, scores in here do
		local s = scores[key] or 0
		if s > 0 and (scope == "" or countries[id] == scope) then
			if at[id] then
				at[id].score = math.max(at[id].score, s)
			else
				table.insert(rows, { userId = id, score = s })
			end
		end
	end
	table.sort(rows, function(a, b)
		return a.score > b.score
	end)
	while #rows > Config.RANK_READ do
		table.remove(rows)
	end
	merged[key .. "/" .. scope] = rows
	if scope == "" then
		local list = {}
		for i = 1, math.min(#rows, Config.RANK_TOP) do
			table.insert(list, row(key, rows[i].userId, rows[i].score, i))
		end
		local was = Ranks.top[key]
		if not was or HttpService:JSONEncode(was) ~= HttpService:JSONEncode(list) then
			Ranks.top[key] = list
			changed:Fire(key, list)
		end
	end
end

local function read(key, scope)
	local b = board(key, scope)
	if not b.store or not budget(Enum.DataStoreRequestType.GetSortedAsync) then
		return
	end
	local ok, page = pcall(function()
		return b.store:GetSortedAsync(false, Config.RANK_READ):GetCurrentPage()
	end)
	if not ok then
		warn("[Tycoon][ranks] read failed")
		return
	end
	b.rows = {}
	local ids = {}
	for _, e in page do
		local id = tonumber(e.key)
		if id then
			table.insert(b.rows, { userId = id, score = e.value })
			table.insert(ids, id)
		end
	end
	learnNames(ids)
end

-- the scopes this server shows: global and the countries of the players here
local function scopes()
	local list, seen = { "" }, {}
	for id in here do
		local cc = countries[id]
		if cc and not seen[cc] then
			seen[cc] = true
			table.insert(list, cc)
		end
	end
	return list
end

local function redraw(due)
	for _, scope in scopes() do
		for key in Config.RANKS do
			if due then
				read(key, scope)
			end
			merge(key, scope)
		end
	end
end

-- Friends: [userId] = { at = os.clock(), ids = { friend ids, you first } } (GetFriendsAsync pages)
local friendLists = {}
local function friendsOf(player)
	local f = friendLists[player.UserId]
	if f and os.clock() - f.at < Config.RANK_REFRESH then
		return f.ids
	end
	local ids = { player.UserId }
	local ok, pages = pcall(Players.GetFriendsAsync, Players, player.UserId)
	while ok and pages and #ids <= Config.RANK_FRIENDS do
		for _, info in pages:GetCurrentPage() do
			if #ids > Config.RANK_FRIENDS then
				break
			end
			table.insert(ids, info.Id)
			if names[info.Id] == nil and type(info.DisplayName) == "string" then
				names[info.Id] = info.DisplayName
			end
		end
		if pages.IsFinished then
			break
		end
		ok = pcall(pages.AdvanceToNextPageAsync, pages)
	end
	friendLists[player.UserId] = { at = os.clock(), ids = ids }
	return ids
end

-- a friend's stored score on a global board: [key] = { [userId] = { score, at } }, kept RANK_REFRESH s
local friendScores = {}
local function storedScore(key, userId)
	friendScores[key] = friendScores[key] or {}
	local c = friendScores[key][userId]
	if c and os.clock() - c.at < Config.RANK_REFRESH then
		return c.score
	end
	local b = board(key, "")
	if not b.store or not budget(Enum.DataStoreRequestType.GetAsync) then
		return c and c.score or 0
	end
	local ok, v = pcall(b.store.GetAsync, b.store, tostring(userId))
	if not ok then
		return c and c.score or 0
	end
	friendScores[key][userId] = { score = tonumber(v) or 0, at = os.clock() }
	return friendScores[key][userId].score
end

-- the list for the Rankings screen: scope "global" | "country" | "friends"
-- returns { rows = { row }, me = row or nil (rank nil = past RANK_READ), country = "FR" or nil }
function Ranks.fetch(player, key, scope)
	local id = player.UserId
	local cc = countryOf(player)
	local list = {}
	if scope == "friends" then
		local ids = friendsOf(player)
		local scores = {}
		local left = #ids
		for _, fid in ids do
			task.spawn(function()
				local live = here[fid] and here[fid][key]
				scores[fid] = live or storedScore(key, fid)
				left -= 1
			end)
		end
		local t = os.clock()
		while left > 0 and os.clock() - t < 8 do
			task.wait(0.1)
		end
		for fid, s in scores do
			if s > 0 then
				table.insert(list, { userId = fid, score = s })
			end
		end
		table.sort(list, function(a, b)
			return a.score > b.score
		end)
	else
		local sc = scope == "country" and cc or ""
		if scope == "country" and not cc then
			return { rows = {}, country = nil }
		end
		merge(key, sc) -- cached page + the live scores here now (no store call)
		list = merged[key .. "/" .. sc]
	end
	local ids = {}
	for i = 1, math.min(#list, Config.RANK_READ) do
		table.insert(ids, list[i].userId)
	end
	learnNames(ids)
	local rows, me = {}, nil
	for i = 1, math.min(#list, Config.RANK_READ) do
		local r = row(key, list[i].userId, list[i].score, i)
		table.insert(rows, r)
		if r.userId == id then
			me = r
		end
	end
	if not me then
		local s = (here[id] and here[id][key]) or 0
		me = row(key, id, s, nil)
	end
	return { rows = rows, me = me, country = cc }
end

function Ranks.start()
	task.spawn(function()
		local sinceRead = math.huge
		while true do
			for id in pending do
				write(id)
			end
			local due = sinceRead >= Config.RANK_REFRESH
			if due then
				sinceRead = 0
			end
			redraw(due)
			task.wait(Config.RANK_WRITE_EVERY)
			sinceRead += Config.RANK_WRITE_EVERY
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		friendLists[player.UserId] = nil
	end)
end

-- a player here changed score: redraw from the cached pages, no new read
function Ranks.touch()
	task.defer(redraw, false)
end

-- Studio only: show `list` on a board (captures and layout checks with ten rows)
function Ranks.debugRows(key, list)
	if RunService:IsStudio() then
		Ranks.top[key] = list
		changed:Fire(key, list)
	end
end

return Ranks
