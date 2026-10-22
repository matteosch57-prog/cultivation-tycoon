-- AntiFling: player bodies pass through each other (security pass 2026-10-22). Each client owns its
-- own character's physics, so a cheat can spin its body at any speed and launch whoever it touches
-- off the peak ("fling", the commonest griefing exploit on the DevForum). Nothing in the game needs
-- bodies to push bodies: the altar's only shove is Palm Strike, which the server decides.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local GROUP = "Characters"
PhysicsService:RegisterCollisionGroup(GROUP)
PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)

local function tag(part)
	if part:IsA("BasePart") then
		part.CollisionGroup = GROUP
	end
end

local function onCharacter(char)
	for _, d in char:GetDescendants() do
		tag(d)
	end
	char.DescendantAdded:Connect(tag) -- accessories and tools arrive after the body
end

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end
