-- Heavenly Altar: king of the hill over the hub (Config ALTAR_*, mock A, owner idea 2026-10-21).
-- A floating jade altar above the cauldron opens every ALTAR_INTERVAL s; two Spirit Springs on the
-- plaza throw players up to it. Stand on it ALONE for ALTAR_HOLD s to claim it; two or more on it
-- pause the timer. Palm Strike knocks rivals off; whoever falls off is out until the round ends.
-- The server decides everything (R9): who stands on it is read from positions every tick, the
-- push is validated here and only the knockback runs on the victim's client (it owns its body).
-- State for the HUD = Workspace attributes: AltarNext, AltarUntil (server time), AltarHolder
-- (display name or ""), AltarHold (s held), AltarCrowd (players on it); player attribute AltarOut.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guard = require(script.Parent:WaitForChild("Guard"))
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
-- The altar: a floating island disc (rock underside, stone rim, jade floor with a gold inlay),
-- eight bronze braziers on the rim that stay dark until a holder's timer lights them (real fire,
-- R3), and two Spirit Springs on the plaza: carved rings that throw you up while it is open.
local function lightBrazier(b, on)
	b.flame.Transparency = on and 0 or 1
	b.fire.Enabled = on
	b.light.Enabled = on
end

local function build(parent)
	local P, PAL = ctx.style.P, ctx.style.PAL
	local m = Instance.new("Model")
	m.Name = "HeavenlyAltar"
	local R = Config.ALTAR_RADIUS
	local y = ctx.baseY + Config.ALTAR_HEIGHT
	top = Vector3.new(0, y, 0)
	local function disc(h, dia, cy, color, mat)
		return P(
			m,
			Vector3.new(h, dia, dia),
			CFrame.new(0, cy, 0) * CFrame.Angles(0, 0, math.pi / 2),
			color,
			mat,
			Enum.PartType.Cylinder
		)
	end
	-- underside: stacked rock rings tapering to a point, like the floating peaks
	local rng = Random.new(77)
	for i = 0, 4 do
		local r = R * (1 - i * 0.19)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2 + i * 0.4
			local s = r * rng:NextNumber(0.55, 0.75)
			P(
				m,
				Vector3.new(s, 1.6 + i * 0.3, s),
				CFrame.new(math.cos(a) * r * 0.45, y - 1.4 - i * 1.5, math.sin(a) * r * 0.45)
					* CFrame.Angles(0, a, rng:NextNumber(-0.2, 0.2)),
				PAL.rock
			)
		end
	end
	-- floor: stone rim, jade field, gold inlay rings and eight spokes
	disc(1.4, R * 2 + 1, y - 0.7, PAL.stone)
	disc(1.45, R * 2 - 0.6, y - 0.68, PAL.stoneLight)
	local field = disc(1.5, R * 2 - 3, y - 0.66, PAL.jade)
	field.Name = "Floor"
	disc(1.52, R * 2 - 3.6, y - 0.65, PAL.gold, Enum.Material.Metal)
	disc(1.54, R * 2 - 4.4, y - 0.64, PAL.jade)
	disc(1.56, 5, y - 0.63, PAL.gold, Enum.Material.Metal)
	disc(1.58, 4.2, y - 0.62, Color3.fromHex("8FD3B8"))
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local mid = (2.6 + (R - 2.2)) / 2
		P(
			m,
			Vector3.new(0.4, 0.08, R - 4.8),
			CFrame.new(math.cos(a) * mid, y + 0.1, math.sin(a) * mid) * CFrame.Angles(0, -a + math.pi / 2, 0),
			PAL.gold,
			Enum.Material.Metal
		)
	end
	-- low balustrade posts between the braziers (rails would trap pushes: posts only)
	for k = 0, 15 do
		if k % 2 == 1 then
			local a = k / 16 * math.pi * 2
			P(
				m,
				Vector3.new(0.6, 1.1, 0.6),
				CFrame.new(math.cos(a) * (R - 0.1), y + 0.55, math.sin(a) * (R - 0.1)),
				PAL.vermilion
			)
			P(
				m,
				Vector3.new(0.8, 0.25, 0.8),
				CFrame.new(math.cos(a) * (R - 0.1), y + 1.2, math.sin(a) * (R - 0.1)),
				PAL.gold,
				Enum.Material.Metal
			)
		end
	end
	-- braziers on the rim
	for k = 0, Config.ALTAR_BRAZIERS - 1 do
		local a = k / Config.ALTAR_BRAZIERS * math.pi * 2
		local c = Vector3.new(math.cos(a) * (R - 0.2), y, math.sin(a) * (R - 0.2))
		for _, t in { 0, 2.1, 4.2 } do
			P(
				m,
				Vector3.new(0.25, 1.6, 0.25),
				CFrame.new(c + Vector3.new(math.cos(t) * 0.55, 0.8, math.sin(t) * 0.55))
					* CFrame.Angles(math.cos(t) * 0.25, 0, -math.sin(t) * 0.25),
				BRONZE,
				Enum.Material.Metal
			)
		end
		P(
			m,
			Vector3.new(0.5, 1.5, 1.5),
			CFrame.new(c + Vector3.new(0, 1.75, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			BRONZE,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		P(
			m,
			Vector3.new(0.2, 1.7, 1.7),
			CFrame.new(c + Vector3.new(0, 2.05, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			GOLD,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		local flame =
			P(m, Vector3.new(0.8, 0.9, 0.8), CFrame.new(c + Vector3.new(0, 2.4, 0)), FLAME, Enum.Material.Neon)
		flame.CanCollide = false
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
	-- Spirit Springs on the plaza, either side of the cauldron (clear of the spawn at z = 9)
	for _, sx in { -1, 1 } do
		local c = Vector3.new(sx * 13, ctx.baseY + 0.45, -2) -- outside the rim: the arc must clear the underside
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
	pe.LightEmission = 0.6
	pe.LightInfluence = 0
	pe.Brightness = 2.5
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Speed = NumberRange.new(3, 5)
	pe.Drag = 6
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.45), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new(0.05)
	pe.Lifetime = NumberRange.new(0.9, 1.3)
	pe.Rotation = NumberRange.new(0, 360)
	pe.Rate = 5
	pe.Parent = att
	-- the attachment sits on the root, outside the folder: destroying the folder clears it too
	m.Destroying:Connect(function()
		att:Destroy()
	end)
	m.Parent = char
end

local KNOCK_CHECK = 1.2 -- s after a knock is sent: room for a 500 ms ping both ways
local KNOCK_MIN_MOVE = 5 -- studs; a real knock carries the body ~14 studs sideways

---------------------------------------------------------------------------------------------
-- Who stands on the altar: a body inside the floor circle, from just below the floor to a jump
-- above it (positions only, read on the server).
local function onTop(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local p = hrp.Position
	local flat = Vector2.new(p.X - top.X, p.Z - top.Z).Magnitude
	return flat <= Config.ALTAR_RADIUS + 0.5 and p.Y > top.Y - 1 and p.Y < top.Y + 12
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
		-- can simply drop it and never fall. A real knock moves the body ~14 studs in 0.22 s; a body
		-- that is still on the altar and has barely moved KNOCK_CHECK s later ignored it, and counts
		-- as fallen (security pass 2026-10-22).
		local k = round.knocked[player]
		if k and clock - k.t >= KNOCK_CHECK then
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
					CFrame.new(away * (Config.ALTAR_RADIUS + 4) + Vector3.new(0, ctx.baseY + 3, 0))
				)
			else
				table.insert(crowd, player)
				round.joined[player] = true
			end
		elseif round.joined[player] and not round.out[player] then
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not hrp or hrp.Position.Y < top.Y - 3 then
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
				ctx.notify:FireClient(other, "altarKnock", dir * Config.ALTAR_PUSH_SPEED + Vector3.new(0, 34, 0))
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
