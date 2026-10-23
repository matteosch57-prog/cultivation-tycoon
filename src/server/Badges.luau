-- Roblox badges (D58, docs/design/BADGES.md): short goals between realms, shown on the player's
-- profile. Main calls Badges.check on every publish; each goal is read from the save, so a badge
-- created later is still awarded to everyone who already met it. A badge id of 0 (not created in
-- Creator Hub yet) is skipped. data.badges remembers what was awarded, so each is asked once per
-- save; a failed call (Roblox down) is retried at the next check.
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Badges = {}

local ELDER = Config.rarityIndex("Elder")

-- [key] = function(s): is the goal met?
local GOALS = {
	founder = function(s)
		return next(s.data.owned) ~= nil or (s.data.best or 1) > 1
	end,
	disciple = function(s)
		return #s.data.disciples > 0
	end,
	realm2 = function(s)
		return (s.data.best or 1) >= 2
	end,
	realm3 = function(s)
		return (s.data.best or 1) >= 3
	end,
	realm4 = function(s)
		return (s.data.best or 1) >= 4
	end,
	realm8 = function(s)
		return (s.data.best or 1) >= 8
	end,
	realm10 = function(s)
		return (s.data.best or 1) >= 10
	end,
	streak7 = function(s)
		return ((s.data.streak or {}).total or 0) >= 7
	end,
	elder = function(s)
		for _, name in s.data.disciples do
			if Config.rarityIndex(name) >= ELDER then
				return true
			end
		end
		return false
	end,
	friends = function(s)
		return (s.friendsPeak or 0) > 0
	end,
	reborn = function(s)
		return (s.data.lives or 1) > 1
	end,
}

local pending = {} -- [player] = { [key] = true } while an award call is in flight
local retryAt = {} -- [player] = { [key] = os.clock() before which a failed award is not asked again }
local RETRY = 60 -- s: Main checks on every publish (each second), and a wrong or disabled id fails every
-- time; without a pause one bad id spends the server's BadgeService budget (50 + 35 x players a minute)

function Badges.check(player, s)
	local d = s.data
	d.badges = d.badges or {}
	pending[player] = pending[player] or {}
	retryAt[player] = retryAt[player] or {}
	local now = os.clock()
	for key, met in GOALS do
		local id = Config.BADGES[key] or 0
		if id > 0 and not d.badges[key] and not pending[player][key] and now >= (retryAt[player][key] or 0) and met(s) then
			pending[player][key] = true
			task.spawn(function()
				local ok, awarded = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
				if ok and not awarded then
					-- false can also mean "already has it" (a save that lost its d.badges): not a failure
					local okHas, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, id)
					awarded = okHas and has
				end
				if ok and awarded then
					d.badges[key] = true
				else
					-- false = not awarded (the badge is disabled or not this experience's): asked again later
					warn("[Tycoon][badge] award failed") -- constant text (Error Report groups by string)
					print("[Tycoon][badge] award failed", key, id, ok and "returned false" or tostring(awarded))
					if retryAt[player] then
						retryAt[player][key] = os.clock() + RETRY
					end
				end
				if pending[player] then
					pending[player][key] = nil
				end
			end)
		end
	end
end

function Badges.leave(player)
	pending[player] = nil
	retryAt[player] = nil
end

return Badges
