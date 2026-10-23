-- Save safety: one DataStore record per player, guarded by a session lock.
--
-- record = { v = DATA_VERSION, data = <player data or nil>, lock = { id = sessionId, t = os.time() } }
--
-- A session takes the lock on load and refreshes it on every save; it releases it on leave. A save
-- only lands while the record still carries this session's lock, so a slow save from an old server
-- can never overwrite what a newer server loaded (a server hop, or a quick rejoin). A lock whose
-- holder stopped refreshing it for SAVE_LEASE seconds (a crashed server) may be taken over.
-- UpdateAsync transforms only report through their return value: a cancel returns nil, and the
-- reason is read back afterwards with GetAsync.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SaveStore = {}

-- warn with constant text (the Error Report groups by string), the detail in a print
local function log(event, userId, detail)
	warn("[Tycoon][save] " .. event)
	print(string.format("[Tycoon][save] event=%s user=%d %s", event, userId, detail or ""))
end

-- Migration hook: every older record shape is lifted to DATA_VERSION here, one step at a time.
local function migrate(record)
	if type(record) ~= "table" then
		return nil
	end
	if record.v == nil then
		-- v0 (before 2026-10-21 save safety): the bare data table, no version and no lock.
		record = { v = 1, data = record }
	end
	-- Add the next step here: if record.v == 1 then ... record.v = 2 end
	return record
end

local function lockFree(record, sessionId)
	local lock = record.lock
	return not lock or lock.id == sessionId or os.time() - (lock.t or 0) >= Config.SAVE_LEASE
end

-- Runs fn with up to SAVE_RETRIES attempts and exponential backoff. Returns ok, result.
local function retry(what, userId, fn)
	local delay = 1
	for attempt = 1, Config.SAVE_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		log(what .. "_error", userId, string.format("attempt=%d err=%s", attempt, tostring(result)))
		if attempt < Config.SAVE_RETRIES then
			task.wait(delay)
			delay *= 2
		end
	end
	return false, nil
end

function SaveStore.newSessionId()
	return HttpService:GenerateGUID(false)
end

-- Takes the lock and returns (data or nil for a new player, true), or (nil, false, reason) when the
-- save could not be read ("error"), is newer than this server ("newer") or stays locked ("locked"):
-- that session must never save (Main asks the player to rejoin). `stillHere()` stops the wait early;
-- `onLocked()` (optional) runs each time the lock is found held, before the wait.
function SaveStore.load(store, userId, sessionId, stillHere, onLocked)
	local key = "u" .. userId
	for wait = 1, Config.SAVE_LOCK_WAITS do
		local ok, record = retry("load", userId, function()
			return store:UpdateAsync(key, function(old)
				local rec = migrate(old) or { v = Config.DATA_VERSION }
				if rec.v > Config.DATA_VERSION or not lockFree(rec, sessionId) then
					return nil -- cancel: newer format or another live session holds it
				end
				rec.lock = { id = sessionId, t = os.time() }
				return rec, { userId } -- tag the key with its player (GDPR erasure, Creator Hub data tools)
			end)
		end)
		if not ok then
			log("load_failed", userId)
			return nil, false, "error"
		end
		if record then
			return record.data, true
		end
		-- Cancelled: find out why.
		local readOk, current = retry("load_check", userId, function()
			return store:GetAsync(key)
		end)
		current = readOk and migrate(current) or nil
		if current and current.v > Config.DATA_VERSION then
			log("load_newer_version", userId, string.format("v=%d mine=%d", current.v, Config.DATA_VERSION))
			return nil, false, "newer"
		end
		log("load_locked", userId, string.format("wait=%d/%d", wait, Config.SAVE_LOCK_WAITS))
		if wait < Config.SAVE_LOCK_WAITS then
			if onLocked then
				onLocked()
			end
			task.wait(Config.SAVE_LOCK_WAIT)
			if not stillHere() then
				return nil, false, "left"
			end
		end
	end
	log("load_lock_held", userId, "another session kept the lock")
	return nil, false, "locked"
end

-- Writes data while this session still holds the lock; `release` drops the lock (leave, close).
-- Returns true when the write landed.
function SaveStore.save(store, userId, sessionId, data, release)
	local ok, record = retry("save", userId, function()
		return store:UpdateAsync("u" .. userId, function(old)
			local rec = migrate(old)
			if not rec or not rec.lock or rec.lock.id ~= sessionId or rec.v > Config.DATA_VERSION then
				return nil -- cancel: this session no longer owns the save
			end
			rec.v = Config.DATA_VERSION
			rec.data = data
			rec.lock = if release then nil else { id = sessionId, t = os.time() }
			return rec, { userId }
		end)
	end)
	if not ok then
		log("save_failed", userId, release and "release=true" or "")
		return false
	end
	if not record then
		log("save_lock_lost", userId, "another session owns this save; write skipped")
		return false
	end
	return true
end

return SaveStore
