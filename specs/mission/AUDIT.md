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

## Area 3 — Marketing & conversion (PENDING — agent running)
