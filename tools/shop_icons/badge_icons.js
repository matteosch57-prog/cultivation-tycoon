// Badge icons (docs/design/BADGES.md, owner 2026-10-23: "give me all icons + title and desc"). The shop
// icons' glossy-disc language (sword_icons.js): a lit disc, a gold ring, a painted subject with an ink
// rim, twinkles. Roblox crops a badge to a circle, so the disc fills the canvas and the subject stays in
// the middle 70%. node tools/shop_icons/badge_icons.js -> badge_<key>.html next to it; render each at
// 512 x 512: msedge --headless=new --window-size=512,512 --default-background-color=00000000
// --screenshot=<png> file:///<html>. Shipped in art/badges and upload/badges.
const fs = require('fs');
const path = require('path');

const INK = '#1a1020';
const star = (x, y, s, c = '#fffbe6', o = 1) =>
  `<path d="M${x} ${y - s} C${x + s * .18} ${y - s * .18} ${x + s * .18} ${y - s * .18} ${x + s} ${y} C${x + s * .18} ${y + s * .18} ${x + s * .18} ${y + s * .18} ${x} ${y + s} C${x - s * .18} ${y + s * .18} ${x - s * .18} ${y + s * .18} ${x - s} ${y} C${x - s * .18} ${y - s * .18} ${x - s * .18} ${y - s * .18} ${x} ${y - s}Z" fill="${c}" opacity="${o}"/>`;
const rays = (n, len, w, color, o, cx = 256, cy = 256) => `<g opacity="${o}">${[...Array(n)].map((_, i) => {
  const a = i * Math.PI * 2 / n;
  return `<path d="M${cx} ${cy} L${cx + Math.cos(a - w) * len} ${cy + Math.sin(a - w) * len} L${cx + Math.cos(a + w) * len} ${cy + Math.sin(a + w) * len}Z" fill="${color}"/>`;
}).join('')}</g>`;
const twinkles = (n, seed, c = '#ffffff', o = .8) =>
  [...Array(n)].map((_, i) => star(70 + ((i + seed) * 97) % 372, 70 + ((i + seed) * 151) % 372, 4 + (i % 4) * 2, c, o)).join('');

const DEFS = `
  <linearGradient id="ring" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3b8"/><stop offset=".5" stop-color="#e9a92c"/><stop offset="1" stop-color="#9b5c0a"/></linearGradient>
  <linearGradient id="goldv" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff6c4"/><stop offset=".45" stop-color="#f6c040"/><stop offset="1" stop-color="#b06a0c"/></linearGradient>
  <radialGradient id="jade" cx="38%" cy="32%" r="75%"><stop offset="0" stop-color="#f2fff9"/><stop offset=".3" stop-color="#8ff3cf"/><stop offset=".7" stop-color="#23b98a"/><stop offset="1" stop-color="#086146"/></radialGradient>
  <radialGradient id="orb" cx="40%" cy="34%" r="70%"><stop offset="0" stop-color="#fffbe6"/><stop offset=".35" stop-color="#ffd85a"/><stop offset=".8" stop-color="#e08a0c"/><stop offset="1" stop-color="#8a4a06"/></radialGradient>
  <linearGradient id="lacq" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d9473a"/><stop offset="1" stop-color="#7e1a15"/></linearGradient>
  <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3fa58a"/><stop offset="1" stop-color="#145a4c"/></linearGradient>
  <linearGradient id="stone" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#efe6d6"/><stop offset="1" stop-color="#a8977d"/></linearGradient>
  <linearGradient id="lantern" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#b3221a"/><stop offset=".5" stop-color="#ff6a3d"/><stop offset="1" stop-color="#b3221a"/></linearGradient>
  <radialGradient id="glowW" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#fff6d0" stop-opacity=".95"/><stop offset=".5" stop-color="#ffd36b" stop-opacity=".4"/><stop offset="1" stop-color="#ffd36b" stop-opacity="0"/></radialGradient>
  <radialGradient id="glowB" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#e8fbff" stop-opacity=".95"/><stop offset=".5" stop-color="#8fd8ff" stop-opacity=".4"/><stop offset="1" stop-color="#8fd8ff" stop-opacity="0"/></radialGradient>
  <radialGradient id="glowV" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#f3e4ff" stop-opacity=".95"/><stop offset=".5" stop-color="#b47bff" stop-opacity=".45"/><stop offset="1" stop-color="#b47bff" stop-opacity="0"/></radialGradient>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="10" stdDeviation="10" flood-color="#1a0d00" flood-opacity=".45"/></filter>
  <filter id="bloom" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="12"/></filter>`;

