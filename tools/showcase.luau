-- Edit-mode preview of the look pass: builds workspace.Showcase from the Style module.
-- Run through the Studio MCP execute_luau (Edit). Requires a CLONE so edits to Style are picked up.
local server = game.ServerScriptService.Server
local clone = server.Style:Clone()
clone.Parent = server
local Style = require(clone)
clone:Destroy()

local old = workspace:FindFirstChild("Showcase")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Showcase"
root.Parent = workspace

local C = CFrame.new(0, 30, -420)
Style.island(root, C, 48, 5)
task.wait()
Style.hall(root, C * CFrame.new(0, 0, -12), { W = 30, D = 18 })
task.wait()
-- stone path from the island edge to the stair
for z = 44, 12, -3.2 do
	Style.P(root, Vector3.new(7, 0.3, 2.8), C * CFrame.new(0, 0.15, z) * CFrame.Angles(0, math.rad((z * 7) % 5 - 2.5), 0), Style.PAL.stoneLight)
end
for _, z in { 18, 32 } do
	Style.lantern(root, C * CFrame.new(-7.5, 0, z), 1)
	Style.lantern(root, C * CFrame.new(7.5, 0, z), 1)
end
Style.sakura(root, C * CFrame.new(-25, 0, 14), 3)
Style.sakura(root, C * CFrame.new(27, 0, -24), 4)
Style.pine(root, C * CFrame.new(29, 0, 16), 6, 14)
Style.pine(root, C * CFrame.new(-33, 0, -18), 7, 16)
Style.pine(root, C * CFrame.new(-38, 0, 2), 8, 11)
task.wait()
-- a small satellite islet
local I2 = C * CFrame.new(78, -14, 30)
Style.island(root, I2, 14, 11)
Style.pine(root, I2 * CFrame.new(2, 0, -1), 12, 12)
-- cloud banks below
for i, p in { { -60, -55, 40, 40 }, { 40, -65, -40, 55 }, { 110, -50, 60, 35 }, { -20, -70, -110, 60 }, { -120, -60, -30, 45 }, { 70, -58, 110, 40 } } do
	Style.cloud(root, C * CFrame.new(p[1], p[2], p[3]), p[4], i)
end
local n = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return "parts=" .. n
