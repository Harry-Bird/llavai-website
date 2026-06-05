# Llavai user accounts — setup & compliance

A static (no-build) account area: **magic-link** sign-in + a private dashboard,
powered by **Supabase** (Auth + Postgres + Storage) in an **EU region**.

> Security model in one line: the browser only ever uses the **public anon key**;
> real protection is **Row-Level Security** in `supabase/schema.sql`. The
> **service_role key is secret** — it goes in n8n only, never in any file here.

---

## 1. Provision Supabase (do this first)

1. Create a Supabase project — **choose an EU region** (e.g. Frankfurt `eu-central-1`
   or Paris `eu-west-3`). Region is set at creation and **cannot be changed later**.
2. Project → **Settings → API**, copy:
   - **Project URL** and **anon public** key → paste into `supabase-config.js` (safe to commit).
   - **service_role** key → store as an n8n credential / secret. **Never** put it in the website.
3. **Storage → New bucket** → name it `documents`, **Public = OFF**.
4. **SQL editor → New query** → paste all of `supabase/schema.sql` → Run.
   (Create the bucket in step 3 *before* running, so the storage policies attach.)
5. Verify **Database → Policies**: RLS shows **Enabled** on `profiles`, `viewings`,
   `documents`, `messages`.

## 2. Configure magic-link auth

1. **Authentication → Providers → Email**: enable it; keep "Confirm email" on;
   passwords can stay disabled (we use magic links only).
2. **Authentication → URL Configuration**:
   - **Site URL**: `https://llavai.com`
   - **Redirect URLs** (allow-list): `https://llavai.com/account`,
     `https://llavai.com/login`, and your Vercel preview domain for testing.
3. **Authentication → Email Templates → Magic Link**: brand the email (Llavai
   tone/colours). Set a short link expiry (e.g. 1 hour) and single-use.
4. **Custom SMTP (recommended)**: Authentication → SMTP settings → connect your
   own sender (e.g. `hello@llavai.com` via your email provider) so links don't come
   from Supabase's shared sender — better deliverability, on-brand, and keeps email
   in your control. Without it, magic links may land in spam.

## 3. Fill in the website config

Edit `supabase-config.js`:

```js
window.LLAVAI_SUPABASE_URL = 'https://YOUR-PROJECT.supabase.co';
window.LLAVAI_SUPABASE_ANON_KEY = 'eyJhbGciOi...'; // anon public key — safe in the browser
```

`/login` and `/account` work automatically (Vercel `cleanUrls`). No build step.

## 4. n8n ↔ Supabase (Julia's outcomes → the dashboard)

- In n8n, add a **Supabase** (or Postgres) credential using the **service_role** key.
- Map a lead/client to their account by **email**: `select id from profiles where email = $email`
  → use that `id` as `user_id` when inserting into `viewings` / `messages`.
- When Julia calls an agency, write/update a `viewings` row (status:
  `matched → calling → booked → confirmed → attended` / `declined` / `no_answer`).
- Team replies → insert into `messages` with `sender = 'team'`.
- (Existing `get-started` / `profile` webhook still captures leads; this just adds
  the authenticated store on top.)

---

## 5. GDPR / legal checklist — controller responsibilities

You'll hold **financial details and identity documents** (NIE, payslips, bank
statements) for **EU data subjects**, so treat the following as required. **Have a
Spanish data-protection professional review this** — Spain adds LOPDGDD + AEPD
guidance on top of GDPR, and this is not legal advice.

- [ ] **EU data residency** confirmed (Supabase region) — keeps data in the EU.
- [ ] **Sign Supabase's DPA** (Data Processing Agreement); list it + any
      sub-processors in your Records of Processing (Art. 30).
- [ ] **Lawful basis** documented: performance of contract for the service; **explicit
      consent** for storing documents (separate, unticked checkbox at upload).
- [ ] **Data minimisation & retention** — biggest lever, because a leak of "NIE +
      payslips" is worst-case. Decide a **retention period** and **auto-delete**
      documents after the search ends (the `documents.expires_at` column + a scheduled
      job — n8n cron or Supabase `pg_cron`). Prefer *not* storing raw docs longer than needed.
- [ ] **Data-subject requests**: access / export / erasure / portability. (Trivial on
      Postgres — provide a way to fulfil these; account deletion cascades all rows.)
- [ ] **Privacy policy** updated to cover the account, the session cookie/token,
      Supabase as processor, and document storage.
- [ ] **Cookie / consent** notice for the auth session token (you currently only use
      `localStorage` for language/lead).
- [ ] **Breach-response** process + contact.
- [ ] **Security hygiene**: private bucket only + time-limited **signed URLs**; RLS on
      every table; **MFA on the Supabase dashboard**; rotate keys if exposed; never
      commit the service_role key.

> ⚠️ The retention period and exactly which documents you store are **your call with
> your DP advisor** — I've left `expires_at` and the doc types configurable rather than
> hard-coding a policy.

---

## Files in this feature

| File | What it is |
|---|---|
| `supabase/schema.sql` | Tables + RLS + Storage policies + signup trigger. Run once. |
| `supabase-config.js`  | Your project URL + anon key (browser-safe). |
| `login.html`          | Magic-link sign-in (`/login`). |
| `account.html`        | Dashboard: pipeline, profile, documents, messages (`/account`). |
