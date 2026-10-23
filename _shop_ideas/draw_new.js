// Shop product icons, round 2: glossy painted items + real disciple renders, transparent 512 PNGs.
// node draw.js <style> <outdir>   style = glow | disc
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const style = process.argv[2] || 'glow';
const OUT = process.argv[3] || path.join(__dirname, 'out_' + style);
fs.mkdirSync(OUT, { recursive: true });
const FONT = fs.readFileSync(path.join(__dirname, 'fred3.ttf')).toString('base64');
const DIS = {};

// one colour family per item: [light, mid, dark]
const FAM = {
  jade: ['#d9fff0', '#33c79a', '#0a6a50'],
  gold: ['#fff4c2', '#f3b733', '#9a5a08'],
  red: ['#ffd7b8', '#e2462a', '#6e1208'],
  violet: ['#f1e2ff', '#a565ff', '#45178a'],
  cyan: ['#e4feff', '#46d8e6', '#0d6a7a'],
  crimson: ['#ffd9dc', '#e2323f', '#6a0d16'],
  orange: ['#ffe8c4', '#ff9a2e', '#8a3b05'],
  sky: ['#e3f1ff', '#4f9dff', '#15407e'],
  pink: ['#ffe3f6', '#ff6edc', '#7a1466'],
};

const defs = (fam) => {
  const [l, m, d] = FAM[fam];
  return `
  <radialGradient id="glow" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="${m}" stop-opacity=".85"/><stop offset=".45" stop-color="${m}" stop-opacity=".35"/><stop offset="1" stop-color="${m}" stop-opacity="0"/></radialGradient>
  <radialGradient id="disc" cx="50%" cy="38%" r="62%"><stop offset="0" stop-color="${l}"/><stop offset=".45" stop-color="${m}"/><stop offset="1" stop-color="${d}"/></radialGradient>
  <radialGradient id="discD" cx="50%" cy="46%" r="58%"><stop offset="0" stop-color="#1c1426"/><stop offset=".55" stop-color="${d}"/><stop offset=".92" stop-color="${m}"/><stop offset="1" stop-color="${l}"/></radialGradient>
  <linearGradient id="ring" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3b8"/><stop offset=".5" stop-color="#e9a92c"/><stop offset="1" stop-color="#9b5c0a"/></linearGradient>
  <radialGradient id="jade" cx="38%" cy="32%" r="75%"><stop offset="0" stop-color="#f2fff9"/><stop offset=".3" stop-color="#8ff3cf"/><stop offset=".7" stop-color="#23b98a"/><stop offset="1" stop-color="#086146"/></radialGradient>
  <linearGradient id="goldv" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff6c4"/><stop offset=".45" stop-color="#f6c040"/><stop offset="1" stop-color="#b06a0c"/></linearGradient>
  <radialGradient id="pill" cx="36%" cy="30%" r="78%"><stop offset="0" stop-color="#fff1c8"/><stop offset=".25" stop-color="#ffab4a"/><stop offset=".65" stop-color="#d23417"/><stop offset="1" stop-color="#5e0c04"/></radialGradient>
  <linearGradient id="lacq" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c33a2e"/><stop offset=".55" stop-color="#8e1f1a"/><stop offset="1" stop-color="#4d0f0b"/></linearGradient>
  <linearGradient id="silk" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff6a52"/><stop offset=".5" stop-color="#d4261c"/><stop offset="1" stop-color="#6c0e0a"/></linearGradient>
  <radialGradient id="spill" cx="50%" cy="100%" r="80%"><stop offset="0" stop-color="#eafff6" stop-opacity="1"/><stop offset=".35" stop-color="#5ff0c0" stop-opacity=".8"/><stop offset="1" stop-color="#2fd6a0" stop-opacity="0"/></radialGradient>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="10" stdDeviation="10" flood-color="#1a0d00" flood-opacity=".45"/></filter>
  <filter id="soft"><feGaussianBlur stdDeviation="14"/></filter>`;
};

