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
  `property_cache`, `call_attempts`, `is_pro()`/`current_tier()`. Zero risk. ✅ **DONE**
  (migration `backend_rebuild_phase0_schema`, applied + verified 2026-06-09).
- **Phase 1 — Billing**: ✅ DONE — W4 checkout + 3-day trial + plan stamping; W3 sync maps plan by price ID. Essential `price_1Tg4mRF7TyaJ4FzileL3yPfd`, Pro `price_1TgUXvF7TyaJ4FziJhqXMovY` (€185/mo).
- **Phase 2 — W1 (Concierge)**: ✅ LIVE — workflow `rlv02UB1RHNnQl4i`
  ("Concierge — Alert to Feed + Julia Call (W1)", webhook path `pro-concierge-inbox`).
  Classify: Gmail-verification relay (code now goes to the **client**, fixing the old
  hardcoded-to-Harry test leftover; marks `alert_email_verified`) vs alert (`+caf_=` sender
  decode, digest skip). Alert path: `get_call_client` RPC (profile + **tier** + is_pro +
  availability, service-role only, anon=401; tier added by migration
  `get_call_client_add_tier`, mirrors `current_tier()`) → **tier gate** (owner review
  2026-06-09: Essential/Trial forwarded alerts must ALSO scrape — that's how their
  real-time feed fills; free tier → `call_attempts` skipped:free_tier, no Apify cost;
  unknown sender → team email) → atomic dedup claim (insert ignore-duplicates +
  return=representation; duplicate ⇒ 0 rows ⇒ chain stops) → Apify sync scrape → per-user
  score → cache + **listing upserted into the client's feed for every paying tier,
  regardless of score** (read-time filtering owns visibility) → `Should Call?` requires
  **is_pro AND score ≥60 AND seasonal/platform/require gates AND phone** (non-Pro ⇒
  skipped:not_pro) → Retell call (from +34931228994, agent `agent_774…`, 3× income rule,
  Llavai-Calendar availability in the payload) → **calendar viewing inserted only after
  Retell accepts** (a failed call must never leave a phantom "Julia is calling" row;
  chain: listing → Retell → mark calling → viewing). Credentials are **pre-bound by ID in
  the SDK code** (Supabase/Apify/Retell-header/SMTP) so MCP full-replace updates no longer
  strip them. n8n Cloud gotcha: `update_workflow` saves a **draft**; production webhooks
  run the **published** version — always `publish_workflow` after updating, then verify
  the execution used the new node names. End-to-end verified 2026-06-09 with an Essential
  test account: scrape ran, listing landed in feed, attempt skipped:not_pro, no call.
  **Remaining:** deactivate `Start Call v2.5` once CloudMailin points only at W1.
- **Phase 3 — Frontend**: ✅ DONE (live) — `current_tier()` gating + Free teaser (`teaser_listings`), feed-preferences settings UI (scoring_prefs + seasonal/platform toggles), and the in-house **Llavai Calendar** (viewings self-manage + availability). Remaining: **W5 Pro apply→approve** flow.
- **Phase 4 — Decommission** Google Sheets nodes + old workflow; add W6 retention.

Old `Start Call v2.5` stays live until W1 is proven, so calls never stop during the cutover.

## 8. Decisions locked (from review of real scrapes)

- **Tiers:** Free = **teaser** (global redacted pool of recent ≥60 listings — no phone/
  url/exact price, RLS view readable by authenticated, costs nothing extra). Trial =
  **card-required** Stripe Essential, **3-day** `trial_period_days` (status `trialing`).
  Essential = active. Pro = apply → approve → Stripe Pro plan. **No trial on Pro upgrades.**
- **No LLM (cost).** At €19/mo we do not call a paid LLM per listing. Enrichment is free:
  (a) read Idealista's already-structured `translatedTexts`/`comments[]` for facts and the
  renter-language description; (b) deterministic **regex/keyword** rules over `propertyComment`
  for the templated legal fine print (Gran Tenedor, rent-control applicability + reference
  rent range, IBI/community/utilities inclusion, deposit months, fees). Store full `raw jsonb`
  so an LLM pass can be added later if revenue allows. Scoring is a free Code node.
- **Two-stage ingestion filter, not score-based exclusion:** Stage 1 = TAG
  (`is_seasonal` via `labels[].name`/description — NOT `tags`; `is_platform_repost` via
  `link.url`/`commercialName`; deactivated) → Stage 2 = appeal **≥60** → Stage 3 = free
  enrichment. **Seasonal / platform reposts are a per-user preference** (`profiles.include_seasonal`,
  `include_platform_reposts`), filtered at feed-read + call-gate, not discarded.
- **Per-user appeal score:** `profiles.scoring_prefs jsonb` (component weights + must-haves/
  boosts + a free-text `context` stored for future LLM use, not applied now). The scoring
  Code node personalises each user's `appeal_score`. Base score cached in `property_cache`.
- **Llavai Calendar (in-house):** `viewings` = events (now with `source` self|julia,
  `address`, `duration_mins`, `confirmed_at`, `listing_id`); new `availability` table =
  weekly free windows; `profiles.timezone` + `booking_buffer_mins`. Essential self-tracks;
  Pro lets Julia book into free slots. No Google Calendar dependency.
- **Scrape field gotchas (baked into the build):** seasonal = `labels[]` not `tags`;
  `priceReferenceIndex` structured field is useless (numbers only in description text);
  `translatedTexts` language follows scrape locale → use `comments[]`; `firstActivationDate`
  often absent → use `modificationDate`; energy state can be `unknown`/`inProcess`;
  `usableArea` not always present.

## 8b. Phase 0 delivered (migration `backend_rebuild_phase0_schema`)
- `profiles` +: intended_plan, pro_status, alert_email_verified, include_seasonal,
  include_platform_reposts, scoring_prefs, timezone, booking_buffer_mins.
- `listings` +: neighbourhood/district/lat/long/address_hidden, usable_area_m2, floor,
  is_exterior, condition, is_studio, has_lift, furnishing, pets_allowed, energy_rating/state,
  agency_total_ads, is_private_landlord, agency_logo, external_reference, is_seasonal,
  is_platform_repost, platform, allows_remote_visit, has_360, allows_counter_offer,
  description, listing_modified_at, price_drop, fine_print, raw (+ feed-flags index).
- `viewings` +: listing_id, property_id, source, address, duration_mins, confirmed_at.
- New tables: `availability` (RLS own), `property_cache` (service-role only),
  `call_attempts` (RLS select-own; unique user_id+property_id). `subscriptions.call_allowance`.
- RPCs: `is_pro()`, `current_tier()` (verified: anon → false/'free').

## 9. Out of scope / unchanged
- Apify actor, Retell agent, CloudMailin, Stripe vendors stay.
- The Supabase-first frontend (get-started/profile/account) shipped earlier stays.
- Legal/GDPR specifics deferred to a Spanish DP professional (see SETUP.md).
</content>
