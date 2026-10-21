-- PerfMark: names the work in a frame for the owner's /perf log (PerfLog), ported from Gladiator RNG
-- (D671). A client job that runs every frame or in bursts times itself:
--   local t0 = PerfMark.begin()  ...work...  PerfMark.finish("hud", t0)
-- While a recording runs, each job adds to its own total (shown per log row as name avg/worst ms) and
-- to a short ring, so a slow frame (a hitch) names what ran just before it. Not recording (every
-- other moment, every player): begin returns 0 and finish is one test, nothing is stored.
local PerfMark = {}

PerfMark.on = false -- set by PerfLog while it records

local SIZE = 64 -- jobs kept in the ring
local names: { string } = table.create(SIZE, "")
local times: { number } = table.create(SIZE, 0)
local durs: { number } = table.create(SIZE, 0)
local at = 0
local totals: { [string]: { ms: number, n: number, worst: number } } = {}

function PerfMark.begin(): number
	return if PerfMark.on then os.clock() else 0
end

function PerfMark.finish(name: string, t0: number)
	if not PerfMark.on or t0 == 0 then
		return
	end
	local ms = (os.clock() - t0) * 1000
	local s = totals[name]
	if not s then
		s = { ms = 0, n = 0, worst = 0 }
		totals[name] = s
	end
	s.ms += ms
	s.n += 1
	s.worst = math.max(s.worst, ms)
	if ms >= 0.5 then -- shorter is noise in a hitch list
		at = at % SIZE + 1
		names[at], times[at], durs[at] = name, os.clock(), ms
	end
end

-- "name avg/worst ms" for every job since the last call, then starts the next window.
function PerfMark.window(): string
	local out = {}
	for name, s in totals do
		table.insert(out, string.format("%s %.2f/%.1f", name, s.ms / math.max(s.n, 1), s.worst))
	end
	table.clear(totals)
	table.sort(out)
	return table.concat(out, " ")
end

-- The jobs within `window` seconds before now, as name:ms summed ("" when none).
function PerfMark.recent(window: number): string
	local now = os.clock()
	local sum: { [string]: number } = {}
	local order = {}
	for i = 0, SIZE - 1 do
		local k = (at - i - 1) % SIZE + 1
		local t = times[k]
		if t <= 0 or now - t > window then
			break
		end
		local n = names[k]
		if not sum[n] then
			sum[n] = 0
			table.insert(order, n)
		end
		sum[n] += durs[k]
	end
	local out = {}
	for _, n in order do
		table.insert(out, string.format("%s:%.0f", n, sum[n]))
	end
	return table.concat(out, "+")
end

function PerfMark.clear()
	table.clear(totals)
	for i = 1, SIZE do
		times[i] = 0
	end
	at = 0
end

-- Is a thing of radius `r` studs at `at` inside the camera's view (its own size as the margin)?
-- Rule: nothing animates per frame for what is not seen (docs/design/TECH.md "Performance").
function PerfMark.onScreen(camera: Camera, pos: Vector3, r: number): boolean
	local p = camera:WorldToViewportPoint(pos)
	if p.Z <= 0 then
		return (camera.CFrame.Position - pos).Magnitude < r -- the camera is inside it
	end
	local vp = camera.ViewportSize
	local m = r * vp.Y / (2 * math.tan(math.rad(camera.FieldOfView) / 2) * p.Z)
	return p.X > -m and p.X < vp.X + m and p.Y > -m and p.Y < vp.Y + m
end

return PerfMark
