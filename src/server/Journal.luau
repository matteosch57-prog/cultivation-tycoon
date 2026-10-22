-- Journal: what each player did, kept in their own save (data audit 2026-10-22, owner: "the more the
-- better, for an early analysis of what players do or do not"). Roblox Analytics only shows
-- totals across players; the journal answers per player, and a pull of many saves answers
-- "what do new players do, in what order, and where do they stop" (docs/design/DATA.md).
--
-- data.journal = {
--   first = { [code] = playSec of the first time },   lifetime, one entry per code
--   count = { [code] = times },                       lifetime
--   log   = { "playSec|code", ... },                  EVERY action, but only in the first LOG_SECONDS
--                                                     of play and at most LOG_MAX lines (new players)
--   sess  = { "start|seconds|afkSeconds|built", ... } the last SESS_MAX sessions (os.time start)
-- }
-- Codes come only from server-side names (pad ids, Config keys, event names), never from client text,
-- so the tables stay bounded (MAX_CODES as a backstop). Fed by Telemetry (every event, sink and source
-- notes itself here) plus join, leave and the AFK clock. Absent from the save template on purpose: it
-- is created on first use, so rolling it back is deleting this module.
local Journal = {}

local LOG_SECONDS = 2 * 3600 -- the first two hours of play are logged action by action
local LOG_MAX = 250 -- lines (~18 bytes each)
local SESS_MAX = 30
local MAX_CODES = 300
local AFK_AFTER = 120 -- s standing still before the time counts as away from keyboard

local live = {} -- [player] = { d, j, startT, joinClock, lastBuy, still, afk, last }

local function codeCount(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function logLine(e, code)
	local t = math.floor(e.d.playSec or 0)
	if t < LOG_SECONDS and #e.j.log < LOG_MAX then
		table.insert(e.j.log, t .. "|" .. code)
	end
end

function Journal.attach(player, d)
	local j = d.journal
	if type(j) ~= "table" then
		j = {}
		d.journal = j
	end
	j.first = j.first or {}
	j.count = j.count or {}
	j.log = j.log or {}
	j.sess = j.sess or {}
	live[player] = {
		d = d,
		j = j,
		codes = codeCount(j.count),
		startT = os.time(),
		joinClock = os.clock(),
		lastBuy = os.clock(),
		still = 0,
		afk = 0,
	}
	Journal.note(player, "join")
end

function Journal.note(player, code)
	local e = live[player]
	if not e then
		return
	end
	local j = e.j
	if j.count[code] == nil then
		if e.codes >= MAX_CODES then
			return
		end
		e.codes += 1
		j.first[code] = math.floor(e.d.playSec or 0)
	end
	j.count[code] = (j.count[code] or 0) + 1
	logLine(e, code)
end

function Journal.bought(player)
	local e = live[player]
	if e then
		e.lastBuy = os.clock()
	end
end

-- once a second: standing still for AFK_AFTER s starts the away clock
function Journal.tick(player, hrp, dt)
	local e = live[player]
	if not e or not hrp then
		return
	end
	local p = hrp.Position
	if e.last and (p - e.last).Magnitude < 1 then
		e.still += dt
		if e.still >= AFK_AFTER then
			e.afk += dt
		end
	else
		e.still = 0
	end
	e.last = p
end

-- at leave: closes the session line; returns seconds since the last purchase and the away share
function Journal.detach(player, built)
	local e = live[player]
	live[player] = nil
	if not e then
		return 0, 0
	end
	logLine(e, "leave")
	local len = math.max(1, os.clock() - e.joinClock)
	table.insert(e.j.sess, string.format("%d|%d|%d|%d", e.startT, len, e.afk, built))
	while #e.j.sess > SESS_MAX do
		table.remove(e.j.sess, 1)
	end
	return os.clock() - e.lastBuy, e.afk / len
end

return Journal
