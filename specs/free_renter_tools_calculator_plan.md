# Rent Calculator — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> **Build directives:** UI via **ui-ux-pro-max**; public copy via **humanizer** then Llavai copy voice; back-end/security via **fullstack-guardian** (none server-side in this tool — it's client-only — but apply the input-validation + no-secrets rules). Keep the site build-free.

**Goal:** Ship a free, client-side rent-affordability calculator (public page + in-app entry) that maps income to green/amber/red rent bands on the Spanish 3× rule, and converts via a "see flats in my band" sign-up nudge.

**Architecture:** Pure ESM logic module (`js/rent-calc.mjs`) shared by the browser and Node unit tests. A static trilingual page `rent-calculator.html` renders the premium UI and wires the module. No backend, no storage, no PII. Lead capture writes the chosen band to `localStorage` and routes logged-out users through the existing magic-link sign-up; logged-in users deep-link into the feed filtered by band.

**Tech Stack:** Vanilla JS (ES modules), static HTML/CSS, `node:test` for unit tests, puppeteer-core (system Chrome) for headless UI verification, Supabase JS (existing) for the auth check on the CTA.

---

## File structure

- Create `js/rent-calc.mjs` — pure affordability logic (`computeBands`, `classifyRent`, `formatEuro`). One responsibility: the maths. No DOM.
- Create `tests/rent-calc.test.mjs` — Node unit tests for the logic.
- Create `rent-calculator.html` — the public page (premium UI + wiring). Imports `rent-calc.mjs`.
- Create `tests/verify-rent-calculator.mjs` — headless puppeteer verification (computed values + mobile overflow).
- Modify `account.html` — read a `band` filter (from query/localStorage) and constrain the feed query.
- Modify `scripts/gen-locales.js` — add `rent-calculator` to the PAGES map so `/es/` + `/uk/` generate.
- Modify `vercel.json` — clean route `/rent-calculator`, `.mjs` content-type header, sitemap stays generated.

---

## Task 1: Affordability logic module (TDD)

**Files:**
- Create: `js/rent-calc.mjs`
- Test: `tests/rent-calc.test.mjs`

- [ ] **Step 1: Write the failing test**

```javascript
// tests/rent-calc.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeBands, classifyRent, formatEuro } from '../js/rent-calc.mjs';

test('computeBands uses household income when higher', () => {
  const b = computeBands(2900, 4200);
  assert.equal(b.income, 4200);
  assert.equal(Math.round(b.green), 1400); // income / 3
  assert.equal(Math.round(b.amber), 1680); // income / 2.5
});

test('computeBands falls back to salary when household is lower/empty', () => {
  const b = computeBands(3000, 0);
  assert.equal(b.income, 3000);
  assert.equal(Math.round(b.green), 1000);
});

test('computeBands handles zero/garbage income safely', () => {
  assert.equal(computeBands(0, 0).green, 0);
  assert.equal(computeBands('x', null).green, 0);
});

test('classifyRent respects the 3x / 2.5x boundaries', () => {
  const b = computeBands(0, 4200); // green 1400, amber 1680
  assert.equal(classifyRent(1400, b), 'approved'); // <= green
  assert.equal(classifyRent(1401, b), 'risky');
  assert.equal(classifyRent(1680, b), 'risky');    // <= amber
  assert.equal(classifyRent(1681, b), 'out');
  assert.equal(classifyRent(1200, computeBands(0, 0)), 'unknown');
});

test('formatEuro rounds and groups es-ES', () => {
  assert.equal(formatEuro(1399.6), '€1.400');
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd ~/llavai-website && node --test tests/rent-calc.test.mjs`
Expected: FAIL — `Cannot find module '../js/rent-calc.mjs'`.

- [ ] **Step 3: Write the minimal implementation**

