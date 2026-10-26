-- Sect Missions (2026-10-25, copies Pet Simulator 99 ranks; rules and numbers in Config "Sect Missions").
-- Main, Altar and Bless call Missions.bump(player, group, n) where the thing happens; this module keeps the
-- slots, pays stars and the rank path, and sends the state to the client as the "Missions" attribute (JSON).
-- Save: data.missions = { rank, stars (in this rank), paid (rewards paid in this rank), done (missions done
-- in this rank), starter (next MISSION_STARTER entry), total (stars ever), slots = { mission }, daily =
-- { day, list = { mission }, chest } }, a mission = { g = group, n = progress, need, stars, text }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Missions = {}
local api -- { sessions, rate, publish, notify, telemetry, giveSummons, addDisciple, ctx }

local rng = Random.new()
local rankWatchers = {} -- Missions.onRank: other modules told of a rank up (the Relic Hall)

-- fn(player, rank) after every rank up (rank = the new rank, 2+); read the current one from
-- player:GetAttribute("MissionRank") or s.data.missions.rank
function Missions.onRank(fn)
	table.insert(rankWatchers, fn)
end

local function today()
	return os.time() // 86400
end

local function state(d)
	local m = d.missions
	if type(m) ~= "table" then
		m = { rank = 1, stars = 0, paid = 0, done = 0, starter = 1, total = 0, slots = {} }
		d.missions = m
	end
	m.slots = m.slots or {}
	return m
end

-- what can be drawn right now (Main's ctx: others here, rebirths, gift left today, furnace, blessing ready,
-- a breakthrough not waiting on a rebirth)
local function allowed(group, c)
	local g = Config.MISSION_GROUPS[group]
	if not g then
		return false
	end
	if g.when == "others" and not c.others then
		return false
	elseif g.when == "giftLeft" and not c.giftLeft then
		return false
	elseif g.when == "furnace" and not c.furnace then
		return false
	elseif g.when == "reborn" and not c.reborn then
		return false
	end
	if group == "breakthrough" and not c.canBreak then
		return false
	end
	return true
end

local function tierOpen(m, tier)
	local rule = Config.MISSION_TIER_AT[tier]
	if not rule then
		return true
	end
	return m.rank > rule.rank or (m.rank == rule.rank and m.done >= rule.done)
end

local function make(group, need, stars, text, at)
	return { g = group, n = 0, need = need, stars = stars, text = Config.missionText(group, need, text), at = at }
end

