
const INK = "#1B1420";
const Q = new URLSearchParams(location.search);
const VIEW = Q.get("view") || "board";

// ------------------------------------------------------------------------------------------
// NOW: the Luau Icon API (64-unit box; every shape gets an ink copy ow wider underneath)
function nowIcon(draw) {
  const under = [], over = [], top = [];
  const ow = 4.5;
  const api = {
    rot: 0,
    shape(cx, cy, w, h, color, r, rot, outline, z) {
      const t = `rotate(${rot || 0} ${cx} ${cy})`;
      const mk = (ex, col) => `<rect x="${cx - w / 2 - ex}" y="${cy - h / 2 - ex}" width="${w + ex * 2}" height="${h + ex * 2}" rx="${r === "c" ? (h / 2 + ex) : (r ? r + (ex ? ex : 0) * 0 : 0)}" fill="${col}" transform="${t}"/>`;
      if (outline !== false) under.push(mk(ow, INK));
      (z === 3 ? top : over).push(mk(0, color));
    },
    circle(cx, cy, r, c, o) { this.shape(cx, cy, r * 2, r * 2, c, "c", 0, o); },
    rect(cx, cy, w, h, c, r, rot, o, z) { this.shape(cx, cy, w, h, c, r, rot, o, z); },
    detail(cx, cy, r, c, tr) { top.push(`<circle cx="${cx}" cy="${cy}" r="${r}" fill="${c}" fill-opacity="${1 - (tr || 0)}"/>`); },
    qi(cx, cy, s) { s = s || 1; this.circle(cx, cy + 8 * s, 20 * s, "#6FD6AE"); this.rect(cx, cy - 9 * s, 27 * s, 27 * s, "#6FD6AE", 3 * s, 45);
      this.detail(cx + 5 * s, cy + 8 * s, 9 * s, "#E8FFF4"); this.detail(cx - 9 * s, cy + 3 * s, 4 * s, "#fff", .2); },
    karma(cx, cy, s) { s = s || 1; this.circle(cx, cy, 22 * s, "#9A6BFF"); this.detail(cx + 4 * s, cy + 3 * s, 12 * s, "#D9B8FF");
      this.detail(cx + 7 * s, cy + 5 * s, 5 * s, "#9A6BFF"); this.detail(cx - 9 * s, cy - 9 * s, 4 * s, "#fff", .15); },
  };
  draw(api);
  return `<svg viewBox="-6 -6 76 76"><g transform="rotate(${api.rot} 32 32)">${under.join("")}${over.join("")}${top.join("")}</g></svg>`;
}
const NOW = {
  qi: a => { a.circle(32, 40, 20, "#6FD6AE"); a.rect(32, 23, 27, 27, "#6FD6AE", 3, 45); a.detail(37, 40, 9, "#E8FFF4"); a.detail(23, 35, 4, "#fff", .2); },
  karma: a => a.karma(32, 32, 1.1),
  robux: a => { a.rect(32, 32, 46, 46, "#fff", 13); a.rect(32, 32, 18, 18, INK, 3, 0, false, 3); },
  shop: a => { a.rect(32, 15, 18, 9, "#E65B4F", 2); a.circle(32, 40, 22, "#FFD34D"); a.rect(32, 22, 22, 6, "#E65B4F", 2); a.qi(32, 39, .42); },
  disciple: a => { a.rect(32, 52, 38, 22, "#5096FF", 9); a.circle(32, 12, 7, INK); a.circle(32, 29, 13, "#F2CFAE"); a.rect(32, 21, 24, 7, INK, 3, 0, false, 3); a.rect(32, 47, 8, 12, "#fff", 2, 0, false, 3); },
  pill: a => { a.rect(23, 32, 22, 20, "#E65B4F", 10); a.rect(41, 32, 22, 20, "#FFF4DC", 10); a.detail(20, 27, 3, "#fff", .3); a.rot = -35; },
  gift: a => { a.rect(32, 42, 42, 28, "#E65B4F", 4); a.rect(32, 25, 50, 12, "#FF7A6B", 3); a.rect(32, 37, 8, 38, "#FFD34D", 0, 0, false, 3); a.detail(22, 22, 3, "#fff", .3); },
  tide: a => { a.rect(32, 46, 54, 22, "#4FB4FF", 6); a.circle(18, 34, 12, "#4FB4FF"); a.circle(42, 30, 14, "#4FB4FF"); a.detail(44, 26, 6, "#BFE6FF"); },
  hall: a => { a.rect(32, 42, 38, 24, "#FFF4DC", 2); a.rect(32, 22, 54, 14, "#E65B4F", 4); a.rect(32, 47, 10, 14, "#8A5A3C", 1, 0, false, 3); },
  goal: a => { a.rect(24, 32, 30, 14, "#FFD34D", 3); a.rect(42, 32, 26, 26, "#FFD34D", 3, 45); },
  x2: a => { a.qi(26, 28, .85); },
  auto: a => { a.circle(10, 16, 5, "#9FF5D0"); a.circle(14, 48, 6, "#9FF5D0"); a.circle(21, 31, 7, "#9FF5D0"); a.circle(43, 32, 17, "#9FF5D0"); a.detail(37, 26, 6, "#fff", .15); },
  vip: a => { const g = "#FFD34D"; a.rect(32, 38, 46, 22, g, 3); a.rect(12, 22, 14, 14, g, 2, 45); a.rect(32, 16, 16, 16, g, 2, 45); a.rect(52, 22, 14, 14, g, 2, 45); a.rect(32, 51, 50, 10, "#FFB02E", 3); a.circle(32, 36, 5, "#59D39F"); },
  hands: a => { const g = "#FFD34D"; [20, 28.5, 37, 45.5].forEach((x, i) => a.rect(x, 25 + Math.abs(i + 1 - 2.5) * 3, 8, 24, g, 4)); a.rect(15, 42, 8, 20, g, 4, -40); a.rect(33, 44, 34, 26, g, 9); },
  rebirth: a => { a.circle(32, 30, 26, "#C0392B"); a.circle(32, 32, 15, "#9FF5C8"); const c = "#FFF4DC"; a.rect(25, 42, 8, 8, c, 1); a.rect(33, 39, 8, 14, c, 1); a.rect(41, 36, 8, 20, c, 1); a.rect(32, 56, 56, 8, "#8A5A3C", 3); },
  like: a => { const G = "#59D39F"; a.rect(14, 40, 12, 28, G, 3); a.rect(38, 42, 30, 26, G, 6); a.rect(36, 20, 12, 22, G, 5, -15); },
  invite: a => { a.rect(24, 48, 34, 22, "#fff", 10); a.circle(24, 24, 11, "#fff"); a.rect(50, 26, 6, 22, "#fff", 2); a.rect(50, 26, 22, 6, "#fff", 2); },
  group: a => { a.rect(16, 34, 6, 54, "#8A5A3C", 2); a.rect(36, 22, 34, 26, "#B06BFF", 3); a.circle(36, 22, 6, "#FFD34D"); },
  palm: a => { const s = "#FFE1C4"; [30, 36, 34, 26].forEach((h, k) => a.rect(22 + k * 8, 34 - h / 2, 7, h, s, 3)); a.rect(13, 40, 7, 18, s, 3, -40); a.rect(34, 46, 32, 26, s, 10); },
  chest: a => { a.rect(32, 44, 46, 26, "#C0392B", 4); a.rect(32, 26, 46, 14, "#E65B4F", 6); a.rect(32, 36, 10, 10, "#FFD34D", 2, 0, false, 3); },
};

