# W7 — Call credits & packs: backend wiring (fullstack-guardian design)

Status: BUILDING 2026-06-11. Implements item 3 ("Backend wiring") of `pricing_model.md`.
Companion to `backend_rebuild_architecture.md` (W1 pre-call gate) and `supabase/STRIPE.md`.

Out of public deploy (`.vercelignore` → `specs/`).

## 1. Goal

Make the already-live-advertised pricing real:
- **Call Packs** (€12 / €49 / €119 → 1 / 5 / 15 calls, one-time) can be bought and credited.
- **Trial** grants **5 free Julia calls** once per account (folded into the Essential trial).
- **Pro** gets **~60 calls/month** (resets each billing period); overage = packs.
- Every Julia call **decrements** the right bucket; when nothing is left, no call is placed.

Value metric is **CALLS, never minutes** (`pricing_model.md` §"Call pack detail"). `duration_minutes`
on `call_attempts` stays (real Retell duration, for cost analytics) but no longer frames the cap.

## 2. The two-bucket model (one balance, two sources)

| Bucket | Where | Lifetime | Filled by | Drained by |
|---|---|---|---|---|
| **Pro monthly allowance** | `subscriptions.call_allowance` (int) | Resets each Stripe period | Pro create/renew → `reset_pro_allowance(60)` | Julia call (first) |
| **Persistent credits** | `call_credit_ledger` (sum of `delta`) | Never expire | Pack purchase, trial grant | Julia call (after allowance) |

`available_calls = (call_allowance if currently Pro) + ledger_balance`.

**Consumption order** (`consume_call`): Pro allowance first, then ledger credits. This makes
Pro's included calls "use it or lose it" each month while purchased packs persist — matching
"~60 included + overage via packs" and "packs stack on Essential / top up Pro".

## 3. Data model (Supabase) — additive migration `w7_call_credits`

```
call_credit_ledger(
  id bigint identity pk,
  user_id uuid not null → auth.users on delete cascade,
  delta integer not null,                 -- +grant / -consumption
  reason text not null,                   -- pack_purchase | trial_grant | call_consumed | adjustment
  source_ref text,                        -- idempotency key (stripe event/session id, or consume:uid:property)
  created_at timestamptz default now()
)
unique(source_ref) where source_ref is not null   -- exactly-once grants & consumption
index(user_id, created_at desc)
RLS: select_own; NO user writes (service-role only, via RPCs)
```

`subscriptions.call_allowance` comment fixed: "Pro monthly included **calls** (not minutes); reset each period."

### RPCs (security definer, search_path=public)

| RPC | Caller | Purpose |
|---|---|---|
| `call_balance()` → jsonb | authenticated (own) | `{is_pro, pro_allowance, credits, total}` for the account UI |
| `available_calls()` → int | authenticated (own) | total, convenience |
| `consume_call(uid, property)` → jsonb | **service_role only** | atomic: allowance→credit; `{consumed, source, remaining}`. Idempotent per (uid,property) via `source_ref='consume:'||uid||':'||property` |
| `grant_pack_credits(uid, n, source_ref)` → jsonb | **service_role only** | idempotent grant (on conflict source_ref do nothing) |
| `grant_trial_calls(uid, n=5)` → jsonb | **service_role only** | once per account (guard: no prior `trial_grant`) |
| `reset_pro_allowance(uid, n=60)` → void | **service_role only** | set `call_allowance` on Pro create/renew |

Per-user atomicity in `consume_call`/grants via `pg_advisory_xact_lock(hashtextextended(uid::text,0))`
so two concurrent W1 runs for one user can't double-spend.

## 4. Stripe (live mode, acct_1Tg3lMF7TyaJ4Fzi) — AS BUILT

