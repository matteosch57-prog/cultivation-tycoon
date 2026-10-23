// Flying Sword store icons, one look per grade (owner 2026-10-23: "icons for sword should show the
// difference of grade too"). Same glossy-disc language as the shop icons (draw_new.js): a lit disc, a
// gold ring, a drop shadow. Each grade steps up: blade, guard, glow, rays, halo, and 1 / 2 / 3 grade
// stars on the rim. node tools/shop_icons/sword_icons.js -> sword1.html .. sword3.html next to it; render each
// at 512 x 512 with a transparent background: msedge --headless=new --window-size=512,512
// --default-background-color=00000000 --screenshot=<png> file:///<html>. Shipped as swordJade / swordHeavenly /
// swordCelestial.png in art/shop_icons and upload/shop_icons.
const fs = require('fs');
const path = require('path');

const star = (x, y, s, c = '#fffbe6', o = 1) =>
  `<path d="M${x} ${y - s} C${x + s * .18} ${y - s * .18} ${x + s * .18} ${y - s * .18} ${x + s} ${y} C${x + s * .18} ${y + s * .18} ${x + s * .18} ${y + s * .18} ${x} ${y + s} C${x - s * .18} ${y + s * .18} ${x - s * .18} ${y + s * .18} ${x - s} ${y} C${x - s * .18} ${y - s * .18} ${x - s * .18} ${y - s * .18} ${x} ${y - s}Z" fill="${c}" opacity="${o}"/>`;
// a five-point grade star, gold with an ink rim
const gradeStar = (x, y, r) => {
  let d = '';
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r * .45 : r;
    d += (i ? 'L' : 'M') + (x + Math.cos(a) * rr).toFixed(1) + ' ' + (y + Math.sin(a) * rr).toFixed(1);
  }
  return `<path d="${d}Z" fill="url(#goldv)" stroke="#5e3204" stroke-width="5" stroke-linejoin="round"/>`;
};
const rays = (n, len, w, color, o) => `<g opacity="${o}">${[...Array(n)].map((_, i) => {
  const a = i * Math.PI * 2 / n;
  return `<path d="M256 256 L${256 + Math.cos(a - w) * len} ${256 + Math.sin(a - w) * len} L${256 + Math.cos(a + w) * len} ${256 + Math.sin(a + w) * len}Z" fill="${color}"/>`;
}).join('')}</g>`;

const BASE_DEFS = `
  <linearGradient id="ring" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3b8"/><stop offset=".5" stop-color="#e9a92c"/><stop offset="1" stop-color="#9b5c0a"/></linearGradient>
  <linearGradient id="goldv" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff6c4"/><stop offset=".45" stop-color="#f6c040"/><stop offset="1" stop-color="#b06a0c"/></linearGradient>
  <radialGradient id="jade" cx="38%" cy="32%" r="75%"><stop offset="0" stop-color="#f2fff9"/><stop offset=".3" stop-color="#8ff3cf"/><stop offset=".7" stop-color="#23b98a"/><stop offset="1" stop-color="#086146"/></radialGradient>
  <radialGradient id="ruby" cx="38%" cy="32%" r="75%"><stop offset="0" stop-color="#ffe2dc"/><stop offset=".35" stop-color="#ff5a4a"/><stop offset="1" stop-color="#6e0d08"/></radialGradient>
  <radialGradient id="sapphire" cx="38%" cy="32%" r="75%"><stop offset="0" stop-color="#ffffff"/><stop offset=".35" stop-color="#8fd8ff"/><stop offset="1" stop-color="#1b4f9e"/></radialGradient>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="10" stdDeviation="10" flood-color="#1a0d00" flood-opacity=".45"/></filter>
  <filter id="bloom" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="12"/></filter>
  <filter id="soft"><feGaussianBlur stdDeviation="5"/></filter>`;

