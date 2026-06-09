# Llavai backend rebuild — target architecture

Status: PROPOSED (design-first). Awaiting approval before build. Last updated 2026-06-09.

## 1. Why rebuild

The original `Start Call v2.5` workflow encodes assumptions that no longer hold:
- It calls Julia for **every** forwarded alert — but calling is now a **Pro-only** feature.
- It reads/writes **Google Sheets** as the system of record — we've moved to **Supabase**.
- The frontend feed + homepage copy were built around **>70**, but the correct gate is
  **≥60** (the old workflow was right). All surfaces now align on **≥60**.
- It predates the **Free / Trial / Essential / Pro** tier model.

We keep the proven *external* components — **Apify** (scrape), **Retell/Julia** (calls),
**CloudMailin** (inbound email), **Stripe** (billing), **Supabase** (data). The rebuild is
the **orchestration, data model, and tier-gating**, plus full removal of Google Sheets.

## 2. Product model (the 4 states)

| Tier | How you get it | Feed (listings ≥60) | Julia calls |
|---|---|---|---|
| **Free** | Account only, no subscription | Locked (paywall/teaser) | No |
| **Trial** | Stripe Essential price w/ `trial_period_days` → status `trialing` | Unlocked | No |
| **Essential** | Stripe Essential price, status `active` | Unlocked | No |
| **Pro** | **Apply → you approve → Stripe Pro price**, plan `pro`, status `active`/`trialing` | Unlocked | **Yes (≥60, ~minutes)** |

Tier is **derived from `subscriptions(plan, status)`** — no separate flag to keep in sync.

## 3. Data model (Supabase) — additive changes

Existing: `profiles`, `viewings`, `documents`, `messages`, `listings`, `subscriptions`.

**3.1 `subscriptions`** — already has `plan`. Fix the Stripe sync to set `plan` from the
Stripe **price/product** ('essential' | 'pro') instead of hardcoding 'essential'.

**3.2 `profiles`** — add Pro-application + alert-forwarding state:
- `intended_plan text` ('essential' | 'pro') — captured at signup.
- `pro_status text default 'none'` ('none' | 'applied' | 'approved' | 'rejected').
- `alert_email_verified boolean default false` — Gmail-forwarding verification (replaces the Sheets verify flow).

**3.3 `viewings`** — link to the listing + dedup:
- `listing_id uuid references public.listings(id) on delete set null`
- `property_id text` (Idealista adid) — dedup key with `user_id`.

**3.4 New `property_cache`** (global scrape cache — replaces Sheets `Properties_Scraped`):
- `property_id text primary key`, `source text`, `parsed jsonb`, `appeal_score int`,
  `scraped_at timestamptz`, `expires_at timestamptz`. Avoids re-paying Apify for a property
  already scraped recently (TTL, e.g. 24h).

**3.5 New `call_attempts`** (Pro call log + dedup — replaces Sheets `Client_Alerts`):
- `id uuid pk`, `user_id uuid`, `property_id text`, `retell_call_id text`,
  `status text` ('queued'|'calling'|'completed'|'failed'|'skipped'),
  `skip_reason text`, `created_at timestamptz`. Unique `(user_id, property_id)` → idempotent
  ("already called for this listing today").

**3.6 RPCs** (security definer, search_path public):
- `has_active_subscription()` — exists (treats `trialing` as active). Keep.
- `is_pro()` → `exists(select 1 from subscriptions where user_id=auth.uid() and plan='pro' and status in ('active','trialing') and (current_period_end is null or current_period_end>now()))`.
- `current_tier()` → 'free' | 'trial' | 'essential' | 'pro' for the frontend to render state.
- A service-side variant for n8n: since n8n uses service_role (no auth.uid()), the call
  pipeline checks tier by querying `subscriptions` filtered by the matched `user_id`.

All new tables get **RLS**: users read their own `call_attempts` (optional); `property_cache`
is service-role-only (no API-role grants); writes are service-role only.

## 4. Workflows (n8n) — the new set

Each workflow is single-responsibility (the opposite of the 43-node monolith).