// a qi drop (the game's currency mark), centre (x, y), height ~2.4 s
const qiDrop = (x, y, s) => `<g transform="translate(${x} ${y}) scale(${s / 50})">
  <path d="M0 -70 C26 -34 48 -6 48 20 A48 48 0 0 1 -48 20 C-48 -6 -26 -34 0 -70Z" fill="url(#jade)" stroke="${INK}" stroke-width="9" stroke-linejoin="round"/>
  <path d="M18 2 C30 14 26 36 8 44" stroke="#f2fff9" stroke-width="9" stroke-linecap="round" fill="none" opacity=".9"/>
  <circle cx="-16" cy="-4" r="8" fill="#fff" opacity=".85"/></g>`;

// a cultivator in robes: head (x, y), scale s, robe colour pair; hands joined at the chest (a bow)
const figure = (x, y, s, robe, robeDark, opts = {}) => {
  const halo = opts.halo ? `<circle cx="0" cy="-6" r="62" fill="none" stroke="url(#goldv)" stroke-width="10"/>` : '';
  return `<g transform="translate(${x} ${y}) scale(${s})" filter="url(#shadow)">${halo}
  <path d="M-78 182 C-74 110 -54 66 0 60 C54 66 74 110 78 182 Z" fill="${robe}" stroke="${INK}" stroke-width="9" stroke-linejoin="round"/>
  <path d="M-78 182 C-74 150 -60 128 -40 120 L-30 182Z" fill="${robeDark}" opacity=".55"/>
  <path d="M-26 64 L0 112 L26 64" fill="#fff8ec" stroke="${INK}" stroke-width="7" stroke-linejoin="round"/>
  <path d="M-30 140 C-12 126 12 126 30 140" stroke="${robeDark}" stroke-width="12" fill="none" stroke-linecap="round"/>
  <ellipse cx="0" cy="124" rx="20" ry="16" fill="#f1c9a0" stroke="${INK}" stroke-width="7"/>
  <circle cx="0" cy="0" r="46" fill="#f1c9a0" stroke="${INK}" stroke-width="9"/>
  <path d="M-46 -2 C-46 -40 -20 -50 0 -50 C20 -50 46 -40 46 -2 C34 -22 14 -28 0 -26 C-14 -28 -34 -22 -46 -2Z" fill="#2a1a24" stroke="${INK}" stroke-width="7" stroke-linejoin="round"/>
  <circle cx="0" cy="-60" r="20" fill="#2a1a24" stroke="${INK}" stroke-width="7"/>
  <rect x="-24" y="-66" width="48" height="10" rx="5" fill="url(#goldv)" stroke="${INK}" stroke-width="4"/>
  <path d="M-20 10 Q-14 15 -8 10 M8 10 Q14 15 20 10" stroke="${INK}" stroke-width="5" stroke-linecap="round" fill="none"/>
  <ellipse cx="-24" cy="22" rx="8" ry="5" fill="#ff8f8f" opacity=".55"/><ellipse cx="24" cy="22" rx="8" ry="5" fill="#ff8f8f" opacity=".55"/>
  </g>`;
};