// ------------------------------------------------------------------------------------------
// NEW geometry: every icon = parts { d (path), c (base colour) , k (kind: "line" = stroke only) }
// in a 64 box with 6 units of padding. One light: top left. Detail level: 2 to 4 parts each.
const C = {
  qi: "#4FD8A4", qiHi: "#D8FFF0", karma: "#9566F2", karmaHi: "#E3CCFF", gold: "#FFC93C", goldDk: "#E89A1C",
  red: "#E5483F", cream: "#FFF1D6", wood: "#8A5A3C", blue: "#4C9BFF", skin: "#F6D2B0", tide: "#3FB0F5", tideHi: "#C9EEFF",
  jade: "#5FD39B", purple: "#A46BFF", white: "#FFFFFF",
};
const drop = (cx, cy, s) => { // the qi drop: a teardrop with a pointed top
  const k = v => (v * s).toFixed(2);
  return `M${cx} ${cy - 26 * s} C${+cx + 4 * s} ${cy - 16 * s} ${+cx + 19 * s} ${cy - 2 * s} ${+cx + 19 * s} ${cy + 9 * s} A${k(19)} ${k(19)} 0 0 1 ${cx - 19 * s} ${cy + 9 * s} C${cx - 19 * s} ${cy - 2 * s} ${cx - 4 * s} ${cy - 16 * s} ${cx} ${cy - 26 * s}Z`;
};
const circ = (cx, cy, r) => `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${r * 2} 0a${r} ${r} 0 1 0 ${-r * 2} 0Z`;
const rr = (x, y, w, h, r) => `M${x + r} ${y}h${w - 2 * r}a${r} ${r} 0 0 1 ${r} ${r}v${h - 2 * r}a${r} ${r} 0 0 1 ${-r} ${r}h${-(w - 2 * r)}a${r} ${r} 0 0 1 ${-r} ${-r}v${-(h - 2 * r)}a${r} ${r} 0 0 1 ${r} ${-r}Z`;
const HAND = "M19 56 C13 50 9 42 8 36 C7 32 11 30 14 33 L19 39 L19 15 C19 11 25 11 25 15 L25 30 L25 10 C25 6 31 6 31 10 L31 29 L31 11 C31 7 37 7 37 11 L37 30 L37 15 C37 11 43 11 43 15 L43 40 C43 49 39 56 33 58 Z";
const NEW = {
  qi: [{ d: drop(32, 36, 1), c: C.qi }, { d: "M24 40 C24 46 28 50 33 50", c: C.qiHi, k: "line", w: 4 }],
  karma: [{ d: circ(32, 32, 24), c: C.karma }, { d: "M32 8 A12 12 0 0 1 32 32 A12 12 0 0 0 32 56 A24 24 0 0 0 32 8Z", c: "#7448D6", k: "flat" }, { d: circ(32, 20, 4), c: C.karmaHi, k: "flat" }, { d: circ(32, 44, 4), c: "#4B2A9E", k: "flat" }],
  robux: "ROBUX",
  shop: [{ d: "M20 22 C14 30 10 38 10 45 C10 54 18 59 32 59 C46 59 54 54 54 45 C54 38 50 30 44 22 Z", c: C.gold }, { d: "M21 22 L18 11 C24 14 28 9 32 13 C36 9 40 14 46 11 L43 22 Z", c: C.gold }, { d: rr(18, 19, 28, 7, 3.5), c: C.red }, { d: drop(32, 44, .38), c: C.qi, k: "flat" }],
  disciple: [{ d: "M12 60 C12 47 20 40 32 40 C44 40 52 47 52 60 Z", c: C.blue }, { d: "M32 40 L26 40 L32 52 L38 40 Z", c: C.cream, k: "flat" }, { d: circ(32, 26, 13), c: C.skin }, { d: "M19 25 C19 15 25 12 32 12 C39 12 45 15 45 25 C41 20 36 19 32 21 C28 19 23 20 19 25Z", c: INK, k: "flat" }, { d: circ(32, 9, 6), c: INK }],
  pill: [{ d: "M14 36 L28 22 L42 36 L28 50 Z", c: C.red, k: "clipL" }, { d: "M14 36 C6 44 6 52 14 52 ... ", c: C.red, k: "skip" }],
  gift: [{ d: rr(9, 26, 46, 13, 4), c: C.red }, { d: rr(13, 37, 38, 22, 3), c: C.red }, { d: "M28 26 h8 v33 h-8 Z", c: C.gold, k: "flat" }, { d: "M32 26 C26 16 15 14 16 21 C17 26 25 26 32 26 Z", c: C.gold }, { d: "M32 26 C38 16 49 14 48 21 C47 26 39 26 32 26 Z", c: C.gold }],
  tide: [{ d: "M6 54 C6 34 18 18 36 18 C49 18 58 26 58 35 C58 43 51 47 45 44 C50 40 47 31 40 32 C32 33 30 44 36 52 C38 55 40 56 42 57 L8 58 Z", c: C.tide }, { d: "M24 40 C24 30 30 24 38 24", c: C.tideHi, k: "line", w: 4 }],
  hall: [{ d: rr(14, 34, 36, 22, 2), c: C.cream }, { d: "M4 32 C10 31 14 26 18 18 L46 18 C50 26 54 31 60 32 L60 36 L4 36 Z", c: C.red }, { d: "M14 18 L50 18 L46 12 L18 12 Z", c: "#B8352E" }, { d: rr(27, 42, 10, 14, 2), c: C.wood, k: "flat" }, { d: rr(10, 54, 44, 6, 2), c: "#B9A88E" }],
  goal: [{ d: "M8 25 L34 25 L34 13 L57 32 L34 51 L34 39 L8 39 Z", c: C.gold }],
  x2: [{ d: drop(26, 30, .8), c: C.qi }, { d: "M24 33 C24 38 27 41 31 41", c: C.qiHi, k: "line", w: 3.5 }, { t: "x2", x: 44, y: 56, c: C.gold }],
  auto: [{ d: drop(30, 36, .72), c: C.qi }, { d: "M46 16 A22 22 0 0 1 50 46", c: C.gold, k: "arrow", w: 5 }, { d: "M16 50 A22 22 0 0 1 12 20", c: C.gold, k: "arrow", w: 5 }],
  vip: [{ d: "M8 22 L20 34 L32 12 L44 34 L56 22 L52 50 L12 50 Z", c: C.gold }, { d: rr(10, 48, 44, 10, 3), c: C.goldDk }, { d: circ(32, 37, 5), c: C.jade, k: "flat" }, { d: circ(8, 21, 4), c: C.gold }, { d: circ(32, 11, 4), c: C.gold }, { d: circ(56, 21, 4), c: C.gold }],
  hands: [{ d: HAND, c: C.gold, tr: "translate(7 0)" }],
  rebirth: [{ d: circ(32, 30, 26), c: C.red }, { d: circ(32, 30, 16), c: "#A9F3D2", k: "hole" }, { d: "M22 46 h7 v-6 h7 v-6 h7 v12 Z", c: C.cream }, { d: rr(4, 52, 56, 8, 3), c: C.wood }],
  like: [{ d: rr(6, 28, 13, 30, 3), c: C.blue }, { d: "M22 30 L30 12 C32 7 40 8 39 15 L37 26 L52 26 C57 26 59 30 58 35 L54 53 C53 56 50 58 47 58 L22 58 Z", c: C.jade }],
  invite: [{ d: "M6 58 C6 46 13 40 24 40 C35 40 42 46 42 58 Z", c: C.white }, { d: circ(24, 25, 11), c: C.white }, { d: "M50 14 v20 M40 24 h20", c: C.jade, k: "line", w: 7, ol: true }],
  group: [{ d: rr(10, 6, 6, 54, 3), c: C.wood }, { d: "M16 10 L54 10 L46 22 L54 34 L16 34 Z", c: C.purple }, { d: circ(31, 22, 5.5), c: C.gold, k: "flat" }],
  palm: [{ d: HAND, c: C.skin, tr: "translate(10 0)" }, { d: "M6 18 h7 M4 28 h8", c: C.cream, k: "line", w: 3.5 }],
  chest: [{ d: "M8 30 C8 18 18 12 32 12 C46 12 56 18 56 30 Z", c: C.red }, { d: rr(8, 30, 48, 26, 3), c: "#B8352E" }, { d: "M8 30 h48", c: INK, k: "line", w: 2.5 }, { d: rr(27, 25, 10, 13, 2.5), c: C.gold }],
};
NEW.altar = [ // the Heavenly Altar: a bronze ding (tripod cauldron) with a fire in it
  { d: "M32 3 C40 12 45 18 43 25 C42 29 37 31 32 31 C27 31 22 29 21 25 C19 18 24 12 32 3Z", c: "#FF7A3D" },
  { d: "M32 14 C36 19 38 22 37 26 C36 28 34 29 32 29 C30 29 28 28 27 26 C26 22 28 19 32 14Z", c: "#FFE36B", k: "flat" },
  { d: "M14 21 C14 15 20 15 20 21 M44 21 C44 15 50 15 50 21", c: "#E8B04A", k: "line", w: 4.5, ol: true },
  { d: "M18 50 L13 60 M46 50 L51 60 M32 52 L32 61", c: "#8A5A3C", k: "line", w: 6, ol: true },
  { d: "M9 27 L55 27 C55 42 46 52 32 52 C18 52 9 42 9 27Z", c: "#E8B04A" },
  { d: rr(7, 24, 50, 7, 3.5), c: "#F6C964" },
  { d: "M14 37 L50 37", c: "#B07A2A", k: "line", w: 3 },
];
// pill: a capsule rotated -35 (two halves)
NEW.pill = [{ d: "M32 20 L32 44 L20 44 A12 12 0 0 1 20 20 Z", c: C.red, tr: "rotate(-35 32 32) translate(0 0)" }, { d: "M32 20 L44 20 A12 12 0 0 1 44 44 L32 44 Z", c: C.cream, tr: "rotate(-35 32 32)" }, { d: "M19 27 C21 25 24 24 27 24", c: "#fff", k: "line", w: 3, tr: "rotate(-35 32 32)" }];


