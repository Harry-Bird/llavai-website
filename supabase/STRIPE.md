# Stripe subscriptions — Essential (€19/mo) and Pro (€185/mo)

This is **built and live**. The front end (`app.html` / `account.html`) and the
n8n workflows exist; the Stripe **secret key never touches the website** — it
lives only in n8n.

## Current pricing model (live mode)
- **Llavai Essential** — €19 / month recurring, **3-day free trial**
  (`trial_period_days: 3` is set on the Checkout Session, not on the price).
  - Product: `prod_UfOlTKAnsV5mSw` · Price: `price_1Tg4mRF7TyaJ4FzileL3yPfd`
- **Llavai Pro** — €185 / month recurring, **no trial** (concierge calling
  starts immediately).
  - Product: `prod_UfqE6N1h4FyXFm` · Price: `price_1TgUXvF7TyaJ4FziJhqXMovY`
- **Call Packs** — one-time payments (`mode: payment`, NOT subscriptions), live mode.
  Prepaid Julia calls; credited to `call_credit_ledger`. Value is **CALLS, never minutes**.
  See `specs/w7_call_credits_design.md`. Sold via **Stripe Payment Links** (static URLs) —
  the account page links to them with `?client_reference_id=<user_id>&prefilled_email=<email>`
  so the right account is credited. (Payment Links were chosen because the n8n MCP can't bind
  the Stripe credential to a *new* httpRequest node, and the one existing checkout node can't
  serve both subscription + payment mode in one form body.)
  - `pack1` — 1 call €12 · Product `prod_UgcGZ6Iqq4WMNP` · Price `price_1ThF2AF7TyaJ4FzibA5LGuSM`
    · Link `https://buy.stripe.com/6oU3cv0oH4ah4Tf65BaEE00` (plink_1ThFV8F7TyaJ4FziH2ClCnhD)
  - `pack5` — 5 calls €49 · Product `prod_UgcGMkM0C5QtY8` · Price `price_1ThF2JF7TyaJ4Fzih3Wb4X6p`
    · Link `https://buy.stripe.com/00w14ndbt4ahetP3XtaEE01` (plink_1ThFVNF7TyaJ4Fzi4FNNyHRP)
  - `pack15` — 15 calls €119 · Product `prod_UgcGmcO6rbKgZr` · Price `price_1ThF2UF7TyaJ4FzimTaaP55l`
    · Link `https://buy.stripe.com/8x2fZh4EXbCJadz8dJaEE02` (plink_1ThFVUF7TyaJ4Fzif82STYmV)
  - Each link carries `metadata{kind:pack, credits:N}` and redirects to
    `/account?checkout=success`.

## Call-credits backend (W7, live)
- **Tables/RPCs** (`migration w7_call_credits` + follow-ups): `call_credit_ledger` (persistent
  pack/trial credits, balance = sum(delta)); `subscriptions.call_allowance` = Pro's ~60
  monthly **calls** (DB trigger `set_pro_call_allowance` sets/refills it on Pro activation +
  each billing period). Service-role-only RPCs `grant_pack_credits`, `grant_trial_calls`,
  `consume_call`; authenticated `call_balance()`/`available_calls()` for the account UI.
- **Workflow "Stripe — Pack credits (W7)"** (`lohfpJ1X1lbRADno`, active):
  own Stripe Trigger → classify → native Supabase "create row" into `call_credit_ledger`.
  - `checkout.session.completed` + `mode=payment` → grant N credits (N from
    `metadata.credits`, fallback `amount_total` 1200/4900/11900 → 1/5/15; user from
    `client_reference_id`). Idempotent via unique `source_ref` = Stripe event id.
- **Trial 5 free calls are USER-CLAIMED, not automatic.** The account page shows a
  "Claim your 5 free calls" button for trial/Essential users who haven't claimed; it calls
  the authenticated RPC `claim_trial_calls()` (once per account, Essential-only, all
  enforced server-side; `source_ref='trial:'+uid`). `call_balance()` returns
  `can_claim_trial` so the UI knows when to show the button. Once claimed, the 5 credits
  sit in the ledger and Julia calls the next 5 qualifying listings (no pause, no picking).
- **"Stripe — Subscription sync"** got one guard node ("Skip Pack Sessions"): pack
  `checkout.session.completed` (`mode=payment`) no longer upserts a `subscriptions` row.
- **Consumption**: DB trigger `trg_consume_on_calling` decrements one credit (Pro allowance
  first, then pack/trial credits) when a `call_attempts` row is marked `'calling'`. Dormant
  until **W1 is activated**; at that cutover, flip W1's call gate from `!is_pro`/`not_pro`
  to `!(available_calls>0)`/`no_credit` (documented on W1's sticky note + the design doc).
- **Tier is derived, not stored**: `public.subscriptions(plan, status)` →
  `current_tier()` maps to `'pro' | 'essential' | 'trial' | 'free'`
  (`plan='pro'` + active/trialing → pro; `status='active'` → essential;
  `status='trialing'` → trial). The account UI reads the RPC, never Stripe.

> An earlier test-mode price (`price_1Tg3xx…`) is dead — don't resurrect it;
> the IDs above are the only ones n8n should reference.

## What's wired up
- **Front end**: `supabase-config.js` → `LLAVAI_CHECKOUT_URL =
  https://llavai.app.n8n.cloud/webhook/stripe-checkout`; the page passes which
  plan the user picked.
- **Checkout workflow ("Stripe — Create Checkout Session")**
  Webhook `POST /webhook/stripe-checkout` → creates a Stripe Checkout Session
  (subscription mode, price per the chosen plan; Essential adds
  `trial_period_days: 3`) → returns `{ url }` to the browser.
  CORS allowed origins: `www.llavai.com`, `llavai.com`.
- **Sync workflow ("Stripe — Subscription sync")**
  **Stripe Trigger** (auto-registers the webhook with Stripe **and verifies the
  signature for you** — no `whsec` to copy) on `checkout.session.completed`,
  `customer.subscription.created/updated/deleted` → Switch →
  upsert `public.subscriptions` (`plan`, `status`, `current_period_end`,
  `call_allowance` for Pro) / mark `canceled`, via the **service_role**
  `Supabase account` credential.

## Known issue (audit B1)
The **W4 checkout draft that adds the Essential trial is saved in n8n but not
yet published**. n8n Cloud gotcha: `update_workflow` saves a *draft* —
production keeps executing the previously published version until someone
hits **Publish**. Until that happens, live Essential checkouts are created
**without** `trial_period_days: 3`. Fix = open W4 in n8n and publish.

## Test
1. Sign in on `/app`, click **Subscribe** (or upgrade from `/account`).
2. Complete Checkout; Essential should show the 3-day trial on the Stripe page
   (once the W4 draft is published — see above), Pro should charge immediately.
3. You return to `/app?checkout=success`; the page polls
   `has_active_subscription()` for ~12s while the sync workflow writes the row,
   then the feed unlocks. `current_tier()` should report `trial` (Essential,
   during trial) or `pro`.

## Security
- Secret key: **n8n only**, never in the repo/browser. ✓
- Stripe Trigger verifies event signatures automatically — forged events are rejected. ✓
- `subscriptions` is RLS read-own; only the service_role (sync workflow) writes it. ✓
- Tier checks happen server-side in SECURITY DEFINER RPCs (`current_tier()`,
  `is_pro()`, `has_active_subscription()`) — the browser can't fake a plan. ✓