// a hall: centre x, ground y, scale s; `tiers` roofs (1 or 2), lit doorway at dusk
const hall = (x, y, s, tiers = 1, opts = {}) => {
  const roof = (ry, w, h) => `<path d="M${-w} ${ry} C${-w + 18} ${ry - 4} ${-w * .7} ${ry - h * .55} ${-w * .55} ${ry - h} L${w * .55} ${ry - h} C${w * .7} ${ry - h * .55} ${w - 18} ${ry - 4} ${w} ${ry} C${w * .55} ${ry - 12} ${-w * .55} ${ry - 12} ${-w} ${ry}Z" fill="url(#tile)" stroke="${INK}" stroke-width="9" stroke-linejoin="round"/>
    <path d="M${-w * .55} ${ry - h} L${w * .55} ${ry - h}" stroke="url(#goldv)" stroke-width="10" stroke-linecap="round"/>`;
  let s2 = `<rect x="-120" y="-24" width="240" height="24" rx="4" fill="url(#stone)" stroke="${INK}" stroke-width="8"/>
    <rect x="-92" y="-104" width="184" height="82" fill="url(#lacq)" stroke="${INK}" stroke-width="8"/>
    <rect x="-24" y="-80" width="48" height="58" rx="4" fill="${opts.lit ? '#ffd36b' : '#4a120e'}" stroke="${INK}" stroke-width="7"/>
    ${[-74, -46, 46, 74].map((px) => `<rect x="${px - 6}" y="-104" width="12" height="82" fill="#5e140f" opacity=".6"/>`).join('')}
    ${roof(-100, 128, 46)}`;
  if (tiers > 1) s2 += `<rect x="-58" y="-180" width="116" height="40" fill="url(#lacq)" stroke="${INK}" stroke-width="8"/>${roof(-140, 92, 40)}${roof(-178, 66, 36)}`;
  return `<g transform="translate(${x} ${y}) scale(${s})" filter="url(#shadow)">${s2}</g>`;
};

const lantern = (x, y, s) => `<g transform="translate(${x} ${y}) scale(${s})">
  <circle cx="0" cy="0" r="40" fill="url(#glowW)"/>
  <line x1="0" y1="-46" x2="0" y2="-30" stroke="${INK}" stroke-width="5"/>
  <rect x="-12" y="-32" width="24" height="8" rx="3" fill="url(#goldv)" stroke="${INK}" stroke-width="4"/>
  <ellipse cx="0" cy="0" rx="22" ry="26" fill="url(#lantern)" stroke="${INK}" stroke-width="6"/>
  <path d="M-8 -22 C-14 -6 -14 6 -8 22 M8 -22 C14 -6 14 6 8 22" stroke="#7e1a15" stroke-width="3" fill="none"/>
  <rect x="-12" y="24" width="24" height="8" rx="3" fill="url(#goldv)" stroke="${INK}" stroke-width="4"/>
  <path d="M0 32 L0 50" stroke="#ffb52e" stroke-width="5" stroke-linecap="round"/></g>`;

const lotus = (x, y, s, petal, petalDark) => {
  const p = (a, len, w) => `<path d="M0 0 C${-w} ${-len * .4} ${-w * .6} ${-len * .85} 0 ${-len} C${w * .6} ${-len * .85} ${w} ${-len * .4} 0 0Z" transform="rotate(${a})" fill="${petal}" stroke="${INK}" stroke-width="7" stroke-linejoin="round"/>`;
  return `<g transform="translate(${x} ${y}) scale(${s})" filter="url(#shadow)">
    <ellipse cx="0" cy="8" rx="120" ry="26" fill="url(#jade)" stroke="${INK}" stroke-width="8"/>
    ${p(-70, 96, 34)}${p(70, 96, 34)}${p(-40, 116, 38)}${p(40, 116, 38)}${p(0, 130, 40)}
    <path d="M0 -6 C-10 -50 -6 -90 0 -118" stroke="${petalDark}" stroke-width="6" fill="none" opacity=".5"/></g>`;
};

const seal = (x, y, r, label) => `<g filter="url(#shadow)"><circle cx="${x}" cy="${y}" r="${r}" fill="url(#goldv)" stroke="#5e3204" stroke-width="8"/>
  <text x="${x}" y="${y + r * .36}" text-anchor="middle" font-family="Georgia, 'Times New Roman', serif" font-weight="700" font-size="${r * 1.05}" fill="#5e3204">${label}</text></g>`;