// packs of qi (shop): 1, 3, 6 drops, back to front
const PACK_AT = [[32, 40, .62], [18, 44, .5], [46, 44, .5], [25, 24, .44], [40, 22, .44], [32, 12, .38]];
const PACKS = {
  pack1: [[32, 36, 1]],
  pack2: [[19, 36, .62], [45, 36, .62], [32, 46, .68]],
  pack3: [[14, 26, .48], [32, 22, .5], [50, 26, .48], [20, 46, .55], [44, 46, .55], [32, 52, .58]],
};
for (const key in PACKS) NEW[key] = PACKS[key].map(([x, y, s]) => ({ d: drop(x, y, s), c: C.qi, sep: true }));
// Karma Shop nodes
const person = (x, y, s, robe) => [{ d: `M${x - 14 * s} ${y + 22 * s} C${x - 14 * s} ${y + 8 * s} ${x - 8 * s} ${y + 2 * s} ${x} ${y + 2 * s} C${x + 8 * s} ${y + 2 * s} ${x + 14 * s} ${y + 8 * s} ${x + 14 * s} ${y + 22 * s} Z`, c: robe }, { d: circ(x, y - 8 * s, 9 * s), c: C.skin }, { d: circ(x, y - 18 * s, 4.5 * s), c: INK }];
NEW.sworn = [...person(20, 34, .95, C.blue), ...person(44, 34, .95, C.red)];
NEW.seat = [{ d: "M6 50 C12 40 20 44 24 50 C26 38 38 38 40 50 C44 44 52 40 58 50 C52 58 12 58 6 50Z", c: "#FF8FB3" }, ...person(32, 30, 1, C.purple)];
NEW.foundation = NEW.hall;
NEW.elixir = NEW.pill;
NEW.meditation = [{ d: circ(32, 32, 22), c: C.gold }, { d: "M40 12 A22 22 0 0 1 40 52 A16 16 0 0 0 40 12Z", c: C.goldDk, k: "flat" }, { d: "M14 44 C20 40 26 40 32 44 C38 48 44 48 50 44", c: "#fff", k: "line", w: 3.5 }];
NEW.echo = [{ d: circ(22, 40, 15), c: C.karma }, { d: circ(42, 25, 18), c: C.karma }, { d: circ(36, 19, 5), c: C.karmaHi, k: "flat" }, { d: circ(17, 35, 4), c: C.karmaHi, k: "flat" }];

