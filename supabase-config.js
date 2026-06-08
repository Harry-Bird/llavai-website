// Llavai — Supabase browser config.
// The anon key is PUBLIC by design (it ships to every browser); real security is
// enforced by Row-Level Security in supabase/schema.sql. NEVER put the secret
// service_role key here — that belongs in n8n only. See SETUP.md.
window.LLAVAI_SUPABASE_URL = 'https://bwgaolpmarlnwbcrklzc.supabase.co';
window.LLAVAI_SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3Z2FvbHBtYXJsbndiY3JrbHpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2NzUxMTAsImV4cCI6MjA5NjI1MTExMH0.LRqRD7Y_hG487_1n61U3PuoJ7kcx0D_WTFs-O7czZ-E';

// n8n webhook that creates a Stripe Checkout Session (see supabase/STRIPE.md).
// Browser-safe — it holds NO secret; the Stripe secret key lives in n8n only.
window.LLAVAI_CHECKOUT_URL = 'https://llavai.app.n8n.cloud/webhook/stripe-checkout';
