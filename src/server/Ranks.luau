-- The best sects (owner 2026-10-22: "we need this for people to see easily whose better", "we can add
-- a country ranking filter too"; research docs/research/2026-10-22_progression_pushes.md gap 1,
-- DevForum global-board threads). Score = realms climbed in every life (`data.climbed`, one per
-- breakthrough, monotonic: a reset can never raise it, R-lesson "index on the monotonic peak"), lives
-- as the tie-break: climbed * 1000 + lives, one key per player in a global OrderedDataStore and in
-- the store of the player's country (LocalizationService).
-- Writes are batched (one round every RANK_WRITE_EVERY s, and on leave) and reads come once per
-- RANK_REFRESH s per board (the global one and each country with a player here), only with request
-- budget to spare (ServerHealth watches GetSorted / SetSorted). Boards reach clients as Workspace
-- attributes (`Ranks` = global, `Ranks_<CC>` = a country): JSON rows, no remote.
-- Studio with the mock save (Config.MOCK_DATASTORE) ranks only the players on this server.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Ranks = {}
Ranks.top = {} -- the global board: { { userId, name, climbed, lives, country } } best first
local changed = Instance.new("BindableEvent")
Ranks.changed = changed.Event -- fires with the global board when it changes

local mock = Config.MOCK_DATASTORE and RunService:IsStudio()
local suffix = RunService:IsStudio() and "_studio" or ""

-- boards[scope] = { store, rows = last page read { { userId, score } } }; scope "" = global
local boards = {}
local function board(scope)
	if not boards[scope] then
		local b = { rows = {} }
		if not mock then
			local ok, result = pcall(function()
				return DataStoreService:GetOrderedDataStore(Config.RANK_STORE .. (scope == "" and "" or "_" .. scope) .. suffix)
			end)
			b.store = ok and result or nil
			if not ok then
				warn("[Tycoon][ranks] store unavailable")
			end
		end
		boards[scope] = b
	end
	return boards[scope]
end
board("")

local pending = {} -- [userId] = score not yet written
local written = {} -- [userId] = last score written
local names = {} -- [userId] = name (cache: GetNameFromUserIdAsync is a web call)
local countries = {} -- [userId] = "FR" (players met on this server)
local here = {} -- [userId] = live score of players on this server

function Ranks.score(d)
	return (d.climbed or 0) * 1000 + math.clamp(d.lives or 1, 1, 999)
end

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

-- a session reports its score (join, breakthrough, reincarnation, leave)
function Ranks.submit(player, d)
	local s = Ranks.score(d)
	here[player.UserId] = s
	task.spawn(countryOf, player)
	if written[player.UserId] ~= s then
		pending[player.UserId] = s
	end
end

local function write(userId)
	local s = pending[userId]
	if not s or mock or not budget(Enum.DataStoreRequestType.SetIncrementSortedAsync) then
		return
	end
	pending[userId] = nil
	local ok = true
	for _, scope in { "", countries[userId] or nil } do
		local b = board(scope)
		if b.store then
			ok = pcall(b.store.SetAsync, b.store, tostring(userId), s) and ok
		end
	end
	if ok then
		written[userId] = s
	else
		pending[userId] = pending[userId] or s -- retry next round
		warn("[Tycoon][ranks] write failed")
	end
end

-- keep a leaver's latest score in the cached pages until the next read brings the stored row
local function keep(scope, userId, s)
	local rows = board(scope).rows
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
	local s = Ranks.score(d)
	here[player.UserId] = nil
	keep("", player.UserId, s)
	if countries[player.UserId] then
		keep(countries[player.UserId], player.UserId, s)
	end
	task.spawn(write, player.UserId)
end

-- cached page + the live scores of players here (of that country), best first, cut to RANK_TOP
local function merge(scope)
	local rows, at = {}, {}
	for _, r in board(scope).rows do
		table.insert(rows, { userId = r.userId, score = r.score })
		at[r.userId] = rows[#rows]
	end
	for id, s in here do
		if scope == "" or countries[id] == scope then
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
		local r = rows[i]
		table.insert(list, { userId = r.userId, name = nameOf(r.userId), climbed = r.score // 1000, lives = r.score % 1000, country = countries[r.userId] or nil })
	end
	local attr = scope == "" and "Ranks" or "Ranks_" .. scope
	local json = HttpService:JSONEncode(list)
	if json ~= workspace:GetAttribute(attr) then
		workspace:SetAttribute(attr, json)
		if scope == "" then
			Ranks.top = list
			changed:Fire(list)
		end
	end
end

local function read(scope)
	local b = board(scope)
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

-- the boards this server shows: the global one and the countries of the players here
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
			for _, scope in scopes() do
				if due then
					read(scope)
				end
				merge(scope)
			end
			task.wait(Config.RANK_WRITE_EVERY)
			sinceRead += Config.RANK_WRITE_EVERY
		end
	end)
end

-- a player here changed score: redraw from the cached pages, no new read
function Ranks.touch()
	task.defer(function()
		for _, scope in scopes() do
			merge(scope)
		end
	end)
end

return Ranks
