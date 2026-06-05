# Stripe subscription — wiring (the €19/mo paywall on /app)

The web app is already wired for this; it just needs two small **n8n** workflows
and your Stripe keys. The Stripe **secret key never touches the website** — it
lives in n8n. I can build both workflows once you've created the keys.

## Stripe setup (5 min, in the Stripe dashboard)
1. **Product** → "Llavai Spot" → **recurring price** €19 / month → copy the **Price ID** (`price_…`).
2. **Developers → API keys** → copy the **Secret key** (`sk_…`).
3. **Developers → Webhooks** → add endpoint (n8n webhook URL from workflow B below) →
   events: `checkout.session.completed`, `customer.subscription.updated`,
   `customer.subscription.deleted` → copy the **Signing secret** (`whsec_…`).

Store the secret key + signing secret as **n8n credentials/secrets**.

## Workflow A — "Create Checkout Session"  (the button calls this)
```
Webhook (POST)  body: { user_id, email, return_to }
  → HTTP Request to Stripe: POST https://api.stripe.com/v1/checkout/sessions
       Auth: Bearer <sk_…>   Content-Type: application/x-www-form-urlencoded
       mode=subscription
       line_items[0][price]=price_…
       line_items[0][quantity]=1
       customer_email={{ $json.body.email }}
       client_reference_id={{ $json.body.user_id }}
       subscription_data[metadata][user_id]={{ $json.body.user_id }}
       success_url={{ $json.body.return_to }}?checkout=success
       cancel_url={{ $json.body.return_to }}
  → Respond to Webhook:  { "url": {{ $json.url }} }
```
- Set the **webhook's Allowed Origins (CORS)** to `https://www.llavai.com` (+ apex/preview).
- Put this webhook's production URL into `supabase-config.js` → `LLAVAI_CHECKOUT_URL`.

## Workflow B — "Stripe Webhook" (keeps `subscriptions` in sync)
```
Webhook (POST, raw)  ← Stripe events
  → (recommended) verify Stripe-Signature against whsec_…
  → Switch on event.type:
       checkout.session.completed / customer.subscription.updated:
          upsert public.subscriptions (Supabase, service_role):
            user_id              = event.data.object.metadata.user_id  (or client_reference_id)
            stripe_customer_id   = …object.customer
            stripe_subscription_id = …object.subscription | id
            status               = 'active' | event.data.object.status
            current_period_end   = to_timestamp(event.data.object.current_period_end)
            plan                 = 'spot'
       customer.subscription.deleted:
          update subscriptions set status='canceled' where stripe_subscription_id = …id
  → Respond 200
```
Use a **Supabase / Postgres** node with the **service_role** credential (bypasses RLS).

## How the front end uses it (already built in app.html)
- `/app` → not subscribed → paywall → **Subscribe** → POST `LLAVAI_CHECKOUT_URL` → redirect to Stripe.
- After payment Stripe returns to `/app?checkout=success` → the page polls
  `has_active_subscription()` for ~12s while Workflow B writes the row, then unlocks the feed.

## Security
- Secret key + signing secret: **n8n only**, never in the repo/browser.
- Verify the Stripe webhook signature (Workflow B) so nobody can forge subscription rows.
- `subscriptions` is RLS-read-own; only the service_role (Workflow B) writes it.
