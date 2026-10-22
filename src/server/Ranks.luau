-- Hub rankings (owner 2026-10-22: "we need this for people to see easily whose better", "a country
-- ranking filter too", "3 different rankings: biggest qi/s too and maybe weekly ... playtime";
-- research docs/research/2026-10-22_progression_pushes.md gap 1, DevForum global-board threads).
-- Config.RANKS lists the boards; each has a global OrderedDataStore and one per country
-- (LocalizationService), one key per player:
--   sects: realms climbed in every life * 1000 + lives (`data.climbed`, one per breakthrough,
--          monotonic: a reset can never raise it, lesson "index on the monotonic peak")
--   qi:    the best qi per second ever reached (`data.peakRate`, monotonic)
--   week:  seconds played this week (`data.weekSec` for `data.week`); a new week is a new store
-- Writes are batched (one round every RANK_WRITE_EVERY s, and on leave) and reads come once per
-- RANK_REFRESH s per board (global + each country with a player here), only with request budget to
-- spare (ServerHealth watches GetSorted / SetSorted). Boards reach clients as Workspace attributes
-- `Rank_<key>` and `Rank_<key>_<CC>`: JSON rows { userId, name, value, extra, country }, no remote.
-- Studio with the mock save (Config.MOCK_DATASTORE) ranks only the players on this server.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Ranks = {}
Ranks.top = {} -- [key] = global rows, best first
local changed = Instance.new("BindableEvent")
Ranks.changed = changed.Event -- (key, rows) when a global board changes

local mock = Config.MOCK_DATASTORE and RunService:IsStudio()
local suffix = RunService:IsStudio() and "_studio" or ""
local MAX_SCORE = 2 ^ 53 -- OrderedDataStore values are integers

-- the score a board ranks `d` by (an integer, higher is better)
local function score(key, d)
	if key == "sects" then
		return (d.climbed or 0) * 1000 + math.clamp(d.lives or 1, 1, 999)
	elseif key == "qi" then
		return math.floor(math.clamp(d.peakRate or 0, 0, MAX_SCORE))
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
	local name = def.store .. (def.weekly and ("_w" .. Config.rankWeek()) or "") .. (scope == "" and "" or "_" .. scope) .. suffix
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
local names = {} -- [userId] = name (cache: GetNameFromUserIdAsync is a web call)
local countries = {} -- [userId] = "FR" or false (players met on this server)
local here = {} -- [userId] = { [key] = live score } of players on this server

local function budget(rt)
	return DataStoreService:GetRequestBudgetForRequestType(rt) >= Config.RANK_MIN_BUDGET
end

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local plr = Players:GetPlayerByUserId(userId)
	if plr then
		names[userId] = plr.DisplayName
		return names[userId]
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and n or "Unknown Sect"
	return names[userId]
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

local function write(userId)
	local p = pending[userId]
	if not p or mock then
		return
	end
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
	task.spawn(write, id)
end

local function row(key, userId, s)
	local r = { userId = userId, name = nameOf(userId), country = countries[userId] or nil }
	if key == "sects" then
		r.value, r.extra = s // 1000, s % 1000 -- realms climbed, lives
	else
		r.value = s
	end
	return r
end

-- cached page + the live scores of players here (of that country), best first, cut to RANK_TOP
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
	local list = {}
	for i = 1, math.min(#rows, Config.RANK_TOP) do
		table.insert(list, row(key, rows[i].userId, rows[i].score))
	end
	local attr = "Rank_" .. key .. (scope == "" and "" or "_" .. scope)
	local json = HttpService:JSONEncode(list)
	if json ~= workspace:GetAttribute(attr) then
		workspace:SetAttribute(attr, json)
		if scope == "" then
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
		return b.store:GetSortedAsync(false, Config.RANK_TOP):GetCurrentPage()
	end)
	if not ok then
		warn("[Tycoon][ranks] read failed")
		return
	end
	b.rows = {}
	for _, e in page do
		local id = tonumber(e.key)
		if id then
			table.insert(b.rows, { userId = id, score = e.value })
		end
	end
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
end

-- a player here changed score: redraw from the cached pages, no new read
function Ranks.touch()
	task.defer(redraw, false)
end

return Ranks
