-- One colour language for every step-on pad (build, breakthrough, shop): the rune rings, their
-- light, the beacon beam and the price on the card all take their colour from here.
-- Ready = you can step on it now, in its kind's colour; locked = not enough qi yet, always red.
local PadLook = {}

PadLook.KIND = {
	build = Color3.fromHex("59D39F"), -- jade
	breakthrough = Color3.fromHex("FFC94A"), -- gold
	shop = Color3.fromHex("A97CF0"), -- amethyst
}
PadLook.LOCKED = Color3.fromHex("E0544B")

-- card text: bright, light tints of the same colours so they read on any sky
PadLook.TEXT = {
	title = Color3.new(1, 1, 1),
	line = Color3.fromHex("FFE9A8"),
	build = Color3.fromHex("9FF5C8"),
	breakthrough = Color3.fromHex("FFE08A"),
	shop = Color3.fromHex("DCC6FF"),
	locked = Color3.fromHex("FF8A80"),
	wait = Color3.fromHex("FF9A8F"), -- a red pad's "in 0:17"
}

function PadLook.color(kind, ready)
	if not ready then
		return PadLook.LOCKED
	end
	return PadLook.KIND[kind] or PadLook.KIND.build
end

function PadLook.textColor(kind, ready)
	if not ready then
		return PadLook.TEXT.locked
	end
	return PadLook.TEXT[kind] or PadLook.TEXT.build
end

return PadLook
