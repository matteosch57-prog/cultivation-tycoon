-- Studio mock (2026-10-22): the player aura of src/server/PlayerAura.luau on clones of your avatar,
-- for screenshots only. Run in Play, in the Server datamodel, with the sources of PlayerAura and
-- AuraGlyph in two temporary ModuleScripts side by side in one folder (`mod` = the PlayerAura one):
-- local run = <this file>; run(mod, "realms") or run(mod, "beads"). The glyphs only turn with
-- AuraSpin.client running; the stills do not need it.
-- Builds workspace._AuraMock: one row of 10 figures on a stone floor high in the sky away from every
-- pad, 9 studs apart along +X, facing +Z, a label under each; the player's own avatar is never moved.
--   realms: realms 1 to 10 in the first life
--   beads:  realm 1 (no realm aura) with 1, 7, 20, 21, 33, 40, 50, 70, 90, 100 rebirths
-- Remove: workspace._AuraMock:Destroy().
return function(mod, which)
	local PlayerAura = require(mod)
	local plr = game:GetService("Players"):GetPlayers()[1]
	local src = plr and plr.Character
	assert(src, "needs a player with a character")

	local old = workspace:FindFirstChild("_AuraMock")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "_AuraMock"
	root.Parent = workspace

	local ORIGIN = CFrame.new(0, 900, 0)
	local GAP = 9
	local cells = {}
	if which == "beads" then
		for _, n in { 1, 7, 20, 21, 33, 40, 50, 70, 90, 100 } do
			table.insert(cells, { realm = 1, rebirths = n, text = n .. " rebirths" })
		end
	else
		for r = 1, 10 do
			table.insert(cells, { realm = r, rebirths = 0, text = "Realm " .. r })
		end
	end

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(GAP * 11, 1, 30)
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromHex("3A3F47")
	floor.CFrame = ORIGIN * CFrame.new(GAP * 4.5, -0.5, 0)
	floor.Parent = root

	src.Archivable = true
	for c, cell in cells do
		local fig = src:Clone()
		for _, d in fig:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") or d.Name == "StatusTitle" or d.Name == "PlayerAura" or d.Name == "AltarCrown" then
				d:Destroy()
			end
		end
		local hum = fig:FindFirstChildOfClass("Humanoid")
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local hrp = fig.HumanoidRootPart
		fig.Parent = root
		fig:PivotTo(ORIGIN * CFrame.new((c - 1) * GAP, hrp.Size.Y / 2 + hum.HipHeight, 0) * CFrame.Angles(0, math.pi, 0))
		hrp.Anchored = true
		PlayerAura.build(fig, cell.realm, cell.rebirths)
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.fromOffset(160, 24)
		g.StudsOffsetWorldSpace = Vector3.new(0, -4, 0)
		g.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextSize = 18
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.3
		t.Text = cell.text
		t.Parent = g
		g.Parent = hrp
	end
	src.Archivable = false
	return root
end
