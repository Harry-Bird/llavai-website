# Business-hours call gate + queue — technical design

Status: DESIGNED 2026-06-11 (overnight session). Owner requirement: Julia may only place
calls **Mon–Fri 08:00–18:00 Europe/Madrid**. Off-hours triggers must queue, not call and
not skip. Companion to `backend_rebuild_architecture.md` (modifies W1 step *g*).

## 1. Goal

An Idealista alert arriving at 03:00 (or Saturday) for a Pro client must NOT dial the
agency. Instead the fully-prepared call is queued and fired at the next business-hours
opening, FIFO. No call may ever bypass the gate; everything is reversible and idempotent.

## 2. Three perspectives

**[Backend]**
- New table `public.call_queue` (additive migration `business_hours_call_queue`):
  - `id uuid pk default gen_random_uuid()`
  - `user_id uuid not null references auth.users(id) on delete cascade`
  - `property_id text not null`, `listing_id uuid references listings(id) on delete set null`
  - `retell_payload jsonb not null` — the exact create-phone-call body W1 would have sent
  - `reason text not null default 'after_hours'` ('after_hours' | future: 'callback_later',
    'allowance_wait' — deliberately generic so W2.1 retry reuses this table)
  - `status text not null check in ('pending','processing','called','failed','expired','cancelled') default 'pending'`
  - `created_at timestamptz default now()`, `not_before timestamptz` (earliest allowed fire,
    null = next window), `expires_at timestamptz default now() + interval '48 hours'`
    (a 2-day-old rental lead is dead — expire, don't embarrass Julia), `processed_at timestamptz`,
    `retell_call_id text`, `last_error text`
  - `unique (user_id, property_id)` — mirrors `call_attempts` dedup
  - index `(status, created_at)`
  - RLS: enabled; `call_queue_select_own` (users may see their own queued calls — future
    "Julia calls at 8am" UI); **writes service-role only** (no insert/update/delete policies).
- **W1 change (draft only tonight):** insert a Code node **`Business Hours Gate`** between
  `Should Call?` and `Trigger Retell Call`:
  - Compute now in Europe/Madrid via `Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Madrid',
    weekday:'short',hour:'2-digit',hour12:false})` (DST-proof, no n8n TZ assumptions).
  - OPEN = Mon–Fri && 08 ≤ hour < 18 → route to `Trigger Retell Call` unchanged.
  - CLOSED → route to new HTTP node **`Queue Call`**: POST `call_queue` row carrying the
    already-built Retell payload + user/property/listing ids (Prefer:
    resolution=ignore-duplicates so replays are no-ops), then **`Mark Attempt Queued For
    Hours`**: PATCH `call_attempts` `skip_reason='after_hours_queued'` (status stays
    `queued` — the row is real, the call is pending; W2's claim later flips it to
    calling/completed as normal). The dedup slot is intentionally retained by the queue row.
  - The `Insert Viewing` node must remain downstream of Retell accept only (unchanged rule:
    no phantom "Julia is calling" rows).
- **New workflow `Concierge — Call Queue Drain (W1.5)` (created tonight, NEVER published):**
  - Schedule trigger every 10 min.
  - Node 1 `Business Hours Gate` (same Code logic; also a hard re-check — defence in depth).
    Closed → end.
  - Node 2 expire pass: PATCH `call_queue` set status='expired' where status=eq.pending and
    expires_at=lt.now().
  - Node 3 **atomic claim**: PATCH `call_queue` set status='processing', processed_at=now()
    where `status=eq.pending&not_before=lte.now()` (or null) `order=created_at.asc&limit=N`
    (N=3 per tick — natural rate limit), `Prefer: return=representation`. 0 rows → end.
    Concurrent ticks cannot double-claim (status transition is the lock).
  - Per claimed row: re-verify `call_attempts(user_id,property_id)` still `status=queued`
    (user might have been downgraded/cancelled — also re-check tier via `get_call_client`
    if cheap) → fire Retell with `retell_payload` → on accept: stamp `retell_call_id` on
    BOTH `call_queue` (status='called') and `call_attempts` (status='calling', same as W1's
    `Mark Attempt Calling`) → insert the `viewings` row (status 'calling', source 'julia')
    exactly as W1 does. On Retell failure: `call_queue.status='failed'` + `last_error` +
    ops email; attempt stays `queued` for manual review (no auto-retry storm in v1).
  - errorWorkflow: `WUv9QtLxzVWzIhJT`.

**[Frontend]** None required tonight. (Future: account.html pipeline tab could render
"Queued — Julia calls when offices open" from `call_queue_select_own`.)

**[Security]**
- `call_queue` writes are service-role only; `retell_payload` contains the same PII W1
  already sends Retell (name, phone, property) — rests only in Postgres under RLS, same
  posture as `property_cache`. Select-own policy exposes a user only their own rows.
- The drain workflow holds no new secrets (same pre-bound n8n credential IDs).
- Gate is enforced in BOTH W1 (entry) and the drain (exit) so a future flow that inserts
  into `call_queue` directly still cannot fire off-hours.
- Expiry prevents an unbounded backlog from a weekend alert flood (Mon 08:00 burst is
  capped at N×6/hour by the claim limit).

## 3. Rollout (NEEDS HARRY — nothing live tonight)

1. Migration `business_hours_call_queue` — applied tonight (additive, zero-risk).
2. Review W1 draft diff + the unpublished drain workflow.
3. Publish W1 draft, then publish the drain workflow (this order: gate before drain is
   harmless; drain before gate is too — table is just empty).
4. Verify: send a synthetic off-hours alert (or temporarily narrow the window) → row lands
   in `call_queue`, no call; widen window → drain fires within 10 min and the normal
   W2 post-call loop closes.
5. Rollback: republish previous W1 version; unpublish drain. Queue rows can be bulk
   `cancelled` with one PATCH. Table can stay (inert).

## 4. Out of scope (noted for W2.1)

`callback_later` retries land naturally here (insert with reason='callback_later',
not_before=+2h). `call_allowance` enforcement belongs in the drain's re-verify step.
Spanish public holidays (Festivos) — v2 candidate: a small `holidays` table checked by
both gates.
