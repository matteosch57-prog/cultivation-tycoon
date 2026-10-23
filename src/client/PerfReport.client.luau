-- Live fps telemetry, every player (phone fps 2026-10-23: the owner's Pixel 10 Pro lost fps near
-- the disciples). Frame times are kept per zone (PerfScene.zone: disciples | hub | peak | bridge |
-- sky); a zone's window is sent when the player leaves it after MIN_WINDOW s, or every WINDOW s,
-- with the heaviest scene the camera had around it in that window (PerfScene.scan, 3 s into a
-- window then every SCAN_EVERY s). The server buckets it into the events ClientFps and ClientLoad
-- (Telemetry.clientPerf). Nothing is sent while the game is in the
-- background (a paused phone reports 1 fps) or in the first SETTLE s (loading).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PerfScene = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PerfScene"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PerfReport") :: RemoteEvent

local WINDOW = 60 -- s: the longest window
local MIN_WINDOW = 12 -- s: a shorter visit to a zone is not sent
local SETTLE = 20 -- s after joining
local ZONE_EVERY = 1 -- s between zone checks
local SCAN_EVERY = 25 -- s between scene scans (a scan walks the workspace over ~1 s of frames)
local FIRST_SCAN = 3 -- s into a window

local focused = true
UserInputService.WindowFocused:Connect(function()
	focused = true
end)
UserInputService.WindowFocusReleased:Connect(function()
	focused = false
end)

local zone = PerfScene.zone()
local frames: { number } = {}
local windowStart = os.clock()
local began = os.clock()
local sent = 0 -- os.clock of the last report
local load: { [string]: number }? = nil -- the window's heaviest scan, per count
local lastScan = os.clock() - SCAN_EVERY + FIRST_SCAN

local function flush()
	local n = #frames
	local span = os.clock() - windowStart
	local z = zone
	local list = frames
	if n < 30 or span < MIN_WINDOW or os.clock() - began < SETTLE or os.clock() - sent < MIN_WINDOW then
		return
	end
	sent = os.clock()
	table.sort(list)
	local c = load or {}
	remote:FireServer({
		zone = z,
		device = PerfScene.device(),
		p50 = 1 / list[math.ceil(n * 0.5)],
		p5 = 1 / list[math.ceil(n * 0.95)],
		parts = c.parts,
		particles = c.particles,
		highlights = c.highlights,
		guis = c.guis,
	})
end

local function newWindow()
	frames = {}
	windowStart = os.clock()
	load = nil
	lastScan = os.clock() - SCAN_EVERY + FIRST_SCAN
end

RunService.RenderStepped:Connect(function(dt)
	if focused then
		table.insert(frames, dt)
	end
end)

task.spawn(function()
	while true do
		task.wait(ZONE_EVERY)
		if not focused then
			newWindow()
		else
			local z = PerfScene.zone()
			if z ~= zone then
				flush()
				newWindow()
				zone = z
			elseif os.clock() - windowStart >= WINDOW then
				flush()
				newWindow()
			elseif os.clock() - lastScan >= SCAN_EVERY then
				lastScan = os.clock()
				local scanZone, scanWindow = zone, windowStart
				PerfScene.scan(function(c)
					if zone ~= scanZone or windowStart ~= scanWindow then
						return -- the window ended while the scan ran
					end
					local l = load or {}
					for k, v in c do
						l[k] = math.max(l[k] or 0, v)
					end
					load = l
				end)
			end
		end
	end
end)