-- the next mission for an empty slot: rank 1 walks the starter line, then a random group not already
-- active and a random open tier of it
local function draw(m, d, c)
	local busy = {}
	for _, x in m.slots do
		busy[x.g] = true
	end
	if m.rank == 1 then
		while m.starter <= #Config.MISSION_STARTER do
			local e = Config.MISSION_STARTER[m.starter]
			m.starter += 1
			local skip = busy[e.group]
				or (e.group == "streak" and not c.streakReady)
				or (e.group == "rebirth" and c.reborn)
				or (e.group ~= "streak" and e.group ~= "rebirth" and not allowed(e.group, c))
			if not skip then
				return make(e.group, e.need, e.stars, e.text, d.playSec or 0)
			end
		end
	end
	local pool = {}
	for group, g in Config.MISSION_GROUPS do
		if not busy[group] and allowed(group, c) then
			for tier = 1, 4 do
				if g.need[tier] and tierOpen(m, tier) then
					table.insert(pool, { group, tier })
				end
			end
		end
	end
	if #pool == 0 then
		return nil
	end
	local pick = pool[rng:NextInteger(1, #pool)]
	local group, tier = pick[1], pick[2]
	return make(group, Config.missionNeed(group, tier, d.realm), Config.MISSION_GROUPS[group].stars[tier], nil, d.playSec or 0)
end

local function fill(m, d, c)
	-- a slot whose group can no longer be done (the furnace or the last gift is gone), or one not started
	-- after MISSION_STALE s of play (no altar visit, nobody to bless), is drawn again. The starter line's
	-- rebirth waits: it is rank 1's goal.
	local play = d.playSec or 0
	for i = #m.slots, 1, -1 do
		local x = m.slots[i]
		local stale = x.n == 0 and play - (x.at or play) >= Config.MISSION_STALE
		if x.g ~= "rebirth" and x.n == 0 and (stale or x.g ~= "streak" and not allowed(x.g, c)) then
			table.remove(m.slots, i)
		end
	end
	while #m.slots < Config.missionSlots(m.rank) do
		local x = draw(m, d, c)
		if not x then
			break
		end
		table.insert(m.slots, x)
	end
end

local function daily(m, d, c)
	local dl = m.daily
	if type(dl) == "table" and dl.day == today() then
		return dl
	end
	dl = { day = today(), list = {}, chest = false }
	m.daily = dl
	if not Config.MISSION_DAILY_ON then
		return dl
	end
	local pool = {}
	for _, group in Config.MISSION_DAILY do
		if allowed(group, c) then
			table.insert(pool, group)
		end
	end
	for _ = 1, Config.MISSION_DAILY_COUNT do
		if #pool == 0 then
			break
		end
		local group = table.remove(pool, rng:NextInteger(1, #pool))
		local g = Config.MISSION_GROUPS[group]
		local tier = Config.MISSION_DAILY_TIER
		while tier > 1 and not g.need[tier] do
			tier -= 1
		end
		while not g.need[tier] and tier < 4 do
			tier += 1
		end
		table.insert(dl.list, make(group, Config.missionNeed(group, tier, d.realm), g.stars[tier]))
	end
	return dl
end

local function pay(player, s, r, why)
	local d = s.data
	local gain = math.floor(api.rate(s, true) * (r.qiSec or 0))
	d.qi += gain
	if (r.summons or 0) > 0 then
		api.giveSummons(s, r.summons)
	end
	if (r.pill or 0) > 0 then
		d.boostUntil = math.max(workspace:GetServerTimeNow(), d.boostUntil or 0) + r.pill
	end
	if r.rarity then
		api.addDisciple(s, r.rarity, true) -- a reward: never turned away
	end
	if gain > 0 then
		api.telemetry.source(player, d, gain, why, true)
	end
	return { qi = gain, summons = r.summons or 0, pill = r.pill or 0, rarity = r.rarity }
end

local function addStars(player, s, n)
	local m = state(s.data)
	m.stars += n
	m.total += n
	local paid = {}
	while true do
		local _, rewards = Config.missionRank(m.rank)
		local r = rewards[m.paid + 1]
		if not r or m.stars < r.at then
			break
		end
		m.paid += 1
		local got = pay(player, s, r, "mission")
		if m.paid == #rewards then -- the last reward ranks you up
			m.rank += 1
			m.stars -= r.at
			m.paid, m.done = 0, 0
			got.rankUp = Config.missionRank(m.rank)
			for _, fn in rankWatchers do
				task.spawn(fn, player, m.rank)
			end
			api.telemetry.custom(player, "Mission", "rank", tostring(m.rank), api.telemetry.minuteBucket(s.data.playSec or 0))
		end
		table.insert(paid, got)
	end
	return paid
end

function Missions.push(player, s)
	if not Config.MISSIONS_ON or not s or not s.data then
		return
	end
	local m = state(s.data)
	local name, rewards = Config.missionRank(m.rank)
	local dl = m.daily
	local out = {
		rank = m.rank,
		name = name,
		stars = m.stars,
		paid = m.paid,
		path = rewards,
		slots = m.slots,
		daily = dl and dl.day == today() and dl.list or {},
		chest = dl and dl.day == today() and dl.chest or false,
		chestReward = Config.MISSION_DAILY_CHEST,
		resetIn = (today() + 1) * 86400 - os.time(),
	}
	player:SetAttribute("Missions", HttpService:JSONEncode(out))
	player:SetAttribute("MissionRank", m.rank) -- the rank alone, for the Relic Hall and others
end

-- top up the slots and today's dailies, then send them (join, a new day, a change of what can be drawn)
function Missions.refresh(player, s)
	if not Config.MISSIONS_ON or not s or not s.data then
		return
	end
	local c = api.ctx(player, s)
	local m = state(s.data)
	fill(m, s.data, c)
	daily(m, s.data, c)
	Missions.push(player, s)
end

-- progress for `group` (n = how many happened). Finished missions pay their stars and are replaced.
function Missions.bump(player, group, n)
	if not Config.MISSIONS_ON or not api then
		return
	end
	local s = api.sessions[player]
	if not s or not s.data then
		return
	end
	local m = state(s.data)
	local c = api.ctx(player, s)
	local gotStars, finished, paid, moved = 0, {}, {}, false
	for i = #m.slots, 1, -1 do
		local x = m.slots[i]
		if x.g == group then
			moved = true
			x.n = math.min(x.need, x.n + (n or 1))
			if x.n >= x.need then
				table.remove(m.slots, i)
				m.done += 1
				gotStars += x.stars
				table.insert(finished, { text = x.text, stars = x.stars })
				api.telemetry.custom(player, "Mission", "done", x.g, tostring(x.stars))
			end
		end
	end
	local dl = daily(m, s.data, c)
	for _, x in dl.list do
		if x.g == group and x.n < x.need then
			moved = true
			x.n = math.min(x.need, x.n + (n or 1))
			if x.n >= x.need then
				gotStars += x.stars
				table.insert(finished, { text = x.text, stars = x.stars, daily = true })
				api.telemetry.custom(player, "Mission", "daily", x.g, tostring(x.stars))
			end
		end
	end
	if gotStars == 0 then
		if moved then
			Missions.push(player, s) -- the tracker's counts move on every step
		end
		return
	end
	local chest
	if not dl.chest and #dl.list > 0 then
		local all = true
		for _, x in dl.list do
			if x.n < x.need then
				all = false
			end
		end
		if all then
			dl.chest = true
			chest = pay(player, s, Config.MISSION_DAILY_CHEST, "missionChest")
		end
	end
	paid = addStars(player, s, gotStars)
	fill(m, s.data, c)
	Missions.push(player, s)
	api.notify:FireClient(player, "mission", finished, paid, chest)
	if #paid > 0 or chest then
		api.publish(player)
	end
end

function Missions.init(deps)
	api = deps
	-- a new UTC day: fresh dailies without a rejoin
	task.spawn(function()
		local day = today()
		while true do
			task.wait(20)
			if today() ~= day then
				day = today()
				for player, s in api.sessions do
					Missions.refresh(player, s)
				end
			end
		end
	end)
end

return Missions