**W1 · Pro Concierge — Alert → Call**  *(NEW; replaces Start Call v2.5)*
- Trigger: **CloudMailin webhook** (Pro clients forward Idealista saved-search alerts).
- Flow:
  1. **Classify** email: forwarding-verification vs listing-alert (reuse existing logic).
  2. **Verification branch** → look up `profiles` by email in **Supabase**, email the code,
     set `alert_email_verified=true`. (No Sheets.)
  3. **Alert branch**:
     a. Extract property URL(s) + identify the client by sender → **Supabase profile lookup**.
     b. **Tier gate**: skip unless the client is **Pro** (`plan='pro'`, active/trialing).
     c. **Dedup**: skip if `call_attempts(user_id, property_id)` already exists.
     d. **Scrape**: use `property_cache` if fresh, else Apify → cache the result.
     e. **Score** (the shared appeal formula) → **gate ≥60**.
     f. **Write** a `listings` row (so it also appears in their feed) + a `viewings` row
        (status `calling`), and a `call_attempts` row.
     g. **Fire Retell** with PII-minimised payload built from the **Supabase profile**.
     h. Update `viewings`/`call_attempts` on result; alert on failure.

**W2 · Feed Backfill — Idealista → listings**  *(DONE, inactive)*
- Cron; fills the feed for all paying/trialing subscribers via `feed_search_clients`.
- No change needed beyond activation; the view already includes `trialing` and all plans.

**W3 · Stripe Subscription Sync**  *(EXISTS — needs fix)*
- Map Stripe **price → `plan`** ('essential' | 'pro'); set `status` incl. `trialing`.
- Currently hardcodes `plan:'essential'` — that's the one change.

**W4 · Stripe Checkout Session**  *(EXISTS — extend)*
- Add the **Pro price**; add `trial_period_days` to the Essential price for the Trial tier.
- Pro checkout is only handed out **after approval** (see W5).

**W5 · Pro Application & Approval**  *(NEW, small)*
- On a `plan=pro` application: set `profiles.intended_plan='pro'`, `pro_status='applied'`,
  notify the team. On approval (a manual action / simple admin call): `pro_status='approved'`
  and send the client a **Pro Stripe checkout/invoice** link.

**W6 · Document retention** *(NEW, optional — GDPR)*
- `pg_cron` (or n8n cron) deletes `documents` past `expires_at` and their Storage objects.

## 5. Tier fan-out (the core idea)

```
            ┌─ W2 cron (all subscribers) ─┐
listings ◄──┤                              ├─ scrape + score + upsert (≥60)
            └─ W1 Pro forwarded alerts ────┘
                          │
        ┌─────────────────┼─────────────────────┐
   Free │ Trial/Essential │ Pro                   │
  locked│ read feed (RLS) │ read feed + Julia calls (W1, ≥60, gated by is_pro)
```

One ingestion surface (`listings`), behaviour fanned out purely by tier.

## 6. Google Sheets decommission

| Sheet (old) | Replaced by |
|---|---|
| Client_Profiles | `public.profiles` (done) |
| Properties_Scraped / Property_Info | `public.property_cache` + `public.listings` |
| Client_Alerts | `public.call_attempts` |

Keep a one-time CSV export for safety, then remove all Google Sheets nodes.

## 7. Build sequence (incremental, reversible)

- **Phase 0 — Schema** (additive migrations): profiles columns, viewings columns,
  `property_cache`, `call_attempts`, `is_pro()`/`current_tier()`. Zero risk.
- **Phase 1 — Billing**: fix W3 plan mapping; add Pro price + Essential trial to W4.
- **Phase 2 — W1 (Pro Concierge)**: build NEW + inactive; test against a real forwarded
  alert; then **repoint CloudMailin** from `Start Call v2.5` → W1 and **deactivate** the old
  workflow (CloudMailin endpoint switch is instantly reversible).
- **Phase 3 — W5 Pro application/approval**; frontend `current_tier()` wiring on `/account`.
- **Phase 4 — Decommission** Google Sheets nodes + old workflow; add W6 retention.

Old `Start Call v2.5` stays live until W1 is proven, so calls never stop during the cutover.

## 8. Open item to confirm

**Free vs Trial definition.** Proposed: **Trial = Stripe Essential subscription with a
`trial_period_days` window** (status `trialing` already unlocks the feed via
`has_active_subscription()`); **Free = account with no subscription** (feed locked, can still
build profile + apply for Pro). Adjust the trial length / whether Free sees a teaser vs full
lock on review.

## 9. Out of scope / unchanged
- Apify actor, Retell agent, CloudMailin, Stripe vendors stay.
- The Supabase-first frontend (get-started/profile/account) shipped earlier stays.
- Legal/GDPR specifics deferred to a Spanish DP professional (see SETUP.md).
</content>
