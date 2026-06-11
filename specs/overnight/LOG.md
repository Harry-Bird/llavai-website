# Overnight session log — 2026-06-10/11

## STATUS
Audit COMPLETE → `AUDIT_2026-06-10.md`. Roadmap COMPLETE → `ROADMAP.md` (read both).
Business-hours queue: designed (`specs/business_hours_call_queue_design.md`) and the
`call_queue` table is LIVE (additive migration, verified: RLS on, select-own only).
Three parallel build agents in flight: frontend fixes, n8n W1-draft + drain workflow
(drafts only), repo-SQL truth sync. Nothing published, no calls fired, Stripe untouched.

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

## INCIDENT (no damage — documented for transparency)
- **n8n MCP `update_workflow` is broken tonight (schema skew):** the live server demands
  an undocumented `operations` array while advertising `{workflowId, code}`. All update
  attempts were rejected at input validation (nothing saved). This is also the likely
  story behind the earlier agents' deaths/probe attempt. Consequences: the W1 gate was
  delivered as the parallel W1-GATED workflow above (creation API works fine), and the
  W4 checkout-validation hardening became a documented hand-edit (below) instead of a
  draft. Suggest merging the gotchas paragraph at the bottom of this file into
  CLAUDE.md §Backend (a hook blocked me from editing CLAUDE.md unattended).

## QUEUED
1. **Business-hours call gate + queue** (owner-requested): `call_queue` migration (apply,
   additive) + W1 gate as DRAFT + drain workflow (new, unpublished). Must queue, not skip
   — a skip permanently consumes the dedup slot (audit M1).
2. Repo schema truth: regenerate supabase/schema.sql from live DB + correct the stale
   "no user writes to viewings" note (audit M6). Repo-only, safe tonight.
3. W1 hardening drafts: errorWorkflow wiring, Cache Property undefined-body guard,
   transient-scrape retry-ability (audit M2/minor).
4. W4 checkout input validation + return_to allow-list, drop preview origin (draft) (R6).
5. W3 sync: stop forcing status 'active' on checkout.session.completed; period-end field
   fix (draft) (R4).
6. W5 Pro apply→approve flow: design + build (frontend apply CTA can ship; n8n side draft).
7. Migration files (write, do NOT apply): revoke anon EXECUTE on tier RPCs (R8);
   viewings insert with check source='self'; index on viewings(listing_id).
8. STRIPE.md refresh; teaser_listings SECURITY DEFINER documentation comment (R7).
9. W2.1: callback_later retry via call_queue; call_allowance enforcement design.
10. Phase 4 design: Sheets decommission plan incl. Profile Creation → Supabase lead capture.

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
