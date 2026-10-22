# UI pass write-up (2026-10-21 to 2026-10-22)

The UI thread's full record: what was built, where it lives, the owner's picks, and what is still
open. Decisions: DECISIONS **D34** (UI and movement) and **D38** (Welcome Pouch). Everything is on
`integration` (branch `ui`, last commit a74d252).

## 1. Currency icons on every amount (R18)
- HUD messages take pieces (`amt(currency, n, sign)`): gift, orb, shop pack, offline, "+N" near the
  counter, the next goal price; the "+N" floating over buildings (Juice) shows the qi drop.
- `Toy.amount` takes `"qi" | "karma" | "robux"`.
- Files: `src/client/Hud.client.luau` (`line`, `fadeOut`, `toast`), `src/client/Juice.client.luau`,
  `src/shared/Toy.luau`.

## 2. Less text (mock `docs/art/mocks/less_text_*.jpg`, owner pick A)
- HUD labels are one word or a number: Shop, 7/7, Use!, timers. The goal shows the pad name only;
  the realm bar a hall icon and n/total; the Rebirth chip a karma orb and n/target (D37's target
  kept); the Spirit Tide a wave icon and a timer.
- Disciples card: no panel, a row of disciples (see 7) with their bonus; a gold dot marks a shop
  disciple also rolled.
- Pad cards: name and price; the 2 to 3 word feature line (`Config.PADS` `feature`) only up close.
- Messages: a few words each ("Gift in 4:59", "Pill ready!", "More land!").

## 3. Phone layout
- The left button column fits between Roblox's top bar and the thumbstick and wraps into two columns
  when too tall (`layout()` in Hud).
- While the Shop, Reincarnation or Welcome offer screen is open the HUD steps aside (toasts stay):
  `MODALS` in Hud.
- Checked in Studio Play with stand-ins for the phone thumbstick and jump button: nothing blocks them;
  the Recruit seal sits left of the jump button (above it on narrow phones).

## 4. Performance (R16)
- Pad price cards write only on change (`put`), scale in 0.05 steps, PerfMark `padcards`.
- New PerfMark jobs: `move`, `reveal`, `auras` (TECH "Rules for new code").

## 5. Movement (`src/client/Movement.client.luau`, `Config.MOVE`)
- Walk 28 (owner: "way faster"; Roblox default 16), jump height 8.5, a soft fall (VectorForce takes
  45% of gravity while falling), one cloud step in the air (jump again) with a jade ring.
- Run = Roblox Ninja pack, jump and fall = Levitation pack (ids in `MOVE.anims`, checked loading).

## 6. Buttons and reveal
- Toy buttons: first look kept, the shine is a glass cap (`Toy.glass`; mocks `premium_buttons.jpg`,
  `glass_bars.jpg`, owner pick 3 of 10).
- Recruit reveal (`src/client/RecruitReveal.client.luau`, `Config.REVEAL`; mock `recruit_b.gif`): a qi
  orb flies from the Recruit seal, charges one step per rarity, bursts into the disciple card with an
  aura that grows with rarity; burst sounds climb with rarity (existing Sfx set); Juice lights the
  platform at the burst (`Config.revealBurst`); a tap skips.
- Recruit button = a round formation seal (mock `recruit_button_c.gif`, owner pick C): orb cycling
  rarity colours in a turning ring, rays and glow from the atlas, breathes; still and grey when out
  of reach. Code: Hud `ui.seal`.

## 7. Disciple icons with moving auras
- One uploaded image, `art/ui/disciple_atlas.png` = **rbxassetid://114202512373902** (drawn by
  `tools/disciple_atlas.html`, cells in `Config.DISCIPLE_ATLAS`): the 9 disciples from the mock plus
  the aura pieces (glow, rays, ring, yin-yang, halo, cloud, flame, sparkle, mote).
- `Toy.disciple(parent, size, rarity)` and `Toy.aura`: 9 auras climbing with rarity (mock
  `disciple_auras.gif`), no backdrop (owner), one shared animator for on-screen auras only.
  `Toy.atlasPiece` exposes a piece (the seal uses it).
- Used by: the HUD disciples row, the Shop's disciple tiles and tab icon, the shop island pad icons,
  the recruit card (no small aura there).
- Lesson: soft glows, tapering rays and curves cannot be drawn with UI boxes; the first box-built
  version was "ugly compared to the mock". Matching a mock needs the mock's own drawings as an image.

## 8. Welcome Pouch (D38; research `2026-10-22_cheap_buys.md`; mocks `welcome_pouch_*.jpg`)
- 5 Robux, once per player: an Elder (+150%) and +10% Qi forever (`data.qiBonus`, kept every life,
  in Main `rate`). Sim: realm 10 lands the same day as without it.
- Offered once by a card after a building with a `feature` from 5 min of play, or any building from
  10 min (`Config.WELCOME`, `Shop.maybeWelcome`, `data.welcomeOffered`); first tile in Boosts with a
  "Once" ribbon until bought; bought = the recruit reveal for its Elder, then a "+10% forever" toast.
- Store entry in `docs/design/SHOP_ITEMS.md` (icon `art/shop_icons/welcome.png`); STATE owner list is
  14 items.

## 9. Analytics: HUD menus
- Event `Menu` (disciples | reinc | karma | group, realm), remote `MenuOpened` (Guard budget, fixed
  keys, once per 3 s per menu), journal code `Menu:<key>`. DATA.md updated.

## Open items
- **Owner:** create the Welcome Pouch product (5 Robux) and paste its id into
  `Config.SHOP_PRODUCTS` `welcome`; then a test purchase checks the grant, the reveal and the toast.
- **Owner on a real phone:** the HUD around the thumbstick and jump button, the Recruit seal, walk 28
  and the cloud step, the run animation in motion, the reveal's sounds.
- Not seen in Play: the shop island pad icons with auras, the Welcome offer firing on its own after a
  real build (logic checked, the card and tile seen by firing the notice), the Menu events (need taps).
- Nothing else pending in this thread.

## Mocks and captures
`docs/art/mocks/`: less_text*, premium_buttons*, glass_bars*, recruit_a/b/c.gif, recruit_reveal.html,
disciple_icons*, disciple_auras*, welcome_pouch*, recruit_button*. Pages shared with the owner:
Disciple Aura Icons, Welcome Pouch, Recruit Button (claude.ai artifacts).
