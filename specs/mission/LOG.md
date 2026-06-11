# Mission log — production-ready + launch-grade (started 2026-06-11)

## STATUS (read this first)
Phase 2 reliability workstream RUNNING: builder sub-agent is creating 3 never-published
n8n drafts (Drain v2 = F1 expiry alert/release + F9 cron + F6 allowance; W1-GATED v2 =
F7 secret gate + explicit 96h expires_at; W4 v2 = F2 validation + errorWorkflow).
Audits done: reliability, marketing, business (AUDIT.md). Web-app agent still running.
expires_at 96h migration → supabase/proposed/ (classifier ruled ALTER non-additive;
W1-GATED v2 fixes it at insert anyway). Production untouched. Tag pre-mission = 2406434.

## DONE
- Phase 0: read CLAUDE.md, overnight AUDIT/LOG/ROADMAP, retro, backend architecture.
  Tagged `pre-mission`, created RESET.md + this log.
- Phase 1 (area 4, business): 7 proposals in specs/proposals/ — AI-disclosure Art.50
  script, Pro call economics/allowance, trial 3→7d design, Julia-on-demand bridge tier,
  growth-first-100, retention-after-keys, price-drop digest. Plus model findings to
  merge into AUDIT.md. CROSS-CHECK PENDING: its 🔴 "trial charges €19" cites the OLD
  audit B1; overnight LOG says W4 trial was published+verified 06-11 — reliability
  agent will confirm published state before this is treated as open.

## IN PROGRESS
- Phase 1 gap audit: reliability, web-app, marketing agents running.

## QUEUED (ordered by user impact; reliability > conversion > polish)
1. F1 🔴 weekend queue expiry: migration (expires_at 48h→96h) + drain-v2 draft
   (expired→ops email + dedup release + business-hours cron, fixes F9 too). (C+H)
2. F2 🟡 W4 checkout validation: parallel validated draft on same path. (C+H)
3. F6 🟡 W2.1 retries + call_allowance enforcement in drain-v2. (C+H — merge into #1's
   drain-v2 build if tractable)
4. F7 🟡 CloudMailin secret gate node in a W1-GATED-v2 draft. (C+H)
5. F3 🟡 errorWorkflow on W3/W4/Backfill/ProfileCreation/W5a — runbook for hand-edits,
   MCP attempt where safe (NOT W3). (mostly H)
6. Web-app + marketing audit findings — pending agents.
7. F10 🟡 Backfill Upsert status check (C draft) + cost note (H).
8. F5 🟡 past_due grace — write decision memo under NEEDS HARRY. (H)
9. F4 🟡 test checkout runbook under NEEDS HARRY. (H)
10. Dashboard: render viewings.notes + call_queue "queued — Julia calls when offices
    open" state (roadmap #9, retention story). (C)
11. 🟢 F11–F15 batch (proposed migrations runbook, bucket, typo, rename). (H mostly)

## NEEDS HARRY
(none yet)

## DECISIONS
- D0 (2026-06-11): Mission state lives in specs/mission/ (already inside .vercelignore's
  `specs` exclusion — verified, so nothing here is served publicly). Alternative: new
  top-level dir + new .vercelignore entry; rejected as needless surface.
- D1 (2026-06-11, after checkpoint/reliability-start): F1 fix routed through workflow
  drafts (W1-GATED v2 sets expires_at=+96h at insert) instead of a live DB ALTER — the
  permission classifier ruled ALTER COLUMN SET DEFAULT outside "additive"; respected,
  not worked around. The ALTER lives in supabase/proposed/20260611_call_queue_expiry_96h.sql
  (with UNDO) as belt-and-braces for any future insert path. Alternative: ask Harry to
  apply mid-mission; rejected — the draft swap covers it and batches Harry's clicks.
- D2 (2026-06-11): On queue expiry, drain v2 DELETEs the call_attempts row scoped to
  status=queued AND skip_reason=after_hours_queued — frees the dedup slot so a future
  re-alert can retry, can never touch a real call record. Alternative (PATCH to skipped)
  keeps dedup blocked forever; rejected as it preserves the silent-loss failure mode.
- D3 (2026-06-11): call_allowance semantics in drain v2: NULL = unlimited (all current
  rows NULL → zero behavior change until Harry sets values). Enforcement = skip + ops
  email, never silent. Pricing/quota numbers themselves stay a Harry decision
  (specs/proposals/pro-call-economics-and-allowance.md).
