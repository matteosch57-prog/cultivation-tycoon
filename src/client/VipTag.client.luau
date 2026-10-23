-- Gold [VIP] before a VIP Sect owner's name in chat (owner pick 2026-10-23, like Pet Simulator 99,
-- Bee Swarm and Blox Fruits). Read from the Pass_vip attribute the server sets on every owner
-- (Shop.luau), so the server sends nothing new. The overhead VIP icon is in StatusTitle.client.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local GOLD = "#FFCD32" -- the arch's VIP gold (Main.server buildGrounds)

TextChatService.OnIncomingMessage = function(message)
	local src = message.TextSource
	local plr = src and Players:GetPlayerByUserId(src.UserId)
	if not (plr and plr:GetAttribute("Pass_vip")) then
		return nil
	end
	local props = Instance.new("TextChatMessageProperties")
	props.PrefixText = string.format('<font color="%s"><b>[VIP]</b></font> %s', GOLD, message.PrefixText)
	return props
end