3 one-time products + prices, sold via **Stripe Payment Links** (static URLs; see
`supabase/STRIPE.md` for IDs). Payment Links were used instead of dynamic Checkout Sessions
because the n8n MCP can't bind the Stripe credential to a *new* httpRequest node, and one
node can't form-encode both subscription + payment mode. The account page appends
`?client_reference_id=<uid>&prefilled_email=<email>` so the buyer is identified. Each link
carries `metadata{kind:pack, credits:N}` and redirects to `/account?checkout=success`.
Essential/Pro subscriptions unchanged.

## 5. n8n wiring — AS BUILT

- **Checkout workflow**: UNCHANGED (subscriptions only). Packs bypass it via Payment Links.
- **New "Stripe — Credits, trial & allowance (W7)"** (`lohfpJ1X1lbRADno`, active): own Stripe
  Trigger → `Classify Event` → native **Supabase "create row"** into `call_credit_ledger`
  (the native node accepts the service credential; httpRequest+supabaseApi can't be bound via
  MCP). Idempotency = unique `source_ref` + node `onError: continueRegularOutput`.
  - `checkout.session.completed` + `mode=payment` → `grant_pack` (credits from
    `metadata.credits`, fallback `amount_total`; user from `client_reference_id`).
  - `customer.subscription.created` + Essential `trialing` → `grant_trial` (5 calls, once).
- **Subscription sync**: one guard node added — pack sessions (`mode=payment`) skip the
  `subscriptions` upsert (else they'd clobber `stripe_subscription_id`).
- **Pro allowance**: handled entirely DB-side by trigger `set_pro_call_allowance` (no n8n
  reset node, no over-grant race) — set to 60 on Pro activation and on each new billing period
  (detected via `current_period_end` advancing, which the sync already writes).
- **Consumption**: DB trigger `trg_consume_on_calling` calls `consume_call(user,property)`
  when a `call_attempts` row is marked `'calling'` (idempotent per listing). **W1
  (`rlv02UB1RHNnQl4i`) is not yet live**; `get_call_client` now returns `available_calls`, so
  at W1 cutover change its `Process & Decide` gate:
  `if (!client.is_pro) {…'not_pro'}` → `if (!(client.available_calls > 0)) {…'no_credit'}`
  (documented on W1's sticky note). Then any-tier-with-credit (Essential pack, trial) gets
  calls, not Pro-only. **Art 50 AI-disclosure** for non-Pro calling is the open gate on that
  cutover (see project memory, ~mid-July).

## 6. Frontend (account.html)

- Show **call balance** (`call_balance()` RPC) near the plan badge: "N Julia calls available".
- **Buy a call pack** — three buttons (1/5/15) POST `{plan:'pack5', user_id, email, return_to}`
  to `LLAVAI_CHECKOUT_URL` → redirect to Stripe (same pattern as Subscribe). Trilingual EN/ES/UA,
  wow-kit voice, friendly+trilingual errors via `friendly()`. On `?checkout=success` re-fetch balance.

## 7. Security checkpoint

- **AuthN/Z**: balance RPCs key off `auth.uid()` only (no spoofing). Mutating RPCs
  (`consume/grant/reset`) **revoked from anon/public/authenticated**, granted to `service_role`
  only — the browser can never grant itself credits. Ledger RLS: read-own, zero user writes.
- **Idempotency = money safety**: unique `source_ref` makes pack grants exactly-once (Stripe
  retries/replays no-op) and consumption once-per-listing (W1 redelivery can't double-charge).
- **Validation**: `consume_call` re-checks tier/balance server-side; `grant_pack_credits`
  trusts only Stripe-sourced `credits` (read from the session/price metadata in n8n, never the browser).
- **No secrets in repo**: Stripe secret key stays in n8n; pack price IDs are public-safe (like existing ones).
- **Atomicity**: advisory locks prevent double-spend races.

## 8. Verify

DB: unit-test RPCs via `execute_sql` with a throwaway user (grant 5 → balance 5 → consume 3 →
balance 2 → consume×3 → last fails). Idempotency: replay a grant `source_ref` → no change.
Stripe: confirm 3 prices live. n8n: published, not draft (publish after update). Frontend:
headless puppeteer balance render + button → checkout URL.
