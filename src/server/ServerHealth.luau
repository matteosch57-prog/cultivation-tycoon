-- ServerHealth: is a server slow, and is it us or the DataStores? Ported from Gladiator RNG
-- (ServerHealth.lua, D322), which ported it from Heavenly RNG. Server only and passive: it spends no
-- DataStore budget (budgets are a local read) and every loop is pcall'd. Outputs:
--   * every HEALTH_SAMPLE s a "[SRVHEALTH]" line (heartbeat fps, worst frame, memory, instances,
--     players, worst ping) and a "[DSMON]" line (the request budgets); "-ALERT" when one is low.
--     Live servers print every sample; Studio only the first and the alerts (shared Play tests).
--   * the engine's own DataStore / MemoryStore throttle warnings, classified ("[DSMON-ALERT]").
--   * the events ServerHealth (the window's worst sample, bucketed, once per HEALTH_EVENT s) and
--     DataStorePressure (a starving budget or a throttle), through Telemetry.
-- A rate limiter in front of a metric ACCUMULATES, it never drops: throttles sum and budgets keep
-- their lowest value over the suppressed window.
local DataStoreService = game:GetService("DataStoreService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local ServerHealth = {}

local BUDGETS = {
	{ name = "GetAsync", rt = Enum.DataStoreRequestType.GetAsync }, -- loads
	{ name = "UpdateAsync", rt = Enum.DataStoreRequestType.UpdateAsync }, -- every save
	{ name = "SetIncrement", rt = Enum.DataStoreRequestType.SetIncrementAsync },
	{ name = "GetSorted", rt = Enum.DataStoreRequestType.GetSortedAsync }, -- leaderboards (later)
	{ name = "SetSorted", rt = Enum.DataStoreRequestType.SetIncrementSortedAsync },
}

local function bucket(v, edges, names)
	for i, e in edges do
		if v < e then
			return names[i]
		end
	end
	return names[#names]
end
function ServerHealth.hbBucket(fps)
	return bucket(fps, { 30, 40, 50, 58 }, { "hb0_30", "hb30_40", "hb40_50", "hb50_58", "hb58plus" })
end
function ServerHealth.memBucket(mb)
	return bucket(mb, { 500, 1000, 2000, 3000 }, { "mem0_500", "mem500_1k", "mem1k_2k", "mem2k_3k", "mem3kplus" })
end
function ServerHealth.playersBucket(n)
	return bucket(n, { 3, 6, 11, 21 }, { "o1_2", "o3_5", "o6_10", "o11_20", "o21plus" })
end

-- The engine's pressure line -> a class. Order matters: "exp" (the whole experience over a shared
-- ceiling) and "srv" (this server over its own budget) share the "Throttled" stem.
function ServerHealth.classify(msg)
	if string.find(msg, "ExperienceThrottled", 1, true) then
		return "exp"
	elseif string.find(msg, "GameServerThrottled", 1, true) then
		return "srv"
	elseif string.find(msg, "KeyThrottled", 1, true) then
		return "key" -- one key over its bytes per minute, across every server
	elseif string.find(msg, "added to queue", 1, true) then
		return "queue" -- 30 per queue; the overflow is dropped
	elseif string.find(msg, "Throttled", 1, true) or string.find(msg, "exceeds the allowed maximum", 1, true) then
		return "throttled"
	elseif string.find(msg, "OverLimit", 1, true) or string.find(msg, "over the limit", 1, true) then
		return "overlimit" -- MemoryStore
	end
	return nil
end

function ServerHealth.accumulate(prev, value, isCounter)
	if prev == nil then
		return value
	end
	return if isCounter then prev + value else math.min(prev, value)
end

function ServerHealth.start()
	local started = os.clock()
	local job = string.sub(tostring(game.JobId), 1, 8)
	local function anyPlayer()
		return Players:GetPlayers()[1] -- an analytics event rides on a player
	end

	-- DataStorePressure: one series per kind|key; suppressed samples accumulate
	local lastEmit, pending = {}, {}
	local function emit(kind, key, value)
		local k = kind .. "|" .. key
		pending[k] = ServerHealth.accumulate(pending[k], value, kind == "throttle")
		local now = os.clock()
		if lastEmit[k] and now - lastEmit[k] < Config.HEALTH_PRESSURE_COOLDOWN then
			return
		end
		local player = anyPlayer()
		if not player then
			return -- keep the pending value for the next chance
		end
		lastEmit[k] = now
		pending[k] = nil
		Telemetry.custom(player, "DataStorePressure", kind, key, ServerHealth.playersBucket(#Players:GetPlayers()))
	end

	local frames, sumDt, maxDt = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		frames += 1
		sumDt += dt
		maxDt = math.max(maxDt, dt)
	end)

	local quiet = RunService:IsStudio()
	local printed = false
	local worst = nil
	local lastEvent = os.clock()

	local function sample()
		local players = Players:GetPlayers()
		local fps = if sumDt > 0 then frames / sumDt else 60
		local frameMs = maxDt * 1000
		frames, sumDt, maxDt = 0, 0, 0
		local mem = Stats:GetTotalMemoryUsageMb()
		local ping = 0
		for _, p in players do
			ping = math.max(ping, math.floor(p:GetNetworkPing() * 1000))
		end
		local alert = fps < Config.HEALTH_LOW_FPS or ping > Config.HEALTH_ALERT_PING
		local say = alert or not quiet or not printed
		printed = true
		if say then
			print(string.format("%s job=%s up=%ds players=%d hbFps=%.0f worstFrame=%.0fms mem=%.0fMB inst=%d ping=%dms", alert and "[SRVHEALTH-ALERT]" or "[SRVHEALTH]", job, math.floor(os.clock() - started), #players, fps, frameMs, mem, Stats.InstanceCount, ping))
		end
		if #players > 0 then
			worst = if worst then { fps = math.min(worst.fps, fps), mem = math.max(worst.mem, mem), players = math.max(worst.players, #players) } else { fps = fps, mem = mem, players = #players }
		end
		local player = anyPlayer()
		if worst and player and os.clock() - lastEvent >= Config.HEALTH_EVENT then
			lastEvent = os.clock()
			Telemetry.custom(player, "ServerHealth", ServerHealth.hbBucket(worst.fps), ServerHealth.memBucket(worst.mem), ServerHealth.playersBucket(worst.players))
			worst = nil
		end
		local parts, low = {}, nil
		for _, b in BUDGETS do
			local n = DataStoreService:GetRequestBudgetForRequestType(b.rt)
			table.insert(parts, string.format("%s=%.0f", b.name, n))
			if n < Config.HEALTH_LOW_BUDGET then
				low = b.name
				emit("budget", b.name, math.floor(n))
			end
		end
		if say or low then
			print(string.format("%s job=%s players=%d | budgets: %s%s", low and "[DSMON-ALERT]" or "[DSMON]", job, #players, table.concat(parts, " "), low and " | LOW=" .. low or ""))
		end
	end

	-- The engine's throttle warnings: the only view of the experience-wide limits.
	local counts = {}
	LogService.MessageOut:Connect(function(message, kind)
		if kind ~= Enum.MessageType.MessageWarning and kind ~= Enum.MessageType.MessageError then
			return
		end
		if string.find(message, "[DSMON", 1, true) or string.find(message, "[SRVHEALTH", 1, true) then
			return -- never react to our own lines
		end
		pcall(function()
			if not (string.find(message, "DataStore", 1, true) or string.find(message, "Datastore", 1, true) or string.find(message, "MemoryStore", 1, true)) then
				return
			end
			local class = ServerHealth.classify(message)
			if class then
				counts[class] = (counts[class] or 0) + 1
				print(string.format("[DSMON-ALERT] job=%s THROTTLE class=%s players=%d total=%d", job, class, #Players:GetPlayers(), counts[class]))
				emit("throttle", class, 1)
			end
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.HEALTH_SAMPLE)
			local ok, err = pcall(sample)
			if not ok then
				warn("[SRVHEALTH] sample failed") -- constant text: the Error Report groups by string
				print("[SRVHEALTH] sample error:", err)
			end
		end
	end)
	print(string.format("[SRVHEALTH] started: a sample every %ds (job=%s)", Config.HEALTH_SAMPLE, job))
end

return ServerHealth
