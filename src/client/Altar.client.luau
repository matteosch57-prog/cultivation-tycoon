-- Heavenly Altar on the client (mock A, docs/art/mocks/altar_A_phone.jpg): while a round is open, a
-- small altar button in the HUD's right stack (owner 2026-10-22: the ring in the middle was "too
-- invasive"; docs/art/mocks/fight_options.jpg): beads around it fill as the holder's timer runs, a
-- tap teleports you onto the deck (owner 2026-10-24), its X hides it until the next round. The
-- Palm Strike button while you stand on the altar (owner pick 1 2026-10-23,
-- docs/art/mocks/altar_phone_buttons.jpg: on a phone it takes the Recruit seal's spot left of Jump and
-- the seal steps aside through the Player attribute AltarPalm; F on a keyboard), the moon gates
-- that throw you up, the knockback (a short ragdoll, a camera kick), toasts and sounds. In the last ALERT_SECS of a round a bouncing "!" sits on the
-- button's other corner (owner 2026-10-23): a tap teleports you onto the deck (owner 2026-10-24).
-- The server decides who holds and who wins (src/server/Altar.luau); this only draws and asks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local px, text, frame = Toy.px, Toy.text, Toy.frame
local GOLD = Color3.fromHex("FFE36B")
local PINK = Color3.fromHex("FFB3A8")
local MINT = Color3.fromHex("9FF5C8")
local BEAD_OFF = Color3.fromHex("3A2C44")
local BEAD_ON = Color3.fromHex("FFD34D")
local PALM = Color3.fromHex("FF9F43")

local pushRemote = remotes:WaitForChild("AltarPush")

local function commas(n)
	local s = tostring(math.floor(n))
	return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
local function short(n)
	n = math.floor(n or 0)
	if n < 1e6 then
		return commas(n)
	end
	local units = { "M", "B", "T", "Qa", "Qi" }
	local v, i = n / 1e6, 1
	while v >= 1000 and i < #units do
		v /= 1000
		i += 1
	end
	local digits = v < 10 and 2 or (v < 100 and 1 or 0)
	local f = 10 ^ digits
	return string.format("%." .. digits .. "f%s", math.floor(v * f) / f, units[i])
end

---------------------------------------------------------------------------------------------
-- device + scale (same rule as the HUD)
local function jumpButton()
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	if jump and jump.Visible and jump.AbsoluteSize.X > 0 then
		return jump
	end
	return nil
end
local function isPhone()
	local forced = player:GetAttribute("HudDevice")
	if forced then
		return forced == "phone"
	end
	return jumpButton() ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