// Ranks (HUD teleport to the ranking wall, owner 2026-10-22): a gold cup with handles on a stand
NEW.trophy = [{ d: "M19 14 C8 13 7 30 21 33", c: C.gold, k: "line", w: 5, ol: true }, { d: "M45 14 C56 13 57 30 43 33", c: C.gold, k: "line", w: 5, ol: true },
  { d: rr(20, 49, 24, 10, 2), c: C.goldDk }, { d: rr(28, 38, 8, 13, 1), c: C.gold }, { d: "M15 9 H49 V22 C49 34 42 41 32 41 C22 41 15 34 15 22 Z", c: C.gold }, { d: circ(24, 17, 3), c: "#fff", k: "flat" }];

// Tide Bell (Shop, owner 2026-10-23, mock docs/art/mocks/shop_new_tiles_banner.html): a bronze-gold bell
// over a tide wave, a jade clapper. Cell 31 of the sheet
NEW.bell = [{ d: "M6 57 C14 53 18 61 26 57 C34 53 38 61 46 57 C52 54 56 59 58 57", c: C.tide, k: "line", w: 4.5, ol: true },
  { d: rr(28, 3, 8, 8, 2), c: C.gold }, { d: "M32 9 C20 9 16 17 16 27 V37 C16 40 13 41 11 42 V47 H53 V42 C51 41 48 40 48 37 V27 C48 17 44 9 32 9 Z", c: C.gold },
  { d: circ(32, 50, 4.5), c: C.jade }, { d: "M21 19 C20 24 20 31 21 37", c: "#FFF3C4", k: "line", w: 3 }];
