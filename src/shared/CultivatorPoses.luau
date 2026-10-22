-- Joint rotations of the cultivators' poses (server Cultivators.luau bakes one into the rig's rest
-- frame; CultivatorIdle.client.luau turns a limb in the body's frame by undoing it). Each rotation
-- is in its joint's parent attachment frame.
-- cross-legged on the cushion
local SEATED = {
	-- thighs forward and out, shins folded back across under the other knee (a level swing)
	LeftHip = CFrame.Angles(0, math.rad(50), 0) * CFrame.Angles(math.rad(90), 0, 0),
	RightHip = CFrame.Angles(0, math.rad(-50), 0) * CFrame.Angles(math.rad(90), 0, 0),
	LeftKnee = CFrame.Angles(0, 0, math.rad(140)),
	RightKnee = CFrame.Angles(0, 0, math.rad(-140)),
	-- the hands meet in the lap (a meditation mudra): it also hides the blocky hands, which read cheap
	-- resting on the knees (mock 2026-10-21)
	LeftShoulder = CFrame.Angles(math.rad(-15), math.rad(-50), 0),
	RightShoulder = CFrame.Angles(math.rad(-15), math.rad(50), 0),
	LeftElbow = CFrame.Angles(math.rad(95), 0, 0),
	RightElbow = CFrame.Angles(math.rad(95), 0, 0),
}

-- Flying (owner 2026-10-22: "a flying animation too, for the thumbnails for example"): standing on a
-- spirit sword, leaning into the wind, the right hand forward in a sword mudra, the left arm trailing
-- back. Used by Cultivators.build with opts.pose = "fly".
local FLY_POSE = {
	Waist = CFrame.Angles(math.rad(-8), 0, 0),
	RightShoulder = CFrame.Angles(math.rad(75), 0, math.rad(8)),
	RightElbow = CFrame.Angles(math.rad(15), 0, 0),
	-- the left arm trails back in the wind (an elbow bent forward read as a boxing guard)
	LeftShoulder = CFrame.Angles(math.rad(-35), 0, math.rad(-18)),
	LeftElbow = CFrame.Angles(math.rad(20), 0, 0),
	LeftHip = CFrame.Angles(math.rad(12), 0, 0),
	RightHip = CFrame.Angles(math.rad(-12), 0, 0),
	RightKnee = CFrame.Angles(math.rad(-15), 0, 0),
}

return { seated = SEATED, fly = FLY_POSE }
