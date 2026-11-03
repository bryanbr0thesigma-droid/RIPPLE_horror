// Renders SVG files to transparent PNGs with headless Chromium (no SVG renderer is needed).
//   node render_svgs.mjs <height_px> <in.svg> <out.png> [<in.svg> <out.png> ...]
import { chromium } from 'playwright';
import fs from 'fs';

const [hpx, ...pairs] = process.argv.slice(2);
const browser = await chromium.launch();
const page = await browser.newPage();
for (let i = 0; i < pairs.length; i += 2) {
  const svg = fs.readFileSync(pairs[i], 'utf8');
  await page.setContent(`<html><body style="margin:0;background:transparent">
    <div id="w" style="display:inline-block;line-height:0">${svg}</div></body></html>`);
  await page.evaluate((h) => {
    const s = document.querySelector('svg');
    if (!s.getAttribute('viewBox')) {
      // without a viewBox, a new size would only grow the canvas, not the drawing
      s.setAttribute('viewBox', `0 0 ${parseFloat(s.getAttribute('width'))} ${parseFloat(s.getAttribute('height'))}`);
    }
    const vb = s.viewBox.baseVal;
    const ratio = vb && vb.width ? vb.width / vb.height : (s.width.baseVal.value / s.height.baseVal.value);
    s.setAttribute('height', h); s.setAttribute('width', Math.round(h * ratio));
  }, Number(hpx));
  await page.locator('#w').screenshot({ path: pairs[i + 1], omitBackground: true });
  console.log(pairs[i + 1]);
}
await browser.close();