const ORDER = ["qi", "karma", "robux", "shop", "disciple", "pill", "gift", "tide", "hall", "goal", "x2", "auto", "vip", "hands", "rebirth", "like", "invite", "group", "palm", "chest", "altar", "pack1", "pack2", "pack3", "sworn", "seat", "foundation", "elixir", "meditation", "echo", "trophy", "bell"];
const LABEL = { qi: "Qi", karma: "Karma", robux: "Robux", shop: "Shop", disciple: "Disciples", pill: "Pill", gift: "Gift", tide: "Tide", hall: "Realm", goal: "Next", x2: "2x Qi", auto: "Auto", vip: "VIP", hands: "Hands", rebirth: "Rebirth", like: "Like", invite: "Invite", group: "Group", palm: "Palm", chest: "Chest", pack1: "Pack 1", pack2: "Pack 3", pack3: "Pack 6", sworn: "Sworn", seat: "Seat", foundation: "Found.", elixir: "Elixir", meditation: "Medit.", echo: "Echo", trophy: "Ranks" };

LABEL.altar = "Altar";
LABEL.bell = "Bell";
let uid = 0;
function shade(c, f) { // f < 1 darker, > 1 lighter
  const n = parseInt(c.slice(1), 16); let r = n >> 16, g = (n >> 8) & 255, b = n & 255;
  const m = v => Math.max(0, Math.min(255, Math.round(f < 1 ? v * f : v + (255 - v) * (f - 1))));
  return "#" + [m(r), m(g), m(b)].map(v => v.toString(16).padStart(2, "0")).join("");
}
// finishes: A sticker (ink outline, flat + hard cel shade + one highlight), B gem (ink outline,
// smooth top-left light, gloss), C clean (no outline, flat two-tone, soft drop shadow)
function newIcon(key, style) {
  if (NEW[key] === "ROBUX") return `<svg viewBox="0 0 64 64"><image href="robux_color.png" x="2" y="2" width="60" height="60"/></svg>`;
  const parts = NEW[key];
  const ow = 4.5;
  let defs = "", under = "", body = "";
  for (const p of parts) {
    const tr = p.tr ? ` transform="${p.tr}"` : "";
    if (p.k === "skip") continue;
    if (p.t) {
      body += `<text x="${p.x}" y="${p.y}" text-anchor="middle" font-family="Fredoka One, Segoe UI Black, sans-serif" font-weight="900" font-size="24" fill="${p.c}" stroke="${INK}" stroke-width="${style === "C" ? 0 : 5}" paint-order="stroke" stroke-linejoin="round">${p.t}</text>`;
      continue;
    }
    if (p.k === "line" || p.k === "arrow") {
      const id = "m" + (++uid);
      const mark = p.k === "arrow" ? ` marker-end="url(#${id})"` : "";
      if (p.k === "arrow") defs += `<marker id="${id}" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="3" markerHeight="3" orient="auto"><path d="M0 0 L10 5 L0 10 Z" fill="${p.c}" stroke="${style === "C" ? "none" : INK}" stroke-width="2.4" stroke-linejoin="round"/></marker>`;
      if (style !== "C" && (p.k === "arrow" || p.ol)) under += `<path d="${p.d}" fill="none" stroke="${INK}" stroke-width="${p.w + ow * 2}" stroke-linecap="round"${tr}/>`;
      body += `<path d="${p.d}" fill="none" stroke="${p.c}" stroke-width="${p.w}" stroke-linecap="round"${mark}${tr} ${p.k === "line" && !p.ol ? 'stroke-opacity=".9"' : ""}/>`;
      continue;
    }
    const outlined = p.k !== "flat" && p.k !== "hole";
    if (style !== "C" && outlined) { const o = `<path d="${p.d}" fill="${INK}" stroke="${INK}" stroke-width="${ow * 2}" stroke-linejoin="round"${tr}/>`; if (p.sep) body += o; else under += o; }
    if (style === "C" && outlined) under += `<path d="${p.d}" fill="#000" fill-opacity=".18" transform="translate(0 3) ${p.tr || ""}"/>`;
    if (p.k === "hole" && style !== "C") body += `<path d="${p.d}" fill="none" stroke="${INK}" stroke-width="${ow}"${tr}/>`;
    const id = "g" + (++uid), cid = "c" + uid;
    defs += `<clipPath id="${cid}"><path d="${p.d}"${tr}/></clipPath>`;
    if (style === "A") {
      body += `<path d="${p.d}" fill="${p.c}"${tr}/>`;
      if (p.k !== "flat" && p.k !== "hole") body += `<g clip-path="url(#${cid})"><path d="${p.d}" fill="${shade(p.c, .78)}" transform="translate(5 6) ${p.tr || ""}" style="mix-blend-mode:normal" opacity="0"/><circle cx="58" cy="62" r="34" fill="${shade(p.c, .8)}"/></g>`;
    } else if (style === "B") {
      defs += `<linearGradient id="${id}" x1="0" y1="0" x2=".7" y2="1"><stop offset="0" stop-color="${shade(p.c, 1.35)}"/><stop offset=".55" stop-color="${p.c}"/><stop offset="1" stop-color="${shade(p.c, .68)}"/></linearGradient>`;
      body += `<path d="${p.d}" fill="url(#${id})"${tr}/>`;
      if (p.k !== "flat" && p.k !== "hole") body += `<g clip-path="url(#${cid})"><ellipse cx="22" cy="14" rx="22" ry="11" fill="#fff" fill-opacity=".38"/></g>`;
    } else {
      body += `<path d="${p.d}" fill="${p.c}"${tr}/>`;
      if (p.k !== "flat" && p.k !== "hole") body += `<g clip-path="url(#${cid})"><circle cx="60" cy="64" r="32" fill="${shade(p.c, .86)}"/></g>`;
    }
  }
  // one highlight per icon in A (top left), the set's shared mark
  return `<svg viewBox="-6 -6 76 76"><defs>${defs}</defs>${under}${body}</svg>`;
}

