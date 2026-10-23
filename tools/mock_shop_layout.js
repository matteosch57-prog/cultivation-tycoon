// Render docs/art/mocks/2026-10-23_shop_layout.html (?opt=A|B|C&dev=pc|phone&page=) with Playwright.
// Needs next to the html: art/shop_icons/*.png, a_qi.png/a_gift.png (icon_atlas cells 0 and 6), fredoka.woff2, bg.jpg.
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const path=require('path');
(async()=>{
 const dir=process.argv[2]; const opts=(process.argv[3]||'A,B,C').split(',');
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1243/chrome-linux/chrome'}).catch(()=>chromium.launch());
 for(const o of opts) for(const [dev,w,h,sf] of [['pc',985,554,1.3],['phone',844,390,1.5]]){
  const p=await b.newPage({viewport:{width:w,height:h},deviceScaleFactor:sf});
  await p.goto('file://'+path.join(dir,'shop.html')+`?opt=${o}&dev=${dev}&page=${process.argv[4]||''}`); await p.waitForTimeout(500);
  await p.screenshot({path:path.join(dir,`out_${o}_${dev}.png`)}); await p.close();
 }
 await b.close();
})();