const GRADES = [
  { // 1 Jade Jian: jade disc, a slim pale-jade blade, a plain jade guard, a soft wind trail
    disc: ['#dcfff0', '#33c79a', '#0a5c46'],
    defs: `<linearGradient id="blade" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#a6efd2"/><stop offset=".5" stop-color="#f4fffb"/><stop offset="1" stop-color="#5cc9a2"/></linearGradient>
      <linearGradient id="trail" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#dfffee" stop-opacity="0"/><stop offset="1" stop-color="#f2fff8" stop-opacity=".8"/></linearGradient>`,
    behind: () => `<path d="M70 430 C170 390 250 340 330 260" stroke="url(#trail)" stroke-width="46" stroke-linecap="round" fill="none" opacity=".7"/>`,
    blade: { w: 22, tip: 44, fill: 'url(#blade)', ink: '#0f3e31', edge: '#ffffff' },
    guard: `<rect x="200" y="336" width="112" height="24" rx="11" fill="url(#jade)" stroke="#07523d" stroke-width="9"/>`,
    grip: '#7a1f1a', pommel: 'url(#jade)', pommelInk: '#07523d', gem: null,
    front: () => `${star(400, 128, 24)}${star(130, 150, 14)}`,
  },
  { // 2 Heavenly Sword: gold disc, gold rays, a wide gold blade with a fuller, a winged red-gold guard,
    // two wound ribbons, a ruby, an ember trail, a red tassel
    disc: ['#fff4c8', '#f2a52a', '#8a4a06'],
    defs: `<linearGradient id="blade" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#b8730c"/><stop offset=".4" stop-color="#f2b32a"/><stop offset=".55" stop-color="#ffe08a"/><stop offset="1" stop-color="#8a4a06"/></linearGradient>
      <linearGradient id="trail" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#ff9a2e" stop-opacity="0"/><stop offset="1" stop-color="#ffd36b" stop-opacity=".9"/></linearGradient>`,
    behind: () => `${rays(10, 300, .09, '#fff1b0', .5)}<path d="M60 440 C170 395 250 340 330 258" stroke="url(#trail)" stroke-width="64" stroke-linecap="round" fill="none" opacity=".8"/>`,
    blade: { w: 32, tip: 52, fill: 'url(#blade)', ink: '#4a2100', edge: '#fff1b0', fuller: '#9a5a08' },
    guard: `<path d="M168 330 C196 318 220 332 256 332 C292 332 316 318 344 330 C352 346 340 362 322 360 C300 358 284 368 256 368 C228 368 212 358 190 360 C172 362 160 346 168 330Z" fill="url(#goldv)" stroke="#5e3204" stroke-width="9" stroke-linejoin="round"/>`,
    grip: '#8e1f1a', pommel: 'url(#goldv)', pommelInk: '#5e3204', gem: 'url(#ruby)',
    ribbons: [['#d23a2a', 0], ['#ffb52e', Math.PI]],
    tassel: true,
    front: () => `${star(410, 118, 30)}${star(118, 150, 20)}${star(420, 392, 16)}${star(160, 420, 12)}`,
  },
  { // 3 Celestial Crystal Sword: a deep night-blue disc, white rays, a double gold halo, a glowing
    // crystal blade, an ornate gold guard with a sapphire, three wound ribbons, a starry trail, twinkles
    disc: ['#2a3f8f', '#14246a', '#070c2c'], dark: true,
    defs: `<linearGradient id="blade" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8fd8ff"/><stop offset=".5" stop-color="#ffffff"/><stop offset="1" stop-color="#4f9dff"/></linearGradient>
      <linearGradient id="trail" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#9fd8ff" stop-opacity="0"/><stop offset=".6" stop-color="#cfeaff" stop-opacity=".8"/><stop offset="1" stop-color="#fff4c2" stop-opacity="1"/></linearGradient>
      <radialGradient id="aura" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#cfeaff" stop-opacity=".9"/><stop offset=".5" stop-color="#6fb6ff" stop-opacity=".35"/><stop offset="1" stop-color="#6fb6ff" stop-opacity="0"/></radialGradient>`,
    behind: () => `<circle cx="256" cy="256" r="230" fill="url(#aura)"/>${rays(16, 300, .05, '#e8f4ff', .45)}
      <g opacity=".95"><circle cx="256" cy="230" r="150" fill="none" stroke="url(#goldv)" stroke-width="14"/><circle cx="256" cy="230" r="124" fill="none" stroke="#fff6c4" stroke-width="5" opacity=".9"/></g>
      <path d="M50 450 C170 400 250 340 330 256" stroke="url(#trail)" stroke-width="80" stroke-linecap="round" fill="none" opacity=".85"/>
      ${[...Array(18)].map((_, i) => star(60 + (i * 97) % 400, 60 + (i * 151) % 400, 4 + (i % 4) * 2, '#ffffff', .8)).join('')}`,
    blade: { w: 30, tip: 56, fill: 'url(#blade)', ink: '#0c2350', edge: '#ffffff', glow: '#bfe6ff' },
    guard: `<path d="M160 334 L200 320 L224 334 L256 316 L288 334 L312 320 L352 334 L336 360 L296 352 L256 372 L216 352 L176 360Z" fill="url(#goldv)" stroke="#5e3204" stroke-width="9" stroke-linejoin="round"/>`,
    grip: '#2a3f8f', pommel: 'url(#sapphire)', pommelInk: '#0c2350', gem: 'url(#sapphire)',
    ribbons: [['#ffffff', 0], ['#8fd3ff', Math.PI * 2 / 3], ['#ffd34d', Math.PI * 4 / 3]],
    front: () => `${star(410, 110, 34)}${star(110, 140, 22)}${star(426, 380, 20)}${star(150, 430, 14)}${star(330, 70, 12)}`,
  },
];

