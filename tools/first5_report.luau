-- First 5 minutes report (thread "Keep new players past 10 minutes", 2026-10-26): where new players
-- stop in their FIRST session, second by second, from the journals in the live saves.
-- READ ONLY (ListKeysAsync + GetAsync on the live store, never a write). Paste into the Studio command
-- bar in Edit with "Enable Studio Access to API Services" on. It runs in the background, paced under
-- the GetAsync budget (lesson 2026-10-25: never read hundreds of saves in one blocking call), and
-- keeps its result in _G.First5. Check progress with: print(_G.First5 and _G.First5.status)
-- and print the report with: print(_G.First5.report). Only anonymous totals and timelines leave Studio.
local MAX_PLAYERS = 700
local STORE = "CultivationTycoon_v1" -- Config.DATASTORE (the live store)
local SKIP = { [0] = true } -- owner accounts are filled in by the caller: SKIP[userId] = true
for _, id in _G.First5Skip or {} do
	SKIP[id] = true
end

local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore(STORE)

local R = { status = "listing", read = 0 }
_G.First5 = R

local function waitBudget(kind)
	while DataStoreService:GetRequestBudgetForRequestType(kind) < 2 do
		task.wait(1)
	end
end

local function median(t)
	if #t == 0 then
		return 0
	end
	table.sort(t)
	return t[math.ceil(#t / 2)]
end

local function bucket(s)
	if s < 30 then
		return "a <30s"
	elseif s < 60 then
		return "b 30-60s"
	elseif s < 120 then
		return "c 1-2m"
	elseif s < 300 then
		return "d 2-5m"
	elseif s < 600 then
		return "e 5-10m"
	end
	return "f 10m+"
end

-- short codes for the timelines
local function short(code)
	return (code:gsub("^buy:", "+"):gsub("^Feature:", "F:"):gsub("^Funnel:", ""))
end

task.spawn(function()
	local keys = {}
	waitBudget(Enum.DataStoreRequestType.ListAsync)
	local ok, pages = pcall(store.ListKeysAsync, store, nil, 100)
	while ok and pages do
		for _, info in pages:GetCurrentPage() do
			local id = tonumber(info.KeyName:match("^u(%d+)$"))
			if id and not SKIP[id] then
				table.insert(keys, info.KeyName)
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
	R.keys = #keys
	-- a random sample, not the first keys in name order
	local rng = Random.new(26)
	for i = #keys, 2, -1 do
		local k = rng:NextInteger(1, i)
		keys[i], keys[k] = keys[k], keys[i]
	end
	R.status = "reading"

	local byBucket = {} -- [bucket] = { n, buys = {}, idle = {}, last = {[code]=n}, maxGap = {}, gapAt = {[code]=n} }
	local stepReach, stepLeft60 = {}, {} -- [code] = players who reached it in session 1 / who left within 60 s of it
	local firstBuy, timelines, cohorts = {}, {}, {}
	local players, noLog = 0, 0
	local STEPS = {}
	for _, c in { "buy:platform", "buy:bridge_fields", "buy:bridge_disciples", "buy:hall", "buy:bridge_dao", "buy:array" } do
		STEPS[c] = true
	end

	for _, key in keys do
		if players >= MAX_PLAYERS then
			break
		end
		waitBudget(Enum.DataStoreRequestType.GetAsync)
		local okR, rec = pcall(store.GetAsync, store, key)
		R.read += 1
		local d = okR and type(rec) == "table" and (rec.data or rec) or nil
		local j = d and d.journal
		if j and j.log and #j.log > 0 and j.sess and j.sess[1] then
			players += 1
			local start, len = j.sess[1]:match("^(%d+)|(%d+)|")
			start, len = tonumber(start), tonumber(len)
			local day = os.date("!%m-%d", start)
			cohorts[day] = (cohorts[day] or 0) + 1
			-- the first session's lines: up to the first "leave"
			local lines = {}
			for _, line in j.log do
				local t, code = line:match("^(%d+)|(.+)$")
				t = tonumber(t)
				table.insert(lines, { t = t, c = code })
				if code == "leave" then
					break
				end
			end
			local leaveT = lines[#lines].c == "leave" and lines[#lines].t or len
			local b = bucket(leaveT)
			local B = byBucket[b]
			if not B then
				B = { n = 0, buys = {}, idle = {}, last = {}, maxGap = {}, gapAt = {} }
				byBucket[b] = B
			end
			B.n += 1
			local buys, lastAct, prevT, maxGap, gapCode, fb = 0, nil, 0, 0, "start", nil
			for _, l in lines do
				if l.c ~= "leave" and l.c ~= "join" then
					lastAct = l
					if l.c:find("^buy:") then
						buys += 1
						fb = fb or l.t
					end
					if l.t - prevT > maxGap then
						maxGap, gapCode = l.t - prevT, l.c
					end
					prevT = l.t
					if STEPS[l.c] or l.c:find("^Recruit") or l.c == "buy:breakthrough" then
						stepReach[l.c] = (stepReach[l.c] or 0) + 1
						if leaveT - l.t <= 60 then
							stepLeft60[l.c] = (stepLeft60[l.c] or 0) + 1
						end
					end
				end
			end
			-- the wait before leaving counts as a gap too
			if leaveT - prevT > maxGap then
				maxGap, gapCode = leaveT - prevT, "(left while waiting)"
			end
			table.insert(B.buys, buys)
			table.insert(B.idle, leaveT - (lastAct and lastAct.t or 0))
			table.insert(B.maxGap, maxGap)
			B.gapAt[gapCode] = (B.gapAt[gapCode] or 0) + 1
			local lc = lastAct and lastAct.c or "(nothing)"
			B.last[lc] = (B.last[lc] or 0) + 1
			if fb then
				table.insert(firstBuy, fb)
			end
			if leaveT < 300 and #timelines < 60 then
				local parts = {}
				for _, l in lines do
					if l.c ~= "join" then
						table.insert(parts, l.t .. short(l.c))
					end
				end
				table.insert(timelines, b:sub(3) .. " | " .. table.concat(parts, " "))
			end
		elseif d then
			noLog += 1
		end
	end

	-- the report
	local out = {}
	local function p(...)
		table.insert(out, string.format(...))
	end
	p("[First5] %d saves listed, %d read, %d with a first-session log, %d without", R.keys, R.read, players, noLog)
	local cs = {}
	for day, n in cohorts do
		table.insert(cs, day .. "=" .. n)
	end
	table.sort(cs)
	p("cohorts by first join (UTC): %s", table.concat(cs, " "))
	p("first buy: median %ds (players with a buy: %d)", median(firstBuy), #firstBuy)
	local bs = {}
	for b in byBucket do
		table.insert(bs, b)
	end
	table.sort(bs)
	for _, b in bs do
		local B = byBucket[b]
		p(
			"== left %s: %d (%.0f%%) | buys median %d | idle before leaving median %ds | longest wait median %ds",
			b:sub(3),
			B.n,
			100 * B.n / players,
			median(B.buys),
			median(B.idle),
			median(B.maxGap)
		)
		local function top(t, label)
			local arr = {}
			for c, n in t do
				table.insert(arr, { c, n })
			end
			table.sort(arr, function(x, y)
				return x[2] > y[2]
			end)
			local s = {}
			for i = 1, math.min(8, #arr) do
				table.insert(s, short(arr[i][1]) .. " " .. arr[i][2])
			end
			p("   %s: %s", label, table.concat(s, ", "))
		end
		top(B.last, "last action")
		top(B.gapAt, "longest wait ended at")
	end
	p("== steps: reached in session 1 / left within 60 s of it")
	local ss = {}
	for c in stepReach do
		table.insert(ss, c)
	end
	table.sort(ss, function(x, y)
		return stepReach[x] > stepReach[y]
	end)
	for _, c in ss do
		p("   %-28s %4d  left<60s %3d (%.0f%%)", short(c), stepReach[c], stepLeft60[c] or 0, 100 * (stepLeft60[c] or 0) / stepReach[c])
	end
	p("== timelines of first sessions under 5 min (seconds+code)")
	for _, t in timelines do
		p("%s", t)
	end
	R.report = table.concat(out, "\n")
	R.status = "done"
end)
print("[First5] started; poll _G.First5.status")
