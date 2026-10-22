-- Phone and gamepad buzz (Roblox HapticEffect, fully released Sept 2025: most iPhones, Pixels and
-- Galaxies, PlayStation and Xbox pads). One shared effect per kind, played on demand (Roblox asks for
-- under 100 live effects); a device without haptics simply feels nothing. Client only.
--   Haptic.play("click")   every button press (UIClick: crisp, short)
--   Haptic.play("reward")  claim, collect, gift (UINotification: a double tap)
--   Haptic.play("impact")  big world moments (GameplayCollision)
local Workspace = game:GetService("Workspace")

local Haptic = {}

local KINDS = {
	hover = Enum.HapticEffectType.UIHover,
	click = Enum.HapticEffectType.UIClick,
	reward = Enum.HapticEffectType.UINotification,
	impact = Enum.HapticEffectType.GameplayCollision,
}
local MIN_GAP = 0.04 -- two presses inside one frame or so buzz once

local effects, last = {}, {}

local function effect(kind)
	local e = effects[kind]
	if e == nil then
		local ok, made = pcall(function()
			local h = Instance.new("HapticEffect")
			h.Name = "Haptic_" .. kind
			h.Type = KINDS[kind]
			h.Parent = Workspace
			return h
		end)
		e = ok and made or false -- false: this client can't make one, never try again
		effects[kind] = e
	end
	return e
end

function Haptic.play(kind)
	if not KINDS[kind] then
		return
	end
	local now = os.clock()
	if now - (last[kind] or 0) < MIN_GAP then
		return
	end
	last[kind] = now
	local e = effect(kind)
	if e then
		pcall(e.Play, e)
	end
end

return Haptic
