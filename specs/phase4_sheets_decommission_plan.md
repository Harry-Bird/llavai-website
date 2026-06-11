# Phase 4 — Google Sheets decommission plan

Status: PLANNED 2026-06-11 (overnight). Evidence: n8n audit dependency map
(`specs/overnight/AUDIT_2026-06-10.md` + agent report). Spreadsheet:
`1hB3W09h0Vk2n089nmgS1MkobNU-jhiAMtiSSGEM58qw` ("Llavai_Database"),
credential `TZ5QLRwY6H74Yc8O`. Six of seven Sheets workflows are still ACTIVE.

## Ordered cutover (each step independently reversible)

**Step 0 — Safety export (manual, 5 min).** Download the full spreadsheet as
CSV/XLSX once and archive it outside the repo (per rebuild spec §6). Gate for
everything below.

**Step 1 — Replace "Profile Creation" `XQU6SaN7fWapUA7A`** — the ONLY Sheets workflow
in a live user-facing path (lead capture). It already lost a real lead on 06-04 to a
Sheets schema error. Replace its `Save to Client_Profiles` node with a Supabase check
("did the magic-link signup land in `profiles`?" — the frontend already writes Supabase
directly per `backend_architecture_design.md` §4.1; this workflow's residual value is
the team email + a safety net). Build as draft → publish in the same review as the
other morning items. Rollback: republish prior version.

**Step 2 — Deactivate the redundant pollers** (no replacement needed, W1 + Feed
Backfill own these paths now):
- "Spot — Sheets to Supabase listings sync" `WumvVn7fOJSgF9OJ` (audit R3: 96 runs/day,
  legacy >70 gate, resurrects dismissed listings).
- "Recall Attempts v1" `4g0N2b6hfXo4u8iD` (its Retell node is disabled — it only
  updates Sheets counters that nothing reads; real retries arrive with W2.1 via
  `call_queue.reason='callback_later'`).
Rollback: reactivate.

**Step 3 — Post-call satellites** (blocked on Harry publishing the Retell agent draft,
which moves the webhook to W2):
- "Call outcomes v3" `CcCxPBYVkcNUt2cF` — deactivate once one real call has flowed
  through W2 end-to-end.
- "Julia — confirm_viewing logger" `535Pb7vqeo14xY4n` — the Retell LLM fires a mid-call
  `confirm_viewing` tool at it. Migrate: small n8n workflow writing the same payload to
  `viewings` (match by user/property, set `viewing_at` hint) or simply into `messages`
  for ops visibility; THEN repoint the LLM tool URL (agent draft edit → Harry publishes);
  THEN deactivate the Sheets logger.

**Step 4 — Start Call v2.5** `nQGk9hfDb4L6VVnx` (audit R2) — confirm CloudMailin targets
only `/webhook/pro-concierge-inbox`, then unpublish. Independent of Sheets but listed
here because it's the last big Sheets consumer (11 nodes).

**Step 5 — Remove the credential.** When zero active workflows reference
`TZ5QLRwY6H74Yc8O`, delete it from n8n (the hard guarantee no flow silently writes
Sheets again). Also archive the never-published clutter: "AI Agent workflow"
`GNdoH1JSk2j1WuXF`, "Calendar App" `GOo6JRVsG7oJOL2x`, and "W2 Setup" `vABLqiZVBxsmLSNM`
once the Retell agent is published.

**Step 6 — W6 document retention** (rides along with Phase 4 per rebuild spec §4):
`pg_cron` job deleting `documents` rows past `expires_at` + their Storage objects.
Pairs with the GDPR retention decision (SETUP.md §5) — needs Harry to pick the
retention window first.

## What each Sheets tab's data becomes
| Tab | Successor | Migration needed? |
|---|---|---|
| Client_Profiles | `public.profiles` | None (long since live) |
| Client_Alerts | `call_attempts` | History optional — keep CSV export only |
| Properties_Scraped / Property_Info | `property_cache` + `listings` | None — cache rebuilds itself (24h TTL) |
| Call_Outcomes | `call_attempts` + `viewings` via W2 | History optional — CSV export |
| Booking_Info | `viewings` | History optional — CSV export |

No tab requires a data migration: Supabase is already the system of record for every
live path; Sheets holds only history, preserved by the Step-0 export.
