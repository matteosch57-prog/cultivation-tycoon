-- Guard: a per-player, per-remote leaky bucket in front of every client call (security pass
-- 2026-10-22). An exploiter can fire any remote thousands of times a second; engine throttling only
-- delays the flood (research: create.roblox.com security-tactics + defensive-design, DevForum
-- "how to secure your RemoteEvent"). A call over its budget is dropped silently and counted; the
-- first drop per player and remote is logged so the Error Report shows who floods what.
local Players = game:GetService("Players")

local Guard = {}

-- [remote] = { per second, burst }. Every legitimate client calls these a few times a minute at most
-- (a button, a reveal animation between rolls), so the budgets sit well above real play.
local LIMITS = {
	Recruit = { 3, 6 },
	ChestSummon = { 3, 6 },
	DaoBuy = { 4, 8 },
	HandsBuild = { 2, 4 },
	UsePill = { 1, 3 },
	ClaimGift = { 1, 3 },
	ClaimGroup = { 1, 3 },
	ClaimWelcome = { 1, 3 },
	SocialInvite = { 1, 3 },
	Reincarnate = { 1, 2 },
	ShopBuy = { 2, 4 },
	ShopOpened = { 2, 4 },
	AltarPush = { 2, 4 },
}

local buckets = {} -- [player] = { [remote] = { tokens, at } }
local dropped = {} -- [player] = { [remote] = count }

function Guard.allow(player, remote)
	local limit = LIMITS[remote]
	if not limit then
		return true
	end
	local mine = buckets[player]
	if not mine then
		mine = {}
		buckets[player] = mine
	end
	local now = os.clock()
	local b = mine[remote]
	if not b then
		b = { limit[2], now }
		mine[remote] = b
	end
	b[1] = math.min(limit[2], b[1] + (now - b[2]) * limit[1])
	b[2] = now
	if b[1] >= 1 then
		b[1] -= 1
		return true
	end
	local d = dropped[player] or {}
	dropped[player] = d
	d[remote] = (d[remote] or 0) + 1
	if d[remote] == 1 then
		warn("[Tycoon][guard] remote flood dropped") -- constant text: the Error Report groups by string
		print(string.format("[Tycoon][guard] user=%d remote=%s", player.UserId, remote))
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	local d = dropped[player]
	if d then
		for remote, n in d do
			print(string.format("[Tycoon][guard] user=%d remote=%s dropped=%d", player.UserId, remote, n))
		end
	end
	buckets[player] = nil
	dropped[player] = nil
end)

return Guard
