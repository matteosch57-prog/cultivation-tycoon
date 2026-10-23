-- Friends card (D35, mock A docs/art/mocks/friends_A.png and friends_C.png): top right, under the
-- HUD's Next goal. With friends here: their head shots and the bonus; alone (after the
-- intro): an ask to play with friends. Invite opens Roblox's own invite prompt. Group (only when
-- Config.GROUP_ID is set): a button that opens the group card: like the game and join the group (both
-- on the game page, no in-game link: owner 2026-10-22), claim.
-- The server checks and pays only the group (R9); nothing here grants anything.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")

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

-- icons from the shared icon sheet (Toy.icon)
local function bannerIcon(parent, size, props) -- the sect banner (Group)
	return Toy.icon(parent, "group", size, props)
end
local function thumbIcon(parent, size, props) -- thumbs up (Like)
	return Toy.icon(parent, "like", size, props)
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
	remotes.MenuOpened:FireServer("group") -- analytics Menu (DATA.md)
	local veil = Instance.new("TextButton")
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 0.32
	veil.ZIndex = 10
	veil.Name = "Card" -- the HUD hides while it is up (Hud MODAL_PART)
	veil.Parent = gui
	veil.Activated:Connect(closeCard)
	card = veil

	local col = frame(veil, { Active = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY })
	Toy.list(col, false, px(14))
	text(col, "Sect Gift", px(34), GOLD, { LayoutOrder = 1 })
	local row = frame(col, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	Toy.list(row, true, px(10))
	text(row, "1", px(28), JADE, { LayoutOrder = 1 })
	thumbIcon(row, px(40), { LayoutOrder = 2 })
	text(row, "Like the game", px(24), Color3.new(1, 1, 1), { LayoutOrder = 3 })
	-- step 2 is a line like step 1: both happen on the game page, where the community link is (owner
	-- 2026-10-22: "dont put a link of the group, just say to go on game page themselves, so they pass
	-- for the like too")
	local jrow = frame(col, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	Toy.list(jrow, true, px(10))
	text(jrow, "2", px(28), JADE, { LayoutOrder = 1 })
	bannerIcon(jrow, px(40), { LayoutOrder = 2 })
	text(jrow, "Join the group", px(24), Color3.new(1, 1, 1), { LayoutOrder = 3 })
	local hint = text(col, "Both on the game page", px(17), Color3.fromHex("CBBFD6"), { LayoutOrder = 4 })
	local claimHolder, claimBtn = Toy.button(col, UDim2.fromOffset(px(210), px(54)), GOLD, px(14))
	claimHolder.LayoutOrder = 5
	Toy.dot(claimBtn, px(18)) -- where the Friends button's dot leads
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
			Toy.reward(claimBtn, { sound = "smallBell" })
			task.wait(0.45)
			closeCard()
		elseif ok and res == "notMember" then
			Sfx.play("deny")
			hint.Text = "Join on the game page, then Claim"
			hint.TextColor3 = PINK
		else
			Sfx.play("deny")
		end
	end)
	local iHolder, iBtn = Toy.button(col, UDim2.fromOffset(px(210), px(44)), GREEN, px(12))
	iHolder.LayoutOrder = 6
	local il = frame(iBtn, { Size = UDim2.fromScale(1, 1) })
	Toy.list(il, true, px(6))
	Toy.icon(il, "invite", px(28), { LayoutOrder = 1 })
	text(il, "Invite", px(20), Color3.new(1, 1, 1), { LayoutOrder = 2 })
	text(il, string.format("+%d%%", math.round(Config.FRIEND_STEP * 100)), px(18), Color3.new(1, 1, 1), { LayoutOrder = 3 })
	Toy.qiIcon(il, px(20), { LayoutOrder = 4 })
	iBtn.Activated:Connect(invite)
	local xHolder, xBtn = Toy.button(veil, UDim2.fromOffset(px(44), px(44)), Color3.fromHex("FF7A6B"), px(12))
	xHolder.AnchorPoint = Vector2.new(1, 0)
	xHolder.Position = UDim2.new(1, -px(16), 0, GuiService.TopbarInset.Max.Y + px(8))
	xHolder.ZIndex = 11
	text(xBtn, "X", px(24), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	xBtn.Activated:Connect(closeCard)
end

---------------------------------------------------------------------------------------------
-- ONE Friends button on the HUD's left rail (owner pick A, phone calm pass, mock
-- docs/art/mocks/hud_phone_A.jpg): it replaces the "Play with friends" card and the "+10%" group chip.
-- Caption = the friends bonus (live, or what one friend would add); a red dot while the Sect Gift
-- (group) is unclaimed. Tap: the Sect Gift card (with Invite in it) while that gift is open, else Invite.
local root -- the button's column, a row of the left rail (Player.HudSlots.Left)
local shown -- the key of what is drawn

local FACE = Color3.fromHex("3A2C44") -- the HUD's button face

local function groupOpen()
	return Config.GROUP_ID > 0 and player:GetAttribute("GroupBonus") ~= true
end

-- the server lights the Sect Gift's red dot at most once a day while it is unclaimed (Dots.luau);
-- opening the card (MenuOpened "group") follows it
local function groupDot()
	local ok, t = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Dots") or "{}")
	return ok and type(t) == "table" and t.group == true
end

local function draw()
	local ids = {}
	for id in string.gmatch(player:GetAttribute("FriendIds") or "", "%d+") do
		table.insert(ids, tonumber(id))
	end
	local alone = #ids == 0
	-- alone: shown once the intro is done (owner: the social card should be there from the start)
	local show = not alone or (player:GetAttribute("WelcomeQi") or 0) == 0
	local key = #ids .. "|" .. tostring(show) .. "|" .. tostring(groupDot()) .. "|" .. Toy.S
	if key == shown then
		return
	end
	shown = key
	if root then
		root:Destroy()
		root = nil
	end
	if not show then
		return
	end
	root = frame(gui, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 })
	root.Name = "FriendsRow"
	Toy.list(root, false, px(1))
	local holder, btn = Toy.button(root, UDim2.fromOffset(px(42), px(42)), FACE, px(11))
	holder.LayoutOrder = 1
	btn.Name = "FriendsButton"
	Toy.icon(btn, "invite", px(31), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	if groupDot() then
		Toy.dot(btn, px(16))
	end
	local pct = math.round(math.max(1, #ids) * Config.FRIEND_STEP * 100)
	text(root, "+" .. pct .. "%", px(12), alone and Color3.fromHex("CBBFD6") or JADE, { LayoutOrder = 2 })
	btn.Activated:Connect(function()
		if groupOpen() then
			openCard()
		else
			invite()
		end
	end)
end

-- the button is a row of the HUD's left rail (Player.HudSlots, D54); its own corner only if the
-- HUD is missing
local function leftRail()
	local slots = player:FindFirstChild("HudSlots")
	local left = slots and slots:FindFirstChild("Left")
	return left and left.Value
end
local function placeCard()
	if not root then
		return
	end
	local rail = leftRail()
	if rail then
		if root.Parent ~= rail then
			root.AnchorPoint = Vector2.new(0, 0)
			root.Position = UDim2.new()
			root.Parent = rail
		end
	elseif root.Parent ~= gui then
		root.AnchorPoint = Vector2.new(0, 0)
		root.Position = UDim2.fromOffset(px(12), GuiService.TopbarInset.Max.Y + px(200))
		root.Parent = gui
	end
end
task.spawn(function()
	local slots = player:WaitForChild("HudSlots", 30)
	if slots then
		slots:WaitForChild("Rebuilt").Event:Connect(function()
			task.defer(placeCard)
		end)
	end
end)

local function rescale()
	Toy.S = computeScale()
	shown = nil
	draw()
end

for _, attr in { "FriendIds", "GroupBonus", "WelcomeQi", "Dots" } do
	player:GetAttributeChangedSignal(attr):Connect(draw)
end
player:GetAttributeChangedSignal("HudDevice"):Connect(rescale)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()
task.spawn(function()
	while true do
		placeCard() -- writes only on a change (R16)
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
