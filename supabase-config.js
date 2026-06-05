// Llavai — Supabase browser config.
// The anon key is PUBLIC by design (it ships to every browser); real security is
// enforced by Row-Level Security in supabase/schema.sql. NEVER put the secret
// service_role key here — that belongs in n8n only. See SETUP.md.
window.LLAVAI_SUPABASE_URL = 'https://YOUR-PROJECT.supabase.co';
window.LLAVAI_SUPABASE_ANON_KEY = 'YOUR-ANON-PUBLIC-KEY';

// n8n webhook that creates a Stripe Checkout Session (see supabase/STRIPE.md).
// Browser-safe — it holds NO secret; the Stripe secret key lives in n8n only.
window.LLAVAI_CHECKOUT_URL = 'YOUR-CHECKOUT-WEBHOOK-URL';
