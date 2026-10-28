-- Breakthrough funnel (thread "Compare new players after tonight's update", 2026-10-28): side by side for
-- two or more join cohorts, how far first sessions get on the way to the first breakthrough, how long
-- each step takes, and for the players who left BEFORE breaking through: when, after what, and after
-- which long wait. Owner: "yes dig it" (why fewer night players reach the first breakthrough).
-- READ ONLY (ListKeysAsync + GetAsync, never a write). Studio command bar in Edit, API access on, a
-- freshly opened place (Studio Edit allows ~2,500 reads per opened place). Result in _G.BtFunnel:
--   print(_G.BtFunnel.status, _G.BtFunnel.read, _G.BtFunnel.keys) / print(_G.BtFunnel.report)
-- Only anonymous totals leave Studio. _G.CohortFrom = N starts at the Nth key (a second pass).
local STORE = "CultivationTycoon_v1"
local SESS_MAX = 30
local MAX_READS = 2450 -- stay under the per-place pool so the report is final, not cut

local function utc(y, m, d, h, mi)
	return DateTime.fromUniversalTime(y, m, d, h, mi or 0).UnixTimestamp
end
local CUTS = _G.BtCuts
	or {
		{ "day", utc(2026, 10, 27, 0), utc(2026, 10, 27, 19, 23) }, -- the best day so far, before the update
		{ "night", utc(2026, 10, 27, 21, 38), math.huge }, -- update + ads
	}

local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore(STORE)
local SKIP = { [game.CreatorId] = true }
for _, id in _G.First5Skip or {} do
	SKIP[id] = true
end

local R = { status = "listing", read = 0, keys = 0 }
_G.BtFunnel = R

local function waitBudget(kind)
	while DataStoreService:GetRequestBudgetForRequestType(kind) < 1 do
		task.wait(1)
	end
end

local function median(t)
	if not t or #t == 0 then
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
	elseif s < 180 then
		return "d 2-3m"
	elseif s < 300 then
		return "e 3-5m"
	elseif s < 600 then
		return "f 5-10m"
	end
	return "g 10m+"
end

local function short(code)
	return (code:gsub("^buy:", "+"):gsub("^Feature:", "F:"):gsub("^Funnel:", ""))
end

