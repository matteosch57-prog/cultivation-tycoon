# Security (anti-cheat)

Audit of 2026-10-22, based on Roblox's security docs and DevForum exploit threads (sources at the end).
Rule: the server decides every price, reward and save; the client only asks.

## What a cheater can do on Roblox
An exploiter runs their own code in their own client. They can fire any remote with any arguments, as
often as they like. They can read every LocalScript and ModuleScript that replicates. Their client also
owns their character's physics, so they can teleport, fly, noclip, go at any speed, ignore knockback and
fling other players. They cannot change server values, other players' data or the DataStore directly.

## Audit, remote by remote
| Path | Client sends | Server checks | Verdict |
|---|---|---|---|
| Pads (buildings, hire, shop pads) | nothing (position) | own plot, price from Config, qi, one per tick | Safe: a teleport saves walking, it still costs qi |
| HandsBuild | pad id | string, length, Karma node, own pad, price, cooldown | Safe |
| Recruit / ChestSummon | nothing | hall owned, price, busy flag / summons left | Safe |
| UsePill | nothing | furnace owned, pill brewed | Safe |
| ClaimGift | nothing | server play time, gift index | Safe |
| ClaimStreak | nothing | server UTC day, `data.streak` (one claim a day) | Safe |
| ClaimShopFree | nothing | server UTC day, `data.shopFreeDay`, `DOT_SHOP_FIRST` s played | Safe |
| MenuOpened | menu key | whitelist `MENUS`; only marks a red dot followed (`Dots.seen`), grants nothing | Safe |
| ClaimWelcome | nothing | `welcomed == false`, once | Safe |
| Teleport | "home" or "ranks" | Guard budget, `TELEPORT_COOLDOWN`, live character; the server picks the spot | Safe (no qi) |
| Breakthrough | nothing | Guard budget; only within `BREAKTHROUGH_ASK_SECONDS` of the server's own offer (pad step or Hands); pad present, qi >= price, rebirth gate re-checked | Safe |
| ClaimGroup | nothing | fresh `GetGroupsAsync`, 3 s cooldown | Safe |
| SocialInvite | nothing | Guard, 10 s per player; telemetry only, grants nothing | Safe |
| Bless (ProximityPrompt) | prompt trigger | not your own shrine, once per sect a UTC day, give/get caps, 1 s busy flag; owner's share needs a real account (age + play time). No Guard (a prompt, not a remote) and the hold time is client side | Safe: an instant trigger gains nothing the caps allow |
| DaoBuy | node key | string, node exists, price, cap | Safe |
| Reincarnate | nothing | the qi price AND `Config.rebirthOpen` (a realm gate that still needs this rebirth, its breakthrough pads all built) inside the one shared function (D63; `soulPeak` is kept for the record only) | **Fixed** (audit 2026-10-22): the realm-only gate let a fired remote repeat it for free lives once a life landed on realm 2 |
| ShopBuy / ShopOpened | item key / source | string, length, 1 s, realm gate, limit / whitelist | Safe |
| SwordRide (D76) | sword key or false | Guard budget, string length, the pass owned (`s.passes`), live character, not within `padRadius` of a pad nor on a running altar; the server welds the sword and sets WalkSpeed (HipHeight untouched: the step height stays the walker's), and switches it off on a pad, the altar, death, or `speedStrikes` checks over `speedSlack` x the tier's speed; pads ignore a rider | Safe: a ride buys and pays nothing |
| ProcessReceipt | (Roblox) | PurchaseId de-dup in the save, grant then save, `NotProcessedYet` on a failed save | Safe |
| Qi orbs | nothing (position) | own orbs, spawn rate caps the income | Safe: a teleport only saves walking |
| Saves | nothing | session lock + version in `SaveStore` | Safe |
| Studio hooks (DebugGrant/Reset/Set) | n/a | created only when `IsStudio()`, BindableFunctions in ServerStorage | Safe |
| AltarPush | nothing | on the altar, cooldown, reach from server positions | Safe |
| **Altar knockback** | n/a | **was: applied on the struck client only** | **Fixed**: see below |
| **Remote floods** | spam | **was: some remotes had no budget** | **Fixed**: `Guard` |
| **Fling griefing** | physics | **was: bodies collided** | **Fixed**: `AntiFling` |

## Fixes (security branch)
- **Guard** (`src/server/Guard.luau`): every remote passes a per-player leaky bucket before it does
  anything; over-budget calls are dropped and logged (`[Tycoon][guard]`). Budgets are well above real play.
- **Altar knockback enforced:** the server remembers every knock it sends. A struck player still on the
  altar who moved under `KNOCK_MIN_MOVE` studs `KNOCK_CHECK` s later ignored it, and counts as fallen
  (out for the round, dropped off the edge). Before, a cheater could hold the altar every round.
- **AntiFling** (`src/server/AntiFling.server.luau`): player bodies pass through each other, so a
  spinning cheat body can't launch anyone. Nothing in the design needed bodies to push bodies.

## Accepted, on purpose
- **Teleport/speed are not policed.** They give no qi: pads still cost qi, orbs are capped by their spawn
  rate, and the altar opens after a 30 s warning that is longer than the walk. A server movement check
  brings false positives (lag, the springs' arc, our own teleports) for no economic gain.
- **Game passes trust `PromptGamePassPurchaseFinished`**, which only the server fires; a pass is held in
  memory and re-checked with `UserOwnsGamePassAsync` at every join. Checking ownership right after a
  purchase can read a stale cache and refuse a real buyer.

## When adding a remote
1. Add its budget to `Guard.LIMITS` and call `Guard.allow` first.
2. `type()` every argument, cap string length, reject NaN/inf (`x == x`), look ids up in Config.
3. Prices, rewards and gates come from the server's own data, never from the client.

Sources: create.roblox.com/docs/scripting/security (security-tactics, defensive-design,
server-side-detection, network-ownership); DevForum "Protect your remotes: utf8 + NaN exploits",
"How to secure your RemoteEvent and RemoteFunction", the `firetouchinterest` Touched spoof report, and
the ProcessReceipt example-code logic error thread.
