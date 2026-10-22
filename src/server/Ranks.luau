-- The best sects across every server (owner 2026-10-22: "we need this for people to see easily whose
-- better"; research docs/research/2026-10-22_progression_pushes.md gap 1, DevForum global-board
-- threads). Score = realms climbed in every life (`data.climbed`, one per breakthrough, monotonic:
-- a reset can never raise it, R-lesson "index on the monotonic peak"), lives as the tie-break:
-- climbed * 1000 + lives in one OrderedDataStore key per player.
-- Writes are batched (one SetAsync per changed player every RANK_WRITE_EVERY s, and on leave) and
-- reads come once per RANK_REFRESH s (GetSortedAsync), both only with request budget to spare
-- (ServerHealth watches GetSorted / SetSorted). Studio with the mock save (Config.MOCK_DATASTORE)
-- ranks only the players on this server and touches no store.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Ranks = {}
Ranks.top = {} -- { { userId, name, climbed, lives } } best first
local changed = Instance.new("BindableEvent")
Ranks.changed = changed.Event

local mock = Config.MOCK_DATASTORE and RunService:IsStudio()
local store = nil
if not mock then
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.RANK_STORE .. (RunService:IsStudio() and "_studio" or ""))
	end)
	if ok then
		store = result
	else
		warn("[Tycoon][ranks] store unavailable")
	end
end

local storeRows = {} -- the last page read from the store: { { userId, score } }
local pending = {} -- [userId] = score not yet written
local written = {} -- [userId] = last score written
local names = {} -- [userId] = name (cache: GetNameFromUserIdAsync is a web call)
local local_ = {} -- [userId] = score of players on this server (the mock board, and fresh rows)

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

-- a session reports its score (breakthrough, reincarnation, join, leave)
function Ranks.submit(player, d)
	local s = Ranks.score(d)
	local_[player.UserId] = s
	if written[player.UserId] ~= s then
		pending[player.UserId] = s
	end
end

local function write(userId)
	local s = pending[userId]
	if not s or not store or not budget(Enum.DataStoreRequestType.SetIncrementSortedAsync) then
		return
	end
	pending[userId] = nil
	local ok = pcall(store.SetAsync, store, tostring(userId), s)
	if ok then
		written[userId] = s
	else
		pending[userId] = pending[userId] or s -- retry next round
		warn("[Tycoon][ranks] write failed")
	end
end

function Ranks.leave(player, d)
	Ranks.submit(player, d)
	local_[player.UserId] = nil
	-- keep the leaver on the board until the next read brings the stored row
	local found = false
	for _, r in storeRows do
		if r.userId == player.UserId then
			r.score = math.max(r.score, Ranks.score(d))
			found = true
		end
	end
	if not found then
		table.insert(storeRows, { userId = player.UserId, score = Ranks.score(d) })
	end
	task.spawn(write, player.UserId)
end

local function publishTop(rows)
	local list = {}
	for _, r in rows do
		table.insert(list, { userId = r.userId, name = nameOf(r.userId), climbed = r.score // 1000, lives = r.score % 1000 })
	end
	local key = HttpService:JSONEncode(list)
	if key ~= workspace:GetAttribute("Ranks") then
		Ranks.top = list
		workspace:SetAttribute("Ranks", key) -- the HUD screen reads this; no remote needed
		changed:Fire(list)
	end
end

-- store rows + the live scores of players here, best first, cut to RANK_TOP
local function merge()
	local rows, at = {}, {}
	for _, r in storeRows do
		table.insert(rows, { userId = r.userId, score = r.score })
		at[r.userId] = rows[#rows]
	end
	-- players here count with their live score (the store lags by up to a write round)
	for id, s in local_ do
		if at[id] then
			at[id].score = math.max(at[id].score, s)
		else
			table.insert(rows, { userId = id, score = s })
		end
	end
	table.sort(rows, function(a, b)
		return a.score > b.score
	end)
	while #rows > Config.RANK_TOP do
		table.remove(rows)
	end
	publishTop(rows)
end

local function read()
	if not store or not budget(Enum.DataStoreRequestType.GetSortedAsync) then
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, Config.RANK_TOP):GetCurrentPage()
	end)
	if not ok then
		warn("[Tycoon][ranks] read failed")
		return
	end
	storeRows = {}
	for _, e in page do
		local id = tonumber(e.key)
		if id then
			table.insert(storeRows, { userId = id, score = e.value })
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
			if sinceRead >= Config.RANK_REFRESH then
				sinceRead = 0
				read()
				merge()
			end
			task.wait(Config.RANK_WRITE_EVERY)
			sinceRead += Config.RANK_WRITE_EVERY
		end
	end)
end

-- a player here changed score: redraw from the cached store rows, no new read
function Ranks.touch()
	task.defer(merge)
end

return Ranks