const BADGES = [
  { key: 'founder', name: 'Sect Founder', desc: 'Raise the first building of your sect.',
    disc: ['#dcfff0', '#33c79a', '#0a5c46'],
    art: () => `${rays(12, 300, .07, '#f2fff8', .35)}<ellipse cx="256" cy="372" rx="170" ry="42" fill="url(#jade)" stroke="${INK}" stroke-width="9"/>
      ${hall(256, 360, 1.15)}${star(400, 130, 26)}${star(118, 160, 16)}${star(410, 300, 12)}` },
  { key: 'disciple', name: 'First Disciple', desc: 'Welcome your first disciple.',
    disc: ['#e3f1ff', '#4f9dff', '#15407e'],
    art: () => `${rays(12, 300, .07, '#e8f4ff', .35)}<circle cx="256" cy="250" r="150" fill="url(#glowB)"/>
      ${figure(256, 188, 1.25, '#5fb8ff', '#1f5fa8')}${star(392, 130, 24)}${star(124, 168, 16)}` },
  { key: 'realm2', name: 'Foundation Laid', desc: 'Break through to Foundation Establishment.',
    disc: ['#ffe3f0', '#ff7fb6', '#8a1f56'],
    art: () => `${rays(14, 300, .06, '#fff0f7', .4)}<circle cx="256" cy="250" r="150" fill="url(#glowW)" opacity=".7"/>
      ${lotus(256, 350, 1.25, '#ffd0e4', '#c2457e')}${seal(256, 236, 54, 'II')}${star(400, 120, 26)}${star(110, 170, 16)}` },
  { key: 'realm3', name: 'Golden Core', desc: 'Form your Golden Core.',
    disc: ['#fff4c8', '#f2a52a', '#8a4a06'],
    art: () => `${rays(18, 300, .07, '#fff6c4', .55)}<circle cx="256" cy="256" r="170" fill="url(#glowW)"/>
      <g filter="url(#shadow)"><circle cx="256" cy="256" r="96" fill="url(#orb)" stroke="#5e3204" stroke-width="10"/></g>
      <ellipse cx="226" cy="220" rx="34" ry="22" fill="#fff" opacity=".7" transform="rotate(-30 226 220)"/>
      <circle cx="256" cy="256" r="128" fill="none" stroke="url(#goldv)" stroke-width="8" stroke-dasharray="18 14"/>
      ${star(400, 120, 30)}${star(116, 150, 18)}${star(404, 400, 14)}` },
  { key: 'streak7', name: 'Loyal Cultivator', desc: 'Return for 7 days of Daily Blessings.',
    disc: ['#4a3a8f', '#2a1f63', '#120c33'], dark: true,
    art: () => `${twinkles(14, 3)}<path d="M108 168 C180 246 332 246 404 168" stroke="#e9a92c" stroke-width="7" fill="none"/>
      ${[0, 1, 2, 3, 4, 5, 6].map((i) => { const t = i / 6, x = 130 + t * 252, y = 196 + Math.sin(t * Math.PI) * 44; return lantern(x, y, i === 3 ? 1.05 : .88); }).join('')}
      ${seal(256, 356, 60, '7')}` },
  { key: 'elder', name: "Elder's Favour", desc: 'Recruit an Elder or rarer.',
    disc: ['#f1e2ff', '#a565ff', '#45178a'],
    art: () => `${rays(16, 300, .06, '#f3e4ff', .45)}<circle cx="256" cy="250" r="180" fill="url(#glowV)"/>
      ${figure(256, 186, 1.2, '#b47bff', '#5a239e', { halo: true })}${star(394, 120, 28)}${star(116, 160, 18)}${star(400, 392, 14)}` },
  { key: 'realm4', name: 'Nascent Soul', desc: 'Awaken your Nascent Soul.',
    disc: ['#2a5f8f', '#163a6a', '#07162c'], dark: true,
    art: () => `${twinkles(16, 7)}${hall(256, 420, .9)}
      <circle cx="256" cy="196" r="120" fill="url(#glowB)"/>
      <g opacity=".95">${figure(256, 160, .78, '#e8fbff', '#8fd8ff', { halo: true })}</g>
      <path d="M256 290 C236 320 270 340 250 372" stroke="#cfeaff" stroke-width="8" fill="none" stroke-linecap="round" opacity=".6"/>
      ${star(392, 110, 26)}${star(120, 140, 16)}` },
  { key: 'friends', name: 'Sect of Friends', desc: 'Cultivate beside a friend.',
    disc: ['#ffe8c4', '#ff9a2e', '#8a3b05'],
    art: () => `${rays(12, 300, .07, '#fff1d6', .4)}${figure(178, 204, .98, '#33c79a', '#0a6a50')}${figure(334, 204, .98, '#ff6a52', '#8e1f1a')}
      <g filter="url(#shadow)"><path d="M256 132 C240 110 206 118 210 146 C214 170 256 188 256 188 C256 188 298 170 302 146 C306 118 272 110 256 132Z" fill="#ff5a6e" stroke="${INK}" stroke-width="8" stroke-linejoin="round"/></g>
      ${star(410, 110, 22)}${star(100, 130, 16)}` },
  { key: 'realm10', name: 'True Immortal', desc: 'Ascend to True Immortal, the tenth realm.',
    disc: ['#ffc88a', '#c2457e', '#2a1452'], dusk: true,
    art: () => `<circle cx="256" cy="250" r="150" fill="#ffd27a" opacity=".6" filter="url(#bloom)"/>${rays(14, 300, .05, '#ffe6b0', .3, 256, 300)}
      ${twinkles(8, 11, '#fff6d0', .7)}
      <path d="M20 380 C120 350 180 360 256 370 C340 360 400 350 492 380 L492 520 L20 520Z" fill="#3a1f5c" opacity=".75"/>
      ${hall(256, 392, 1.32, 2, { lit: true })}${star(396, 110, 28)}${star(112, 140, 18)}` },
  { key: 'reborn', name: 'Reborn', desc: 'Start a new life through reincarnation.',
    disc: ['#ffd9dc', '#e2323f', '#6a0d16'],
    art: () => {
      let flames = '';
      for (let i = 0; i < 16; i++) {
        const a = i / 16 * Math.PI * 2, r = 150, x = 256 + Math.cos(a) * r, y = 256 + Math.sin(a) * r;
        flames += `<path d="M0 0 C-16 -18 -10 -40 0 -58 C10 -40 16 -18 0 0Z" transform="translate(${x.toFixed(1)} ${y.toFixed(1)}) rotate(${(a * 180 / Math.PI + 90 + 30).toFixed(1)})" fill="${i % 2 ? '#ffb52e' : '#ff6a3d'}" stroke="#6e1208" stroke-width="5"/>`;
      }
      return `${rays(14, 300, .06, '#ffe6d0', .4)}<circle cx="256" cy="256" r="150" fill="none" stroke="#ff9a2e" stroke-width="22" opacity=".6" filter="url(#bloom)"/>
        <g filter="url(#shadow)">${flames}<circle cx="256" cy="256" r="150" fill="none" stroke="url(#goldv)" stroke-width="12"/></g>
        <path d="M150 170 C190 120 250 110 300 130 L284 104 M300 130 L270 140" stroke="#fff6c4" stroke-width="10" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
        <path d="M362 342 C322 392 262 402 212 382 L228 408 M212 382 L242 372" stroke="#fff6c4" stroke-width="10" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
        ${qiDrop(256, 262, 50)}${star(410, 100, 24)}${star(100, 410, 16)}`;
    } },
];