function board() {
  let h = `<div class="board"><div class="head">Icons: today (NOW) and three finishes of one new drawing set</div>
  <div class="note">A sticker: ink outline, flat colour, one hard shade. B gem: ink outline, light from the top left, gloss. C clean: no outline, flat two-tone. Robux = Roblox's own gold icon in every row.</div>`;
  for (const [tag, bg] of [["NOW", "sky"], ["A", "sky"], ["B", "sky"], ["C", "sky"], ["A", "dark"], ["B", "dark"], ["C", "dark"]]) {
    h += `<div class="row ${bg}"><div class="tag">${tag}</div>`;
    for (const k of ORDER) {
      const svg = tag === "NOW" ? nowIcon(NOW[k]) : newIcon(k, tag);
      h += `<div class="cell">${svg}<div class="lab">${LABEL[k]}</div></div>`;
    }
    h += `</div>`;
  }
  return h + "</div>";
}
function atlas() {
  const style = Q.get("style") || "A";
  let h = `<div class="atlas">`;
  ORDER.forEach((k, i) => {
    if (k === "robux") return;
    const s = newIcon(k, style).replace("<svg ", `<svg style="left:${(i % 8) * 128}px;top:${Math.floor(i / 8) * 128}px" `);
    h += s;
  });
  return h + "</div>";
}