// sparkles: 4-point stars
const star = (x, y, s, c = '#fffbe6', o = 1) =>
  `<path d="M${x} ${y - s} C${x + s * .18} ${y - s * .18} ${x + s * .18} ${y - s * .18} ${x + s} ${y} C${x + s * .18} ${y + s * .18} ${x + s * .18} ${y + s * .18} ${x} ${y + s} C${x - s * .18} ${y + s * .18} ${x - s * .18} ${y + s * .18} ${x - s} ${y} C${x - s * .18} ${y - s * .18} ${x - s * .18} ${y - s * .18} ${x} ${y - s}Z" fill="${c}" opacity="${o}"/>`;

const orb = (x, y, r) => `
  <g filter="url(#shadow)"><circle cx="${x}" cy="${y}" r="${r}" fill="url(#jade)" stroke="#075540" stroke-width="${Math.max(4, r * .12)}"/></g>
  <ellipse cx="${x - r * .32}" cy="${y - r * .38}" rx="${r * .34}" ry="${r * .2}" fill="#fff" opacity=".85" transform="rotate(-30 ${x - r * .32} ${y - r * .38})"/>`;

const drop = (tx = 0, ty = 0, s = 1) => `
  <g transform="translate(${tx} ${ty}) scale(${s})" >
    <g filter="url(#shadow)"><path d="M256 62 C300 136 384 214 384 304 A128 128 0 0 1 128 304 C128 214 212 136 256 62Z" fill="url(#jade)" stroke="#07523d" stroke-width="13" stroke-linejoin="round"/></g>
    <path d="M196 238 C206 196 228 160 252 124" stroke="#fff" stroke-width="20" stroke-linecap="round" fill="none" opacity=".8"/>
    <circle cx="186" cy="282" r="11" fill="#fff" opacity=".75"/>
    <path d="M300 300 C326 338 304 384 258 388" stroke="#effff8" stroke-width="15" stroke-linecap="round" fill="none" opacity=".7"/>
  </g>`;

const chest = (tx, ty, s, open = true) => `
  <g transform="translate(${tx} ${ty}) scale(${s})">
    ${open ? `<path d="M118 238 L150 128 L362 128 L394 238 Z" fill="#5e1411" stroke="#2a0705" stroke-width="10" stroke-linejoin="round"/>
    <path d="M134 232 L160 142 L352 142 L378 232 Z" fill="#2a0e0c"/>
    <ellipse cx="256" cy="222" rx="150" ry="70" fill="url(#spill)"/>` : ''}
    <g filter="url(#shadow)"><rect x="112" y="232" width="288" height="170" rx="18" fill="url(#lacq)" stroke="#2a0705" stroke-width="11"/></g>
    <rect x="164" y="236" width="26" height="162" fill="url(#goldv)"/><rect x="322" y="236" width="26" height="162" fill="url(#goldv)"/>
    <rect x="112" y="232" width="288" height="26" rx="10" fill="url(#goldv)" stroke="#6b3a06" stroke-width="5"/>
    <rect x="216" y="276" width="80" height="70" rx="14" fill="#6fd6ae" stroke="#0f5a43" stroke-width="7"/>
    <circle cx="256" cy="320" r="14" fill="none" stroke="#e7c35a" stroke-width="7"/>
    <path d="M128 262 L128 300" stroke="#ff8a74" stroke-width="8" stroke-linecap="round" opacity=".55"/>
  </g>`;


