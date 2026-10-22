# NPC animation: why the workers and disciples looked stiff (2026-10-22)

Owner report: worker and disciple motion looks unnatural; some parts move while others stay frozen;
hair sometimes stays put while the character moves out of it; recruiting reloads every disciple.

## What was wrong (checked in Studio Edit)
- **Robes do not follow parts moved one by one.** Both NPC kinds were posed by disabling the rig's
  joints, anchoring every part and moving each part's CFrame from the client (BulkMoveTo). Layered
  clothing (the hanfu robes) is skinned to the body through the joints, so a lifted arm left the
  sleeve where it was (capture: the monk's mudra arm out of its sleeve).
- **Hair and props that stream in late were never moved.** The client sorted the parts into
  groups once, when the figure arrived; anything that streamed in after stayed frozen. The models
  were not Atomic.
- **Only the arms worked.** The worker loops turned the arms and waist while the hips and feet
  stayed fixed (and hip keys lifted the feet off the ground), with hard cuts between a swing and a
  rest.
- **Recruit reload:** `buildDisciples` destroyed the whole Disciples folder and rebuilt every seat;
  each avatar arrives a moment later, so every figure popped out and back in.

## What works (sourced)
- AnimationConstraint (the new rigs' joints) and Motor6D both have `Transform`; procedural motion
  is layered by writing it in `RunService.PreSimulation`, applied by the engine in one batch
  ([AnimationConstraint docs](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint)).
  Keep `IsKinematic` on (staff: turning it off makes arms lag).
- Layered clothing relies on the joints (DevForum reports of it breaking when joints are swapped).
- In Studio Edit, `Animator:StepAnimations(0)` applies pending Transforms, so poses can be checked
  and filmed without Play. Layered robes take ~1 s to settle in Edit after a pose change.
- Animations an experience does not own cannot be played; an un-uploaded KeyframeSequence plays
  only in Studio (`AnimationClipProvider`), so procedural Transforms are the no-upload route.
- Animation principles that read as natural: overlapping action (joints at different rates),
  follow-through, slow in / slow out, weight shift through the hips with planted feet.

## The fix
`Rig.luau`: root anchored, body on its own joints (`Rig.live`), poses baked into the rest frame
(`Rig.bake`), the client writes Transforms (`Rig.apply`), two-bone legs keep the feet planted
(`Rig.leg`). Mock clips: `docs/art/mocks/anim_mock_*.mp4`.