end
local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	if isPhone() then
		return math.clamp(vp.Y / 390, 0.78, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

local gui = Instance.new("ScreenGui")
gui.Name = "Altar"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local ui = {}
local beads = {}
local dismissed = 0 -- AltarUntil of the round the player closed with the X (hidden until the next)
local ROW = Color3.fromHex("D9473B") -- red lacquer, so the bronze ding reads
local ALERT_SECS = 30 -- the "!" shows once the counter reads this or less
local ALERT_NEAR = 40 -- studs from the altar: already there, no "!"

-- the qi counter's bottom edge (HUD), where altar toasts sit
local function counterBottom()
	local hud = playerGui:FindFirstChild("Hud")
	local c = hud and hud:FindFirstChild("Counter", true)
	if c and c.AbsoluteSize.Y > 0 then
		-- Absolute* is measured from below the top bar even with IgnoreGuiInset: convert to this gui
		return c.AbsolutePosition.Y + c.AbsoluteSize.Y - gui.AbsolutePosition.Y
	end
	return px(80)
end

-- the HUD's right stack (gift, pill, ...): Player.HudSlots.Right, re-sent by HudSlots.Rebuilt
-- after every HUD build. Without it the row stands on its own in the top right.
local function rightStack()
	local slots = player:FindFirstChild("HudSlots")
	local right = slots and slots:FindFirstChild("Right")
	return right and right.Value
end
local function placeRow()
	if not ui.row then
		return
	end
	local stack = rightStack()
	if stack then
		ui.row.AnchorPoint = Vector2.new(0, 0)
		ui.row.Position = UDim2.new()
		ui.row.LayoutOrder = 3
		ui.row.Parent = stack
	else
		ui.row.AnchorPoint = Vector2.new(1, 0)
		ui.row.Position = UDim2.new(1, -px(16), 0, px(96))
		ui.row.Parent = gui
	end
end

-- the guide trail to the nearest moon gate (no longer drawn by the altar button, which teleports;
-- only cleared here), from Config, not the parts: far from the hub the altar model has not streamed in
local function nearestSpring()
	local top = workspace:GetAttribute("AltarTop")
	if not top then
		return nil
	end
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local sx = hrp and hrp.Position.X < top.X and -1 or 1
	return Vector3.new(top.X + sx * Config.ALTAR_SPRING_X, top.Y - Config.ALTAR_HEIGHT + 0.5, top.Z - 2)
end
local function guideToAltar(on)
	player:SetAttribute("GuideTo", on and nearestSpring() or nil)
end

local function build()
	if ui.row then
		ui.row:Destroy()
	end
	for _, c in gui:GetChildren() do
		c:Destroy()
	end
	table.clear(beads)
	Toy.S = computeScale()
	-- the altar row: a 46 px toy button with the altar icon, the hold beads around it, the seconds
	-- under it, an X on its corner
	local rowSize = px(46)
	local row = frame(nil, { Size = UDim2.fromOffset(rowSize + px(12), rowSize + px(28)), Visible = false, Name = "AltarRow" })
	ui.row = row
	local holder, btn = Toy.button(row, UDim2.fromOffset(rowSize, rowSize), ROW, rowSize / 2)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, px(6))
	Toy.icon(btn, "altar", math.floor(rowSize * 0.74), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	-- one bead per 2 s held (10 for the 20 s claim): fewer, bigger beads read at 46 px
	local n = math.ceil(Config.ALTAR_HOLD / 2)
	for i = 1, n do
		local a = (i - 1) / n * math.pi * 2 - math.pi / 2
		local r = rowSize / 2 + px(6)
		local b = frame(holder, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(a) * r, 0.5, math.sin(a) * r),
			Size = UDim2.fromOffset(px(7), px(7)),
			BackgroundTransparency = 0,
			BackgroundColor3 = BEAD_OFF,
			ZIndex = 3,
		})
		Toy.corner(b, UDim.new(1, 0))
		local st = Instance.new("UIStroke")
		st.Color = Toy.INK
		st.Thickness = px(1.5)
		st.Parent = b
		beads[i] = b
	end
	ui.secs = text(row, "", px(13), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, rowSize + px(12)) })
	-- the X: hides the row until the next round
	local x = Instance.new("TextButton")
	x.Text = ""
	x.AutoButtonColor = false
	x.AnchorPoint = Vector2.new(0.5, 0.5)
	x.Position = UDim2.new(0.5, rowSize / 2 + px(2), 0, px(6) + px(2))
	x.Size = UDim2.fromOffset(px(20), px(20))
	x.BackgroundColor3 = Toy.INK
	x.BackgroundTransparency = 0.2
	x.ZIndex = 5
	x.Parent = row
	Toy.corner(x, UDim.new(1, 0))
	for _, rot in { 45, -45 } do
		local bar = frame(x, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(px(10), px(2.5)), Rotation = rot, BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6 })
		Toy.corner(bar, UDim.new(1, 0))
	end
	Toy.feel(x)
	x.Activated:Connect(function()
		dismissed = workspace:GetAttribute("AltarUntil") or 0
		row.Visible = false
		guideToAltar(false)
	end)
	-- the altar button and the "!" both teleport onto the deck, no trail (owner 2026-10-24: "clicking
	-- on HUD arena is teleporting in arena, stop showing path")
	local function goToAltar()
		guideToAltar(false)
		local slots = player:FindFirstChild("HudSlots")
		local travel = slots and slots:FindFirstChild("Travel")
		if travel then
			travel:Fire("altar") -- the HUD's jade wipe (Base / Ranks chips)
		else
			remotes.Teleport:FireServer("altar")
		end
	end
	btn.Activated:Connect(goToAltar)
	-- the "!": gold, on the top-left corner (the X has the right one); it bounces and rocks per frame
	local alert = Instance.new("TextButton")
	alert.Text = "!"
	alert.FontFace = Toy.FONT
	alert.TextSize = px(18)
	alert.TextColor3 = Toy.INK
	alert.AutoButtonColor = false
	alert.AnchorPoint = Vector2.new(0.5, 0.5)
	alert.Size = UDim2.fromOffset(px(24), px(24))
	alert.BackgroundColor3 = GOLD
	alert.ZIndex = 7
	alert.Visible = false
	alert.Parent = row
	Toy.corner(alert, UDim.new(1, 0))
	local ast = Instance.new("UIStroke")
	ast.Color = Toy.INK
	ast.Thickness = px(2)
	ast.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ast.Parent = alert
	ui.alert, ui.alertX, ui.alertY = alert, -rowSize / 2 - px(2), px(6) + px(2)
	Toy.feel(alert)
	alert.Activated:Connect(goToAltar)
	placeRow()
	-- Palm Strike: on a phone in the Recruit seal's spot, left of Jump with their bottoms level (the
	-- seal steps aside while this shows: Hud reads AltarPalm); bottom right on a computer (key F),
	-- where the seal also sits
	local size = px(isPhone() and 78 or 64)
	local holder, btn = Toy.button(gui, UDim2.fromOffset(size, size), PALM, size / 2)
	holder.AnchorPoint = Vector2.new(1, 1)
	local jump = jumpButton()
	if jump then
		holder.Position = UDim2.fromOffset(
			jump.AbsolutePosition.X - gui.AbsolutePosition.X - px(12),
			jump.AbsolutePosition.Y + jump.AbsoluteSize.Y - gui.AbsolutePosition.Y
		)
	else
		holder.Position = UDim2.new(1, -px(24), 1, -px(96))
	end
	holder.Visible = false
	ui.palm, ui.palmBtn = holder, btn
	-- the palm (the shared icon sheet)
	Toy.icon(btn, "palm", math.floor(size * 0.66), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.52, 0.5) })
	ui.cool = frame(btn, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 0.45,
		BackgroundColor3 = Toy.INK,
		ZIndex = 6,
	})
	Toy.corner(ui.cool, UDim.new(0, size / 2))
	-- the name sits on the button's bottom edge (the button's bottom is level with Jump's, near the
	-- screen edge)
	text(
		holder,
		isPhone() and "Palm" or "Palm (F)",
		px(14),
		Color3.new(1, 1, 1),
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -px(2)), ZIndex = 8 }
	)
	btn.Activated:Connect(function()
		ui.strike()
	end)
	-- one toast line under the ring area (altar news only)
	ui.toast = frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, counterBottom() + px(8)),
		AutomaticSize = Enum.AutomaticSize.XY,
		Visible = false,
	})
	Toy.list(ui.toast, true, px(6))
