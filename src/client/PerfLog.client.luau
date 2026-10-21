-- Phone performance log (B01 step 3). Owner only (the place's creator, or anyone in Studio).
-- The phone is the truth: Studio on a PC is not GPU bound like a phone (Gladiator RNG D671).
--   /perf    start or stop a 10 minute recording: every 10 s one "[Perf]" line in the console
--            (fps median / slow 5% / worst frame, draw calls, triangles, instances, memory),
--            then a summary. Read it on the phone with /console.
--   /clouds  hide or show the cloud sea's particles on this screen only (overdraw A/B test).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer
if not (RunService:IsStudio() or player.UserId == game.CreatorId) then
	return
end

local ROW_EVERY = 10 -- s between log rows
local RECORD_FOR = 600 -- s

local function stat(name: string): number
	local ok, v = pcall(function()
		return (Stats :: any)[name]
	end)
	return if ok and type(v) == "number" then v else -1
end

local recording: RBXScriptConnection? = nil
local summary: { number } = {} -- fps median of each row
local function stop()
	if recording then
		recording:Disconnect()
		recording = nil
	end
	table.sort(summary)
	local n = #summary
	if n > 0 then
		print(string.format("[Perf] summary rows=%d median fps %.0f, lowest 10 s median %.0f", n, summary[math.ceil(n / 2)], summary[1]))
	end
	print("[Perf] stopped")
end

local function start()
	local frames: { number } = {}
	local rowStart, began = os.clock(), os.clock()
	table.clear(summary)
	print("[Perf] t,fps_p50,fps_p5,worst_ms,draws,tris,shadow_draws,instances,mem_mb,quality")
	recording = RunService.RenderStepped:Connect(function(dt)
		table.insert(frames, dt)
		local now = os.clock()
		if now - rowStart < ROW_EVERY then
			return
		end
		table.sort(frames)
		local n = #frames
		local p50 = 1 / frames[math.ceil(n * 0.5)]
		local p5 = 1 / frames[math.ceil(n * 0.95)]
		local q = UserSettings().GameSettings.SavedQualityLevel.Value
		print(string.format("[Perf] %.0f,%.0f,%.0f,%.0f,%d,%d,%d,%d,%.0f,%d", now - began, p50, p5, frames[n] * 1000, stat("SceneDrawcallCount"), stat("SceneTriangleCount"), stat("ShadowsDrawcallCount"), stat("InstanceCount"), Stats:GetTotalMemoryUsageMb(), q))
		table.insert(summary, p50)
		table.clear(frames)
		rowStart = now
		if now - began >= RECORD_FOR then
			stop()
		end
	end)
	print("[Perf] recording 10 min (type /perf again to stop)")
end

local cloudsHidden = false
local function setClouds(hidden: boolean)
	local sea = workspace:FindFirstChild("Sect") and workspace.Sect:FindFirstChild("CloudSea")
	if not sea then
		print("[Perf] no cloud sea streamed in")
		return
	end
	local n = 0
	for _, d in sea:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.Enabled = not hidden
			if hidden then
				d:Clear()
			end
			n += 1
		end
	end
	print(string.format("[Perf] clouds %s (%d emitters)", hidden and "hidden" or "shown", n))
end

local function command(name: string, alias: string, fn: () -> ())
	local c = Instance.new("TextChatCommand")
	c.Name = name
	c.PrimaryAlias = alias
	c.Triggered:Connect(fn)
	c.Parent = TextChatService
end
command("PerfRecord", "/perf", function()
	if recording then
		stop()
	else
		start()
	end
end)
command("PerfClouds", "/clouds", function()
	cloudsHidden = not cloudsHidden
	setClouds(cloudsHidden)
end)
