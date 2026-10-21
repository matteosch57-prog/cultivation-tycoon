-- Client sound kit: every event in the game has a sound. All ids are Roblox-licensed library
-- audio (Pro Sound Effects / APM), so nothing is uploaded. Small pools per sound (no new
-- Sound instance per play), slight random pitch so repeats never sound mechanical, and three
-- SoundGroups (SFX / Music / Ambience) so levels can be balanced in one place.
-- `from` trims silent lead-ins and `vol` evens loudness, both MEASURED in Play 2026-10-21 with
-- PlaybackLoudness (thunder starts 1.45 s in, the temple bell 0.94 s). `to` = when it fades out.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local Sfx = {}

local DEFS = {
	-- buying and building
	buy = { id = 9113849492, vol = 0.6, pitchVar = 0.06, from = 0.11 }, -- coins jingle
	buyChime = { id = 9116394545, vol = 1, pitchVar = 0.04 }, -- soft magic chime cluster
	rise = { id = 9125805579, vol = 0.4, pitchVar = 0.05, from = 0.13 }, -- rising whoosh as a building assembles
	land = { id = 9116395089, vol = 0.5, pitchVar = 0.04 }, -- chime cluster when it settles
	hallBell = { id = 9125597331, vol = 0.7, pitchVar = 0.02, from = 0.92, to = 4.4 }, -- temple bell: Main Hall level up
	expand = { id = 9120769331, vol = 0.28, pitchVar = 0.02, from = 0.28, to = 3.3 }, -- low boom: the island grows
	deny = { id = 9113537815, vol = 0.16, pitchVar = 0.08, from = 0.07 }, -- soft boink: can't afford yet
	-- qi
	orb = { id = 9126073001, vol = 0.7, pitchVar = 0.1, from = 0.11 }, -- bright ding
	pillReady = { id = 9126073318, vol = 0.6, pitchVar = 0.03, from = 0.11 },
	gulp = { id = 9114171855, vol = 0.7, pitchVar = 0.05 },
	powerUp = { id = 9117297453, vol = 0.6, pitchVar = 0.03, from = 0.3, to = 2.5 },
	-- disciples and realms
	recruit = { id = 9116422213, vol = 0.4, pitchVar = 0.03 },
	rareChime = { id = 9116394756, vol = 0.55, pitchVar = 0.02 },
	gong = { id = 9125585534, vol = 0.5, pitchVar = 0.02, to = 4 },
	thunder = { id = 9120019110, vol = 0.7, pitchVar = 0.04, from = 1.43, to = 7.5 },
	-- UI
	click = { id = 9119717523, vol = 0.25, pitchVar = 0.08 },
	toast = { id = 9126076030, vol = 0.2, pitchVar = 0.06 },
}

-- ambience loops and the music bed (Workspace attribute MusicTrack = 1..3 switches it live)
local AMBIENCE = { id = 9112750044, vol = 0.22 } -- quiet tranquil birds
Sfx.MUSIC = {
	{ id = 1837116223, vol = 0.22, name = "Guzheng" },
	{ id = 1842822990, vol = 0.22, name = "Temple Of Lihangin" },
	{ id = 1836899157, vol = 0.22, name = "Harmonious Cycles" },
}
Sfx.WATERFALL = 9120552550 -- Waterfall Steady Stream 1 (positional, on each waterfall)

local groups = {}
local function group(name, vol)
	local g = SoundService:FindFirstChild(name) or Instance.new("SoundGroup")
	g.Name = name
	g.Volume = vol
	g.Parent = SoundService
	groups[name] = g
	return g
end

local pools = {}
local POOL = 3

local function makeSound(id, vol, parent, grp)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = vol
	s.SoundGroup = grp
	s.Parent = parent
	return s
end

function Sfx.init()
	if Sfx.ready then
		return
	end
	Sfx.ready = true
	group("SFX", 1)
	group("Music", 1)
	group("Ambience", 1)
	local holder = Instance.new("Folder")
	holder.Name = "SfxPool"
	holder.Parent = SoundService
	local preload = {}
	for name, d in DEFS do
		pools[name] = { i = 0 }
		for k = 1, POOL do
			local s = makeSound(d.id, d.vol, holder, groups.SFX)
			pools[name][k] = s
			table.insert(preload, s)
		end
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(preload)
		end)
	end)
	-- ambience loop
	local amb = makeSound(AMBIENCE.id, AMBIENCE.vol, holder, groups.Ambience)
	amb.Looped = true
	amb:Play()
	-- music
	Sfx.musicSound = makeSound(Sfx.MUSIC[1].id, Sfx.MUSIC[1].vol, holder, groups.Music)
	Sfx.musicSound.Looped = true
	local function applyTrack()
		local idx = math.clamp(tonumber(workspace:GetAttribute("MusicTrack")) or 1, 1, #Sfx.MUSIC)
		local t = Sfx.MUSIC[idx]
		Sfx.musicSound:Stop()
		Sfx.musicSound.SoundId = "rbxassetid://" .. t.id
		Sfx.musicSound.Volume = t.vol
		Sfx.musicSound:Play()
	end
	workspace:GetAttributeChangedSignal("MusicTrack"):Connect(applyTrack)
	applyTrack()
end

-- play(name [, opts]) opts: pitch (multiplier), volume (multiplier), at (Vector3: positional)
function Sfx.play(name, opts)
	local d = DEFS[name]
	local pool = pools[name]
	if not d or not pool then
		return
	end
	opts = opts or {}
	pool.i = pool.i % POOL + 1
	local s = pool[pool.i]
	if opts.at then
		-- positional one-shot: a short-lived emitter at the spot (rare events only)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.one
		p.Position = opts.at
		p.Parent = workspace
		s = makeSound(d.id, d.vol, p, groups.SFX)
		s.RollOffMaxDistance = 220
		s.RollOffMinDistance = 30
		task.delay((d.to or 6) + 1, function()
			p:Destroy()
		end)
	end
	local base = d.vol * (opts.volume or 1)
	s.Volume = base
	s.PlaybackSpeed = (opts.pitch or 1) * (1 + (math.random() * 2 - 1) * (d.pitchVar or 0))
	s.TimePosition = d.from or 0
	s:Play()
	if d.to then
		-- cut long library clips with a short fade so they never drag on
		local token = {}
		s:SetAttribute("Token", tostring(token))
		task.delay(d.to, function()
			if s:GetAttribute("Token") == tostring(token) and s.IsPlaying then
				for k = 1, 8 do
					s.Volume = base * (1 - k / 8)
					task.wait(0.04)
				end
				s:Stop()
			end
		end)
	end
	return s
end

-- a looping positional sound inside `part` (waterfalls)
function Sfx.loopAt(part, id, vol, maxDist)
	local s = makeSound(id, vol, part, groups.Ambience)
	s.Looped = true
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = maxDist or 90
	s:Play()
	return s
end

return Sfx
