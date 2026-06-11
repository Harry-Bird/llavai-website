# Mission gap audit — 2026-06-11

Four parallel read-only audits (reliability / web app / marketing+conversion / business).
Every finding re-verified with evidence before recording. Ratings: 🔴 blocks launch ·
🟡 hurts trust or conversion · 🟢 polish. Builder: (C) Claude within constraints
(drafts/additive/frontend) · (H) NEEDS HARRY (publish/click/business call).

## Area 1 — Reliability for 100 users (COMPLETE)

### 🔴
- **F1 · Weekend Pro alerts silently die in the call queue.** `call_queue.expires_at`
  default 48h; drain only runs Mon–Fri 08–18 Madrid and expires stale rows BEFORE
  claiming. Fri 18:00→Sat 07:59 alerts expire before Monday's first claim. Expiry sends
  no alert and never releases the `call_attempts` dedup row → that property is blocked
  for that user forever. Fix: expiry default ≥96h (or next-business-window), drain routes
  expired→ops email + frees dedup. (C draft + H publish swap)

### 🟡
- **F2 · W4 checkout webhook accepts junk; `return_to` open redirect; guessable path**
  (published 4766700d, 3 nodes, no validation; executions 2856/2752 = caller-facing 500s;
  stale Vercel preview in allowedOrigins). Fix: validation node (email regex, UUID
  user_id, return_to ^https://(www\.)?llavai\.com). (C draft + H publish)
- **F3 · errorWorkflow missing on W3, W4, Feed Backfill, Profile Creation, W5a.** Worst:
  W3 failure = customer pays, tier never flips, silence. W3 must be hand-edited (Stripe
  Trigger re-registers webhook on MCP replace). (H, C drafts where MCP allows)
- **F4 · W3 Stripe sync has NEVER fired** (0 executions all time; 0 live subs). Unproven
  before first customer. Fix: one €19 test checkout e2e. (H)
- **F5 · `past_due` → instant 'free' lockout** during Stripe dunning. Business call:
  grace via including past_due, or hard lockout. (H decision, C SQL after)
- **F6 · No retry path + call_allowance unenforced** (W2.1 unbuilt). Transient failures
  permanently consume dedup slots; unbounded Pro call costs. (C draft + H publish)
- **F7 · CloudMailin inbox webhook guessable + unauthenticated** (`pro-concierge-inbox`,
  no secret check) → forged alerts can suppress a client's real alert via dedup, burn
  Apify, make Julia dial. Fix: header-secret gate node + CloudMailin config. (C draft + H)
- **F8 · Sheets stack still live; Profile Creation runs OLD published version**
  (24704158 ≠ active 15831bc9 — onError email fix not in production). Ops new-lead email
  rides entirely on the Sheets append (lost a lead 06-04). Fix: Phase 4 plan. (H publishes)
- **F9 · Drain burns ~4.3k n8n executions/mo ticking 24/7** (quota cliff: Starter=2.5k;
  exhaustion stops ALL workflows). Fix: cron `*/10 8-17 * * 1-5` Madrid in drain-v2 +
  confirm plan tier. (C draft + H plan check)
- **F10 · Apify cost cliff at 100 users** (Backfill: per-client sync runs every 6h →
  ~400 runs/day at 100 users; Upsert neverError:true hides DB rejections). (H pricing
  decision; C node hardening)

### 🟢
- F11 · supabase/proposed/ hardening unapplied (anon RPC EXECUTE, leaked-password
  protection off, FK indexes). One apply session. (H approval)
- F12 · stray "name documents" bucket. (H click)
- F13 · auth_rls_initplan WARN ×19 — batch with F11.
- F14 · Error-handler subject typo "[Lavai". (H hand-edit or C if MCP works)
- F15 · production workflow still named "…(W1-GATED draft)". (H rename)

### HEALTHY (verified — do not re-check)
Cutover real (W1-GATED + drain published == drafts, errorWorkflow wired, e2e 3052);
trial LIVE (W4 4766700d, trial_period_days=3 + metadata); W3 status-race fix live;
tier RPCs correct; W2 post-call clean; no stranded queue/attempt rows; Stripe prices
clean (€0 archived, live mode); RLS on all 10 tables; checkout alert() gone; W5a/W5b
as designed; no execution failures since 06-10.

## Area 4 — Business model (COMPLETE — all proposals in specs/proposals/)

- 🔴 **call_allowance unenforced at €185 flat** → heavy user sets the margin (negative
  tail). Proposal: pro-call-economics-and-allowance.md. (overlaps F6)
- 🔴 **EU AI Act Art. 50 disclosure, applies 2026-08-02 (~7 weeks)** — "obvious from
  context" exemption unavailable by design. Proposal with exact ES/EN script:
  julia-ai-disclosure-art50.md. (H legal review + Retell draft later)
- ~~"Trial charges €19"~~ — STALE: cited the old audit; reliability verified the trial
  is live. The remaining issue is copy coherence (below).
- 🟡 Homepage Pro card shows no price while account.html says €185 — pick one
  (recommend show it). 🟡 "Two plans · from €19/mo" hides Free teaser + trial — the
  cheapest conversion assets are unmarketed. 🟡 No bridge between €19 and €185
  (proposal: julia-on-demand-bridge-tier.md). 🟡 No answer to the success event
  (retention-after-the-keys.md).
- Proposals index: julia-ai-disclosure-art50, pro-call-economics-and-allowance,
  trial-design-time-to-first-win, julia-on-demand-bridge-tier, growth-first-100-users,
  retention-after-the-keys, essential-engagement-price-drop-digest.

## Area 2 — Web app quality (PENDING — agent running)

## Area 3 — Marketing & conversion (COMPLETE)

Lighthouse (live): / 84-100-100-100 · /get-started 89-100-100-100 · guide 88-96-100-100.
Zero overflow at 320–430 incl. 344 (mobile UA); trilingual parity perfect (145/145/145
data-lang on index); JSON-LD valid everywhere it exists; no console errors; no invented
legal figures in guides. Artifacts: /tmp/llavai-verify/shots/ + lh-*.json.

### 🔴
- **M1 · "Win you the flat" overpromise cluster** — 6 live locations × 3 languages
  (index.html:582-584 tiers H2 above pricing; blog/index.html:396-398 "Julia виграє
  квартиру"; deposit + rent-control + neighbourhoods guide CTAs). Llavai books
  viewings. Rewrite to viewing-truthful copy ("Both get you to the viewing first").  (C)
- **M2 · Neighbourhoods guide (live, 584cb0c) has broken canonical + malformed sitemap
  entry** — apex + trailing slash = double redirect; newest content may not index.
  Fix both to https://www.llavai.com/blog/best-neighbourhoods-barcelona-rent-expat. (C)
- **M3 · Featured Essential card CTA → /login?next=/account** (index.html:624) — the
  highest-intent click lands on "Sign in", skips lead capture entirely. → /get-started. (C)

### 🟡
- **M4 · "it's free" sticky bar vs "from €19/mo" hero in one mobile fold** — trial never
  mentioned. Fix: "Get started — free 3-day trial". (C)
- **M5 · Trial terms hidden until after email capture** — add one reassure line on
  get-started: "Free 3-day trial of Essential (€19/mo after) · cancel anytime · no
  payment details now." (C)
- **M6 · Julia promised to non-Pro audiences** (get-started meta description + success
  screen for essential leads; blog hub CTA sub; profile success). Condition on plan=pro
  or plan-neutral rewrite. (C)
- **M7 · /blog hub missing the 2 newest guides** (rent-control + neighbourhoods). (C)
- **M8 · Guides are crawl cul-de-sacs** — no related-guides block, no breadcrumb to
  /blog (only cover-letter interlinks). (C)
- **M9 · Homepage LCP 3.8s: reveal animation holds hero .lede at opacity:0 ~1.6s** —
  exempt above-fold hero from JS-gated opacity (+ consider preloading 2 hero woff2).
  Should clear Perf ≥90. (C)
- **M10 · No hreflang / per-language URLs** — trilingual content invisible to search.
  Strategic; needs /es/ /ua/ paths; do NOT bolt hreflang onto single-URL. (proposal-level)
- **M11 · Pro has no price anywhere public** ("By application") — overlaps business 🟡;
  recommend showing €185 or "reply within 24h with pricing". (C copy + H business call)

### 🟢
- P1 trailing-slash internal links (308 hop) · P2 guide FAQ coral em contrast (use
  --coral-text) · P3 homepage lacks wow kit (tier-card stamps; hero live-dossier idea =
  strongest move) · P4 WHO/WHY-NOW buried in lede · P5 sitemap lastmod stale for / ·
  P6 get-started JSON-LD absent · P7 local checkout was behind origin (now pulled).