-- codes worth a row: steps and choices, not repeats of the same earning tick
local function counts(code)
	return not code:find("^load:") and code ~= "join" and code ~= "leave"
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

	local C = {}
	for _, cut in CUTS do
		-- reach/tAt: every first session; the rest only for players who left before a breakthrough
		C[cut[1]] = { n = 0, bt = 0, reach = {}, tAt = {}, pre = 0, leave = {}, last = {}, gapEnd = {}, maxGap = {}, idle = {}, buys = {}, before = {} }
	end
	local failed = 0

	local function build()
		local out = {}
		local function p(...)
			table.insert(out, string.format(...))
		end
		p("[BtFunnel] %d saves listed, %d read (%d failed)%s", R.keys, R.read, failed, R.status == "done" and "" or " PARTIAL")
		local labels = {}
		for _, cut in CUTS do
			local S = C[cut[1]]
			table.insert(labels, cut[1])
			p(
				"== %s: %d first sessions, %d (%.0f%%) broke through; %d left before it | their buys median %d | idle before leaving median %ds | longest wait median %ds",
				cut[1],
				S.n,
				S.bt,
				100 * S.bt / math.max(1, S.n),
				S.pre,
				median(S.buys),
				median(S.idle),
				median(S.maxGap)
			)
			local bs = {}
			for b, k in S.leave do
				table.insert(bs, { b, k })
			end
			table.sort(bs, function(x, y)
				return x[1] < y[1]
			end)
			local s = {}
			for _, e in bs do
				table.insert(s, string.format("%s %d (%.0f%%)", e[1]:sub(3), e[2], 100 * e[2] / math.max(1, S.pre)))
			end
			p("   left before breakthrough at: %s", table.concat(s, ", "))
			local function top(t, label, k)
				local arr = {}
				for c, v in t do
					table.insert(arr, { c, v })
				end
				table.sort(arr, function(x, y)
					return x[2] > y[2]
				end)
				local s2 = {}
				for i = 1, math.min(k, #arr) do
					table.insert(s2, string.format("%s %d (%.0f%%)", short(arr[i][1]), arr[i][2], 100 * arr[i][2] / math.max(1, S.pre)))
				end
				p("   %s: %s", label, table.concat(s2, ", "))
			end
			top(S.last, "last action", 10)
			top(S.gapEnd, "longest wait ended at", 8)
			top(S.before, "seen in the 20 s before leaving", 10)
		end
		-- the steps: reach % and median time, cohorts side by side, in the first cohort's time order
		local A = C[CUTS[1][1]]
		local all = {}
		for code in A.reach do
			all[code] = true
		end
		for _, cut in CUTS do
			for code, k in C[cut[1]].reach do
				if k >= 0.05 * C[cut[1]].n then
					all[code] = true
				end
			end
		end
		local rows = {}
		for code in all do
			local maxShare = 0
			for _, cut in CUTS do
				local S = C[cut[1]]
				maxShare = math.max(maxShare, (S.reach[code] or 0) / math.max(1, S.n))
			end
			if maxShare >= 0.05 then
				table.insert(rows, { code = code, t = median(table.clone(A.tAt[code] or { 99999 })) })
			end
		end
		table.sort(rows, function(x, y)
			return x.t < y.t
		end)
		p("== steps in session 1: reached %% / median s (%s)", table.concat(labels, " | "))
		for i, r in rows do
			if i > 45 then
				break
			end
			local cells = {}
			for _, cut in CUTS do
				local S = C[cut[1]]
				table.insert(cells, string.format("%3.0f%% %4ds", 100 * (S.reach[r.code] or 0) / math.max(1, S.n), median(table.clone(S.tAt[r.code] or {}))))
			end
			p("   %-26s %s", short(r.code), table.concat(cells, " | "))
		end
		R.report = table.concat(out, "\n")
	end

	for i, key in keys do
		if i < (_G.CohortFrom or 1) then
			continue
		end
		if R.read >= MAX_READS then
			break
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
		elseif j and j.sess and j.sess[1] and (d.sessions or #j.sess) <= SESS_MAX then
			local start, len = j.sess[1]:match("^(%d+)|(%d+)|")
			start, len = tonumber(start), tonumber(len)
			local S
			for _, cut in CUTS do
				if start >= cut[2] and start < cut[3] then
					S = C[cut[1]]
				end
			end
			if S then
				S.n += 1
				local lines, seen, btT = {}, {}, nil
				for _, line in j.log or {} do
					local t, code = line:match("^(%d+)|(.+)$")
					t = tonumber(t)
					table.insert(lines, { t = t, c = code })
					if code == "leave" then
						break
					end
					if counts(code) and not seen[code] then
						seen[code] = true
						S.reach[code] = (S.reach[code] or 0) + 1
						S.tAt[code] = S.tAt[code] or {}
						table.insert(S.tAt[code], t)
					end
					if code == "buy:breakthrough" then
						btT = btT or t
					end
				end
				if btT then
					S.bt += 1
				else
					S.pre += 1
					local leaveT = (#lines > 0 and lines[#lines].c == "leave") and lines[#lines].t or len
					local b = bucket(leaveT)
					S.leave[b] = (S.leave[b] or 0) + 1
					local prevT, maxGap, gapCode, lastAct, buys, near = 0, 0, "start", nil, 0, {}
					for _, l in lines do
						if counts(l.c) then
							lastAct = l
							if l.c:find("^buy:") then
								buys += 1
							end
							if l.t - prevT > maxGap then
								maxGap, gapCode = l.t - prevT, l.c
							end
							prevT = l.t
							if leaveT - l.t <= 20 then
								near[l.c] = true
							end
						end
					end
					if leaveT - prevT > maxGap then
						maxGap, gapCode = leaveT - prevT, "(left while waiting)"
					end
					table.insert(S.maxGap, maxGap)
					table.insert(S.buys, buys)
					table.insert(S.idle, leaveT - (lastAct and lastAct.t or 0))
					S.gapEnd[gapCode] = (S.gapEnd[gapCode] or 0) + 1
					local lc = lastAct and lastAct.c or "(nothing)"
					S.last[lc] = (S.last[lc] or 0) + 1
					for c in near do
						S.before[c] = (S.before[c] or 0) + 1
					end
				end
			end
		end
	end
	R.status = "done"
	build()
end)
print("[BtFunnel] started; poll _G.BtFunnel.status")
