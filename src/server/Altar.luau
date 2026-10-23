-- Heavenly Altar: king of the hill over the hub (Config ALTAR_*, mock A, owner idea 2026-10-21; the
-- stage is a store arena on a lotus-isle rock since 2026-10-23). A floating square duel stage above
-- the cauldron opens every ALTAR_INTERVAL s; two Spirit Springs on the
-- plaza throw players up to it. Stand on it ALONE for ALTAR_HOLD s to claim it; two or more on it
-- pause the timer. Palm Strike knocks rivals off; whoever falls off is out until the round ends.
-- The server decides everything (R9): who stands on it is read from positions every tick, the
-- push is validated here and only the knockback runs on the victim's client (it owns its body).
-- State for the HUD = Workspace attributes: AltarNext, AltarUntil (server time), AltarHolder
-- (display name or ""), AltarHold (s held), AltarCrowd (players on it); player attribute AltarOut.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetService = game:GetService("AssetService")

local Guard = require(script.Parent:WaitForChild("Guard"))
local Lowpoly = require(script.Parent:WaitForChild("Lowpoly"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Altar = {}

local ctx -- from Main: sessions, rate, publish, notify, telemetry, style, baseY
local top -- world position of the altar's top centre
local braziers = {} -- { flame = Part, fire = Fire, light = PointLight }
local springs = {} -- Parts on the plaza (clients launch themselves from them)
local round = nil -- { untilT, holder, hold, joined = {[player]=true}, out = {[player]=true} }
local crowned = nil -- the winner wearing the light aura until the next round
local lastPush = {}

local GOLD = Color3.fromHex("D4A445")
local BRONZE = Color3.fromHex("7A5A3A")
local FLAME = Color3.fromRGB(255, 190, 110)

---------------------------------------------------------------------------------------------
-- The altar (owner 2026-10-23, picked A of docs/art/mocks/altar_store_arenas.jpg on the lotus isles'
-- base, preview docs/art/mocks/altar_arena_isle_preview.jpg): the free Creator Store "Ancient Chinese
-- Arena" (Config.ALTAR_ARENA, rebuilt by mesh id, never inserted) standing on the rock islet the
-- disciples' lotus isles float on (Config.SKY_MESH islet + its grass top, vines, spirit crystals,
-- clouds trailing under it), its deck ALTAR_HEIGHT over the plaza. The meshes only draw: an invisible
-- slab is the deck players stand on (every edge open for ring-outs) and the grass top catches whoever
-- falls short. Eight bronze braziers on the deck's edge stay dark until a holder's timer lights them
-- (real fire, R3). Two Spirit Springs on the plaza throw you up while it is open.
local function lightBrazier(b, on)
	b.flame.Transparency = on and 0 or 1
	b.fire.Enabled = on
	b.light.Enabled = on
end

local SPIRIT = Color3.fromHex("6FF2C8")
local LAWN = Color3.fromHex("7DAA5C")
local ROCK = Color3.fromHex("9A8672")
local CLOUD_NATIVE = Vector3.new(13.76, 9.09, 24.67)

-- the arena mesh, fetched once (a fetch can time out: try again), nil when it never loads
local function arenaMesh()
	local A = Config.ALTAR_ARENA
	for try = 1, 3 do
		local ok, mp = pcall(AssetService.CreateMeshPartAsync, AssetService, A.mesh, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
		if ok and mp then
			mp.TextureID = A.texture
			return mp
		end
		task.wait(try)
	end
	warn("[Tycoon][perf] event=altar_arena_load_failed")
	return nil
end

-- the meshes (arena, islet, grass top) arrive off the boot: Main must not wait on four fetches
local function dress(m, y, R)
	local A = Config.ALTAR_ARENA
	local k = R / A.deckHalf -- arena studs per mesh stud
	local base = y - A.deckTop * k -- the arena mesh's bottom, on the islet's grass
	-- the islet: wide enough that the arena's corner poles stand on its grass, flat enough (0.45 tall)
	-- that its point stays well over the cauldron
	local w = R * 3.3
	local rng = Random.new(78)
	local function sky(name, size, cf)
		local p = Lowpoly.sky(name)
		if p then
			p:ClearAllChildren()
			p.Size = size
			p.CFrame = cf
			p.CanCollide = name == "isletTop" -- the grass top catches a short fall
			p.CanQuery = p.CanCollide
			p.CanTouch = false
			p.Parent = m
		end
		return p
	end
	Lowpoly.skyReady(10)
	local rock = sky("islet", Vector3.new(w, w * 0.45, w), CFrame.new(0, base - 0.8 - w * 0.225, 0) * CFrame.Angles(0, 0.6, 0))
	if rock then
		rock.Material = Enum.Material.Rock
		rock.Color = ROCK
	end
	local grass = sky("isletTop", Vector3.new(w + 0.6, 0.8, w + 0.6), CFrame.new(0, base - 0.5, 0) * CFrame.Angles(0, 0.6, 0))
	if grass then
		grass.Material = Enum.Material.LeafyGrass
		grass.Color = LAWN
	end
	-- vines off the rim, spirit crystals under the rock (as the lotus isles, Builders.isleBody)
	local P = ctx.style.P
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local len = rng:NextNumber(4, 8)
		local v = P(m, Vector3.new(0.4, len, 0.4), CFrame.new(math.cos(a) * w * 0.46, base - 1.6 - len / 2, math.sin(a) * w * 0.46), ctx.style.PAL.grassDark, Enum.Material.LeafyGrass)
		v.CanCollide, v.CanQuery = false, false
	end
	for _ = 1, 4 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(1, w * 0.15)
		local gem = P(m, Vector3.new(0.9, rng:NextNumber(2.6, 4.2), 0.9), CFrame.new(math.cos(a) * d, base - 0.8 - w * 0.42, math.sin(a) * d) * CFrame.Angles(0, math.rad(45), rng:NextNumber(-0.3, 0.3)), SPIRIT, Enum.Material.Glass)
		gem.CanCollide, gem.CanQuery, gem.CastShadow = false, false, false
	end
	-- clouds trailing under the rim
	for i = 1, 6 do
		local a, r = i / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3), rng:NextNumber(14, 18)
		local cw = rng:NextNumber(9, 13)
		local size = Vector3.new(cw * 0.56, cw * 0.37, cw)
		local c = P(m, size, CFrame.new(math.cos(a) * r, base - rng:NextNumber(9, 15), math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color3.fromRGB(255, 252, 255))
		c.CanCollide, c.CanQuery, c.CastShadow = false, false, false
		local sm = Instance.new("SpecialMesh")
		sm.MeshType = Enum.MeshType.FileMesh
		sm.MeshId = Config.SKY_MESH.cloud
		sm.Scale = size / CLOUD_NATIVE
		sm.Parent = c
	end
	-- the arena itself: draws only (its gong, rack, stairs and corner poles never block a push)
	local arena = arenaMesh()
	if arena then
		arena.Anchored = true
		arena.Size = A.native * k
		arena.CFrame = CFrame.new(-A.offsetX * k, base + arena.Size.Y / 2, 0)
		arena.CanCollide, arena.CanQuery, arena.CanTouch = false, false, false
		arena.Name = "Arena"
		arena.Parent = m
	end
end

local function build(parent)
	local P, PAL = ctx.style.P, ctx.style.PAL
	local m = Instance.new("Model")
	m.Name = "HeavenlyAltar"
	local R = Config.ALTAR_RADIUS
	local y = ctx.baseY + Config.ALTAR_HEIGHT
	top = Vector3.new(0, y, 0)
	local props = {} -- parts that must not collide
	local function prop(p)
		table.insert(props, p)
		return p
	end
	-- the deck players stand on: invisible, the arena mesh draws it
	local floor = P(m, Vector3.new(R * 2, 1, R * 2), CFrame.new(0, y - 0.5, 0), Color3.new(1, 1, 1))
	floor.Name = "Floor"
	floor.Transparency = 1
	floor.CastShadow = false
	task.spawn(dress, m, y, R)
	-- braziers: two on each edge of the deck
	for k = 0, Config.ALTAR_BRAZIERS - 1 do
		local side, slot = k % 4, k // 4
		local face = CFrame.Angles(0, side * math.pi / 2, 0)
		local c = (face * CFrame.new((slot == 0 and -1 or 1) * R * 0.5, y, R - 1)).Position
		for _, t in { 0, 2.1, 4.2 } do
			prop(P(
				m,
				Vector3.new(0.25, 1.6, 0.25),
				CFrame.new(c + Vector3.new(math.cos(t) * 0.55, 0.8, math.sin(t) * 0.55))
					* CFrame.Angles(math.cos(t) * 0.25, 0, -math.sin(t) * 0.25),
				BRONZE,
				Enum.Material.Metal
			))
		end
		prop(P(
			m,
			Vector3.new(0.5, 1.5, 1.5),
			CFrame.new(c + Vector3.new(0, 1.75, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			BRONZE,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		))
		prop(P(
			m,
			Vector3.new(0.2, 1.7, 1.7),
			CFrame.new(c + Vector3.new(0, 2.05, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			GOLD,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		))
		local flame =
			prop(P(m, Vector3.new(0.8, 0.9, 0.8), CFrame.new(c + Vector3.new(0, 2.4, 0)), FLAME, Enum.Material.Neon))
		local fire = Instance.new("Fire")
		fire.Size = 2.2
		fire.Heat = 7
		fire.Color = Color3.fromRGB(255, 160, 70)
		fire.SecondaryColor = Color3.fromRGB(255, 80, 30)
		fire.Parent = flame
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 175, 95)
		light.Range = 12
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = flame
		local b = { flame = flame, fire = fire, light = light }
		lightBrazier(b, false)
		table.insert(braziers, b)
	end
	for _, p in props do
		p.CanCollide = false
		p.CanQuery = false
	end
	-- Spirit Springs on the plaza, either side of the cauldron (clear of the spawn at z = 9 and out
	-- past the deck, so the arc clears the apron)
	for _, sx in { -1, 1 } do
		local c = Vector3.new(sx * Config.ALTAR_SPRING_X, ctx.baseY + 0.45, -2)
		local ring = P(
			m,
			Vector3.new(0.3, 4.6, 4.6),
			CFrame.new(c) * CFrame.Angles(0, 0, math.pi / 2),
			PAL.gold,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		ring.Name = "Spring"
		P(
			m,
			Vector3.new(0.34, 3.6, 3.6),
			CFrame.new(c) * CFrame.Angles(0, 0, math.pi / 2),
			PAL.jade,
			nil,
			Enum.PartType.Cylinder
		)
		P(
			m,
			Vector3.new(0.38, 1.4, 1.4),
			CFrame.new(c) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromHex("8FD3B8"),
			nil,
			Enum.PartType.Cylinder
		)
		-- rising qi wisps while the altar is open (particles, not a light source)
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Color3.fromHex("C9FFE6"), Color3.fromHex("FFE9A8"))
		pe.LightEmission = 0.3
		pe.Size = NumberSequence.new(0.5, 0)
		pe.Lifetime = NumberRange.new(1, 1.6)
		pe.Speed = NumberRange.new(6, 9)
		pe.SpreadAngle = Vector2.new(12, 12)
		pe.Rate = 14
		pe.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis points up
		pe.Enabled = false
		pe.Parent = ring
		ring:SetAttribute("Spring", true)
		table.insert(springs, ring)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanTouch = false
		end
	end
	m.Parent = parent
	workspace:SetAttribute("AltarTop", top)
	workspace:SetAttribute("AltarRadius", Config.ALTAR_RADIUS)
end

local function setSprings(on)
	for _, s in springs do
		s.ParticleEmitter.Enabled = on
	end
end

---------------------------------------------------------------------------------------------
-- The winner's light aura until the next round opens (owner 2026-10-22: "Crown is ugly, add a light
-- aura better"; picked W3 of docs/art/mocks/aura_options.jpg): a gold rim light on the whole body
-- (a Highlight: gold outline + a faint gold fill) and gold sparkles twinkling around it. Glowing
-- objects only, no Light (R3). Kept in a folder "AltarCrown" on the character (names kept from the
-- crown).
local TEX = "rbxasset://textures/particles/"
local AURA_GOLD = Color3.fromHex("FFD34D")
local AURA_PALE = Color3.fromHex("FFF1B8")
local function removeCrown()
	if crowned then
		local c = crowned.Character and crowned.Character:FindFirstChild("AltarCrown")
		if c then
			c:Destroy()
		end
		crowned:SetAttribute("AltarCrown", nil)
		crowned = nil
	end
end

local function giveCrown(player)
	removeCrown()
	crowned = player
	player:SetAttribute("AltarCrown", true)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not head or not hrp then
		return
	end
	local m = Instance.new("Folder")
	m.Name = "AltarCrown"
	-- the gold rim light on the body
	local hl = Instance.new("Highlight")
	hl.Name = "Glow"
	hl.FillColor = AURA_GOLD
	hl.FillTransparency = 0.82
	hl.OutlineColor = AURA_PALE
	hl.OutlineTransparency = 0.15
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = char
	hl.Parent = m
	-- gold sparkles twinkling around the body: thrown out a little in every direction, slowed by drag,
	-- they swell and fade on the spot
	local att = Instance.new("Attachment")
	att.Name = "AltarAura"
	att.Parent = hrp
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Sparkles"
	pe.Texture = TEX .. "sparkles_main.dds"
	pe.Color = ColorSequence.new(AURA_PALE)
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Brightness = 3
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Speed = NumberRange.new(5, 7) -- out past the body (they start inside it), then drag stops them
	pe.Drag = 2.5
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, 0.9), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new(0.05)
	pe.Lifetime = NumberRange.new(0.9, 1.3)
	pe.Rotation = NumberRange.new(0, 360)
	pe.Rate = 6
	pe.Parent = att
	-- the attachment sits on the root, outside the folder: destroying the folder clears it too
	m.Destroying:Connect(function()
		att:Destroy()
	end)
	m.Parent = char
end

local KNOCK_CHECK = 1.2 -- s after a knock is sent: room for a 500 ms ping both ways; plus twice the
-- player's own ping (owner 2026-10-23: a laggy phone must not read as "ignored the knock"), capped
local KNOCK_PING_CAP = 1.5 -- s of ping counted at most (a cheat cannot buy unlimited time with lag)

local function knockWait(player)
	local ok, ping = pcall(player.GetNetworkPing, player)
	return KNOCK_CHECK + 2 * (if ok and type(ping) == "number" then math.clamp(ping, 0, KNOCK_PING_CAP) else 0)
end
local KNOCK_MIN_MOVE = 5 -- studs; a real knock carries the body ~24 studs sideways

---------------------------------------------------------------------------------------------
-- Who stands on the altar: a body over the square deck, from just below the floor to a jump above
-- it (positions only, read on the server). The client's copy is Altar.client amOnTop.
local function onTop(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local p = hrp.Position
	local half = Config.ALTAR_RADIUS + 0.5
	return math.abs(p.X - top.X) <= half and math.abs(p.Z - top.Z) <= half and p.Y > top.Y - 1 and p.Y < top.Y + 12
end

local function reward(player, seconds, sku)
	local s = ctx.sessions[player]
	if not s then
		return 0
	end
	local gain = math.floor(ctx.rate(s, true) * seconds)
	s.data.qi += gain
	ctx.telemetry.source(player, s.data, gain, sku)
	ctx.publish(player)
	return gain
end

local function setHud()
	workspace:SetAttribute("AltarHolder", round and round.holder and round.holder.DisplayName or "")
	workspace:SetAttribute("AltarHold", round and math.floor(round.hold * 10) / 10 or 0)
end

local function closeRound(winner)
	local r = round
	round = nil
	workspace:SetAttribute("AltarUntil", 0)
	workspace:SetAttribute("AltarCrowd", 0)
	setHud()
	setSprings(false)
	local joined = 0
	for player in r.joined do
		if player.Parent then
			joined += 1
			if player ~= winner then
				local gain = reward(player, Config.ALTAR_JOIN_SECONDS, "altarJoin")
				ctx.notify:FireClient(player, "altarJoin", gain)
			end
		end
		player:SetAttribute("AltarOut", nil)
	end
	for player in r.out do
		if player.Parent then
			player:SetAttribute("AltarOut", nil)
		end
	end
	if winner then
		local contested = joined > 1 -- an empty-server claim pays less: the prize is for a fight
		local gain = reward(winner, contested and Config.ALTAR_WIN_SECONDS or Config.ALTAR_SOLO_SECONDS, "altarWin")
		giveCrown(winner)
		ctx.notify:FireAllClients("altarWon", winner.DisplayName, gain, winner.UserId)
		for _, b in braziers do
			lightBrazier(b, true)
		end
		task.delay(6, function()
			if not round then
				for _, b in braziers do
					lightBrazier(b, false)
				end
			end
		end)
	else
		ctx.notify:FireAllClients("altarFade")
		for _, b in braziers do
			lightBrazier(b, false)
		end
	end
	local reporter = winner or next(r.joined) or Players:GetPlayers()[1]
	if reporter and reporter.Parent then
		local ws = winner and ctx.sessions[winner]
		ctx.telemetry.custom(
			reporter,
			"AltarRound",
			winner and "claimed" or "faded",
			tostring(math.min(joined, 9)),
			ws and ctx.telemetry.realmBucket(ws.data.realm) or "none"
		)
	end
	print(string.format("[Tycoon] altar %s, %d joined", winner and ("claimed by " .. winner.UserId) or "faded", joined))
end

local function openRound(now)
	removeCrown()
	round = { untilT = now + Config.ALTAR_WINDOW, holder = nil, hold = 0, joined = {}, out = {}, knocked = {} }
	workspace:SetAttribute("AltarUntil", round.untilT)
	workspace:SetAttribute("AltarNext", now + Config.ALTAR_INTERVAL)
	setHud()
	setSprings(true)
	for _, b in braziers do
		lightBrazier(b, false)
	end
	ctx.notify:FireAllClients("altarOpen", Config.ALTAR_WINDOW)
end

-- one server tick (0.1 s)
local warned = false
local function tick(dt)
	local now = workspace:GetServerTimeNow()
	local nextAt = workspace:GetAttribute("AltarNext")
	if not round then
		if not warned and now >= nextAt - Config.ALTAR_WARN then
			warned = true
			ctx.notify:FireAllClients("altarSoon", math.max(1, math.ceil(nextAt - now)))
		end
		if now >= nextAt then
			warned = false
			openRound(now)
		end
		return
	end
	-- who is on it; whoever stood on it and is now below the floor is out for this round
	local crowd = {}
	local clock = os.clock()
	for _, player in Players:GetPlayers() do
		-- The knockback runs on the struck player's own client (it owns its character), so a cheat
		-- can simply drop it and never fall. A real knock moves the body ~24 studs in 0.3 s; a body
		-- that is still on the altar and has barely moved KNOCK_CHECK s later ignored it, and counts
		-- as fallen (security pass 2026-10-22).
		local k = round.knocked[player]
		if k and clock - k.t >= knockWait(player) then
			round.knocked[player] = nil
			local hrp = onTop(player) and player.Character.HumanoidRootPart
			local moved = hrp and (hrp.Position - k.at) * Vector3.new(1, 0, 1)
			if moved and moved.Magnitude < KNOCK_MIN_MOVE and not round.out[player] then
				round.out[player] = true
				player:SetAttribute("AltarOut", true)
				ctx.notify:FireClient(player, "altarOut")
				print(string.format("[Tycoon][guard] user=%d ignored a knock", player.UserId))
			end
		end
		if onTop(player) then
			if round.out[player] then
				-- out players never count; if one got back up anyway, drop them off the edge
				local hrp = player.Character.HumanoidRootPart
				local away = Vector3.new(hrp.Position.X, 0, hrp.Position.Z).Unit
				if away ~= away then
					away = Vector3.new(0, 0, 1)
				end
				player.Character:PivotTo(
					CFrame.new(away * (Config.ALTAR_RADIUS * 1.5 + 4) + Vector3.new(0, ctx.baseY + 3, 0)) -- past the deck's corners
				)
			else
				table.insert(crowd, player)
				round.joined[player] = true
			end
		elseif round.joined[player] and not round.out[player] then
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			-- off the deck = out: below it, or past its edge (the islet's grass round the deck sits only
			-- ~3 studs lower and catches a short fall: standing there is out too)
			local off = hrp and Vector2.new(math.abs(hrp.Position.X - top.X), math.abs(hrp.Position.Z - top.Z))
			if not hrp or hrp.Position.Y < top.Y - 1.5 or math.max(off.X, off.Y) > Config.ALTAR_RADIUS + 1.5 then
				round.out[player] = true
				player:SetAttribute("AltarOut", true)
				ctx.notify:FireClient(player, "altarOut")
			end
		end
	end
	workspace:SetAttribute("AltarCrowd", #crowd)
	if #crowd == 1 then
		local p = crowd[1]
		if round.holder ~= p then
			round.holder = p
			round.hold = 0
		end
		round.hold += dt
	elseif #crowd == 0 then
		round.holder = nil
		round.hold = 0
	end -- two or more: the timer pauses where it is
	if round.holder and not round.holder.Parent then
		round.holder, round.hold = nil, 0
	end
	-- braziers follow the holder's timer: one more lights every ALTAR_HOLD / ALTAR_BRAZIERS s
	local lit = math.floor(round.hold / Config.ALTAR_HOLD * #braziers + 1e-6)
	for i, b in braziers do
		local on = i <= lit
		if b.fire.Enabled ~= on then
			lightBrazier(b, on)
		end
	end
	setHud()
	if round.holder and round.hold >= Config.ALTAR_HOLD then
		closeRound(round.holder)
	elseif now >= round.untilT then
		closeRound(nil)
	end
end

---------------------------------------------------------------------------------------------
-- Palm Strike: the striker must be on the altar in an open round, with the cooldown spent. Every
-- rival on it within reach and in front (a wide cone) gets knocked back away from the striker.
local function strike(player)
	if not Guard.allow(player, "AltarPush") then
		return
	end
	if not round or round.out[player] or not onTop(player) then
		return
	end
	local now = os.clock()
	if now - (lastPush[player] or 0) < Config.ALTAR_PUSH_COOLDOWN - 0.15 then
		return
	end
	lastPush[player] = now
	local hrp = player.Character.HumanoidRootPart
	local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0 and look.Unit or Vector3.new(0, 0, -1)
	local hit = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and onTop(other) then
			local o = other.Character.HumanoidRootPart.Position
			local d = (o - hrp.Position) * Vector3.new(1, 0, 1)
			if d.Magnitude <= Config.ALTAR_PUSH_REACH and (d.Magnitude < 2.5 or d.Unit:Dot(look) > 0.25) then
				local dir = d.Magnitude > 0.1 and d.Unit or look
				ctx.notify:FireClient(other, "altarKnock", dir * Config.ALTAR_PUSH_SPEED + Vector3.new(0, 30, 0))
				round.knocked[other] = { t = os.clock(), at = o }
				hit += 1
			end
		end
	end
	ctx.notify:FireAllClients("altarPalm", hrp.Position + look * 2.5, hit, player.UserId)
end

function Altar.init(context, parent)
	ctx = context
	build(parent)
	workspace:SetAttribute("AltarNext", workspace:GetServerTimeNow() + Config.ALTAR_FIRST)
	workspace:SetAttribute("AltarUntil", 0)
	workspace:SetAttribute("AltarCrowd", 0)
	setHud()
	local push = Instance.new("RemoteEvent")
	push.Name = "AltarPush"
	push.OnServerEvent:Connect(strike)
	push.Parent = ctx.remotes
	Players.PlayerRemoving:Connect(function(p)
		lastPush[p] = nil
		if crowned == p then
			crowned = nil
		end
		if round then
			round.joined[p], round.out[p], round.knocked[p] = nil, nil, nil
		end
	end)
	-- a winner who respawns keeps the crown
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function()
			if crowned == p then
				task.wait(1)
				giveCrown(p)
			end
		end)
	end)
	for _, p in Players:GetPlayers() do
		p.CharacterAdded:Connect(function()
			if crowned == p then
				task.wait(1)
				giveCrown(p)
			end
		end)
	end
	task.spawn(function()
		while true do
			local dt = task.wait(0.1)
			local ok, err = pcall(tick, dt)
			if not ok then
				warn("[Tycoon] altar tick failed:", err)
			end
		end
	end)
end

-- Studio test hook (DebugSet "altar"): open a round now
function Altar.debugOpen()
	if not round then
		openRound(workspace:GetServerTimeNow())
	end
end

return Altar
