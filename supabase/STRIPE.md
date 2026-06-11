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