```javascript
// js/rent-calc.mjs — pure rental-affordability maths (Spanish 3x rule). No DOM, no side effects.
export function computeBands(netSalary, householdIncome) {
  const s = Number(netSalary) || 0;
  const h = Math.max(Number(householdIncome) || 0, s);
  if (h <= 0) return { income: 0, green: 0, amber: 0, scaleMax: 0 };
  return { income: h, green: h / 3, amber: h / 2.5, scaleMax: h / 2 };
}

export function classifyRent(rent, bands) {
  const r = Number(rent) || 0;
  if (!bands || bands.green <= 0) return 'unknown';
  if (r <= bands.green) return 'approved';
  if (r <= bands.amber) return 'risky';
  return 'out';
}

export function formatEuro(n) {
  return '€' + Math.round(Number(n) || 0).toLocaleString('es-ES');
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node --test tests/rent-calc.test.mjs`
Expected: PASS — 5 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add js/rent-calc.mjs tests/rent-calc.test.mjs
git commit -m "feat(tools): rent-affordability logic module + unit tests"
```

---

## Task 2: Public calculator page (premium UI + wiring)

**Files:**
- Create: `rent-calculator.html`
- Reference (visual): `.superpowers/brainstorm/18394-1781435620/content/rent-calculator.html` (validated prototype)

- [ ] **Step 1: Build the page via ui-ux-pro-max to the premium bar**

Invoke the **ui-ux-pro-max** skill to build `rent-calculator.html`, using the validated prototype as the structural reference and the Llavai kit (Fraunces/Newsreader; `--cream #F4EFE5`, `--ink #1B388F`, `--coral #E55B45`; cards, line icons). Requirements the page MUST meet:
- Reuse the existing site `nav` + `footer` and `fonts.css`/CSS variables; trilingual `[data-lang]` EN/ES/UK with the standard `setLang()` toggle.
- Inputs: `#sal` (net monthly salary), `#hh` (household income). A result block `#green`, a 3-segment gauge, a band legend (`#b1/#b2/#b3`), a rent `<input type=range id=rent>`, and a verdict `#verdict`/`#vtext`.
- Import the logic: `<script type="module"> import { computeBands, classifyRent, formatEuro } from '/js/rent-calc.mjs'; … </script>` and recompute on every `input` event.
- All copy written through the **humanizer** skill, then the Llavai copy voice (British/intl spelling). No "Optional"/AI-tells; high-empathy, tactical.
- Mobile-first, no horizontal overflow from 320px up (min-width:0 on flex/grid children; verify by measurement, not eyeballing).

- [ ] **Step 2: Wire the logic (exact binding)**

The module is the single source of truth for the maths; the page only formats/render. Minimum wiring:

```javascript
import { computeBands, classifyRent, formatEuro } from '/js/rent-calc.mjs';
const $ = id => document.getElementById(id);
function render() {
  const b = computeBands($('sal').value, $('hh').value);
  $('green').innerHTML = formatEuro(b.green) + ' <small>/mo</small>';
  $('b1').textContent = '≤ ' + formatEuro(b.green);
  $('b2').textContent = formatEuro(b.green) + '–' + formatEuro(b.amber);
  $('b3').textContent = '> ' + formatEuro(b.amber);
  $('rent').max = Math.round(b.scaleMax) || 2600;
  const r = Number($('rent').value);
  const cls = classifyRent(r, b);
  $('rentval').textContent = formatEuro(r);
  $('vtext').textContent = formatEuro(r) + ' — ' + ({approved:'most likely approved', risky:'risky, may need a guarantor', out:'out of band, usually rejected', unknown:'enter your income to see'})[cls];
  $('verdict').className = 'verdict ' + ({approved:'v-ok', risky:'v-am', out:'v-rd', unknown:'v-am'})[cls];
  // gauge widths
  $('gg').style.width = (b.green / b.scaleMax * 100 || 0) + '%';
  $('ga').style.width = ((b.amber - b.green) / b.scaleMax * 100 || 0) + '%';
  $('gr').style.width = Math.max(0, 100 - (b.amber / b.scaleMax * 100)) + '%';
}
['sal','hh','rent'].forEach(id => $(id).addEventListener('input', render));
render();
```

- [ ] **Step 3: Serve locally for module loading**