function svg(b) {
  const [l, m, d] = b.disc;
  const disc = b.dusk
    ? `<linearGradient id="disc" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="${l}"/><stop offset=".45" stop-color="${m}"/><stop offset="1" stop-color="${d}"/></linearGradient>`
    : `<radialGradient id="disc" cx="50%" cy="${b.dark ? 40 : 38}%" r="62%"><stop offset="0" stop-color="${l}"/><stop offset="${b.dark ? .55 : .45}" stop-color="${m}"/><stop offset="1" stop-color="${d}"/></radialGradient>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512"><defs>${DEFS}${disc}<clipPath id="cl"><circle cx="256" cy="256" r="240"/></clipPath></defs>
    <circle cx="256" cy="256" r="248" fill="url(#disc)"/>
    <g clip-path="url(#cl)">${b.art()}<ellipse cx="256" cy="110" rx="180" ry="66" fill="#fff" opacity=".14"/></g>
    <circle cx="256" cy="256" r="246" fill="none" stroke="url(#ring)" stroke-width="16"/>
    <circle cx="256" cy="256" r="232" fill="none" stroke="#fff" stroke-opacity=".25" stroke-width="3"/></svg>`;
}

BADGES.forEach((b) => {
  fs.writeFileSync(path.join(__dirname, `badge_${b.key}.html`), `<!doctype html><html><head><style>html,body{margin:0;background:transparent;overflow:hidden}</style></head><body>${svg(b)}</body></html>`);
});
fs.writeFileSync(path.join(__dirname, 'badges.json'), JSON.stringify(BADGES.map((b) => ({ key: b.key, name: b.name, desc: b.desc })), null, 2));
console.log('ok');