const lotus = (x, y, s, gold) => {
  const petal = gold ? 'url(#goldv)' : 'url(#pinkp)'; const st = gold ? '#5e3204' : '#7a1466';
  let g = '';
  for (const [dx, rot] of [[-70, -38], [70, 38], [-38, -16], [38, 16], [0, 0]]) g += `<path d="M${x + dx * s} ${y} C${x + dx * s - 34 * s} ${y - 60 * s} ${x + dx * s - 10 * s} ${y - 104 * s} ${x + dx * s} ${y - 118 * s} C${x + dx * s + 10 * s} ${y - 104 * s} ${x + dx * s + 34 * s} ${y - 60 * s} ${x + dx * s} ${y}Z" fill="${petal}" stroke="${st}" stroke-width="${9 * s}" stroke-linejoin="round" transform="rotate(${rot} ${x + dx * s} ${y})"/>`;
  return `<g filter="url(#shadow)"><ellipse cx="${x}" cy="${y + 8 * s}" rx="${120 * s}" ry="${34 * s}" fill="url(#jade)" stroke="#07523d" stroke-width="${10 * s}"/>${g}</g>
    <ellipse cx="${x}" cy="${y - 6 * s}" rx="${70 * s}" ry="${16 * s}" fill="#fff" opacity=".22"/>`;
};
const ITEMS = {
  seats: { fam: 'gold', art: () => `
      ${lotus(170, 360, .82, false)}${lotus(342, 360, .82, false)}
      <text x="256" y="230" text-anchor="middle" font-family="F" font-size="176" fill="url(#goldv)" stroke="#4a2100" stroke-width="24" stroke-linejoin="round" paint-order="stroke">+2</text>
      <text x="256" y="230" text-anchor="middle" font-family="F" font-size="176" fill="none" stroke="#fff8d0" stroke-width="3" opacity=".6">+2</text>
      ${star(420, 120, 26)}${star(92, 150, 18)}${star(256, 450, 14)}`,
    extra: `<linearGradient id="pinkp" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff0fa"/><stop offset=".55" stop-color="#ff9fdc"/><stop offset="1" stop-color="#d2479f"/></linearGradient>` },
  tidebell: { fam: 'sky', art: () => `
      <circle cx="256" cy="300" r="186" fill="none" stroke="#bff7ff" stroke-width="10" opacity=".35"/>
      <circle cx="256" cy="300" r="150" fill="none" stroke="#bff7ff" stroke-width="12" opacity=".55"/>
      <path d="M90 420 C150 380 200 450 256 410 C312 370 362 440 422 400" stroke="#9ff7d8" stroke-width="18" fill="none" stroke-linecap="round" opacity=".85"/>
      <rect x="236" y="66" width="40" height="44" rx="10" fill="url(#goldv)" stroke="#4a2a04" stroke-width="10"/>
      <g filter="url(#shadow)"><path d="M256 96 C176 96 150 160 150 230 L150 320 C150 336 132 344 120 352 L120 372 L392 372 L392 352 C380 344 362 336 362 320 L362 230 C362 160 336 96 256 96Z" fill="url(#bronze)" stroke="#3b2205" stroke-width="13" stroke-linejoin="round"/></g>
      <path d="M150 250 L362 250 M150 290 L362 290" stroke="#3b2205" stroke-width="8" opacity=".55"/>
      ${[0,1,2].map(i=>`<circle cx="${206 + i*50}" cy="200" r="11" fill="#ffe07a" stroke="#3b2205" stroke-width="5"/>`).join('')}
      <circle cx="256" cy="392" r="22" fill="url(#jade)" stroke="#07523d" stroke-width="8"/>
      <path d="M180 140 C170 180 170 240 174 300" stroke="#fff6cc" stroke-width="12" stroke-linecap="round" fill="none" opacity=".7"/>
      ${star(410, 130, 26)}${star(100, 180, 18)}`,
    extra: `<linearGradient id="bronze" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffe7a0"/><stop offset=".35" stop-color="#d79a2a"/><stop offset=".75" stop-color="#8a5310"/><stop offset="1" stop-color="#4a2a04"/></linearGradient>` },
  starter: { fam: 'red', art: () => `
      <g opacity=".7">${[...Array(12)].map((_, i) => { const a = i * Math.PI / 6; return `<path d="M256 250 L${256 + Math.cos(a - .09) * 300} ${250 + Math.sin(a - .09) * 300} L${256 + Math.cos(a + .09) * 300} ${250 + Math.sin(a + .09) * 300}Z" fill="#ffd9b0" opacity=".45"/>`; }).join('')}</g>
      <g filter="url(#shadow)"><rect x="118" y="206" width="276" height="200" rx="22" fill="url(#silk)" stroke="#3c0603" stroke-width="13"/>
      <rect x="100" y="166" width="312" height="66" rx="18" fill="url(#silk)" stroke="#3c0603" stroke-width="13"/></g>
      <rect x="230" y="166" width="52" height="240" fill="url(#goldv)" stroke="#6b3a06" stroke-width="6"/>
      <path d="M256 166 C206 96 150 116 176 160 C190 176 230 170 256 166Z M256 166 C306 96 362 116 336 160 C322 176 282 170 256 166Z" fill="url(#goldv)" stroke="#5e3204" stroke-width="9" stroke-linejoin="round"/>
      ${orb(150, 132, 30)}${orb(372, 122, 34)}
      <path d="M140 240 L140 380" stroke="#ff9d8a" stroke-width="9" stroke-linecap="round" opacity=".55"/>
      ${star(420, 250, 26)}${star(84, 300, 18)}${star(330, 450, 14)}` },
  sword: { fam: 'cyan', art: () => `
      <path d="M70 420 C170 380 250 330 330 250" stroke="url(#qitrail)" stroke-width="70" stroke-linecap="round" fill="none" opacity=".75"/>
      <g transform="rotate(-38 256 256)" filter="url(#shadow)">
        <path d="M256 40 L282 92 L282 340 L230 340 L230 92 Z" fill="url(#steel)" stroke="#14303a" stroke-width="11" stroke-linejoin="round"/>
        <path d="M256 60 L256 330" stroke="#ffffff" stroke-width="7" opacity=".75"/>
        <rect x="186" y="336" width="140" height="30" rx="12" fill="url(#goldv)" stroke="#5e3204" stroke-width="9"/>
        <circle cx="256" cy="351" r="12" fill="url(#jade)" stroke="#07523d" stroke-width="5"/>
        <rect x="240" y="364" width="32" height="74" rx="8" fill="#7a1f1a" stroke="#2a0705" stroke-width="9"/>
        <circle cx="256" cy="452" r="18" fill="url(#goldv)" stroke="#5e3204" stroke-width="8"/>
        <path d="M256 470 C240 500 226 510 214 520" stroke="#e2462a" stroke-width="10" stroke-linecap="round" fill="none"/>
      </g>
      ${star(410, 120, 28)}${star(120, 140, 18)}${star(420, 400, 16)}`,
    extra: `<linearGradient id="steel" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#9fe9f2"/><stop offset=".5" stop-color="#f4ffff"/><stop offset="1" stop-color="#5cbccc"/></linearGradient>
      <linearGradient id="qitrail" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#bff7ff" stop-opacity="0"/><stop offset="1" stop-color="#e9ffff" stop-opacity=".95"/></linearGradient>` },
};

