# Stripe subscription — the €19/mo paywall on /app

This is **built**. The front end (`app.html`) and both n8n workflows exist; the
Stripe **secret key never touches the website** — it lives only in n8n.

## What's already done
- **Product + price** (Stripe, test mode): "Llavai Essential", €19 / month recurring.
  - Price ID: `price_1Tg3xxJwiwjO8HDcclckh5cc`  (product `prod_UfOlTKAnsV5mSw`)
- **Front end**: `supabase-config.js` → `LLAVAI_CHECKOUT_URL =
  https://llavai.app.n8n.cloud/webhook/stripe-checkout`
- **Workflow A — "Stripe — Create Checkout Session"** (`7v8gjHd91PtNBSa1`)
  Webhook `POST /webhook/stripe-checkout` → creates a Stripe Checkout Session
  (subscription mode, the price above) → returns `{ url }` to the browser.
  CORS allowed origins: `www.llavai.com`, `llavai.com`, the `feat/user-accounts`
  preview.
- **Workflow B — "Stripe — Subscription sync"** (`zsBLr5NCkPbps2A3`)
  **Stripe Trigger** (auto-registers the webhook with Stripe **and verifies the
  signature for you** — no `whsec` to copy) on `checkout.session.completed`,
  `customer.subscription.created/updated/deleted` → Switch →
  upsert `public.subscriptions` (active) / mark `canceled`, via the **service_role**
  `Supabase account` credential.

## Finish-up (≈3 min in the n8n UI — credentials can't be set via the API)
1. **Create one Stripe credential**: n8n → Credentials → New → **Stripe API** →
   paste the **Secret key** (`sk_test_…`) → save (name it "Stripe account").
2. **Workflow A** → open node **"Create Stripe Checkout Session"** → Credential →
   select **Stripe account** → save → **Activate** the workflow (top-right toggle).
3. **Workflow B** → set three credentials, then **Activate**:
   - **"Stripe Subscription Events"** (trigger) → select **Stripe account**
   - **"Upsert Subscription (active)"** → select **Supabase account**
   - **"Mark Subscription Canceled"** → select **Supabase account**
   (Activating B is what registers the webhook endpoint inside Stripe.)

## Test (Stripe test mode)
1. Sign in on `/app`, click **Subscribe**.
2. On Stripe Checkout use card `4242 4242 4242 4242`, any future expiry / CVC.
3. You return to `/app?checkout=success`; the page polls
   `has_active_subscription()` for ~12s while Workflow B writes the row, then the
   feed unlocks.

## Going live (later)
- Swap the test price/secret for **live** ones: create a live price, paste the
  live `sk_live_…` into the Stripe credential, update the price ID in Workflow A.
- **Rotate** the test key that was shared in chat (Stripe → Developers → API keys).
- The Stripe Trigger re-registers itself for live mode automatically on activation.

## Security
- Secret key: **n8n only**, never in the repo/browser. ✓
- Stripe Trigger verifies event signatures automatically — forged events are rejected. ✓
- `subscriptions` is RLS read-own; only the service_role (Workflow B) writes it. ✓
