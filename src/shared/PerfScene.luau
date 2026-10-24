-- PerfScene: where the player is (a zone) and how heavy the scene around the camera is, for the fps
-- telemetry (PerfReport.client) and the owner's /perf rows (PerfLog). Phone fps 2026-10-23: the
-- owner's Pixel lost fps near the disciples; the live numbers say which zone and which load.
-- The scan walks workspace a slice a frame (SLICE instances), so it never costs a hitch itself, and
-- counts what sits within RADIUS of the camera: parts, enabled particle emitters and their live
-- particles (Rate x average Lifetime, the steady state), enabled Highlights and enabled
-- BillboardGuis / SurfaceGuis (the PlayerGui's adorned ones too).
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(script.Parent:WaitForChild("Config"))

local PerfScene = {}

PerfScene.RADIUS = 80 -- studs around the camera
PerfScene.ZONES = { "disciples", "hub", "peak", "bridge", "sky" }
local SLICE = 1000 -- instances scanned a frame
local DISCIPLE_NEAR = 45 -- studs from a seated disciple: the "disciples" zone

-- the latest finished scan (nil until the first one ends)
PerfScene.latest = nil :: { parts: number, emitters: number, particles: number, highlights: number, guis: number, at: number }?

-- phone | tablet | pc | console: a touch screen with no keyboard is a phone below 900 px short side
function PerfScene.device(): string
	if GuiService:IsTenFootInterface() then
		return "console"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(0, 0)
		return math.min(vp.X, vp.Y) < 900 and "phone" or "tablet"
	end
	return "pc"
end

-- the zone of the local player's avatar (the camera when it has none)
function PerfScene.zone(): string
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	local at = (root and root.Position) or (cam and cam.CFrame.Position) or Vector3.zero
	for _, m in CollectionService:GetTagged("Cultivator") do
		-- (a shop or streak card's ViewportFrame holds a tagged preview figure at the origin)
		if m:IsA("Model") and m:IsDescendantOf(workspace) and (m:GetPivot().Position - at).Magnitude < DISCIPLE_NEAR then
			return "disciples"
		end
	end
	if Players.LocalPlayer:GetAttribute("Riding") then
		return "sky"
	end
	local flat = Vector3.new(at.X, 0, at.Z).Magnitude
	if flat < Config.HUB_RADIUS + 25 then
		return "hub"
	end
	if math.abs(flat - Config.PLOT_RADIUS) < 140 then
		return "peak"
	end
	return "bridge"
end

local function posOf(inst: Instance): Vector3?
	local p = inst.Parent
	if p and p:IsA("Attachment") then
		return p.WorldPosition
	elseif p and p:IsA("BasePart") then
		return p.Position
	end
	return nil
end

local scanning = false
-- start a scan around the camera; `done(counts)` runs when it ends (a few frames later)
function PerfScene.scan(done: ((any) -> ())?)
	if scanning then
		return
	end
	scanning = true
	task.spawn(function()
		local cam = workspace.CurrentCamera
		local eye = cam and cam.CFrame.Position or Vector3.zero
		local r = PerfScene.RADIUS
		local c = { parts = 0, emitters = 0, particles = 0, highlights = 0, guis = 0, at = os.clock() }
		local function near(a: Instance?): boolean
			local p = a and (if a:IsA("BasePart") then a.Position elseif a:IsA("Attachment") then a.WorldPosition elseif a:IsA("Model") then a:GetPivot().Position else nil)
			return p ~= nil and (p - eye).Magnitude < r
		end
		-- a walk by hand (one GetChildren at a time): one GetDescendants of the whole workspace is a
		-- hitch of its own on a phone
		local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local stack: { Instance } = { workspace, gui :: any }
		local n = 0
		while #stack > 0 do
			local d = table.remove(stack) :: Instance
			for _, k in d:GetChildren() do
				table.insert(stack, k)
			end
			if d:IsA("BasePart") then
				if d.Transparency < 1 and (d.Position - eye).Magnitude < r then
					c.parts += 1
				end
			elseif d:IsA("ParticleEmitter") then
				local p = d.Enabled and posOf(d)
				if p and (p - eye).Magnitude < r then
					c.emitters += 1
					c.particles += d.Rate * (d.Lifetime.Min + d.Lifetime.Max) / 2
				end
			elseif d:IsA("Highlight") then
				if d.Enabled and near(d.Adornee or d.Parent) then
					c.highlights += 1
				end
			elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
				if d.Enabled and near(d.Adornee or d.Parent) then
					c.guis += 1
				end
			end
			n += 1
			if n % SLICE == 0 then
				RunService.Heartbeat:Wait()
			end
		end
		c.particles = math.floor(c.particles)
		PerfScene.latest = c
		scanning = false
		if done then
			done(c)
		end
	end)
end

return PerfScene
