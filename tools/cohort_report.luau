-- Cohort report (thread "Compare new players after tonight's update", 2026-10-27): first-session numbers
-- of players grouped by WHEN their first session started, so a publish can be compared with the days
-- before it on the same yardstick (the journal), not against Creator Hub's.
-- READ ONLY (ListKeysAsync + GetAsync on the live store, never a write). Paste into the Studio command
-- bar in Edit with "Enable Studio Access to API Services" on. It reads EVERY save (a cohort can only be
-- found by reading), paced under the GetAsync budget, in the background; result in _G.Cohort.
--   print(_G.Cohort.status, _G.Cohort.read, _G.Cohort.keys)   -- progress
--   print(_G.Cohort.report)                                     -- final at "done", partial every 100 reads
-- Only anonymous totals leave Studio. Set _G.CohortCuts before pasting to change the cohorts.
local STORE = "CultivationTycoon_v1" -- Config.DATASTORE (the live store)
local SESS_MAX = 30 -- Journal.luau: sess keeps the last 30, so sess[1] is the first session only below it

-- cohorts: { label, from (UTC os.time), to }
local function utc(y, m, d, h, mi)
	return DateTime.fromUniversalTime(y, m, d, h, mi or 0).UnixTimestamp
end
local CUTS = _G.CohortCuts
	or {
		{ "10-25", utc(2026, 10, 25, 0), utc(2026, 10, 26, 0) },
		{ "10-26", utc(2026, 10, 26, 0), utc(2026, 10, 27, 0) },
		{ "10-27 before 19:23", utc(2026, 10, 27, 0), utc(2026, 10, 27, 19, 23) },
		{ "10-27 19:23-21:38 (update)", utc(2026, 10, 27, 19, 23), utc(2026, 10, 27, 21, 38) },
		{ "after 21:38 (update + ads)", utc(2026, 10, 27, 21, 38), math.huge },
	}

local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore(STORE)
local SKIP = { [game.CreatorId] = true }
for _, id in _G.First5Skip or {} do
	SKIP[id] = true
end

local R = { status = "listing", read = 0, keys = 0 }
_G.Cohort = R

local function waitBudget(kind)
	while DataStoreService:GetRequestBudgetForRequestType(kind) < 1 do
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

local MARKS = { 60, 120, 300, 600, 1800 }

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
		R.keys = #keys
		if pages.IsFinished then
			break
		end
		waitBudget(Enum.DataStoreRequestType.ListAsync)
		if not pcall(pages.AdvanceToNextPageAsync, pages) then
			break
		end
	end
	R.status = "reading"

	local C = {} -- [label] = stats
	for _, cut in CUTS do
		C[cut[1]] = { n = 0, len = {}, mark = {}, bt = 0, btLeft60 = 0, btSec = {}, rb = 0, rbSec = {}, returned = 0, load = {} }
	end
	local noSess, trimmed, older, failed = 0, 0, 0, 0
	-- the report so far; rebuilt every 100 reads so a stalled read still has numbers
	local function build()
		local out = {}
		local function p(...)
			table.insert(out, string.format(...))
		end
		p("[Cohort] %d saves listed, %d read (%d failed%s), %d no ended session, %d over 30 sessions, %d first joined before the cohorts", R.keys, R.read, failed, R.read < R.keys and ", PARTIAL" or "", noSess, trimmed, older)
		for _, cut in CUTS do
			local S = C[cut[1]]
			local n = math.max(1, S.n)
			local marks = {}
			for _, m in MARKS do
				table.insert(marks, string.format("%dm %.0f%%", m / 60, 100 * (S.mark[m] or 0) / n))
			end
			p("== %s: %d players | first session median %ds | reached %s | came back %d (%.0f%%)", cut[1], S.n, median(S.len), table.concat(marks, " "), S.returned, 100 * S.returned / n)
			p(
				"   1st breakthrough in session 1: %d (%.0f%%), median at %ds, left within 60 s %d (%.0f%% of them) | rebirth in session 1: %d (%.0f%%), median at %ds",
				S.bt,
				100 * S.bt / n,
				median(S.btSec),
				S.btLeft60,
				100 * S.btLeft60 / math.max(1, S.bt),
				S.rb,
				100 * S.rb / n,
				median(S.rbSec)
			)
			local ls = {}
			for stage, t in S.load do
				table.insert(ls, string.format("%s med %ds n%d", stage, median(t), #t))
			end
			table.sort(ls)
			p("   load: %s", #ls > 0 and table.concat(ls, " | ") or "(no load codes)")
		end
		R.report = table.concat(out, "\n")
	end


	-- Studio Edit gives ~2,500 reads per opened place (2026-10-27): a bigger store takes two passes,
	-- reopening the place in between and setting _G.CohortFrom = 2501 for the second (keys are in name order)
	for i, key in keys do
		if i < (_G.CohortFrom or 1) then
			continue
		end
		waitBudget(Enum.DataStoreRequestType.GetAsync)
		local okR, rec = pcall(store.GetAsync, store, key)
		R.read += 1
		if R.read % 100 == 0 then
			build()
		end
		local d = okR and type(rec) == "table" and (rec.data or rec) or nil
		local j = d and d.journal
		if not okR then
			failed += 1
		elseif j and j.sess and j.sess[1] then
			if (d.sessions or #j.sess) > SESS_MAX then
				trimmed += 1 -- sess[1] is not the first session any more
			else
				local start, len = j.sess[1]:match("^(%d+)|(%d+)|")
				start, len = tonumber(start), tonumber(len)
				local S
				for _, cut in CUTS do
					if start >= cut[2] and start < cut[3] then
						S = C[cut[1]]
					end
				end
				if not S then
					older += 1
				else
					S.n += 1
					table.insert(S.len, len)
					for _, m in MARKS do
						if len >= m then
							S.mark[m] = (S.mark[m] or 0) + 1
						end
					end
					if #j.sess >= 2 then
						S.returned += 1
					end
					-- the first session's log lines: up to the first "leave"
					local leaveT, btT, rbT = len, nil, nil
					for _, line in j.log or {} do
						local t, code = line:match("^(%d+)|(.+)$")
						t = tonumber(t)
						if code == "leave" then
							leaveT = t
							break
						elseif code == "buy:breakthrough" then
							btT = btT or t
						elseif code == "buy:rebirth" then
							rbT = rbT or t
						else
							local stage, sec = code:match("^load:([%w_]+):(%d+)$")
							if stage then
								S.load[stage] = S.load[stage] or {}
								table.insert(S.load[stage], tonumber(sec))
							end
						end
					end
					if btT then
						S.bt += 1
						table.insert(S.btSec, btT)
						if leaveT - btT <= 60 then
							S.btLeft60 += 1
						end
					end
					if rbT then
						S.rb += 1
						table.insert(S.rbSec, rbT)
					end
				end
			end
		elseif d then
			noSess += 1 -- online now (sess is written at leave) or never finished a session
		end
	end

	build()
	R.status = "done"
end)
print("[Cohort] started; poll _G.Cohort.status")
