-- The Robux purchase moment (owner pick A "Spotlight", mock docs/art/mocks/2026-10-22_teleport_and_buy.html):
-- a dark veil, slow gold rays, the item pops in with Toy.reward (white blink, ring, motes, chime,
-- double buzz), its name in gold and one line under it, then it flies to where it lives: qi packs pour
-- qi drops into the counter, the pill into the HUD's pill chip, a pass into the counter. A tap skips to
-- the flight. Passes, qi packs and the pill only: a bought disciple plays the recruit reveal
-- (Shop.client fires RecruitFx). Timing: Config.BUY_MOMENT (the Hud bumps the counter on arrival).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local Toy = require(Shared:WaitForChild("Toy"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local px = Toy.px
local B = Config.BUY_MOMENT
local GOLD = Color3.fromHex("FFD34D")
local QI = Color3.fromHex("9FF5D0")

-- 1,234 / 12.5M (the HUD's own formatting)
local function short(n)
	n = math.floor(n or 0)
	if n < 1e6 then
		local out = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end
	local units = { "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td" }
	local v, i = n / 1e6, 1
	while v >= 1000 and i < #units do
		v /= 1000
		i += 1
	end
	local digits = v < 10 and 2 or (v < 100 and 1 or 0)
	local f = 10 ^ digits
	return string.format("%." .. digits .. "f%s", math.floor(v * f) / f, units[i])
end

local gui = Instance.new("ScreenGui")
gui.Name = "BuyMoment"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 25 -- over the Shop screen it was bought from
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function tw(obj, t, goal, style, dir)
	local x = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	x:Play()
	return x
end

-- shown on screen: every ancestor visible (a hidden HUD row keeps its children's Visible true)
local function shown(obj)
	local o = obj
	while o and o:IsA("GuiObject") do
		if not o.Visible then
			return false
		end
		o = o.Parent
	end
	return obj.AbsoluteSize.X > 0
end

-- where the item lands: the pill chip for the pill, else the qi counter (nil: it fades where it is)
local function target(key)
	local hud = playerGui:FindFirstChild("Hud")
	if not hud then
		return nil
	end
	local t = key == "pill" and hud:FindFirstChild("PillButton", true) or nil
	if not (t and shown(t)) then
		t = hud:FindFirstChild("Counter", true)
	end
	return t and shown(t) and t or nil
end

local busy = false
local function play(key, name, line, gain)
	while busy do -- two buys close together play one after the other
		task.wait(0.2)
	end
	busy = true
	gui:ClearAllChildren()
	local vp = workspace.CurrentCamera.ViewportSize
	local mid = Vector2.new(vp.X / 2, vp.Y * 0.44)
	local skip = false
	local veil = Instance.new("TextButton")
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Parent = gui
	veil.Activated:Connect(function()
		skip = true
	end)
	tw(veil, 0.25, { BackgroundTransparency = 0.3 }) -- dark enough to read over an open screen (the Shop)
	-- slow gold rays behind the item
	local rays = Toy.atlasPiece(gui, "rays12", px(420), px(420), GOLD, 1, { Position = UDim2.fromOffset(mid.X, mid.Y), ZIndex = 2 })
	tw(rays, 0.4, { ImageTransparency = 0.35 })
	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 24
	end)
	local glow = Toy.atlasPiece(gui, "glow", px(300), px(300), GOLD, 1, { Position = UDim2.fromOffset(mid.X, mid.Y), ZIndex = 2 })
	tw(glow, 0.4, { ImageTransparency = 0.4 })
	-- the item pops in (overshoot, then settles) and bursts
	local item = Toy.frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(mid.X, mid.Y), Size = UDim2.fromOffset(px(130), px(130)), ZIndex = 3 })
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = item
	Toy.icon(item, key, px(130), { ZIndex = 4 })
	tw(scale, B.pop, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(B.pop * 0.6, function()
		Toy.reward(item)
	end)
	-- its name in gold and one line under it (qi packs: the qi gained)
	local col = Toy.frame(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(mid.X, mid.Y + px(78)), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 3 })
	Toy.list(col, false, px(2))
	local labels = { Toy.text(col, name, px(38), GOLD, { LayoutOrder = 1, ZIndex = 4, TextTransparency = 1 }) }
	if gain then
		local row, l = Toy.amount(col, "qi", px(24), QI, { LayoutOrder = 2 })
		l.Text = "+" .. short(gain)
		l.ZIndex = 4
		row.Visible = false
		task.delay(B.pop, function()
			row.Visible = true
		end)
	elseif line then
		table.insert(labels, Toy.text(col, line, px(20), Color3.new(1, 1, 1), { LayoutOrder = 2, ZIndex = 4, TextTransparency = 1 }))
	end
	for _, l in labels do
		l.UIStroke.Transparency = 1
		tw(l, 0.3, { TextTransparency = 0 })
		tw(l.UIStroke, 0.3, { Transparency = 0 })
	end
	local t0 = os.clock()
	while os.clock() - t0 < B.pop + B.hold and not skip do
		task.wait()
	end
	-- out: the veil, rays and words fade, the item flies home
	tw(veil, 0.35, { BackgroundTransparency = 1 })
	tw(rays, 0.35, { ImageTransparency = 1 })
	tw(glow, 0.35, { ImageTransparency = 1 })
	col:Destroy()
	scale.Scale = 1
	local to = target(key)
	if to then
		-- Absolute* of both guis share one origin; this gui ignores the inset, so measure from it
		local tc = to.AbsolutePosition + to.AbsoluteSize / 2 - gui.AbsolutePosition
		if gain then
			-- qi packs: the chest breaks into drops that pour into the counter
			tw(scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			for i = 1, 12 do
				local a = math.random() * math.pi * 2
				local d = px(40 + math.random() * 70)
				local drop = Toy.qiIcon(gui, px(26), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(mid.X, mid.Y), ZIndex = 5 })
				tw(drop, 0.22, { Position = UDim2.fromOffset(mid.X + math.cos(a) * d, mid.Y + math.sin(a) * d * 0.6) })
				task.delay(0.22 + i * 0.035, function()
					tw(drop, B.fly - 0.22, { Position = UDim2.fromOffset(tc.X, tc.Y), Size = UDim2.fromOffset(px(14), px(14)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					task.delay(B.fly - 0.22, function()
						drop:Destroy()
						Sfx.play("orb")
					end)
				end)
			end
		else
			tw(item, B.fly, { Position = UDim2.fromOffset(tc.X, tc.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tw(scale, B.fly, { Scale = 0.3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(B.fly, function()
				item.Visible = false
				Sfx.play("orb")
				if to:IsA("GuiButton") then
					Toy.reward(to, { sound = "padReady" }) -- the pill chip answers
				end
			end)
		end
	else
		tw(scale, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end
	task.wait(B.fly + 0.5)
	spin:Disconnect()
	gui:ClearAllChildren()
	busy = false
end

remotes:WaitForChild("Notify").OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "shopPass" then -- a = name, b = key
		local it = Config.shopItem(b)
		task.spawn(play, b or "x2", a, it and it.line)
	elseif kind == "shopQi" then -- a = qi gained, b = name, c = key
		task.spawn(play, c or "pack1", b, nil, a)
	elseif kind == "shopPill" then
		local it = Config.shopItem("pill")
		task.spawn(play, "pill", it.name, it.line)
	end
end)

-- Studio test hook: local player attribute BuyMoment = a shop key plays its moment (no purchase)
player:GetAttributeChangedSignal("BuyMoment"):Connect(function()
	local key = player:GetAttribute("BuyMoment")
	local it = key and Config.shopItem(key)
	if it then
		task.spawn(play, key, it.name, not it.seconds and it.line or nil, it.seconds and 123456 or nil)
	end
end)