end

local toastToken = 0
local function toast(str, color, qiAmount, secs)
	toastToken += 1
	local my = toastToken
	for _, c in ui.toast:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	text(ui.toast, str, px(18), color or Color3.new(1, 1, 1), { LayoutOrder = 1 })
	if qiAmount then
		local _, label = Toy.amount(ui.toast, "qi", px(18), MINT, { LayoutOrder = 2 })
		label.Text = "+" .. short(qiAmount)
	end
	ui.toast.Visible = true
	local sc = ui.toast:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	sc.Scale = 0.6
	sc.Parent = ui.toast
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Sfx.play("toast")
	task.delay(secs or 3.5, function()
		if toastToken == my then
			ui.toast.Visible = false
		end
	end)
end

---------------------------------------------------------------------------------------------
-- where I am
local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end
local function altarTop()
	return workspace:GetAttribute("AltarTop")
end
local function amOnTop()
	local hrp = root()
	local top = altarTop()
	if not hrp or not top then
		return false
	end
	local p = hrp.Position
	local half = Config.ALTAR_RADIUS + 0.5 -- the square deck (server: Altar.luau onTop)
	return math.abs(p.X - top.X) <= half
		and math.abs(p.Z - top.Z) <= half
		and p.Y > top.Y - 1
		and p.Y < top.Y + 12
end
local function isOpen()
	return (workspace:GetAttribute("AltarUntil") or 0) > workspace:GetServerTimeNow()
end

-- Palm Strike: ask the server, swing a short lunge for feel; the cooldown shades the button
local lastStrike = 0
function ui.strike()
	if not isOpen() or player:GetAttribute("AltarOut") or not amOnTop() then
		return
	end
	if os.clock() - lastStrike < Config.ALTAR_PUSH_COOLDOWN then
		return
	end
	lastStrike = os.clock()
	pushRemote:FireServer()
	local hrp = root()
	if hrp then
		hrp.AssemblyLinearVelocity += hrp.CFrame.LookVector * 18
	end
	ui.cool.Size = UDim2.fromScale(1, 1)
	TweenService:Create(
		ui.cool,
		TweenInfo.new(Config.ALTAR_PUSH_COOLDOWN, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(1, 0) }
	):Play()
end
ContextActionService:BindAction("AltarPalm", function(_, state)
	if state == Enum.UserInputState.Begin then
		ui.strike()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonX)

