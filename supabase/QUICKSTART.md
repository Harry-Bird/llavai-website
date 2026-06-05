# Supabase quick-start (10 min) — unblocks /login, /account, and /app

Do these in order. Everything (accounts, dashboard, listings feed) depends on it.

### 1. Create the project
- supabase.com → **New project** → pick an **EU region** (Frankfurt `eu-central-1` or Paris). *(Region is permanent.)*
- **Settings → API**, copy **Project URL** and the **anon public** key.

### 2. Paste keys into the site
Edit `supabase-config.js`:
```js
window.LLAVAI_SUPABASE_URL      = 'https://YOUR-PROJECT.supabase.co';
window.LLAVAI_SUPABASE_ANON_KEY = 'eyJhbGciOi…';   // anon public — safe in the browser
// window.LLAVAI_CHECKOUT_URL   = '...';            // later, from STRIPE.md
```
Commit + push (deploys automatically).

### 3. Create the Storage bucket (do this BEFORE the SQL)
- **Storage → New bucket** → name **`documents`** → **Public = OFF**.

### 4. Run the SQL — in this order
**SQL editor → New query →** paste **all of `supabase/schema.sql`** → **Run**.
Then **New query →** paste **all of `supabase/listings.sql`** → **Run**.

### 5. Turn on magic-link auth
- **Authentication → Providers → Email**: enabled (passwords can stay off).
- **Authentication → URL Configuration**:
  - **Site URL:** `https://www.llavai.com`
  - **Redirect URLs:** `https://www.llavai.com/account`, `https://www.llavai.com/app`, `https://www.llavai.com/login`, and your Vercel preview domain.
- **(Recommended) Authentication → SMTP**: connect your own sender (e.g. `hello@llavai.com`) so links don't go to spam.

### 6. Verify
- **Database → Policies**: RLS **Enabled** on `profiles`, `viewings`, `documents`, `messages`, `listings`, `subscriptions`.
- Open `/login` on the live site → enter your email → you should get a magic link → it lands you on `/account`.

### 7. Give n8n write access (for the pipeline + Stripe)
- **Settings → API → service_role** key → store it as an **n8n credential / secret**. **Never** put it in the website.
- This is what the `Start Call → listings` branch and the Stripe webhook use to write rows (bypassing RLS).

Done → `/login`, `/account`, and `/app` are live. Next: I wire `Start Call → listings` and Stripe (see `supabase/STRIPE.md`).
