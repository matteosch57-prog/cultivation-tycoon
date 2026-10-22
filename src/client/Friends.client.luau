-- Friends card (D35, mock A docs/art/mocks/friends_A.png and friends_C.png): top right, under the
-- HUD's Next goal. With friends here: their head shots and the bonus; alone (after the
-- intro): an ask to play with friends. Invite opens Roblox's own invite prompt. Group (only when
-- Config.GROUP_ID is set): a button that opens the group card: like the game, join the group, claim.
-- The server checks and pays only the group (R9); nothing here grants anything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toy = require(Shared:WaitForChild("Toy"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local px, text, frame = Toy.px, Toy.text, Toy.frame
local JADE = Color3.fromHex("9FF5C8")
local GREEN = Color3.fromHex("59D39F")
local PURPLE = Color3.fromHex("C59BFF")
local GOLD = Color3.fromHex("FFD34D")
local PINK = Color3.fromHex("FF9FB0")
local SKIN = Color3.fromHex("F2C9A0")

local heads = {} -- [userId] = head shot image

local gui = Instance.new("ScreenGui")
gui.Name = "Friends"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 1
gui.Parent = playerGui

local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice") -- "phone" / "pc" forces a layout (testing)
	local touch = if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
	if touch then
		return math.clamp(vp.Y / 390, 0.78, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

-- person with a plus (Invite)
local function personIcon(parent, size)
	local ic = Toy.Icon.new(parent, size, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5) })
	ic:rect(24, 48, 34, 22, Color3.new(1, 1, 1), 10)
	ic:circle(24, 24, 11, Color3.new(1, 1, 1))
	ic:rect(50, 26, 6, 22, Color3.new(1, 1, 1), 2)
	ic:rect(50, 26, 22, 6, Color3.new(1, 1, 1), 2)
	return ic
end

-- the sect banner (Group)
local function bannerIcon(parent, size, props)
	local ic = Toy.Icon.new(parent, size, props)
	ic:rect(16, 34, 6, 54, Color3.fromHex("8A5A3C"), 2)
	ic:rect(36, 22, 34, 26, Color3.fromHex("B06BFF"), 3)
	ic:circle(36, 22, 6, GOLD)
	return ic
end

-- a gold gift box with a red ribbon (the group gift button)
local function giftIcon(parent, size, props)
	local ic = Toy.Icon.new(parent, size, props)
	ic:rect(32, 42, 42, 28, GOLD, 4)
	ic:rect(32, 25, 50, 12, Color3.fromHex("FFE58A"), 3)
	ic:rect(32, 37, 8, 38, Color3.fromHex("E65B4F"), nil, 0, false)
	ic:rect(24, 14, 14, 10, Color3.fromHex("E65B4F"), 4, 30)
	ic:rect(40, 14, 14, 10, Color3.fromHex("E65B4F"), 4, -30)
	ic:detail(18, 34, 3, Color3.new(1, 1, 1), 0.2)
	return ic
end

-- thumbs up (Like)
local function thumbIcon(parent, size, props)
	local ic = Toy.Icon.new(parent, size, props)
	ic:rect(14, 40, 12, 28, GREEN, 3)
	ic:rect(38, 42, 30, 26, GREEN, 6)
	ic:rect(36, 20, 12, 22, GREEN, 5, -15)
	return ic
end

local function head(parent, userId, order)
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromOffset(px(34), px(34))
	img.BackgroundColor3 = SKIN
	img.LayoutOrder = order
	img.Image = heads[userId] or ""
	Toy.corner(img, UDim.new(0.5, 0))
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = px(2.5)
	st.Parent = img
	img.Parent = parent
	if not heads[userId] then
		task.spawn(function()
			local ok, url = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			if ok and url then
				heads[userId] = url
				if img.Parent then
					img.Image = url
				end
			end
		end)
	end
	return img
end

local function invite()
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if not (ok and can) then
		Sfx.play("deny")
		return
	end
	remotes.SocialInvite:FireServer()
	pcall(SocialService.PromptGameInvite, SocialService, player)
end

---------------------------------------------------------------------------------------------
-- the group card: three steps over a dark veil; only Claim talks to the server
local card
local function closeCard()
	if card then
		card:Destroy()
		card = nil
	end
end

local function openCard()
	closeCard()
	local veil = Instance.new("TextButton")
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 0.32
	veil.ZIndex = 10
	veil.Parent = gui
	veil.Activated:Connect(closeCard)
	card = veil

	local col = frame(veil, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY })
	Toy.list(col, false, px(14))
	text(col, "Sect Gift", px(34), GOLD, { LayoutOrder = 1 })
	local steps = {
		{ thumbIcon, "Like the game" },
		{ bannerIcon, "Join our group" },
	}
	for i, st in steps do
		local row = frame(col, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 + i })
		Toy.list(row, true, px(10))
		text(row, tostring(i), px(28), JADE, { LayoutOrder = 1 })
		st[1](row, px(40), { LayoutOrder = 2 })
		text(row, st[2], px(24), Color3.new(1, 1, 1), { LayoutOrder = 3 })
	end
	local hint = text(col, "Find the group on the game page", px(15), Color3.fromHex("CBBFD6"), { LayoutOrder = 4 })
	local claimHolder, claimBtn = Toy.button(col, UDim2.fromOffset(px(210), px(54)), GOLD, px(14))
	claimHolder.LayoutOrder = 5
	local cl = frame(claimBtn, { Size = UDim2.fromScale(1, 1) })
	Toy.list(cl, true, px(6))
	text(cl, "3", px(24), Color3.new(1, 1, 1), { LayoutOrder = 1 })
	text(cl, "Claim", px(24), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	text(cl, string.format("+%d%%", math.round(Config.GROUP_BONUS * 100)), px(20), JADE, { LayoutOrder = 3 })
	Toy.qiIcon(cl, px(22), { LayoutOrder = 4 })
	local busy = false
	claimBtn.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local ok, res = pcall(function()
			return remotes.ClaimGroup:InvokeServer()
		end)
		busy = false
		if ok and res == "claimed" then
			Sfx.play("smallBell")
			closeCard()
		elseif ok and res == "notMember" then
			Sfx.play("deny")
			hint.Text = "Join the group, then come back"
			hint.TextColor3 = PINK
		else
			Sfx.play("deny")
		end
	end)
	local xHolder, xBtn = Toy.button(veil, UDim2.fromOffset(px(44), px(44)), Color3.fromHex("FF7A6B"), px(12))
	xHolder.AnchorPoint = Vector2.new(1, 0)
	xHolder.Position = UDim2.new(1, -px(16), 0, GuiService.TopbarInset.Max.Y + px(8))
	xHolder.ZIndex = 11
	text(xBtn, "X", px(24), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	xBtn.Activated:Connect(closeCard)
end

---------------------------------------------------------------------------------------------
-- the right card, redrawn only when what it shows changes
local root
local groupHolder -- the Group button, beside the HUD's qi total (owner)
local shown -- the key of what is drawn

local function draw()
	local ids = {}
	for id in string.gmatch(player:GetAttribute("FriendIds") or "", "%d+") do
		table.insert(ids, tonumber(id))
	end
	local alone = #ids == 0
	-- alone: shown once the intro is done (owner: the social card should be there from the start)
	local showAlone = alone and (player:GetAttribute("WelcomeQi") or 0) == 0
	local showGroup = Config.GROUP_ID > 0 and player:GetAttribute("GroupBonus") ~= true and (not alone or showAlone)
	local key = table.concat(ids, ",") .. "|" .. tostring(showAlone) .. "|" .. tostring(showGroup) .. "|" .. Toy.S
	if key == shown then
		return
	end
	shown = key
	if root then
		root:Destroy()
		root = nil
	end
	if groupHolder then
		groupHolder:Destroy()
		groupHolder = nil
	end
	if alone and not showAlone then
		return
	end
	root = frame(gui, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -px(14), 0, GuiService.TopbarInset.Max.Y + px(58)),
		AutomaticSize = Enum.AutomaticSize.XY,
	})
	Toy.list(root, false, px(6), { HorizontalAlignment = Enum.HorizontalAlignment.Right })
	local pct = math.round(#ids * Config.FRIEND_STEP * 100)
	if alone then
		text(root, "Play with friends", px(15), Color3.new(1, 1, 1), { LayoutOrder = 1 })
		text(root, string.format("+%d%% Qi each", math.round(Config.FRIEND_STEP * 100)), px(19), JADE, { LayoutOrder = 2 })
	else
		local row = frame(root, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
		Toy.list(row, true, px(6))
		text(row, string.format("+%d%% Qi", pct), px(19), JADE, { LayoutOrder = 1 })
		local hs = frame(row, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
		Toy.list(hs, true, -px(8))
		for i, id in ids do
			local h = head(hs, id, i)
			h.ZIndex = 10 - i
		end
		text(root, #ids == 1 and "1 friend here" or string.format("%d friends here", #ids), px(14), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	end
	local iHolder, iBtn = Toy.button(root, UDim2.fromOffset(px(104), px(36)), GREEN, px(11))
	iHolder.LayoutOrder = 3
	local il = frame(iBtn, { Size = UDim2.fromScale(1, 1) })
	Toy.list(il, true, px(4))
	local ic = personIcon(il, px(24))
	ic.box.LayoutOrder = 1
	text(il, "Invite", px(17), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	iBtn.Activated:Connect(invite)
	if showGroup then
		local gHolder, gBtn = Toy.button(gui, UDim2.fromOffset(px(116), px(40)), PURPLE, px(12))
		gHolder.AnchorPoint = Vector2.new(0, 0.5)
		gHolder.Visible = false -- until place() finds the counter
		groupHolder = gHolder
		-- owner: "just show +10% Qi with an attractive icon, when they click they'll know"
		local gl = frame(gBtn, { Size = UDim2.fromScale(1, 1) })
		Toy.list(gl, true, px(3))
		giftIcon(gl, px(28), { LayoutOrder = 1 })
		text(gl, string.format("+%d%%", math.round(Config.GROUP_BONUS * 100)), px(19), Color3.new(1, 1, 1), { LayoutOrder = 2 })
		Toy.qiIcon(gl, px(22), { LayoutOrder = 3 })
		gBtn.Activated:Connect(openCard)
		-- a slow wobble (one looping tween, on screen only while the button exists)
		gHolder.Rotation = -3
		TweenService:Create(gHolder, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 3 }):Play()
	end
end

-- keep the Group button just right of the HUD's qi counter (its width grows with the number; the
-- HUD rebuilds it on a rescale, so it is looked up again each time)
local function place()
	if not groupHolder then
		return
	end
	local hud = playerGui:FindFirstChild("Hud")
	local counter = hud and hud:FindFirstChild("Counter", true)
	if not (counter and counter.Visible and counter.AbsoluteSize.X > 0) then
		groupHolder.Visible = false
		return
	end
	local inset = gui.AbsolutePosition
	local pos = UDim2.fromOffset(counter.AbsolutePosition.X - inset.X + counter.AbsoluteSize.X + px(14), counter.AbsolutePosition.Y - inset.Y + counter.AbsoluteSize.Y / 2)
	if groupHolder.Position ~= pos then
		groupHolder.Position = pos
	end
	groupHolder.Visible = true
end

local function rescale()
	Toy.S = computeScale()
	shown = nil
	draw()
end

for _, attr in { "FriendIds", "GroupBonus", "WelcomeQi" } do
	player:GetAttributeChangedSignal(attr):Connect(draw)
end
player:GetAttributeChangedSignal("HudDevice"):Connect(rescale)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()
task.spawn(function()
	while true do
		place() -- writes only on a change (R16)
		task.wait(0.25)
	end
end)
-- Studio test hook: player attribute FriendsCard = true opens the group card (no mouse input in tests)
if game:GetService("RunService"):IsStudio() then
	player:GetAttributeChangedSignal("FriendsCard"):Connect(function()
		if player:GetAttribute("FriendsCard") then
			openCard()
		else
			closeCard()
		end
	end)
end
