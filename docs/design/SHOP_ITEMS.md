# Shop items: what to create in the Creator Dashboard

The owner creates each one (R5). Paste its id into `src/shared/Config.luau` (`SHOP_PASSES` /
`SHOP_PRODUCTS`, the `key` column). Prices are suggestions (MONETIZATION "price ladder"); the
game reads the real price from Roblox. Icons: `art/shop_icons/<key>.png` (512 x 512, drawn by
`art/shop_icons/icons.html`).

## Game passes (Monetization > Passes)
| Key | Type | Name | Description | Price (R$) | Icon |
|---|---|---|---|---|---|
| x2 | Game pass | 2x Qi | Double all the Qi your sect earns, forever. Counts while you are away and on gifts too. | 299 | x2.png |
| auto | Game pass | Auto Orbs | Qi orbs on your peak fly to you on their own. No more chasing them. | 249 | auto.png |
| vip | Game pass | VIP Sect | One extra disciple seat, and your sect's name shines in gold on your gate. | 399 | vip.png |

## Developer products (Monetization > Developer Products)
| Key | Type | Name | Description | Price (R$) | Icon |
|---|---|---|---|---|---|
| welcome | Developer product | Welcome Pouch | A welcome gift for new sects: an Elder disciple (+150% Qi) and +10% Qi forever. Once per player. | 5 | welcome.png |
| pill | Developer product | Instant Pill | Swallow a pill right now: 2x Qi for 60 seconds. Adds to any pill already running. | 25 | pill.png |
| pack1 | Developer product | Qi Pouch | Get 10 minutes of your sect's income in Qi, instantly. | 29 | pack1.png |
| pack2 | Developer product | Qi Chest | Get 1 hour of your sect's income in Qi, instantly. | 99 | pack2.png |
| pack3 | Developer product | Qi Vault | Get 6 hours of your sect's income in Qi, instantly. | 299 | pack3.png |
| elder | Developer product | Elder | An Elder disciple joins your sect: +150% Qi. | 49 | elder.png |
| immortal | Developer product | Immortal | An Immortal disciple joins your sect: +400% Qi. | 99 | immortal.png |
| celestial | Developer product | Celestial | A Celestial disciple joins your sect: +900% Qi. | 249 | celestial.png |
| dao | Developer product | Dao Ancestor | A Dao Ancestor joins your sect: +2,000% Qi. | 599 | dao.png |
| emperor | Developer product | Heavenly Emperor | A Heavenly Emperor joins your sect: +4,500% Qi. | 1,299 | emperor.png |
| primordial | Developer product | Primordial | A Primordial disciple joins your sect: +10,000% Qi. | 2,999 | primordial.png |
| tidebell | Developer product | Tide Bell | Ring the bell: a Spirit Tide starts now and everyone on the server earns 2x Qi for 90 seconds, with your name on it. | 79 | tidebell.png |
| starter | Developer product | Sect Starter Pack | An Immortal disciple (+400% Qi), 1 hour of your income in Qi and 2x Qi for 10 minutes. Once per player. | 75 | starter.png |

The disciples have no buy limit (D75). The created disciple products still say "Up to 8 per player" /
"Once per player, from realm N" in the dashboard until the owner edits their descriptions. The
`tidebell` and `starter` icons are in `art/shop_icons/` and `upload/shop_icons/` (glossy discs, drawn
with a copy of `tools/shop_icons/draw.js`).