-- a camera kick: the view widens and shakes a moment (a hit taken, or a hit landed)
local kickToken = 0
local function kick(strength)
	local cam = workspace.CurrentCamera
	local _, hum = root()
	if not cam or not hum then
		return
	end
	kickToken += 1
	local my = kickToken
	local fov = cam.FieldOfView
	cam.FieldOfView = fov + 6 * strength
	TweenService:Create(cam, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov }):Play()
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.22 and kickToken == my do
			local k = (1 - (os.clock() - t0) / 0.22) * 0.35 * strength
			hum.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
			RunService.RenderStepped:Wait()
		end
		if kickToken == my then
			hum.CameraOffset = Vector3.zero
		end
	end)
end

-- knockback from a rival's palm: a strong push on my own body (I own its physics), ALTAR_PUSH_TIME s
-- of drive and ALTAR_RAGDOLL s of tumble (PlatformStand: the stick cannot walk the knock back), a low
-- thump and a camera kick
local function knock(vel)
	local hrp, hum = root()
	if not hrp or not hum then
		return
	end
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	hum.PlatformStand = true
	task.delay(Config.ALTAR_RAGDOLL, function()
		if hum.Parent then
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
	Sfx.play("padSnap", { volume = 1.3 })
	Sfx.play("expand", { volume = 0.5 })
	kick(1)
	local att = hrp:FindFirstChild("RootAttachment")
	if not att then
		hrp.AssemblyLinearVelocity = vel
		return
	end
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.VectorVelocity = vel
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = hrp
	task.delay(Config.ALTAR_PUSH_TIME, function()
		lv:Destroy()
		-- the drive is the knock: keep only a little of its sideways speed, or a ragdolled body
		-- (no air control) sails ~75 studs over the plaza (Play check 2026-10-23)
		if hrp.Parent then
			local v = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.15, v.Y, v.Z * 0.15)
		end
	end)
end

-- The moon gates (D79, they replaced the Spirit Springs): stepping into one while the altar is open
-- (and I'm not out) teleports me onto the deck, with the HUD's jade wipe; the server checks I stand
-- in the doorway (Main, Teleport "altarGate"). Gate spots come from Config, not the parts (streaming).
local lastLaunch = 0
local function checkSprings()
	if not isOpen() or os.clock() - lastLaunch < 1.2 then
		return
	end
	local out = player:GetAttribute("AltarOut")
	local hrp = root()
	local top = altarTop()
	if not hrp or not top then
		return
	end
	local ground = top.Y - Config.ALTAR_HEIGHT
	for _, sx in { -1, 1 } do
		local gate = Vector3.new(top.X + sx * Config.ALTAR_SPRING_X, ground, top.Z - 2)
		local d = hrp.Position - gate
		if Vector2.new(d.X, d.Z).Magnitude < 2.6 and d.Y > -1 and d.Y < 7 then
			if out then
				-- a fallen player's gate stays shut: say why, once per 4 s (Play check 2026-10-23)
				lastLaunch = os.clock() + 2.8
				toast("Out this round, back in next round", PINK, nil, 2.5)
				return
			end
			lastLaunch = os.clock()
			local slots = player:FindFirstChild("HudSlots")
			local travel = slots and slots:FindFirstChild("Travel")
			if travel then
				travel:Fire("altarGate")
			else
				remotes.Teleport:FireServer("altarGate")
			end
			Sfx.play("rise", { volume = 1.3 })
			return
		end
	end
end

---------------------------------------------------------------------------------------------
-- per frame: the ring, the palm button, the gates
local lastLit = 0
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0
	if not ui.row then
		return
	end
	local open = isOpen()
	local untilT = workspace:GetAttribute("AltarUntil") or 0
	ui.row.Visible = open and dismissed ~= untilT
	if ui.row.Parent ~= rightStack() and rightStack() then
		placeRow()
	end
	ui.toast.Position = UDim2.new(0.5, 0, 0, counterBottom() + px(8))
	local out = player:GetAttribute("AltarOut")
	local onTop = amOnTop()
	ui.palm.Visible = open and not out and onTop
	if (player:GetAttribute("AltarPalm") == true) ~= ui.palm.Visible then
		player:SetAttribute("AltarPalm", ui.palm.Visible or nil) -- Hud: the Recruit seal steps aside
	end
	ui.alert.Visible = false
	-- the trail stops once you are up there, or when the round ends
	if player:GetAttribute("GuideTo") and (not open or onTop) then
		guideToAltar(false)
	end
	checkSprings()
	if not open then
		lastLit = 0
		return
	end
	local hold = workspace:GetAttribute("AltarHold") or 0
	local holder = workspace:GetAttribute("AltarHolder") or ""
	local crowd = workspace:GetAttribute("AltarCrowd") or 0
	for i, b in beads do
		b.BackgroundColor3 = i <= math.floor(hold / 2 + 1e-6) and BEAD_ON or BEAD_OFF
	end
	-- under the button: the seconds the holder still needs, or the window left while it is empty;
	-- the colour says who: gold = you, pink = contested or you fell, white = someone else, mint = empty
	local color
	if out or crowd >= 2 then
		color = PINK
	elseif holder ~= "" then
		color = holder == player.DisplayName and GOLD or Color3.new(1, 1, 1)
	else
		color = MINT
	end
	local secs = holder ~= "" and math.max(0, Config.ALTAR_HOLD - hold)
		or math.max(0, untilT - workspace:GetServerTimeNow())
	ui.secs.Text = math.ceil(secs) .. "s"
	ui.secs.TextColor3 = color
	-- the "!" (last ALERT_SECS, not out, not already at the hub)
	local me = root()
	local at = altarTop()
	ui.alert.Visible = secs <= ALERT_SECS
		and not out
		and me ~= nil
		and at ~= nil
		and Vector2.new(me.Position.X - at.X, me.Position.Z - at.Z).Magnitude > ALERT_NEAR
	-- a soft bell each time another brazier lights, if I'm near the hub
	local lit = math.floor(hold / Config.ALTAR_HOLD * Config.ALTAR_BRAZIERS + 1e-6)
	if lit > lastLit then
		local hrp = root()
		local top = altarTop()
		if hrp and top and (hrp.Position - top).Magnitude < 80 then
			Sfx.play("smallBell", { volume = 0.6 + lit * 0.08 })
		end
	end
	lastLit = lit
end)

