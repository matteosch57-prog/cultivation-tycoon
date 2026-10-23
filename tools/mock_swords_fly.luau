-- Studio mock (2026-10-23, owner: "Show as gif moving around ?"): flies the three sword tiers of
-- tools/mock_swords_tiers.luau round a banked loop in formation, one frame per call, for a GIF.
-- Run mock_swords_tiers first (Play, server side), then for k = 0, FRAMES - 1:
--   local cam = fly(k / FRAMES)   -- poses workspace._SwordMock, returns the chase camera CFrame
--   (client) workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
--   (client) workspace.CurrentCamera.CFrame = cam; wait ~0.2 s; capture
-- The loop: radius R round CENTRE, nose forward along the circle, banked into the turn, bobbing
-- twice a lap. Every part keeps its offset from the mock's ORIGIN, so beams, ribbons, halos and
-- locked particles ride along; the unlocked sparks stay behind in the world like a real wake.
local ORIGIN = CFrame.new(400, 900, 0) -- must match mock_swords_tiers
local R = 40
local CENTRE = ORIGIN.Position - Vector3.new(R, 0, 0) -- phase 0 puts the formation back on ORIGIN
local BANK = math.rad(12)

local rel = nil -- part -> offset from ORIGIN, taken on the first call

local function pose(phase)
	local a = phase * math.pi * 2
	return CFrame.new(CENTRE) * CFrame.Angles(0, a, 0) * CFrame.new(R, math.sin(a * 2) * 1.5, 0) * CFrame.Angles(math.sin(a * 2) * 0.05, 0, BANK)
end

return function(phase)
	local root = workspace:FindFirstChild("_SwordMock")
	assert(root, "[SwordFly] run mock_swords_tiers first")
	if not rel then
		rel = {}
		for _, p in root:GetDescendants() do
			if p:IsA("BasePart") then
				rel[p] = ORIGIN:ToObjectSpace(p.CFrame)
			end
		end
	end
	local at = pose(phase)
	for p, off in rel do
		if p.Parent then
			p.CFrame = at * off
		end
	end
	-- chase camera: behind and above the middle tier, a little outside the turn, looking ahead of it
	local eye = at * CFrame.new(10, 6, 24)
	return CFrame.lookAt(eye.Position, (at * CFrame.new(0, 1, -6)).Position)
end
