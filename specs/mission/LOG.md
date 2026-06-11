# Mission log — production-ready + launch-grade (started 2026-06-11)

## STATUS (read this first)
MISSION COMPLETE + LAUNCH-NIGHT CUTOVERS DONE (2026-06-11 evening, Harry live-approving).
All three n8n v2 cutovers are PUBLISHED and verified in production (Harry authorized
unpublish/publish explicitly): Drain v2 LZzSF0CfiXxiE06G (first cron tick green),
W1-GATED v2 IAqF3sVJDuQqK2hm (403 no-secret / 200 with-secret verified by live curl;
CloudMailin free plan = secret moved to ?secret= query param, gate accepts header OR
query), W4 v2 rSUCsckVa9dJ5BxE (junk POST → 400 verified). W3 FIRED IN PRODUCTION for
the first time: real test checkout hsdb23+launchtest@gmail.com → trialing/essential
with real Stripe ids; cancel-at-period-end processed (status stays trialing until
2026-06-14, deleted-event → canceled branch verified statically in W3). Stripe no-code
customer portal activated; account.html plan line now has "Manage subscription ·
cancel anytime" (commit 255f178). n8n plan: Starter, 410/2,500 June executions —
headroom OK post-drain-v2. Leaked-password protection unavailable on Supabase free
plan — accepted risk (auth is magic-link). Remaining items renumbered below.

## DONE
- Phase 0: orient + checkpoint (pre-mission tag, RESET.md, this log).
- Phase 1: 4-area audit → AUDIT.md. 7 business proposals in specs/proposals/.
- Conversion batch 1 (e6feb50): "win the flat" overpromise gone ×3 langs ×6 places;
  featured CTA /login→/get-started?plan=essential; trial marketed (hero/sticky/
  get-started reassure); Julia plan-scoped; neighbourhoods canonical+sitemap fixed;
  hub +2 cards; trailing slashes dropped; LCP fix (hero opacity exemption + font
  preloads). Live-verified.
- Web-app batch (c19f0f1): feed/teaser cards trilingual; profile review translates
  values + select segments; doc-type labels trilingual; ≤340px progress dots;
  email-setup WAI-ARIA tabs + focus ring; lang-toggle aria-label ×15 pages.
