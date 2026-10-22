# Launch flow and group prompt (2026-10-22)

Owner feedback: the join feels weird (spawn on the hub, teleport to the peak, then a welcome screen
about 10 s later). The group gift was never seen.

## What the code does today
- `Players.CharacterAutoLoads` is on, so the avatar appears at the hub SpawnLocation at once.
- `onJoin` (Main.server.luau) then yields on friends, the DataStore load, `Shop.onJoin` pass checks,
  `IsInGroup`, and `rebuild` of the whole peak. Only after that does `placeOnPeak` pivot the avatar
  and the `WelcomeQi` attribute open the Heavenly Gift. That wait is the gap the owner sees.
- `Config.GROUP_ID = 0`, so the group gift button never shows (Friends.client `showGroup`).
  ECONOMY "Group gift (D35)" chose no in-game join prompt on purpose.

## Research
- A custom loading screen is a LocalScript in ReplicatedFirst: build and parent the gui first, then
  `ReplicatedFirst:RemoveDefaultLoadingScreen()` (removing it earlier flashes the world); wait on
  `game:IsLoaded()` / `game.Loaded`, optionally `ContentProvider:PreloadAsync` the gui images.
  The Roblox default screen cannot be removed entirely, only shortened.
  Sources: [Custom Loading Screens](https://developer.roblox.com/articles/Custom-Loading-Screens),
  [RemoveDefaultLoadingScreen](https://devforum.roblox.com/t/removedefaultloadingscreen/68005),
  [Loading screen not instant](https://devforum.roblox.com/t/loading-screen-not-instant/4129529),
  [Respawning and Loading Screens](https://devforum.roblox.com/t/respawning-and-loading-screens/284119).
- Spawning at the plot: no forum thread covers it directly; the standard engine route is to hold the
  first character (`CharacterAutoLoads = false`, then `LoadCharacter` once the plot is built, placed
  in `CharacterAdded` with no wait) so the avatar never appears elsewhere. Respawns then need a
  `Died` handler.
- In-game group join: `GroupService:PromptJoinAsync(groupId)` (client) shows Roblox's own join
  prompt and returns `GroupMembershipStatus` (None, Joined, JoinRequestPending, AlreadyMember).
  Heavenly RNG already uses it (RollController AR-1). Sources:
  [GroupMembershipStatus](https://create.roblox.com/docs/en-us/reference/engine/enums/GroupMembershipStatus.md),
  [Join Group Prompt request](https://devforum.roblox.com/t/join-group-prompt/2609702).

## Options mocked
`docs/art/mocks/loading.html` -> `loading_A.jpg` (qi drop fills), `loading_B.jpg` (cloud sea + qi
bar), `loading_C.jpg` (jade seal ring + sky dive). Render: `python tools/mock_loading.py`.
