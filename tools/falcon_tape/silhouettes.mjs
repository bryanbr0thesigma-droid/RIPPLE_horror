// Renders the creature's silhouettes for the tape with three.js in headless Chromium.
// Needs: npm install three@0.169.0 playwright, and ../../game/assets/creature/creature.glb copied
// next to silhouettes.html. Serve this folder on port 8765 (python3 -m http.server 8765), then:
//   node silhouettes.mjs silhouettes
import { chromium } from 'playwright';
import fs from 'fs';

const out = process.argv[2] || 'silhouettes';
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage();
page.on('console', m => console.log('page:', m.text()));
page.on('pageerror', e => console.log('error:', e.message));
await page.goto('http://127.0.0.1:8765/silhouettes.html' + (process.env.MODEL ? '?model=' + process.env.MODEL : ''));
await page.waitForFunction(() => window.ready, null, { timeout: 120000 });
const dur = await page.evaluate(() => window.durations);
console.log(dur);

// [name, clip, yaw, frames per second (0 = one still at t), t, frame [cx, cy, cz, halfHeight]]
const F = [0, 0.27, 0.1, 0.42];
const shots = process.argv[3] ? JSON.parse(process.argv[3]) : [
  ['side_idle', 'idle standing', 90, 12, 0, F],
  ['search', 'search', 90, 12, 0, F],
  ['screech', 'screech', 90, 12, 0, [0, 0.27, 0.05, 0.46]],
];
for (const [name, clip, yaw, fps, t0, frame, pose] of shots) {
  const n = fps && dur[clip] ? Math.max(1, Math.round(dur[clip] * fps)) : 1;
  for (let i = 0; i < n; i++) {
    const t = fps ? i / fps : t0;
    const r = await page.evaluate(([c, t, y, f, p]) => window.shot(c, t, y, f, p), [clip, t, yaw, frame || null, pose || null]);
    fs.writeFileSync(`${out}/${name}_${String(i).padStart(3, '0')}.png`, Buffer.from(r.png.split(',')[1], 'base64'));
    if (i === 0) console.log(name, n, r.box.map(v => v.toFixed(2)).join(' '));
  }
}
await browser.close();
