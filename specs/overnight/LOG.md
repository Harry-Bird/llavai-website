# Overnight session log — 2026-06-10/11

## MORNING EXECUTION — ROUND 3
- ✅ **#4 Start Call v2.5 RETIRED** (CloudMailin target confirmed by Harry = W1 path
  only). The last unguarded calling path is gone. Rollback: republish nQGk9hfDb4L6VVnx.
- Recall Attempts v1 deactivation deferred to Phase 4 (classifier scoped it out of
  today's authorization; inert anyway — its Retell node is disabled).
- ✅ **#11 W3 status-race FIXED** (Harry hand-edit, Claude-verified live, version
  8836e378, 09:31): checkout.session.completed no longer writes `status` (bare
  `undefined` dropped by JSON.stringify) — `trialing` survives any event order.
  First attempt had `'undefined'` as a string (would have clobbered trialing with
  garbage); caught on verification, corrected, republished. Lesson: verify published
  expression text, not just the publish action.
- Remaining open: W4 validation hand-edit, "name documents" bucket delete,
  W1-GATED rename, Phase 4 execution per specs/phase4_sheets_decommission_plan.md.

## MORNING EXECUTION — ROUND 2 (Retell publish + cutover DONE)
- ✅ **#3 Retell agent v1 PUBLISHED** (verified: is_published:true, webhook→W2, 12
  analysis fields, Harry's prompt edits shipped). The W2 Setup workflow's publish node
  had a bug (415: no Content-Type; then the API requires {"version":1}) — fixed via a
  one-shot workflow. All three setup workflows archived per the design. Post-call data
  now flows to Supabase/dashboard, not Sheets.
- ✅ **#8 BUSINESS-HOURS CUTOVER LIVE** (joint effort — Harry published the drain from
  the UI, Claude swapped W1): old W1 deactivated, W1-GATED active on the same webhook
  path, drain active. **Julia can no longer call outside Mon–Fri 08:00–18:00 Madrid.**
  Credential confidence: in-code bindings proven at runtime by executions 3046/3049.
  ✅ VERIFIED IN PRODUCTION (execution 3052, Harry-authorized synthetic alert):
  webhook → classify → Supabase RPC (cred ✓) → unknown-sender ops email delivered
  (SMTP cred ✓); Retell/Apify never reached. Stripe endpoint also confirmed = W3's
  trigger webhookId, all 4 events. 🖱 Cosmetic: rename "…(W1-GATED draft)" to drop
  "draft" in the UI (MCP rename unavailable).
- Evidence note: the "credentials skipped during auto-assignment" warning on MCP-created
  workflows is noise — bindings work at runtime.

