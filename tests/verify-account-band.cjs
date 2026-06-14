// Headless verification for the rent-band feed filter in account.html.
// Self-serves the repo, injects a fake Supabase client (so boot stays clean without auth),
// then exercises the pure band helpers: bandMax() coercion, the chip render, Clear, the
// localStorage fallback, invalid input, and mobile overflow with the chip shown.
// Run: NODE_PATH=/tmp/llavai-verify/node_modules node tests/verify-account-band.cjs
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
  const base = `http://localhost:${port}/account.html`;
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  const page = await browser.newPage();
  const errs = [];
  page.on('pageerror', e => errs.push(e.message));

  // Stand in for Supabase: real config vars + a no-session client + a chainable query
  // (clearBand() calls loadFeed(), which must not throw on the fake).
  await page.evaluateOnNewDocument(() => {
    window.LLAVAI_SUPABASE_URL = 'https://example.supabase.co';
    window.LLAVAI_SUPABASE_ANON_KEY = 'test-anon-key';
    const q = { select(){return q;}, gte(){return q;}, neq(){return q;}, lte(){return q;}, order(){return q;}, limit(){return Promise.resolve({data:[],error:null});} };
    window.supabase = { createClient: () => ({
      auth: { getSession: async () => ({ data: { session: null } }), onAuthStateChange: () => ({ data: { subscription: { unsubscribe(){} } } }) },
      from: () => q,
    }) };
  });
  // Keep the fake intact and the page put: drop the CDN client, the config file, track.js,
  // and any /login bounce the no-session boot schedules.
  await page.setRequestInterception(true);
  page.on('request', r => {
    const u = r.url();
    if (/supabase|track\.js|\/login/.test(u)) return r.abort();
    return r.continue();
  });

  const fails = [];
  const showFeedPanel = () => page.evaluate(() => {
    var g = document.getElementById('gate'); if (g) g.hidden = true;
    var d = document.getElementById('dash'); if (d) d.hidden = false;
    document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
    var fp = document.getElementById('panel-feed'); if (fp) fp.classList.add('active');
  });

  try {
    // 1) ?band=1400 — bandMax coerces, chip renders with the formatted value + Clear
    await page.goto(base + '?band=1400', { waitUntil: 'domcontentloaded', timeout: 30000 });
    const t1 = await page.evaluate(() => {
      const bm = window.bandMax();
      window.renderBandChip();
      const el = document.getElementById('bandChip');
      return { bm, hidden: el.hidden, html: el.innerHTML, role: el.getAttribute('role'), hasClear: !!document.getElementById('bandClear') };
    });
    if (t1.bm !== 1400) fails.push('bandMax(?band=1400)=' + t1.bm);
    if (t1.hidden !== false) fails.push('chip hidden with band set');
    if (!/€1\.400/.test(t1.html)) fails.push('chip missing €1.400: ' + t1.html);
    if (!/<b>/.test(t1.html)) fails.push('chip value not emphasised');
    if (!t1.hasClear) fails.push('chip Clear button missing');
    if (t1.role !== 'status') fails.push('chip role!=status: ' + t1.role);

    // 2) Clear — wipes localStorage + the ?band param, hides the chip
    const t2 = await page.evaluate(async () => {
      window.clearBand();
      await new Promise(r => setTimeout(r, 150));
      return { ls: localStorage.getItem('llavai-rent-band'), search: location.search, bm: window.bandMax(), hidden: document.getElementById('bandChip').hidden };
    });
    if (t2.ls !== null) fails.push('clearBand left localStorage: ' + t2.ls);
    if (/band=/.test(t2.search)) fails.push('clearBand left ?band: ' + t2.search);
    if (t2.bm !== 0) fails.push('bandMax after clear=' + t2.bm);
    if (t2.hidden !== true) fails.push('chip visible after clear');

    // 3) Invalid band value, no localStorage -> no filter
    await page.goto(base + '?band=notanumber', { waitUntil: 'domcontentloaded', timeout: 30000 });
    const t3 = await page.evaluate(() => {
      localStorage.removeItem('llavai-rent-band');
      const bm = window.bandMax();
      window.renderBandChip();
      return { bm, hidden: document.getElementById('bandChip').hidden };
    });
    if (t3.bm !== 0) fails.push('bandMax(?band=notanumber)=' + t3.bm);
    if (t3.hidden !== true) fails.push('chip shown for invalid band');

    // 4) localStorage fallback (no query param) -> reads the stored ceiling
    await page.goto(base, { waitUntil: 'domcontentloaded', timeout: 30000 });
    const t4 = await page.evaluate(() => {
      localStorage.setItem('llavai-rent-band', JSON.stringify({ max: 1555, riskyMax: 1866 }));
      return window.bandMax();
    });
    if (t4 !== 1555) fails.push('bandMax(localStorage)=' + t4);

    // 5) Mobile overflow with the chip shown (mobile UA + Z Fold 344px)
    await page.goto(base + '?band=1400', { waitUntil: 'domcontentloaded', timeout: 30000 });
    await showFeedPanel();
    await page.evaluate(() => window.renderBandChip());
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
  console.log(fails.length ? 'FAIL: ' + fails.join('; ') : 'OK: band chip renders, filter coerces, Clear works, fallback + invalid handled, no overflow');
  process.exit(fails.length ? 1 : 0);
})();
