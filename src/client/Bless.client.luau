-- Incense Blessing (Bless.luau): a shrine's prompt shows only where this player can bless today:
-- never on their own peak or an empty one, never on a sect they already blessed (BlessedTo).
local Players = game:GetService("Players")
local CHECK = 0.5 -- seconds between checks (prompts change rarely)

local player = Players.LocalPlayer

local function update()
	local blessed = {}
	for id in string.gmatch(player:GetAttribute("BlessedTo") or "", "[^,]+") do
		blessed[id] = true
	end
	for _, peak in (workspace:FindFirstChild("Sect") or workspace):GetChildren() do
		local shrine = peak:FindFirstChild("Shrine")
		local prompt = shrine and shrine:FindFirstChild("ProximityPrompt", true)
		if prompt then
			local owner = shrine:GetAttribute("OwnerId") or 0
			prompt.Enabled = owner ~= 0 and owner ~= player.UserId and not blessed[tostring(owner)]
		end
	end
end

while true do
	update()
	task.wait(CHECK)
end
