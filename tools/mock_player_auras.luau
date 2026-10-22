-- Studio mock (2026-10-22): the player aura styles of src/server/PlayerAura.luau, side by side on
-- clones of your avatar, for screenshots only. Run in Play, in the Server datamodel, with
-- PlayerAura's source in a temporary ModuleScript (`mod`): local run = <this file>; run(mod).
-- Builds workspace._AuraMock: one row per style on a stone floor high in the sky away from every
-- pad, a label under each figure; the player's own avatar is never moved. Remove: _AuraMock:Destroy().
return function(mod)
	local PlayerAura = require(mod)
	local Players = game:GetService("Players")
	local plr = Players:GetPlayers()[1]
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
	local GAP_X, GAP_Z = 7, 16
	local ROWS = {
		{ style = "A", title = "A  Realm aura", cells = { { 1, 1 }, { 2, 1 }, { 3, 1 }, { 4, 1 }, { 5, 1 }, { 6, 1 }, { 7, 1 }, { 8, 1 }, { 9, 1 }, { 10, 1 } } },
		{ style = "B", title = "B  Realm aura + life beads", cells = { { 1, 1 }, { 4, 1 }, { 1, 2 }, { 4, 2 }, { 4, 3 }, { 6, 4 }, { 8, 5 }, { 10, 6 }, { 10, 8 }, { 10, 10 } } },
		{ style = "C", title = "C  Life aura", cells = { { 4, 1 }, { 1, 2 }, { 1, 3 }, { 1, 4 }, { 1, 5 }, { 1, 6 }, { 1, 7 }, { 1, 8 }, { 1, 9 }, { 1, 10 } } },
	}

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(GAP_X * 11, 1, GAP_Z * #ROWS + 8)
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromHex("3A3F47")
	floor.CFrame = ORIGIN * CFrame.new(GAP_X * 4.5, -0.5, GAP_Z * (#ROWS - 1) / 2)
	floor.Parent = root

	local function label(parent, text, size)
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.fromOffset(220, size + 6)
		g.StudsOffsetWorldSpace = Vector3.new(0, -4.2, 0)
		g.AlwaysOnTop = true
		g.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextSize = size
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.3
		t.Text = text
		t.Parent = g
		g.Parent = parent
	end

	src.Archivable = true
	for r, row in ROWS do
		for c, cell in row.cells do
			local realm, lives = cell[1], cell[2]
			local fig = src:Clone()
			for _, d in fig:GetDescendants() do
				if d:IsA("Script") or d:IsA("LocalScript") or d.Name == "StatusTitle" or d.Name == "PlayerAura" or d.Name == "AltarCrown" then
					d:Destroy()
				end
			end
			local hum = fig:FindFirstChildOfClass("Humanoid")
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			local hrp = fig.HumanoidRootPart
			local up = hrp.Size.Y / 2 + hum.HipHeight
			fig.Parent = root
			fig:PivotTo(ORIGIN * CFrame.new((c - 1) * GAP_X, up, (r - 1) * GAP_Z) * CFrame.Angles(0, math.pi, 0)) -- facing +Z, toward the camera side
			hrp.Anchored = true
			local tier, color, beads = PlayerAura.look(row.style, realm, lives)
			PlayerAura.build(fig, tier, color, beads)
			label(hrp, "Realm " .. realm .. (lives > 1 and ("  Life " .. lives) or ""), 16)
		end
		local tag = Instance.new("Part")
		tag.Anchored = true
		tag.Transparency = 1
		tag.CanCollide = false
		tag.Size = Vector3.new(1, 1, 1)
		tag.CFrame = ORIGIN * CFrame.new(-GAP_X * 1.4, 3, (r - 1) * GAP_Z)
		tag.Parent = root
		label(tag, row.title, 22)
	end
	src.Archivable = false
	return root
end