function sword(g) {
  const b = g.blade;
  const x0 = 256 - b.w, x1 = 256 + b.w;
  let s = '';
  if (b.glow) s += `<path d="M256 ${40 - 10} L${x1 + 14} ${40 + b.tip} L${x1 + 14} 340 L${x0 - 14} 340 L${x0 - 14} ${40 + b.tip} Z" fill="${b.glow}" filter="url(#bloom)" opacity=".9"/>`;
  s += `<g filter="url(#shadow)"><path d="M256 40 L${x1} ${40 + b.tip} L${x1} 340 L${x0} 340 L${x0} ${40 + b.tip} Z" fill="${b.fill}" stroke="${b.ink}" stroke-width="11" stroke-linejoin="round"/></g>`;
  if (b.fuller) s += `<path d="M256 ${70 + b.tip} L256 326" stroke="${b.fuller}" stroke-width="9" stroke-linecap="round" opacity=".8"/>`;
  s += `<path d="M${256 - b.w * .35} ${60 + b.tip * .5} L${256 - b.w * .35} 328" stroke="${b.edge}" stroke-width="7" stroke-linecap="round" opacity=".8"/>`;
  for (const [c, ph] of g.ribbons || []) {
    let d = '';
    for (let k = 0; k <= 40; k++) {
      const f = k / 40, y = 330 - f * 270, x = 256 + Math.sin(ph + f * Math.PI * 4) * (b.w + 16) * (1 - f * .4);
      d += (k ? 'L' : 'M') + x.toFixed(1) + ' ' + y.toFixed(1);
    }
    s += `<path d="${d}" stroke="${c}" stroke-width="6" fill="none" stroke-linecap="round" opacity=".9"/>`;
  }
  s += `<g filter="url(#shadow)">${g.guard}</g>`;
  if (g.gem) s += `<circle cx="256" cy="346" r="14" fill="${g.gem}" stroke="#2a0705" stroke-width="5"/>`;
  s += `<rect x="240" y="366" width="32" height="74" rx="8" fill="${g.grip}" stroke="#1a0705" stroke-width="9"/>
    <path d="M244 386 L268 398 M244 410 L268 422" stroke="#00000055" stroke-width="5"/>
    <circle cx="256" cy="454" r="19" fill="${g.pommel}" stroke="${g.pommelInk}" stroke-width="8"/>`;
  if (g.tassel) s += `<path d="M256 472 C244 500 232 512 222 526 M256 472 C252 504 248 516 246 530" stroke="#e2462a" stroke-width="9" stroke-linecap="round" fill="none"/>`;
  return `<g transform="rotate(-38 256 256)">${s}</g>`;
}

function svg(g, grade) {
  const [l, m, d] = g.disc;
  const disc = g.dark
    ? `<radialGradient id="disc" cx="50%" cy="40%" r="62%"><stop offset="0" stop-color="${l}"/><stop offset=".55" stop-color="${m}"/><stop offset="1" stop-color="${d}"/></radialGradient>`
    : `<radialGradient id="disc" cx="50%" cy="38%" r="62%"><stop offset="0" stop-color="${l}"/><stop offset=".45" stop-color="${m}"/><stop offset="1" stop-color="${d}"/></radialGradient>`;
  let stars = '';
  for (let i = 0; i < grade; i++) stars += gradeStar(256 + (i - (grade - 1) / 2) * 46, 470, 22);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512"><defs>${BASE_DEFS}${disc}${g.defs}<clipPath id="cl"><circle cx="256" cy="256" r="228"/></clipPath></defs>
    <circle cx="256" cy="256" r="236" fill="url(#disc)"/>
    <g clip-path="url(#cl)">${g.behind()}${sword(g)}${g.front()}<ellipse cx="256" cy="118" rx="170" ry="66" fill="#fff" opacity=".16"/></g>
    <circle cx="256" cy="256" r="236" fill="none" stroke="url(#ring)" stroke-width="16"/>
    <circle cx="256" cy="256" r="222" fill="none" stroke="#fff" stroke-opacity=".25" stroke-width="3"/>
    ${stars}</svg>`;
}

GRADES.forEach((g, i) => {
  fs.writeFileSync(path.join(__dirname, `sword${i + 1}.html`), `<!doctype html><html><head><style>html,body{margin:0;background:transparent;overflow:hidden}</style></head><body>${svg(g, i + 1)}</body></html>`);
});
console.log('ok');