## MORNING EXECUTION (2026-06-11, with Harry's blanket permission)
Checklist results — ✅ done by Claude, 🖱 needs one Harry click, the permission
classifier blocked the rest of the automation (it still enforces last night's
"Retell must not fire" rule and can't see that the morning permission supersedes it):

- ✅ **#1 Trial is LIVE.** W4 draft published (`4766700d…`) + verified end-to-end with a
  real session: livemode:true, amount_total **€0 today** (card now, €19 after 3-day
  trial), metadata.plan=essential stamped. Test session expires harmlessly in 24h.
  This also resolved audit M4's mode question: the key IS live mode — there are simply
  no subscribers yet.
- ✅ **#2 Security hole closed.** "Retell Agent Manager" unpublished.
- ✅ **#5 Spot sync deactivated** (was 96 runs/day, could resurrect dismissed listings).
- ✅ **#6 (partial)** €0 "3 DAY TRIAL" price archived (active:false). Mode confirmed live.
  🖱 Webhook endpoints not exposed via MCP — Dashboard → Developers → Webhooks: confirm
  ONE enabled endpoint → llavai.app.n8n.cloud with the 4 subscription events.
- ✅ **#12 (partial)** W5a "Pro — Application Alert" PUBLISHED. 🖱 Confirm its Fetch
  Profile node shows a green Supabase credential (if not, bind + republish — it fails
  harmlessly meanwhile). W5b stays manual/unpublished as designed.
- 🖱 **#3 Retell agent publish** — classifier blocked the setup-workflow execution.
  EITHER: Retell dashboard → Julia Next Gen → publish draft v1. OR tell Claude
  explicitly "publish the Retell agent now" in a message and it will retry.
- 🖱 **#4 Start Call v2.5** — left ACTIVE deliberately: I cannot see CloudMailin's
  target. Evidence says it points at W1 (W1's 06-09 e2e came through it; v2.5 silent
  since 06-05) but if I'm wrong, unpublishing loses real client alerts. Confirm in the
  CloudMailin dashboard → then unpublish v2.5 (or ask Claude to).
- 🖱 **#7 stray bucket** — SQL deletion is blocked by Supabase storage protection;
  delete "name documents" in Dashboard → Storage (10 seconds, it's empty).
- 🖱 **#8 business-hours CUTOVER — deliberately NOT done blind.** The classifier blocked
  the safe credential-verification runs, and creds are the one thing MCP can't see.
  Runbook (5 min): open `0hqUPqF8YsxJP1Et` (W1-GATED) and `xpSI4mowbRPnjy03` (drain),
  confirm every HTTP/email node shows a green credential (if any are blank: pick
  "Supabase account" / "Apify Token" / "Header Auth account" / "SMTP account") → then
  unpublish W1 `rlv02UB1RHNnQl4i`, publish W1-GATED, publish the drain. CloudMailin
  unchanged. Rollback: swap back.
- 🖱 **#10/#11 W4 validation + W3 status-race hand-edits** — in the n8n editor (MCP
  update API still broken; W3 must never be MCP-replaced anyway).

## STATUS — MORNING HANDOFF (session complete)
Everything queued tonight is done. Read in this order:
1. **AUDIT_2026-06-10.md** — what's broken/missing/risky (headline: the 3-day trial was
   never published; an open webhook can rewrite Julia's agent).
2. **NEEDS HARRY below** — 11 morning actions, ~30–40 min of clicking, each with rollback.
   Items 1–5 are the high-impact ones; item 8 is your business-hours queue cutover.
3. **ROADMAP.md** — Now/Next/Later, evidence-linked.
Shipped live tonight (all verified headlessly): 6 frontend fixes + the W5 "Apply for
Pro" flow (CTA + RPC). Applied to the DB (additive only): call_queue + apply_for_pro.
Built as never-published drafts awaiting your review: W1-GATED (business-hours gate),
Call Queue Drain (W1.5), Pro Application Alert (W5a), Pro Approve/Reject (W5b, stays
manual forever). Guarantees held all night: no publishes, no outbound contact, no calls,
Stripe read-only, everything reversible. One tooling incident (n8n update API schema
skew) — no damage, documented below, workaround already applied.

## DONE
- Phase 1 audit, 5 areas, all re-verified → specs/overnight/AUDIT_2026-06-10.md
- Business-hours call queue: design doc + `business_hours_call_queue` migration applied
  (additive; table verified live with RLS + select-own policy)
- Product roadmap → specs/overnight/ROADMAP.md (Now/Next/Later, evidence-linked)
- W5 Pro apply→approve: design doc (specs/w5_pro_application_design.md) + migration
  `w5_apply_for_pro` APPLIED (additive RPC, verified: secdef, authenticated-only,
  anon revoked). n8n W5a/W5b drafts + frontend CTA pending (queued behind running agents).
  Mirror this migration into supabase/migrations/ after the SQL-truth agent finishes.

- Repo SQL truth (audit M6) COMPLETE: schema.sql regenerated from live DB (6 missing
  tables, both views incl. teaser SECURITY DEFINER warning, 5 functions, 10 policies,
  ~21 columns now captured; stale viewings comment corrected); supabase/migrations/
  mirrors call_queue + w5_apply_for_pro; supabase/proposed/ holds 3 reviewed-NOT-applied
  hardening migrations (anon RPC revoke, viewings source='self' check — verified safe
  against addViewing(), viewings.listing_id index); STRIPE.md refreshed.
  Follow-up noted: delete superseded listings.sql + migration-supabase-first.sql.
- Frontend fixes 1–6 ALL committed, headlessly verified, live-deploy spot-checked:
  checkout alert() → trilingual inline error (bdb8e35), undoDismiss null fix (2b56186),
  profile wizard Enter-advances via real forms (adde234), account add-viewing +
  preferences Enter-submit (0047898), 4 placeholders translated ES/UK (90db793),
  all canonicals/og/sitemap/robots → www host, no trailing slashes (8b6f1d4).
- Phase 4 Sheets decommission: ordered 6-step reversible plan →
  specs/phase4_sheets_decommission_plan.md (no data migration needed anywhere).

- W5 "Apply for Pro" CTA LIVE (72cac5d): apply form in #pipelineUpsell → live
  apply_for_pro() RPC; APPLICATION RECEIVED / APPROVED rubber stamps; trilingual;
  friendly('apply') errors; 322/322 headless checks (4 tiers × 5 statuses × 3 langs,
  mobile overflow clean). Applications land in the messages table — check Messages
  triage in the morning. n8n W5a (instant ops email) + W5b (approve/reject manual
  workflow) still to be drafted.

- **Drain workflow BUILT**: "Concierge — Call Queue Drain (W1.5)" `xpSI4mowbRPnjy03`,
  NEVER published (activeVersion null, inactive). Verified by direct inspection: every-10-min
  schedule → Madrid business-hours gate (Intl, DST-proof) → expire pass → atomic claim
  (pending→processing is the lock, FIFO, limit 3/tick) → re-check attempt still queued
  (cancel branch if not) → fire Retell from stored payload → success mirrors W1
  (queue=called, attempt=calling, viewings insert — ALL insert columns verified against
  the live viewings table) / failure → queue=failed + ops email, no auto-retry.
  errorWorkflow wired. Caveat for review: MCP can't verify credential bindings — open
  the workflow in the editor and confirm the Supabase/Retell/SMTP nodes show green creds.

## INCIDENT (no damage — documented for transparency)
- The first W1-gate agent died on an API socket error; the harness flagged that it had
  attempted to overwrite the W1 draft with a single-node "probe" stub. VERIFIED CLEAN:
  W1 versionId == activeVersionId == bf17abe6 (original), updatedAt unchanged (06-09),
  all 28 nodes intact, no stray workflows. Nothing persisted; production was never at
  risk (drafts don't run production). The relaunched agent is constrained to exactly one
  full-content update, stubs forbidden.

- **W1 business-hours gate BUILT — as a parallel draft workflow** (W1 itself untouched):
  "Concierge — Alert to Feed + Julia Call (W1-GATED draft)" `0hqUPqF8YsxJP1Et`,
  validated (34 nodes), unpublished/inactive (activeVersion null). It is W1 reproduced
  exactly + Business Hours Gate (Madrid, DST-proof) + Office Open? IF: open → Trigger
  Retell Call unchanged; closed → Queue Call (call_queue insert, ignore-duplicates,
  carrying the EXACT Retell payload) → call_attempts.skip_reason='after_hours_queued'.
  Bonus: errorWorkflow wired + Cache Property undefined-body guard. Same webhook path
  as W1, so go-live is an unpublish/publish swap with no CloudMailin change (cutover
  sticky inside the workflow). Why a parallel workflow: see incident note below.

- **W5a + W5b BUILT as never-published drafts** (verified inactive, activeVersion null):
  - "Pro — Application Alert (W5a)" `Ic18iiJwshQjo2zG` (7 nodes): webhook → email
    validate → profile lookup (must exist + pro_status='applied') → ops email to
    harry.bird@llavai.com. Webhook path is random 32-hex — lives only in n8n, NOT
    written here (repo no-secrets rule); open the workflow to read it. Wiring the
    frontend's best-effort POST to it is optional (the messages row from apply_for_pro()
    is already the source of truth, working tonight).
  - "Pro — Approve or Reject (W5b, manual)" `qf7hdl8rvb2CBJVP` (12 nodes): MEANT to stay
    unpublished forever — run manually with the "Input — Edit Before Running" Set node
    ({email, action approve|reject}). Approve: pro_status → approved, creates the Pro
    Stripe checkout session (€185 price, no trial, plan/user_id metadata so W3 maps it),
    emails the client the link (owner-initiated by you running it). Reject: pro_status →
    rejected. Throws clearly on bad input or wrong application state.
  - Same credential caveat as the other new workflows: confirm green creds on the HTTP
    nodes before first use (Supabase + the LIVE "Stripe account" `G2B8q9RMvmtML0x7`).

## INCIDENT (no damage — documented for transparency)
- **n8n MCP `update_workflow` is broken tonight (schema skew):** the live server demands
  an undocumented `operations` array while advertising `{workflowId, code}`. All update
  attempts were rejected at input validation (nothing saved). This is also the likely
  story behind the earlier agents' deaths/probe attempt. Consequences: the W1 gate was
  delivered as the parallel W1-GATED workflow above (creation API works fine), and the
  W4 checkout-validation hardening became a documented hand-edit (below) instead of a
  draft. Suggest merging the gotchas paragraph at the bottom of this file into
  CLAUDE.md §Backend (a hook blocked me from editing CLAUDE.md unattended).

## QUEUED — all original items closed; deliberately NOT done tonight
- Transient-scrape retry-ability in W1 (audit minor): failed Apify scrapes still consume
  the dedup slot. Natural home is the call_queue retry pattern (W2.1) — roadmap item 11.
- W2.1 build (callback_later retries + call_allowance enforcement): designed in outline
  (call_queue design §4: reason='callback_later' + not_before; allowance check in the
  drain's re-verify step) — roadmap item 11, build next session.
- Frontend POST to W5a (optional best-effort speed alert): needs the webhook path, which
  would be public in the HTML like the checkout URL — your call (NEEDS HARRY 12).
- Sheets decommission execution: plan ready (specs/phase4_sheets_decommission_plan.md),
  blocked on morning approvals (Retell publish, CloudMailin confirm).

## NEEDS HARRY (morning checklist — each with rollback)
1. **Publish W4 checkout draft** `7v8gjHd91PtNBSa1` — ships the 3-day trial + plan
   stamping (B1, currently customers are charged immediately). Then run ONE test checkout
   and confirm `subscriptions.status='trialing'`. Rollback: republish previous version
   (611e4527).
2. **Unpublish/archive "Retell Agent Manager"** `FjW1V5CLHHUTxflI` — unauthenticated
   guessable webhook that can rewrite/publish Julia's agent (R1). Superseded by W2 Setup.
   Rollback: republish.
3. **Publish the Retell agent draft (v1)** — ships your 06-09 prompt edits + W2 post-call
   wiring (pre-existing item). Until then post-call data goes to Sheets.
4. **Confirm CloudMailin targets ONLY `/webhook/pro-concierge-inbox`**, then unpublish
   Start Call v2.5 (R2 — it has no tier gate and can double-call).
5. Deactivate "Spot — Sheets to Supabase sync" (R3 — runs 96×/day, can resurrect
   dismissed listings) once you're happy the feed comes from W1 + Feed Backfill.
6. Stripe dashboard (write ops, not done tonight): archive €0 "3 DAY TRIAL" price
   `price_1TgL9eF7TyaJ4FzifrGNTqZ1` (R5); verify webhook endpoint exists in the
   PRODUCTION mode with the 4 sub events (M4 — W3 has never fired); check whether the
   MCP key is test or live mode (0 subscriptions visible).
7. Delete stray empty storage bucket `"name documents"` in Supabase.
8. **Business-hours queue go-live (the cutover):**
   a. Open BOTH new workflows in the n8n editor and confirm every HTTP/email node shows
      a green credential (create_workflow_from_code may skip credential auto-assignment
      — known caveat, ids are in the SDK code): "W1-GATED draft" `0hqUPqF8YsxJP1Et` and
      "Call Queue Drain (W1.5)" `xpSI4mowbRPnjy03`.
   b. Review the gate diff (only additions: Business Hours Gate, Office Open?, Queue
      Call, Mark Attempt Queued For Hours, cutover sticky; plus errorWorkflow setting
      and the Cache Property guard).
   c. Cut over: unpublish W1 `rlv02UB1RHNnQl4i` → publish W1-GATED → publish the drain.
      CloudMailin needs no change (same webhook path).
   d. Verify: temporarily narrow the gate window (or send a synthetic off-hours alert)
      → row lands in call_queue, no call; restore window → drain fires within 10 min.
   e. Rollback: unpublish W1-GATED + drain, republish W1. Queue rows: one PATCH to
      status='cancelled'.
9. FYI: until #8 ships, the live W1 still calls at any hour on a real Pro alert.
10. **W4 checkout hand-edit** (while publishing the trial draft, item #1 — MCP updates
    are broken, see incident): in "Stripe — Create Checkout Session" add an IF/Code
    validation after the webhook — require email (regex), UUID user_id, and `return_to`
    matching ^https://(www\.)?llavai\.com(/|$) (else respond 400, don't call Stripe);
    and remove the stale Vercel preview URL from the webhook's allowedOrigins.
11. **W3 sync hand-edit** (do NOT update via MCP — its Stripe Trigger re-registers the
    live webhook on full-replace, and update_workflow is broken anyway): in "Upsert
    Subscription", stop forcing status:'active' on checkout.session.completed — let only
    customer.subscription.created/updated set status (fixes the trial-shows-as-essential
    race, audit R4). Small edit in the n8n editor.
12. **W5 go-live**: verify creds on W5a `Ic18iiJwshQjo2zG` + W5b `qf7hdl8rvb2CBJVP`
    (HTTP nodes may show unbound — known caveat), then publish W5a only (W5b stays
    manual/unpublished forever). Applications already reach you via the Messages tab
    without it; W5a just adds an instant ops email. Optional: wire account.html's
    apply flow to POST to W5a's webhook (path is in the workflow; it would be public
    in the HTML like the checkout URL — same posture, your call). Test the full loop
    with a test account: apply → messages row + (if published) ops email → W5b approve
    → checkout link lands → pay test → current_tier()='pro'. Rollback: unpublish W5a;
    the RPC/CTA are harmless without approval.

## CONSTRAINTS IN FORCE
Nothing published, no outbound contact, no workflow executions with side-effects,
Stripe read-only, additive SQL only, everything reversible.

## n8n MCP gotchas worth merging into CLAUDE.md §Backend (2026-06-11)
- `update_workflow` can develop schema skew (server demanded an undocumented
  `operations` array while advertising `{workflowId, code}`); when it does, build a NEW
  never-published workflow via create_workflow_from_code (same webhook path is fine
  while unpublished) and cut over by unpublish-old/publish-new.
- `create_workflow_from_code` may SKIP credential auto-assignment on HTTP nodes even
  when the SDK code pre-binds ids — verify green credentials in the editor before
  publishing anything.
- The MCP connection stalls/socket-drops under long sessions; after any failed write,
  verify state read-only (versionId/activeVersionId/updatedAt) — drafts ≠ production,
  so dead attempts usually changed nothing.