-- the "!" bounces and rocks every frame (the 0.1 s tick above only shows or hides it)
RunService.RenderStepped:Connect(function()
	local a = ui.alert
	if not a or not a.Visible then
		return
	end
	local t = os.clock()
	local hop = math.abs(math.sin(t * 6)) * px(5)
	a.Position = UDim2.new(0.5, ui.alertX, 0, ui.alertY - hop)
	a.Rotation = math.sin(t * 12) * 12
end)

---------------------------------------------------------------------------------------------
-- a palm's shockwave: a pale ring that widens and fades where the strike landed
local function shockwave(pos)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = Color3.fromHex("FFF4DC")
	ring.Transparency = 0.35
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	TweenService:Create(
		ring,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.2, 10, 10), Transparency = 1 }
	):Play()
	task.delay(0.4, function()
		ring:Destroy()
	end)
end

remotes:WaitForChild("Notify").OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "altarSoon" then
		toast("The Heavenly Altar opens in " .. tostring(a) .. " s at the hub!", GOLD)
	elseif kind == "altarOpen" then
		Sfx.play("gong", { volume = 0.7 })
		toast("The Heavenly Altar is open! Hold it " .. Config.ALTAR_HOLD .. " s", GOLD)
	elseif kind == "altarKnock" then
		knock(a)
	elseif kind == "altarPalm" then
		local top = altarTop()
		local hrp = root()
		if hrp and top and (hrp.Position - top).Magnitude < 90 then
			shockwave(a)
			Sfx.play(b and b > 0 and "padSnap" or "gather", { volume = 0.8 })
			if c == player.UserId and b and b > 0 then
				kick(0.5) -- my palm landed
			end
		end
	elseif kind == "altarOut" then
		Sfx.play("deny")
		toast("You fell! Back in next round", PINK)
	elseif kind == "altarJoin" then
		toast("For joining the fight", MINT, a)
	elseif kind == "altarWon" then
		if c == player.UserId then
			Sfx.play("hallBell")
			Sfx.play("buyChime")
			toast("You claimed the Heavenly Altar!", GOLD, b, 5)
		else
			Sfx.play("smallBell")
			toast(tostring(a) .. " claimed the Heavenly Altar", GOLD)
		end
	elseif kind == "altarFade" then
		toast("The altar faded, nobody held it", Color3.new(1, 1, 1))
	end
end)

build()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	task.defer(build)
end)
playerGui.ChildAdded:Connect(function(c)
	if c.Name == "TouchGui" or c.Name == "Hud" then
		task.delay(1, build)
	end
end)
task.delay(2, build) -- TouchGui and the HUD counter settle a moment after spawn
