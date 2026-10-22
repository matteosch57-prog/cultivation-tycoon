// Shop product icons, round 2: glossy painted items + real disciple renders, transparent 512 PNGs.
// node draw.js <style> <outdir>   style = glow | disc
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const style = process.argv[2] || 'glow';
const OUT = process.argv[3] || path.join(__dirname, 'out_' + style);
fs.mkdirSync(OUT, { recursive: true });
const FONT = fs.readFileSync(path.join(__dirname, 'fredoka.woff2')).toString('base64');
const DIS = JSON.parse(fs.readFileSync(path.join(__dirname, 'disciples.json')));

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

const ITEMS = {
  x2: { fam: 'jade', art: () => drop(-34, -16, .9) +
      `<text x="352" y="440" text-anchor="middle" font-family="F" font-size="168" fill="url(#goldv)" stroke="#4a2100" stroke-width="24" stroke-linejoin="round" paint-order="stroke">2x</text>
       <text x="352" y="440" text-anchor="middle" font-family="F" font-size="168" fill="none" stroke="#fff8d0" stroke-width="3" opacity=".6">2x</text>` },
  auto: { fam: 'sky', art: () => `
      <path d="M86 150 C150 70 300 80 300 190" stroke="url(#trail)" stroke-width="30" stroke-linecap="round" fill="none" opacity=".75"/>
      <path d="M430 160 C470 260 400 330 330 300" stroke="url(#trail2)" stroke-width="26" stroke-linecap="round" fill="none" opacity=".75"/>
      <path d="M120 420 C170 470 260 440 250 360" stroke="url(#trail3)" stroke-width="24" stroke-linecap="round" fill="none" opacity=".75"/>
      ${orb(262, 270, 112)}${orb(108, 140, 44)}${orb(420, 168, 38)}${orb(118, 410, 34)}
      ${star(392, 410, 26)}${star(410, 70, 18)}`,
    extra: `<linearGradient id="trail" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#9ff7d8" stop-opacity="0"/><stop offset="1" stop-color="#9ff7d8"/></linearGradient>
      <linearGradient id="trail2" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9ff7d8" stop-opacity="0"/><stop offset="1" stop-color="#9ff7d8"/></linearGradient>
      <linearGradient id="trail3" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#9ff7d8" stop-opacity="0"/><stop offset="1" stop-color="#9ff7d8"/></linearGradient>` },
  vip: { fam: 'gold', art: () => `
      <g filter="url(#shadow)"><path d="M132 344 L106 168 L200 254 L256 120 L312 254 L406 168 L380 344 Z" fill="url(#goldv)" stroke="#5e3204" stroke-width="13" stroke-linejoin="round"/>
      <rect x="122" y="334" width="268" height="66" rx="16" fill="url(#goldv)" stroke="#5e3204" stroke-width="13"/></g>
      <path d="M150 320 L134 206" stroke="#fff6cc" stroke-width="10" stroke-linecap="round" opacity=".8"/>
      <circle cx="256" cy="367" r="22" fill="url(#jade)" stroke="#07523d" stroke-width="6"/>
      <circle cx="180" cy="367" r="13" fill="#e2462a" stroke="#5e0c04" stroke-width="5"/><circle cx="332" cy="367" r="13" fill="#e2462a" stroke="#5e0c04" stroke-width="5"/>
      <circle cx="106" cy="166" r="20" fill="url(#jade)" stroke="#5e3204" stroke-width="7"/><circle cx="256" cy="116" r="24" fill="#e2462a" stroke="#5e3204" stroke-width="7"/><circle cx="406" cy="166" r="20" fill="url(#jade)" stroke="#5e3204" stroke-width="7"/>
      ${star(404, 300, 30)}${star(96, 280, 18)}${star(330, 90, 16)}` },
  pill: { fam: 'red', art: () => `
      <circle cx="256" cy="300" r="190" fill="url(#flame)"/>
      <circle cx="256" cy="300" r="164" fill="none" stroke="#ffd36a" stroke-width="5" stroke-dasharray="4 18" stroke-linecap="round" opacity=".9"/>
      <g filter="url(#shadow)"><circle cx="256" cy="300" r="132" fill="url(#pill)" stroke="#4a0902" stroke-width="13"/></g>
      <path d="M150 300 C190 250 240 330 280 280 C310 244 350 266 362 296" stroke="#ffd36a" stroke-width="13" fill="none" stroke-linecap="round" opacity=".9"/>
      <path d="M170 360 C210 330 250 380 300 350" stroke="#ffd36a" stroke-width="10" fill="none" stroke-linecap="round" opacity=".7"/>
      <ellipse cx="206" cy="236" rx="44" ry="24" fill="#fff" opacity=".8" transform="rotate(-32 206 236)"/>
      ${star(400, 430, 26)}${star(110, 140, 18)}`,
    extra: `<radialGradient id="flame"><stop offset=".6" stop-color="#ffc23a" stop-opacity=".9"/><stop offset="1" stop-color="#ff7a1e" stop-opacity="0"/></radialGradient>` },
  pack1: { fam: 'jade', art: () => `
      ${orb(212, 146, 40)}${orb(290, 128, 46)}${orb(250, 96, 30)}
      <g filter="url(#shadow)"><path d="M190 200 C120 230 92 330 120 390 C140 432 372 432 392 390 C420 330 392 230 322 200 Z" fill="url(#silk)" stroke="#3c0603" stroke-width="13" stroke-linejoin="round"/>
      <path d="M176 176 C210 196 302 196 336 176 L322 214 C290 228 222 228 190 214 Z" fill="url(#silk)" stroke="#3c0603" stroke-width="11" stroke-linejoin="round"/></g>
      <path d="M176 214 C230 236 282 236 336 214" stroke="url(#goldv)" stroke-width="16" fill="none" stroke-linecap="round"/>
      <circle cx="256" cy="232" r="16" fill="url(#goldv)" stroke="#6b3a06" stroke-width="5"/>
      <path d="M256 246 L232 300 M256 246 L282 300" stroke="url(#goldv)" stroke-width="10" stroke-linecap="round"/>
      <path d="M170 350 C200 320 236 360 256 336 C276 312 312 352 342 330" stroke="#ffcf5c" stroke-width="9" fill="none" stroke-linecap="round" opacity=".85"/>
      <path d="M150 300 C146 330 150 360 162 380" stroke="#ff9d8a" stroke-width="10" fill="none" stroke-linecap="round" opacity=".6"/>
      ${star(400, 140, 22)}${star(98, 210, 16)}` },
  pack2: { fam: 'jade', art: () => chest(0, 30, 1) + orb(206, 170, 34) + orb(300, 150, 40) + orb(254, 112, 28) + star(412, 120, 24) + star(96, 170, 16) },
  pack3: { fam: 'gold', art: () => `
      <g opacity=".7">${[...Array(12)].map((_, i) => { const a = i * Math.PI / 6; return `<path d="M256 260 L${256 + Math.cos(a - .09) * 300} ${260 + Math.sin(a - .09) * 300} L${256 + Math.cos(a + .09) * 300} ${260 + Math.sin(a + .09) * 300}Z" fill="#fff1b0" opacity=".55"/>`; }).join('')}</g>
      ${chest(-6, 52, 1.04)}
      ${orb(150, 196, 40)}${orb(230, 150, 50)}${orb(318, 160, 46)}${orb(380, 222, 36)}${orb(190, 112, 30)}${orb(282, 96, 34)}
      ${orb(96, 420, 30)}${orb(420, 420, 34)}
      ${star(430, 96, 26)}${star(80, 120, 20)}` },
  welcome: { fam: 'red', art: () => `
      <g filter="url(#shadow)"><rect x="150" y="96" width="212" height="320" rx="26" fill="url(#silk)" stroke="#3c0603" stroke-width="13"/></g>
      <path d="M156 110 L256 214 L356 110" fill="#8a140c" stroke="#3c0603" stroke-width="11" stroke-linejoin="round"/>
      <path d="M176 380 C210 360 230 392 256 372 C282 352 302 384 336 364" stroke="#ffcf5c" stroke-width="8" fill="none" stroke-linecap="round" opacity=".8"/>
      <g filter="url(#shadow)"><circle cx="256" cy="232" r="60" fill="url(#goldv)" stroke="#5e3204" stroke-width="10"/></g>
      ${drop(256 - 256 * .3, 232 - 270 * .3, .3)}
      <path d="M168 140 L168 300" stroke="#ff9d8a" stroke-width="9" stroke-linecap="round" opacity=".55"/>
      ${star(398, 140, 28)}${star(116, 360, 20)}${star(390, 420, 14)}` },
};

