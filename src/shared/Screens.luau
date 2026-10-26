-- One card at a time (thread "Keep new players past 10 minutes", 2026-10-26): a fresh save saw the
-- Daily Blessing, then "Free summons!" 1.6 s later, then the breakthrough screen over the chest card.
-- A card that opens on its own waits here until no other full screen is up. A screen counts while its
-- gui is Enabled and draws something (Gifts and Intro stay Enabled, emptied); the Friends gui always
-- holds its HUD row, so only its card counts.
local Screens = {}

Screens.COVERS = { "Shop", "WelcomeOffer", "StarterOffer", "Gifts", "Intro", "Breakthrough", "Reincarnation", "Disciples", "Index", "RecruitOdds", "IdleChest", "MissionsPage", "Streak", "RecruitReveal" }

-- true while a screen other than `except` (a gui name) is up
function Screens.covered(playerGui, except)
	for _, name in Screens.COVERS do
		if name ~= except then
			local g = playerGui:FindFirstChild(name)
			if g and g:IsA("ScreenGui") and g.Enabled and #g:GetChildren() > 0 then
				return true
			end
		end
	end
	local friends = playerGui:FindFirstChild("Friends")
	return friends ~= nil and friends:FindFirstChild("Card") ~= nil
end

-- yields until no other screen is up, then GAP s more so two cards never land back to back
function Screens.waitClear(playerGui, except, gap)
	repeat
		while Screens.covered(playerGui, except) do
			task.wait(0.5)
		end
		task.wait(gap or 1.5)
	until not Screens.covered(playerGui, except)
end

return Screens
