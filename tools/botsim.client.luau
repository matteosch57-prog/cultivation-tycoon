-- botsim: one bot player through the REAL game (Studio Play, mock save), to check tools/sim_check.py
-- against the engine (owner 2026-10-23: "make a real sim, use the studio engine").
--
-- Not part of the game: it lives in tools/ (outside Rojo's src), so it never ships and live never runs
-- it. Run it in a solo Studio Play through the MCP: execute_luau in the CLIENT datamodel with this file's
-- source. It returns at once and plays in a background thread; read _G.BOT (see the bottom) to poll.
-- It refuses to start outside Studio or when the server is not on the Studio mock save.
--
-- The bot is the sim's "regular" player, rule for rule (sim_check.sim, policy "gated"), using the same
-- paths a person does: it stands on pads (the server's position check buys them), presses the remotes
-- the HUD presses (Recruit x10, Breakthrough confirm, Reincarnate, DaoBuy, ClaimGift, UsePill,
-- ChestSummon, ClaimShopFree, ClaimWelcome, ClaimStreak) and walks to orbs every ORB_EVERY seconds.
--   1. everything built: rebirth if the next realm waits for one (RebirthOpen) and qi holds the
--      price, else confirm the breakthrough once qi holds its cost; nothing else meanwhile
--   2. target = the cheapest building pad; recruit x10 when that batch costs no more than the target
--   3. a hire cheaper than the target: hire when affordable, else wait for it
--   4. the target once affordable, after WALK seconds (the sim's walk)
--   (with the Heavenly Hands karma node every build goes through HandsBuild, no walk, like the sim)
-- "Waiting" = a second where qi holds less than the cheapest thing on offer (any pad, hire, recruit
-- x10, breakthrough, rebirth): the frustration the owner asked about.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

assert(RunService:IsStudio(), "botsim: Studio only")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
assert(Config.MOCK_DATASTORE, "botsim: needs the Studio mock save (Config.MOCK_DATASTORE)")

local WALK = 6 -- s from "affordable" to standing on the pad (sim_check KINDS.regular.walk)
local ORB_EVERY = 30 -- s between orb pick-ups (sim_check KINDS.regular.orb_every)
local SHOP_FREE_AT = 600 -- s into the session (sim_check: s == 600)
local DURATION = (_G.BOT_MINUTES or 30) * 60
local DAO_ORDER = { "hands", "isles", "elixir", "meditation", "seat", "echo" } -- sim_check do_rebirth

local player = Players.LocalPlayer
local R = ReplicatedStorage:WaitForChild("Remotes")
local me = player.UserId

local BOT = { log = {}, snaps = {}, waitS = 0, longest = 0, gap = 0, t = 0, done = false, err = nil, stop = false }
if _G.BOT and not _G.BOT.done then
	_G.BOT.stop = true -- one bot at a time
	task.wait(1.5)
end
_G.BOT = BOT

local t0 = os.clock()
local function now()
	return math.floor(os.clock() - t0)
end
local function A(k)
	return player:GetAttribute(k)
end
local function note(kind, what, cost)
	table.insert(BOT.log, string.format("%d|%s|%s|%s|q=%d|r=%.1f|R%d|L%d", now(), kind, tostring(what), tostring(cost or ""), A("Qi") or 0, A("Rate") or 0, A("Realm") or 0, A("Lives") or 0))
end

local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local home -- where the bot stands between actions (its spawn, off every pad)
local function goTo(pos)
	local h = hrp()
	if h then
		h.AssemblyLinearVelocity = Vector3.zero
		h.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	end
end
local function goHome()
	if home then
		goTo(home)
	end
end

local function invoke(name, ...)
	local f = R:FindFirstChild(name)
	if not f then
		return nil
	end
	local ok, res = pcall(f.InvokeServer, f, ...)
	return ok and res or nil
end

-- my pads by kind: build pads, hires, the breakthrough pad, the idle chest
local function pads()
	local build, hires, bt, chest = {}, {}, nil, nil
	for _, p in CollectionService:GetTagged("StepPad") do
		if p.Parent and p:GetAttribute("OwnerId") == me then
			local n = p.Name
			if n == "Pad_breakthrough" then
				bt = p
			elseif n == "Chest" then
				chest = p
			elseif n:sub(1, 5) == "Hire_" then
				table.insert(hires, p)
			elseif n:sub(1, 4) == "Pad_" then
				table.insert(build, p)
			end
		end
	end
	return build, hires, bt, chest
end
local function cheapest(list)
	local best, cost = nil, math.huge
	for _, p in list do
		local c = p:GetAttribute("Cost") or math.huge
		if c < cost then
			best, cost = p, c
		end
	end
	return best, cost
end

-- Heavenly Hands (karma node): the HUD's gold hand builds a pad from anywhere (remote HandsBuild),
-- so from then on the bot walks nowhere, like the sim (walk 0 with hands)
local function hands()
	return (player:GetAttribute("Dao_hands") or 0) > 0
end

local function standOn(p, what)
	local cost = p:GetAttribute("Cost")
	if hands() and p:GetAttribute("PadId") then
		local ok = invoke("HandsBuild", p:GetAttribute("PadId"))
		task.wait(Config.HANDS_COOLDOWN)
		note("buy", what, ok and cost or "refused")
		return
	end
	goTo(p.Position)
	local t = os.clock()
	while p.Parent and p:GetAttribute("OwnerId") == me and os.clock() - t < 2 do
		task.wait(0.1)
	end
	note("buy", what, cost)
	goHome()
	task.wait(0.25) -- off every pad before the next (the server's padHold)
end

local btAsk = false
R:WaitForChild("Notify").OnClientEvent:Connect(function(kind)
	if kind == "breakthroughAsk" then
		btAsk = true
	end
end)

local function daoBuys()
	for _, key in DAO_ORDER do
		for _ = 1, 6 do
			local res = invoke("DaoBuy", key)
			if not res or (type(res) == "table" and res.ok == false) then
				break
			end
			note("dao", key)
		end
	end
end

local function run()
	repeat
		task.wait(0.5)
	until hrp() and A("Qi") ~= nil
	task.wait(3)
	home = hrp().Position
	if (A("WelcomeQi") or 0) > 0 then
		invoke("ClaimWelcome")
		note("get", "welcome")
	end
	if invoke("ClaimStreak") then
		note("get", "streak")
	end
	local walkUntil, lastOrb, shopDone = nil, 0, false
	while now() < DURATION and not BOT.stop do
		local t = now()
		BOT.t = t
		local qi = A("Qi") or 0
		local build, hires, bt, chest = pads()
		local target, tcost = cheapest(build)
		local hire, hcost = cheapest(hires)
		local realm, rr = A("Realm") or 1, A("RealmRecruits") or 0
		local b10 = A("HasHall") and Config.recruitBatchCost(realm, rr, 10) or math.huge
		local rebirthOpen = A("RebirthOpen") == true
		local rprice = A("RebirthPrice") or math.huge

		-- waiting: nothing on offer is affordable
		local floor = math.min(tcost, hcost, b10, bt and (bt:GetAttribute("Cost") or math.huge) or math.huge, rebirthOpen and rprice or math.huge)
		if floor < math.huge and qi < floor then
			BOT.waitS += 1
			BOT.gap += 1
			BOT.longest = math.max(BOT.longest, BOT.gap)
		else
			BOT.gap = 0
		end
		if t % 10 == 0 then
			table.insert(BOT.snaps, string.format("%d|q=%d|r=%.1f|R%d|L%d|w=%d", t, qi, A("Rate") or 0, realm, A("Lives") or 1, BOT.waitS))
		end

		-- side income, as the sim takes it
		if A("GiftIn") == 0 and invoke("ClaimGift") then
			note("get", "gift")
		end
		if A("PillReady") and invoke("UsePill") then
			note("get", "pill")
		end
		if (A("ChestSummons") or 0) > 0 and invoke("ChestSummon", A("ChestSummons")) then
			note("get", "summons")
		end
		if not shopDone and t >= SHOP_FREE_AT then
			shopDone = true
			if invoke("ClaimShopFree") then
				note("get", "shopfree")
			end
		end
		if chest then
			standOn(chest, "chest")
		end
		if t - lastOrb >= ORB_EVERY then
			lastOrb = t
			local any = false
			for _, o in workspace:GetDescendants() do
				if o.Name == "QiOrb" and o:IsA("BasePart") then
					any = true
					local before = A("Qi") or 0
					goTo(o.Position - Vector3.new(0, 3, 0))
					local w = os.clock()
					while o.Parent and os.clock() - w < 1.5 do
						task.wait(0.1)
					end
					note("orb", o.Parent and "missed" or "got", (A("Qi") or 0) - before)
				end
			end
			if any then
				goHome()
			end
		end

		-- 1. everything built: the next realm waits for a rebirth (no breakthrough pad then: the server
		-- shows it only once the rebirths are there), or the breakthrough pad stands
		if rebirthOpen then
			walkUntil = nil
			if qi >= rprice then
				local res = invoke("Reincarnate")
				note("rebirth", tostring(res and (type(res) ~= "table" or res.ok ~= false)), rprice)
				task.wait(2)
				daoBuys()
			end
		elseif bt then
			walkUntil = nil
			if qi >= (bt:GetAttribute("Cost") or math.huge) then
				btAsk = false
				if hands() then
					invoke("HandsBuild", "breakthrough")
				else
					goTo(bt.Position)
				end
				local w = os.clock()
				while not btAsk and os.clock() - w < 2 do
					task.wait(0.1)
				end
				local ok = invoke("Breakthrough")
				note("breakthrough", tostring(ok), bt:GetAttribute("Cost"))
				goHome()
				task.wait(2)
			end
		elseif target then
			if b10 <= tcost and qi >= b10 then -- 2. recruits
				local res = invoke("Recruit", 10)
				note("recruit", res and (type(res) ~= "table" or res.ok ~= false) and "x10" or "refused", b10)
			elseif hire and hcost < tcost then -- 3. a hire first
				if qi >= hcost then
					standOn(hire, hire.Name)
				end
			elseif qi >= tcost then -- 4. the cheapest building, after the walk
				walkUntil = walkUntil or t + (hands() and 0 or WALK)
				if t >= walkUntil then
					walkUntil = nil
					standOn(target, target.Name)
				end
			end
		end
		local nxt = t0 + t + 1
		while os.clock() < nxt do
			task.wait(0.05)
		end
	end
	BOT.done = true
	note("end", "")
end

task.spawn(function()
	local ok, err = pcall(run)
	if not ok then
		BOT.err = tostring(err)
		BOT.done = true
	end
end)
return "botsim started, " .. DURATION .. " s"
