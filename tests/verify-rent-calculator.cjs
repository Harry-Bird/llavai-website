// Headless verification for rent-calculator.html.
// Self-serves the repo with correct .mjs MIME (Chrome refuses modules served as octet-stream),
// then drives the page and asserts the computed bands, the verdict, no overflow, and no JS errors.
// Run: NODE_PATH=/tmp/llavai-verify/node_modules node tests/verify-rent-calculator.cjs
const http = require('http');
const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer-core');

const ROOT = path.join(__dirname, '..');
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const MIME = { '.html':'text/html', '.mjs':'text/javascript', '.js':'text/javascript', '.css':'text/css', '.json':'application/json', '.svg':'image/svg+xml', '.ico':'image/x-icon', '.woff2':'font/woff2' };

const server = http.createServer((req, res) => {
  try {
    let p = decodeURIComponent(req.url.split('?')[0]);
    if (p === '/') p = '/index.html';
    const file = path.join(ROOT, path.normalize(p).replace(/^(\.\.[/\\])+/, ''));
    if (!file.startsWith(ROOT) || !fs.existsSync(file)) { res.writeHead(404); return res.end('nf'); }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
    res.end(fs.readFileSync(file));
  } catch (e) { res.writeHead(500); res.end(String(e)); }
});

(async () => {
  await new Promise(r => server.listen(0, r));
  const port = server.address().port;
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  const page = await browser.newPage();
  const errs = [];
  page.on('pageerror', e => errs.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errs.push('console:' + m.text()); });
  const fails = [];
  try {
    await page.goto(`http://localhost:${port}/rent-calculator.html`, { waitUntil: 'networkidle2', timeout: 30000 });
    await page.evaluate(() => {
      const set = (id, v) => { const el = document.getElementById(id); el.value = v; el.dispatchEvent(new Event('input', { bubbles: true })); };
      set('sal', '2900'); set('hh', '4200');
    });
    const green = await page.$eval('#green', el => el.textContent.trim());
    const b2 = await page.$eval('#b2', el => el.textContent.trim());
    if (!green.startsWith('€1.400')) fails.push('green=' + green);
    if (!b2.replace(/\s/g, '').startsWith('€1.400-1.680')) fails.push('b2=' + b2);
    // rent just over 3x-amped band -> "out of band"
    await page.evaluate(() => { const r = document.getElementById('rent'); r.value = '1681'; r.dispatchEvent(new Event('input', { bubbles: true })); });
    const vtext = await page.$eval('#vtext', el => el.textContent.trim());
    if (!/out of band/.test(vtext)) fails.push('verdict=' + vtext);
    // mobile overflow sweep (incl. 320 + Z Fold 344)
    await page.setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148');
    for (const w of [320, 344, 360, 390, 430]) {
      await page.setViewport({ width: w, height: 820, isMobile: true });
      const over = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
      if (over > 0) fails.push(`overflow ${over}px@${w}`);
    }
    if (errs.length) fails.push('JSERR:' + errs.join(' | '));
  } catch (e) { fails.push('THREW:' + e.message); }
  await browser.close();
  server.close();
  console.log(fails.length ? 'FAIL: ' + fails.join('; ') : 'OK: calc correct, verdict correct, no overflow, no JS errors');
  process.exit(fails.length ? 1 : 0);
})();
