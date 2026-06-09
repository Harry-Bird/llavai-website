# Stripe subscription — the €19/mo paywall on /app

This is **built and live**. The front end (`app.html`) and both n8n workflows
exist; the Stripe **secret key never touches the website** — it lives only in n8n.

## What's wired (live mode)
- **Product + price** (Stripe, **live mode**): "Llavai Essential", €19 / month recurring.
  - Price ID: `price_1Tg4mRF7TyaJ4FzileL3yPfd` (lookup key `llavai_essential_monthly`,
    product `prod_UfOlTKAnsV5mSw`).
  - ⚠️ The old test price `price_1Tg3xxJwiwjO8HDcclckh5cc` is **not** used anywhere.
- **Front end**: `supabase-config.js` → `LLAVAI_CHECKOUT_URL =
  https://llavai.app.n8n.cloud/webhook/stripe-checkout`
- **Workflow A — "Stripe — Create Checkout Session"** (`7v8gjHd91PtNBSa1`)
  Webhook `POST /webhook/stripe-checkout` → creates a Stripe Checkout Session
  (subscription mode, the live price above) → returns `{ url }` to the browser.
  Uses the live **"Stripe account"** credential. CORS allowed origins:
  `www.llavai.com`, `llavai.com`, and the preview domain.
- **Workflow B — "Stripe — Subscription sync"** (`zsBLr5NCkPbps2A3`)
  **Stripe Trigger** (auto-registers the webhook with Stripe **and verifies the
  signature for you** — no `whsec` to copy) on `checkout.session.completed`,
  `customer.subscription.created/updated/deleted` → Switch →
  upsert `public.subscriptions` (active) / mark `canceled`, via the **service_role**
  `Supabase account` credential. Uses the same live **"Stripe account"** credential.

## Verify end-to-end (do this once, on the live site)
1. Sign in on `/app`, click **Subscribe**.
2. Pay with a **real card** (live mode — the `4242…` test card will be declined).
3. You return to `/app?checkout=success`; the page polls
   `has_active_subscription()` for ~12s while Workflow B writes the row.
4. Confirm a row appears in `public.subscriptions` with `status='active'` and the
   feed unlocks — then **refund** the charge in Stripe.
   If the row never appears, check that Workflow B's Stripe Trigger shows a
   registered endpoint in **Stripe → Developers → Webhooks (live)**.

## Housekeeping
- **Rotate** any `sk_test_…` / `sk_live_…` key that was ever pasted into a chat
  (Stripe → Developers → API keys).
- The unused **"Stripe account TEST"** credential in n8n can be deleted so the
  wrong mode can never be bound by accident.

## Security
- Secret key: **n8n only**, never in the repo/browser. ✓
- Stripe Trigger verifies event signatures automatically — forged events are rejected. ✓
- `subscriptions` is RLS read-own; only the service_role (Workflow B) writes it. ✓