ES module imports require http (not file://). Run in repo root:
Run: `cd ~/llavai-website && python3 -m http.server 8099 >/tmp/llavai-http.log 2>&1 &`
Expected: server up on `http://localhost:8099`.

- [ ] **Step 4: Write the headless verification**

```javascript
// tests/verify-rent-calculator.mjs
import puppeteer from 'puppeteer-core';
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const b = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args:['--no-sandbox'] });
const p = await b.newPage();
const errors = []; p.on('pageerror', e => errors.push(e.message));
await p.goto('http://localhost:8099/rent-calculator.html', { waitUntil:'networkidle2' });
await p.$eval('#sal', el => el.value='');     await p.type('#sal','2900');
await p.$eval('#hh', el => el.value='');      await p.type('#hh','4200');
await p.$eval('#sal', el => el.dispatchEvent(new Event('input',{bubbles:true})));
await p.$eval('#hh', el => el.dispatchEvent(new Event('input',{bubbles:true})));
const green = await p.$eval('#green', el => el.textContent.trim());
console.assert(green.startsWith('€1.400'), 'green band should be €1.400, got ' + green);
// overflow at Z Fold + common widths, mobile UA
await p.setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148');
for (const w of [344,360,390,430]) {
  await p.setViewport({ width:w, height:800, isMobile:true });
  const over = await p.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  console.assert(over <= 0, `overflow ${over}px at ${w}`);
}
console.log(errors.length ? 'PAGEERRORS: ' + errors.join('; ') : 'OK: calc + no overflow, no JS errors');
await b.close();
```

- [ ] **Step 5: Run the verification**

Run: `NODE_PATH=/tmp/llavai-verify/node_modules node tests/verify-rent-calculator.mjs`
Expected: `OK: calc + no overflow, no JS errors` and no assertion output. (If puppeteer-core is missing, install once: `npm_config_cache=/tmp/npmcache npm i --prefix /tmp/llavai-verify puppeteer-core`.)

- [ ] **Step 6: Commit**

```bash
git add rent-calculator.html tests/verify-rent-calculator.mjs
git commit -m "feat(tools): public rent calculator page wired to logic module"
```

---

## Task 3: Lead capture + "see flats in my band" CTA

**Files:**
- Modify: `rent-calculator.html` (CTA handler)
- Modify: `account.html` (apply band filter to the feed)

- [ ] **Step 1: CTA handler on the calculator page**

```javascript
// in rent-calculator.html module script
async function seeMatches() {
  const b = computeBands($('sal').value, $('hh').value);
  const band = { max: Math.round(b.green), riskyMax: Math.round(b.amber) };
  try { localStorage.setItem('llavai-rent-band', JSON.stringify(band)); } catch(e) {}
  // Logged-in users (supabase session) go straight to the filtered feed; others sign up first.
  let signedIn = false;
  try { if (window.sb) { const { data } = await window.sb.auth.getSession(); signedIn = !!(data && data.session); } } catch(e) {}
  location.href = signedIn ? '/account?band=' + band.max : '/get-started?next=' + encodeURIComponent('/account?band=' + band.max);
}
document.getElementById('seeMatches').addEventListener('click', seeMatches);
```
(Load `/supabase-config.js` + the supabase client on this page exactly as `account.html` does, exposing `window.sb`.)

- [ ] **Step 2: Apply the band filter in the feed (account.html)**

Find `loadFeed()` (account.html, the `from('listings').select(...)` call). Add a band ceiling read from the query param or localStorage, and `.lte('price', max)` when present:

```javascript
function bandMax(){
  const q = new URLSearchParams(location.search).get('band');
  if (q && +q > 0) return +q;
  try { const s = JSON.parse(localStorage.getItem('llavai-rent-band')||'null'); return s && s.max ? s.max : 0; } catch(e){ return 0; }
}
// inside loadFeed(), after building the query:
let q = sb.from('listings').select('id,status,appeal_score,photos,price,currency,price_per_m2,features,advertised_phone,first_activation,property_url,agency_name,user_type,rooms,bathrooms,area_m2').gte('appeal_score',60).neq('status','dismissed');
const bm = bandMax(); if (bm) q = q.lte('price', bm);
var res = await q.order('created_at',{ascending:false}).limit(60);
```
Also surface a dismissible "Showing flats in your approved band (≤ €X). Clear" chip when `bm` is set, that removes the param/localStorage and reloads the feed.

- [ ] **Step 3: Verify the filter (headless, simulated)**

Reuse the account.html headless pattern (request-interception to bypass auth, force `#dash` visible) from `/tmp/llavai-verify`; assert that with `?band=1400` set, `bandMax()` returns 1400 and the chip renders. Run the existing account verify script with the band param.
Run: `NODE_PATH=/tmp/llavai-verify/node_modules node tests/verify-account-band.mjs` (adapt the existing account harness; assert chip text contains `1.400`).
Expected: `OK: band chip renders, filter applied`.

- [ ] **Step 4: Commit**

```bash
git add rent-calculator.html account.html tests/verify-account-band.mjs
git commit -m "feat(tools): calculator CTA + feed band filter + lead capture"
```

---

## Task 4: In-app entry point

**Files:**
- Modify: `account.html` (Profile/Tools link)

- [ ] **Step 1: Add a "Tools" entry linking to the calculator**

In the account Profile panel, add a row/link "Rent calculator → /rent-calculator" using the existing section markup + an inline Lucide icon (no emoji). When opened from a signed-in session the page's CTA deep-links back to the filtered feed (Task 3). Keep it trilingual.

- [ ] **Step 2: Verify it renders in the Profile panel**

Run the account headless harness, switch to the Profile tab, assert the "Rent calculator" link is present and points to `/rent-calculator`.
Expected: `OK: tools link present`.

- [ ] **Step 3: Commit**

```bash
git add account.html
git commit -m "feat(tools): in-app rent calculator entry point"
```

---

## Task 5: Trilingual locale generation

**Files:**
- Modify: `scripts/gen-locales.js` (PAGES map + head meta for `rent-calculator`)

- [ ] **Step 1: Add the page to the generator**

Add a `rent-calculator` entry to the `PAGES` map with per-locale `title`/`description` (write the ES/UK strings via humanizer + copy voice), following the existing homepage/blog entries.

- [ ] **Step 2: Regenerate locales**

Run: `NODE_PATH=/tmp/llavai-verify/node_modules node scripts/gen-locales.js`
Expected: `/es/rent-calculator/…` and `/uk/rent-calculator/…` generated; `sitemap.xml` + reciprocal hreflang updated; exit 0.

- [ ] **Step 3: Commit**

```bash
git add scripts/gen-locales.js es uk sitemap.xml rent-calculator.html
git commit -m "feat(tools): trilingual /es/ + /uk/ for rent calculator"
```

---

## Task 6: Routing + headers

**Files:**
- Modify: `vercel.json`

- [ ] **Step 1: Clean route + .mjs content-type**

Add to `vercel.json`: a clean `/rent-calculator` route to `rent-calculator.html` (matching how other pages are served), and a header ensuring `*.mjs` is served as `text/javascript; charset=utf-8` (so the module loads on iOS Safari reliably).

- [ ] **Step 2: Verify locally**

Run the local server + `curl -sI http://localhost:8099/js/rent-calc.mjs | grep -i content-type`
Expected: `text/javascript` (after deploy Vercel applies the header; locally python sets it too).

- [ ] **Step 3: Commit**

```bash
git add vercel.json
git commit -m "chore(tools): route + .mjs content-type for rent calculator"
```

---

## Task 7: Full verification + deploy

- [ ] **Step 1: Run all tests + verifications green**

Run: `node --test tests/rent-calc.test.mjs && NODE_PATH=/tmp/llavai-verify/node_modules node tests/verify-rent-calculator.mjs`
Expected: unit tests PASS; verification prints `OK`.

- [ ] **Step 2: Stop the local server**

Run: `pkill -f "http.server 8099" || true`

- [ ] **Step 3: Deploy**

```bash
git push origin main
```
Then confirm live: `curl -s -L https://www.llavai.com/rent-calculator | grep -c 'id="sal"'` → `1`, and the `/es/` + `/uk/` variants 200.

---

## Self-review (completed inline)

- **Spec coverage:** Calculator §3 fully covered — client-only logic (T1), public page (T2), free + "see flats in my band" sign-up nudge (T3), in-app entry (T4), trilingual/SEO (T5), build-free routing (T6). Cover letter §4 and dossier §5 are out of scope here → separate plans next.
- **Placeholder scan:** logic + wiring + verification code are concrete; UI build is delegated to ui-ux-pro-max with explicit acceptance requirements (not a placeholder — the maths/wiring/verification are pinned).
- **Type consistency:** `computeBands→{income,green,amber,scaleMax}`, `classifyRent→'approved'|'risky'|'out'|'unknown'`, `formatEuro` used identically across module, page wiring, and tests; `localStorage 'llavai-rent-band' = {max,riskyMax}` read by `bandMax()` and the CTA writer.
