# Overnight session log — 2026-06-10/11

## STATUS
Audit COMPLETE → `AUDIT_2026-06-10.md` (read that first). Headline findings: the 3-day
trial was never published in n8n (live checkouts charge immediately) — one-click fix for
you; an unauthenticated webhook can rewrite Julia's agent (unpublish it); W1 has no error
handling (failed calls strand clients permanently); confirmed W1 will call at any hour —
building your business-hours queue now. Phase 2 (safe fixes) + Phase 3 (builds, drafts
only) in progress. Nothing published, no calls fired, Stripe untouched.

## DONE
- Phase 1 audit, 5 areas, all re-verified → specs/overnight/AUDIT_2026-06-10.md

## IN PROGRESS
- Phase 2: frontend fixes (checkout alert() B2, Enter-submit, placeholders, canonicals, undoDismiss)

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
8. Business-hours queue go-live (after reviewing tonight's build): publish W1 draft +
   the drain workflow. Steps + rollback will be appended here once built.
9. FYI: until #8 ships, the live W1 still calls at any hour on a real Pro alert.

## CONSTRAINTS IN FORCE
Nothing published, no outbound contact, no workflow executions with side-effects,
Stripe read-only, additive SQL only, everything reversible.