const RARE = { elder: 'violet', primordial: 'pink', immortal: 'gold', celestial: 'cyan', dao: 'crimson', emperor: 'orange' };
for (const [k, fam] of Object.entries(RARE)) {
  ITEMS[k] = { fam, darkDisc: true, art: () => {
    const d = DIS[k]; const box = style === 'disc' ? 400 : 440;
    const sc = Math.min(box / d.w, box / d.h); const w = d.w * sc, h = d.h * sc;
    return `<image href="data:image/png;base64,${d.b64}" x="${256 - w / 2}" y="${style === 'disc' ? 276 - h / 2 : 262 - h / 2}" width="${w}" height="${h}" filter="url(#shadow)"/>${star(410, 110, 24)}${star(100, 400, 16)}`;
  } };
}

function svg(key, it) {
  const back = style === 'disc'
    ? `<circle cx="256" cy="256" r="236" fill="url(#${it.darkDisc ? 'discD' : 'disc'})"/><circle cx="256" cy="256" r="236" fill="none" stroke="url(#ring)" stroke-width="16"/><circle cx="256" cy="256" r="222" fill="none" stroke="#fff" stroke-opacity=".25" stroke-width="3"/><ellipse cx="256" cy="120" rx="170" ry="70" fill="#fff" opacity=".18"/>`
    : `<circle cx="256" cy="262" r="250" fill="url(#glow)"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512"><defs>${defs(it.fam)}${it.extra || ''}</defs>${back}${style === 'disc' ? `<clipPath id="cl"><circle cx="256" cy="256" r="228"/></clipPath><g clip-path="url(#cl)">${it.art()}</g><circle cx="256" cy="256" r="236" fill="none" stroke="url(#ring)" stroke-width="16"/>` : it.art()}</svg>`;
}

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' }).catch(() => chromium.launch());
  const page = await browser.newPage({ viewport: { width: 512, height: 512 } });
  for (const [key, it] of Object.entries(ITEMS)) {
    await page.setContent(`<style>@font-face{font-family:F;src:url(data:font/woff2;base64,${FONT})}html,body{margin:0;background:transparent}</style>${svg(key, it)}`);
    await page.evaluate(() => document.fonts.ready);
    await page.locator('svg').screenshot({ path: path.join(OUT, key + '.png'), omitBackground: true });
  }
  await browser.close();
  console.log('done', Object.keys(ITEMS).length, OUT);
})();