function svg(key, it) {
  const back = style === 'disc'
    ? `<circle cx="256" cy="256" r="236" fill="url(#${it.darkDisc ? 'discD' : 'disc'})"/><circle cx="256" cy="256" r="236" fill="none" stroke="url(#ring)" stroke-width="16"/><circle cx="256" cy="256" r="222" fill="none" stroke="#fff" stroke-opacity=".25" stroke-width="3"/><ellipse cx="256" cy="120" rx="170" ry="70" fill="#fff" opacity=".18"/>`
    : `<circle cx="256" cy="262" r="250" fill="url(#glow)"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512"><defs>${defs(it.fam)}${it.extra || ''}</defs>${back}${style === 'disc' ? `<clipPath id="cl"><circle cx="256" cy="256" r="228"/></clipPath><g clip-path="url(#cl)">${it.art()}</g><circle cx="256" cy="256" r="236" fill="none" stroke="url(#ring)" stroke-width="16"/>` : it.art()}</svg>`;
}

(async () => {
  const browser = await chromium.launch().catch(() => chromium.launch());
  const page = await browser.newPage({ viewport: { width: 512, height: 512 } });
  for (const [key, it] of Object.entries(ITEMS)) {
    await page.setContent(`<style>@font-face{font-family:F;src:url(data:font/ttf;base64,${FONT})}html,body{margin:0;background:transparent}</style>${svg(key, it)}`);
    await page.evaluate(() => document.fonts.ready);
    await page.locator('svg').screenshot({ path: path.join(OUT, key + '.png'), omitBackground: true });
  }
  await browser.close();
  console.log('done', Object.keys(ITEMS).length, OUT);
})();
