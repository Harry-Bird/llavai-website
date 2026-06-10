# W2 — Retell post-call webhook: technical design

Status: BUILT & VERIFIED 2026-06-10 (synthetic end-to-end: booked flip, replay no-op,
non-analyzed event ignored). Workflow "Concierge — Post-Call Update (W2)" `3IugKzEahVXSZHwr`,
published. **Pending one human action:** the Retell agent's webhook_url + analysis fields
were applied to the agent *draft* (v1) only — production calls use published v0 until
**Harry publishes the agent** (his 2026-06-09 LLM prompt edits ship with it; deliberately
not published unilaterally). Until then post-call events still go to the old
"Call outcomes v3" (Sheets). Companion to `backend_rebuild_architecture.md`
(closes W1's loop step *h*).

## 1. Goal

When Julia's call reaches a terminal state, Retell fires `call_analyzed` → n8n W2:
- `call_attempts`: status `calling` → `completed`/`failed`, + `duration_minutes`
  (numeric 2dp — the unit the future Pro cap `subscriptions.call_allowance` is modelled in),
  `disconnection_reason`, `ended_at`.
- `viewings` (the row W1 inserted with status `calling`, source `julia`):
  → `booked` (+`viewing_at`, `confirmed_at`) / `declined` / `no_answer`, summary into `notes`.

## 2. Three perspectives

- **[Backend]** Migration `w2_call_attempts_post_call_columns` (applied):
  `call_attempts` + `duration_minutes numeric(8,2)`, `disconnection_reason text`,
  `ended_at timestamptz`, partial **unique** index on `retell_call_id`.
  New n8n workflow **"Concierge — Post-Call Update (W2)"**, single responsibility.
- **[Frontend]** No changes. `account.html` already renders/translates `booked`,
  `declined`, `no_answer` badges. `viewings.notes` is stored but not yet rendered;
  the card template escapes everything via `esc()`, so rendering it later is safe.
- **[Security]** §6.

## 3. Retell agent setup (one-shot, separate setup workflow)

Agent `agent_774cc5844d7d7824eb70b63fe4` ("Julia Next Gen") needs:
- `webhook_url` → the W2 webhook (secret path — lives only in n8n + Retell, **not in this repo**).
- `post_call_analysis_data` (merged with whatever exists, never replaced blindly):
  - `viewing_booked` *(boolean)* — true only if a concrete date+time was agreed.
  - `viewing_datetime` *(string)* — ISO 8601 with offset, Europe/Madrid (adds the DATE the
    legacy fields lack).
  - `call_outcome` *(enum)* — `booked | declined | callback_later | no_answer | other`.

What inspection found (2026-06-10): the agent already had 9 Spanish analysis fields
(`Outcome` enum incl. booking_confirmed/disqualified, `property_still_available`,
`viewing_time_extracted` HH:MM-only, `agent_email_captured`, compliance/quality fields) —
all preserved, ours appended (12 total). Its webhook_url pointed at the old Sheets-based
"Call outcomes v3" (`CcCxPBYVkcNUt2cF`) — W2 supersedes it (its "client" emails actually
went to harry.bird@, so nothing client-facing is lost). The Retell LLM also fires a
mid-call `confirm_viewing` tool at `webhook/julia-confirm-viewing` ("Julia — confirm_viewing
logger" → Sheets) — unaffected by this cutover, Phase-4 migration candidate. "Recall
Attempts v1" (failed-call retry via Sheets) is not replicated by W2 (W2.1 candidate).

Retell PATCH `update-agent` edits the **latest draft**; production calls use the
**published** version (v0 here). Setup workflow `vABLqiZVBxsmLSNM` (never published; run
via manual executions with `{"action": "inspect" | "versions" | "llm" | "apply" | "publish"}`)
applied the patch to draft v1 after the rails confirmed what was pending: the agent draft
was an auto-draft, but the **LLM draft carries Harry's 2026-06-09 edits**, so `publish`
was left to Harry — one click ships his prompt iteration + the W2 wiring together.
Archive the setup workflow once that's done.

## 4. Event handling (W2)

Process **only `event == 'call_analyzed'`** — it fires for connected *and* failed
dials and carries `call_analysis`. `call_started`/`call_ended` → 200, ignore.
Always respond 200 immediately (Retell: 10s timeout, 3 retries).

| `disconnection_reason` | call_attempts.status | viewings.status |
|---|---|---|
| `dial_no_answer`, `dial_busy`, `voicemail_reached`, `machine_detected`, `inactivity` | `completed` | `no_answer` |
| `dial_failed`, `invalid_destination`, `concurrency_limit*`, `no_valid_payment`, `scam_detected`, `error*`, `telephony*`, anything unknown | `failed` | `no_answer` + ops email |
| connected (`user_hangup`, `agent_hangup`, `call_transfer`, `max_duration_reached`) | `completed` | from analysis ↓ |

Connected-call outcome from `call_analysis.custom_analysis_data` — new fields with
**legacy cross-reads** as fallback:
booked := `viewing_booked === true` OR `call_outcome === 'booked'` OR legacy
`Outcome === 'booking_confirmed'` → **booked** (+`viewing_at` if `viewing_datetime`
parses sanely — between now−1d and now+60d — else booked with null `viewing_at`; raw
string or legacy `viewing_time_extracted` kept in notes as a time hint);
else declined := `call_outcome === 'declined'` OR legacy `Outcome === 'disqualified'`
OR `property_still_available === false` → **declined**; everything else
(`callback_later`, `no_answer`, `other`, `lead_captured`) → **no_answer** with the
nuance in `notes` (`Julia: <call_summary>`; legacy `agent_email_captured` appended as
"(Agency contact: …)").

Duration: `round(duration_ms/60000, 2)`, fallback `(end_timestamp−start_timestamp)`,
else 0 (failed dials).

## 5. Data flow & idempotency

1. Webhook (POST, secret path) → respond immediately.
2. Code "Gate & Parse": event gate, **agent_id allow-list**, call_id shape check
   (`^[A-Za-z0-9_-]+$`), outcome/duration derivation (§4).
3. **Atomic claim**: `PATCH call_attempts?retell_call_id=eq.<id>&status=eq.calling`
   with `Prefer: return=representation` → returns `user_id`+`property_id`.
   Replays/duplicate deliveries match 0 rows ⇒ chain stops cleanly.
4. 0 rows → `GET` same call_id without status filter:
   exists ⇒ already processed (ignore); missing ⇒ **ops email** (unknown call_id).
5. `PATCH viewings?user_id=eq.…&property_id=eq.…&source=eq.julia&status=eq.calling`
   → status/viewing_at/confirmed_at/notes.
6. Error-class disconnects additionally send an ops email (call_id + reason only).

Join key is `retell_call_id` (stored by W1's "Mark Attempt Calling"). Deliberately
**no W1 changes**. Fallback if it was never stored: the webhook payload echoes
`retell_llm_dynamic_variables` (`client_email`, `property_url`) — manual recovery
via the ops email; automating that is W2.1 if it ever actually happens.

## 6. Security checkpoint

- **AuthN**: unguessable 32-hex webhook path over HTTPS. Retell's `x-retell-signature`
  HMAC needs the API key *inside* a Code node — n8n Cloud credentials aren't readable
  there, so signature verification is an upgrade path (n8n Variables), not v1.
- **AuthZ / blast radius**: agent_id allow-list; the workflow can only *update* rows
  already in status `calling` matched by an unguessable call_id; it inserts nothing;
  field set is fixed. Forged requests with random call_ids → at most an ops email.
- **Validation**: event type, call_id charset, datetime parse + sanity window,
  status values from a fixed map (CHECK constraints as backstop).
- **Output/PII**: webhook response is an immediate empty 200 (no echo). Ops emails
  carry call_id + disconnection_reason only — no client name/email/phone, no transcript.
- **XSS**: `notes` not rendered today; `esc()` discipline already in the card template.
- **Injection**: REST writes are JSON-encoded bodies; filter values are validated
  (charset above) before interpolation into the PostgREST query string.
- **Secrets**: webhook path not committed (this repo deploys to a public site);
  Supabase service-role + SMTP via pre-bound n8n credential IDs.

## 7. Out of scope (W2.1+)

Client "viewing booked" notification email; `callback_later` retry queue;
`call_allowance` enforcement (sum of `duration_minutes` per period);
Retell signature verification via n8n Variables.
