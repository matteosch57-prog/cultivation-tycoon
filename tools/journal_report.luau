-- Journal report: paste into the Studio command bar (Edit, not Play) with "Enable Studio Access to API
-- Services" on. READ ONLY: it only calls ListKeysAsync and GetAsync on the live save store, never a
-- write. Prints what players did (docs/design/DATA.md has how to read it).
--   USER_ID = 0   -> a summary over up to MAX_PLAYERS saves
--   USER_ID = 123 -> that one player's whole journal
local USER_ID = 0
local MAX_PLAYERS = 300
local STORE = "CultivationTycoon_v1" -- Config.DATASTORE (the live store, not "_studio")

local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore(STORE)

local function waitBudget(kind)
	while DataStoreService:GetRequestBudgetForRequestType(kind) < 1 do
		task.wait(1)
	end
end

local function read(key)
	waitBudget(Enum.DataStoreRequestType.GetAsync)
	local ok, rec = pcall(store.GetAsync, store, key)
	if ok and type(rec) == "table" then
		return rec.data or rec -- v0 records are the bare data table
	end
	return nil
end

local function median(t)
	if #t == 0 then
		return 0
	end
	table.sort(t)
	return t[math.ceil(#t / 2)]
end

if USER_ID ~= 0 then
	local d = read("u" .. USER_ID)
	local j = d and d.journal
	if not j then
		print("[Journal] no journal for", USER_ID)
		return
	end
	print(
		string.format(
			"[Journal] user %d: realm %d, best %d, lives %d, %d sessions, %.0f min played",
			USER_ID,
			d.realm or 1,
			d.best or 1,
			d.lives or 1,
			d.sessions or 0,
			(d.playSec or 0) / 60
		)
	)
	for _, line in j.sess do
		local start, len, afk, built = line:match("^(%d+)|(%d+)|(%d+)|(%d+)$")
		print(
			string.format(
				"  session %s  %d min  afk %d min  %s buildings",
				os.date("!%Y-%m-%d %H:%M", tonumber(start)),
				tonumber(len) // 60,
				tonumber(afk) // 60,
				built
			)
		)
	end
	for _, line in j.log do
		local t, code = line:match("^(%d+)|(.+)$")
		print(string.format("  %5.1f min  %s", tonumber(t) / 60, code))
	end
	return
end

-- summary
local players, withJournal, oneSession, returned1, returned7 = 0, 0, 0, 0, 0
local did, firstAt = {}, {} -- [code] = players who did it; [code] = { minutes of the first time }
local lastActs = {} -- [code] = one-session players whose last action before leaving was this
local sessLen, afkShare = {}, {}
local pages = (function()
	waitBudget(Enum.DataStoreRequestType.ListAsync)
	local ok, p = pcall(store.ListKeysAsync, store, nil, 100)
	return ok and p or nil
end)()
while pages and players < MAX_PLAYERS do
	for _, info in pages:GetCurrentPage() do
		if players >= MAX_PLAYERS then
			break
		end
		local d = read(info.KeyName)
		if d then
			players += 1
			local j = d.journal
			if j then
				withJournal += 1
				for code, at in j.first or {} do
					did[code] = (did[code] or 0) + 1
					firstAt[code] = firstAt[code] or {}
					table.insert(firstAt[code], at / 60)
				end
				local first, lenSum, afkSum = nil, 0, 0
				for _, line in j.sess or {} do
					local start, len, afk = line:match("^(%d+)|(%d+)|(%d+)|")
					start, len, afk = tonumber(start), tonumber(len), tonumber(afk)
					first = first or start
					lenSum += len
					afkSum += afk
					table.insert(sessLen, len / 60)
					if start - first >= 86400 and start - first < 2 * 86400 then
						returned1 += 1
						first = math.huge -- count a player once
					end
				end
				if lenSum > 0 then
					table.insert(afkShare, afkSum / lenSum)
				end
				if #(j.sess or {}) <= 1 then
					oneSession += 1
					-- the last real action before "leave"
					for i = #(j.log or {}), 1, -1 do
						local code = j.log[i]:match("^%d+|(.+)$")
						if code ~= "leave" and not code:find("^Feature:orb") then
							lastActs[code] = (lastActs[code] or 0) + 1
							break
						end
					end
				end
				if
					(d.sessions or 0) >= 2
					and (d.last or 0) - (tonumber(((j.sess or {})[1] or ""):match("^(%d+)")) or math.huge)
						>= 7 * 86400
				then
					returned7 += 1
				end
			end
		end
	end
	if pages.IsFinished then
		break
	end
	waitBudget(Enum.DataStoreRequestType.ListAsync)
	if not pcall(pages.AdvanceToNextPageAsync, pages) then
		break
	end
end

print(
	string.format(
		"[Journal] %d saves read, %d with a journal; %d played one session only",
		players,
		withJournal,
		oneSession
	)
)
print(string.format("[Journal] came back the next day: %d; still playing a week later: %d", returned1, returned7))
print(
	string.format(
		"[Journal] median session %.1f min, median afk share %d%%",
		median(sessLen),
		math.floor(median(afkShare) * 100)
	)
)
local rows = {}
for code, n in did do
	table.insert(rows, { code = code, n = n, at = median(firstAt[code]) })
end
table.sort(rows, function(a, b)
	return a.at < b.at
end)
print("[Journal] what players do, by median first time (share of journaled players, minutes played)")
for _, r in rows do
	print(string.format("  %5.1f min  %3d%%  %s", r.at, math.floor(r.n / math.max(1, withJournal) * 100), r.code))
end
local last = {}
for code, n in lastActs do
	table.insert(last, { code = code, n = n })
end
table.sort(last, function(a, b)
	return a.n > b.n
end)
print("[Journal] one-session players: their last action before leaving")
for i = 1, math.min(15, #last) do
	print(string.format("  %3d  %s", last[i].n, last[i].code))
end