- Guides batch (234b2d7): related-guides + breadcrumb on all 6 (M8); FAQ contrast (P2).
- Dashboard (b99837e): call_queue rows render as QUEUED/JULIA CALLING stamps with
  "calls when offices open" copy; viewings.notes rendered as "Julia's call summary"
  (roadmap #9 — the Pro retention surface).
- Homepage tiers wow kit (e4ccb8a): stacked paper + JULIA CALLS stamp (P3 partial).
- email-setup wow kit + get-started JSON-LD (527065f) (W9, P6).
- n8n drafts BUILT + independently re-verified inactive (activeVersionId null):
  - Drain v2 `LZzSF0CfiXxiE06G` — F1 (expiry→ops email + dedup release), F9 (cron
    Mon–Fri 8–18 Madrid, ~4.3k→~1.3k exec/mo), F6 (call_allowance enforcement,
    NULL=unlimited). not_before + call_allowance columns already exist live — no
    migration needed.
  - W1-GATED v2 `IAqF3sVJDuQqK2hm` — F7 (x-llavai-inbox-secret header gate, 403 on
    mismatch; secret lives ONLY in the IF node) + F1 at source (96h expires_at).
  - W4 v2 `rSUCsckVa9dJ5BxE` — F2 (validation: email/UUID/plan/return_to whitelist,
    400 short-circuit), stale Vercel preview origin dropped, errorWorkflow set (F3).

## IN PROGRESS
- Phase 3 wrap-up: remaining proposals + LAUNCH-REPORT.md.

## QUEUED
- Proposal: per-language URLs + hreflang (M10) — strategic SEO.
- Proposal: landing-hero live dossier (roadmap #20 / P3's strongest move).
- 🟢 W7 (<title> per language), W10 leftovers (native file input styling, 👋 copy,
  noscript refresh param) — low value, deliberate skips unless time allows.
- P4 hero WHO/WHY-NOW copy sharpening — founder-voice copy, queued as suggestion in
  LAUNCH-REPORT rather than changed silently.

## NEEDS HARRY (in execution order, each reversible)

**DONE 2026-06-11 evening (launch night, Harry approving live):** A1 ✅ A2 ✅ A3 ✅
(all three cutovers published + live-verified; rollback IDs below remain valid),
C8 ✅ (W3 fired 4×, trialing + cancel verified), C9 ✅ (Starter 410/2,500),
B5 ✅ (Profile Creation draft 24704158 published — onError fix live; rollback
republish 15831bc9), B6 ✅ (all 4 proposed migrations APPLIED + moved to
supabase/migrations/; anon→current_tier verified 42501 permission denied;
leaked-password N/A on free plan — accepted; bucket delete = dashboard-only,
SQL blocked by storage.protect_delete).
B4 ✅ B7 ✅ bucket ✅ (Harry's clicks, confirmed by Harry 2026-06-11 evening).
D10 ✅ past_due = paid for 7 days from last Stripe event (all 3 tier functions,
migration past_due_grace_and_call_allowance; anon-revoke survived the replace —
re-verified 401). D12 ✅ Harry chose 1000 min/mo; enforcement counts CALLS, so
set call_allowance=300 (~1000 min at ~3.3 min/call) — column default + all rows.
D11 ✅ homepage Pro price now €185/mo ×3 langs (matches account.html).
STILL OPEN: D13 (AI Act, mid-July), D14 (Sheets decommission session),
D15 (Apify cost before ~20 subs).

## POST-LAUNCH AUDIT (2026-06-11 late evening — Harry found the messages bug)
Full dead-end audit (3 parallel auditors: n8n estate / frontend / Supabase).
FIXED LIVE (Harry authorized): W6 `2USsHXveBY166yTP` published + pg_net triggers
on messages AND documents (migration messages_notify_trigger; redacted copy in
supabase/migrations/) — emails ops on every client message, [PRO APPLICATION],
and document upload. END-TO-END VERIFIED: test insert → pg_net 200 → W6 exec
3105 success. Also covers the never-wired W5a handshake (frontend never POSTs
to W5a — zero executions ever; left published, now redundant).
UNPUBLISHED (zero legit executions, unauthenticated/legacy): Recall Attempts v1
`4g0N2b6hfXo4u8iD`, Julia confirm logger `535Pb7vqeo14xY4n`, Call outcomes v3
`CcCxPBYVkcNUt2cF`. teaser_listings: authenticated reduced to SELECT-only.
Frontend fixes (b3bca47): availability wipe guard, dismiss/deleteDoc error
honesty, profile success copy honest per-path.
NOTED, not actioned: property_cache dead write (Apify cost lever, see D15);
Profile Creation writes PII to Sheets only — lost-lead risk, raises D14
priority; stripe-checkout webhook guessable (validated input, low risk);
stale "DRAFT" sticky notes on live v2 workflows (Harry to edit text);
Profile Creation needs errorWorkflow click + republish (Harry).

**A. n8n v2 cutovers — ✅ DONE (kept for rollback reference)**
Pre-check for all three: open the workflow in the n8n editor and confirm every
HTTP/email node shows a GREEN credential (create_workflow_from_code "skipped
credential auto-assignment" caveat; ids are pre-bound in code but verify visually).
1. **Drain v2** `LZzSF0CfiXxiE06G`: green creds → unpublish old drain
   `xpSI4mowbRPnjy03` → publish v2. Verify: next business-hours tick runs green;
   optional: insert a test call_queue row with past expires_at → expiry ops email
   arrives + matching queued call_attempts row deleted. ROLLBACK: unpublish v2,
   republish xpSI4mowbRPnjy03 version `bfdfdc08-e420-414c-a141-650b86c4c2c9`.
2. **W1-GATED v2** `IAqF3sVJDuQqK2hm` — FIRST configure CloudMailin: add custom HTTP
   header `x-llavai-inbox-secret` with the value read from the "Inbox Secret Valid?"
   node in the v2 editor (header must be live BEFORE the swap or all alerts get 403).
   Then: green creds → unpublish `0hqUPqF8YsxJP1Et` → publish v2 (same webhook path,
   CloudMailin target URL unchanged). Verify: forward a real alert → 200 + normal
   behavior; curl POST without the header → 403. Optional: set workflow Settings →
   binaryMode "separate" to byte-match production (no functional impact expected).
   ROLLBACK: unpublish v2, republish 0hqUPqF8YsxJP1Et version
   `d4cd1195-a6b9-457c-a002-abe884b773fd`, remove the CloudMailin header.
   (This swap also fixes the weekend-expiry hole at the source AND retires the
   "(W1-GATED draft)" name confusion = audit F15.)
3. **W4 v2** `rSUCsckVa9dJ5BxE`: green Stripe cred (LIVE `G2B8q9RMvmtML0x7`) →
   unpublish `7v8gjHd91PtNBSa1` → publish v2. Verify: real checkout from account.html
   works; curl with bogus user_id → 400, no Stripe session. ROLLBACK: unpublish v2,
   republish 7v8gjHd91PtNBSa1 version `4766700d-d167-448b-ba3d-03103ee86ad2`.

**B. Quick clicks / hand-edits**
4. **errorWorkflow on the rest (audit F3)**: in the n8n editor set Settings →
   Error workflow = "Error Handling" (WUv9QtLxzVWzIhJT) on: W3 `zsBLr5NCkPbps2A3`
   (hand-edit ONLY — never MCP-replace W3), Feed Backfill `lc7n2PBfrXl8xdU7`,
   Profile Creation `XQU6SaN7fWapUA7A`, W5a `Ic18iiJwshQjo2zG`. Republish each.
   (W4 is covered by the v2 swap above.) ROLLBACK: clear the setting.
5. **Profile Creation draft publish (audit F8 part)**: it runs an OLD published
   version (active 15831bc9 ≠ draft 24704158 with the onError email fix). Review the
   draft diff in the editor → publish. ROLLBACK: republish 15831bc9.
6. **Supabase proposed migrations (audit F11 + F1 belt-and-braces)**: review
   supabase/proposed/ (now 4 files incl. 20260611_call_queue_expiry_96h.sql) → say
   "apply the proposed migrations" to Claude or paste into the SQL editor. Each file
   carries its UNDO. Also: Dashboard → Auth → enable leaked-password protection;
   Dashboard → Storage → delete empty "name documents" bucket (F12).
7. **Error-handler subject typo "[Lavai" (F14)**: one-character hand-edit in
   WUv9QtLxzVWzIhJT → republish.

**C. Verifications that need a real action**
8. **W3 end-to-end test (audit F4 — W3 has NEVER fired)**: one real €19 checkout →
   confirm a W3 execution appears, subscriptions.status='trialing',
   current_tier()='trial' in the dashboard → cancel the sub in Stripe. Without this,
   the first paying customer is the test.
9. **n8n plan/quota check (F9)**: Settings → Usage. If on Starter (2.5k exec/mo), the
   OLD drain alone (~4.3k/mo) would exhaust it — cutover #1 drops it to ~1.3k.

**D. Business decisions (memo'd, not decided by Claude)**
10. **past_due grace (F5)**: today a failed renewal charge → instant 'free' lockout
    mid-dunning. Option A: treat past_due as paid for ~7 days (Stripe smart retries
    run); Option B: keep hard lockout. Recommendation: A. One-line SQL change ready
    once you decide.
11. **Pro price on the homepage (M11/business 🟡)**: account.html says €185/mo,
    homepage says only "By application". Recommendation: show €185 (anchors vs human
    flat-finders at far more). Copy is a 2-minute change once you decide.
12. **call_allowance values (business 🔴)**: columns exist, drain v2 enforces, all
    NULL = unlimited today. Recommendation in
    specs/proposals/pro-call-economics-and-allowance.md (150 min/mo + 10 calls/day).
    Set via one SQL UPDATE when decided.
13. **EU AI Act disclosure (applies 2026-08-02)**: review
    specs/proposals/julia-ai-disclosure-art50.md → send to the Spanish legal contact →
    then ask Claude to draft the Retell prompt edit (draft only, you publish).
    Target: published by mid-July.
14. **Phase 4 Sheets decommission (F8)**: plan ready in
    specs/phase4_sheets_decommission_plan.md — schedule a session.
15. **Apify cost at scale (F10)**: before ~20 active subscribers, price the Backfill
    pattern (per-client scrape ×4/day). Options in AUDIT.md.

## DECISIONS
- D0: mission state in specs/mission/ (inside .vercelignore's `specs`).
- D1: F1 fix routed through drafts (W1-GATED v2 sets expires_at) after the classifier
  ruled ALTER COLUMN non-additive; ALTER parked in supabase/proposed/ with UNDO.
- D2: queue expiry releases the call_attempts dedup row via DELETE scoped to
  status=queued AND skip_reason=after_hours_queued (can never delete a real call).
- D3: call_allowance NULL = unlimited; enforcement = skip + ops email, never silent;
  the numbers themselves are Harry's call (proposal #2).
- D4: trial copy now marketed site-wide as "free 3-day trial … €19/mo after" — matches
  the verified live W4 behavior (card now, €0 today). Preceding tag:
  checkpoint/conversion-start.
- D5: Pro stamp says JULIA CALLS (not "BY APPLICATION") — avoids tripling the
  "by application" string already in tag+price; states the differentiator. Preceding
  tag: checkpoint/conversion-start.
- D6: success screens (get-started/profile) reworded to plan-neutral dossier framing
  rather than tier-conditional code — simpler, honest for both plans, no Julia promise
  to non-Pro (CLAUDE.md rule). Preceding tag: checkpoint/webapp-start.
- D7: queued-call rows render inside the existing pipeline list (not a new tab) —
  zero new nav surface, the queue is pipeline state. Preceding tag:
  checkpoint/webapp-start.
