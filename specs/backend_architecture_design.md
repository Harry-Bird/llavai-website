# Llavai — backend architecture (Supabase-first)

Status: implemented in this branch. Last updated 2026-06-09.

## 1. Summary

Llavai is a static, no-build trilingual site on Vercel. The backend is **Supabase**
(Auth + Postgres + Storage, EU region) as the **single system of record**, with **n8n**
as the **server-side automation layer only** (Stripe, Julia's call pipeline, Idealista
scraping) and **Stripe** for the €19/mo subscription.

The guiding rule of this design: **sensitive tenant data (income, guarantor, document
intentions, the documents themselves) only ever rests in Postgres under Row-Level
Security. It never transits or rests in n8n.** n8n receives only a lightweight,
non-financial "new lead / profile completed" alert so Julia's 60-second-call promise
still fires; it then *reads* the full profile back from Supabase via the service_role key.

## 2. The problem this fixes

Before: `get-started.html` and `profile.html` both `POST`ed to a single n8n webhook and
never touched Supabase auth. The rich profile form collected ~20 fields that map
column-for-column onto the `profiles` table, but those answers landed in n8n, not in
`profiles`. The only way data reached `/account` was a separate magic-link sign-in (which
created an *empty* profile row) plus a fragile "match by email" join in n8n that wasn't
reliably built. Two front doors, joined by a string match, with the richest PII falling
into the gap.

After: one front door. The frontend writes profile data into Supabase directly; auth and
the profile row are the same identity; no email-matching join exists to break.

## 3. Components & responsibilities

| Component | Owns | Secret it holds |
|---|---|---|
| Static site (Vercel) | UI, validation, talking to Supabase with the **anon** key under RLS | anon key only (public by design) |
| Supabase Auth | Magic-link identity; `auth.users` | — |
| Supabase Postgres | System of record: `profiles`, `viewings`, `documents`, `messages`, `listings`, `subscriptions`. RLS on every table. | — |
| Supabase Storage | Private `documents` bucket; per-user folder; signed URLs | — |
| n8n | Stripe checkout session, Stripe→`subscriptions` sync, Julia call pipeline → `viewings`, Idealista scrape+score → `listings`, team alerts | **service_role** key + Stripe secret — n8n only, never in repo |
| Stripe | Subscription billing | secret key — n8n only |

## 4. Data flows

### 4.1 Lead capture (`/get-started`)
1. Validate first name + email (client) and email format.
2. `supabase.auth.signInWithOtp({ email, options:{ data:{ first_name, phone, intended_plan }, emailRedirectTo: origin + '/account' } })`
   — creates the `auth.users` row (unconfirmed) and emails the magic link. **Only
   non-sensitive metadata** goes here (name/phone/plan) — never financial fields.
   The `on_auth_user_created` trigger creates the `profiles` row and copies
   `first_name` + `phone` out of the metadata.
3. In parallel (best-effort, non-blocking): POST a **non-financial** alert to the n8n
   webhook so the team/Julia are notified instantly (the 60-second promise).
4. Stash `{firstName,email,phone}` in `localStorage('llavai-lead')` to pre-fill the
   profile form.
5. Show success ("check your email for your sign-in link").

If Supabase is unreachable or the OTP send fails, the lead is **not lost**: the n8n alert
+ localStorage still captured them, and a later `/login` sign-in will create the user and
flush their stashed data (see 4.3).

### 4.2 Full profile (`/profile`)
1. Multi-step form, validation, review (unchanged).
2. Build one `profileRow` object keyed to **exact `profiles` columns**.
3. If a Supabase **session exists** → `update(profileRow).eq('id', user.id)` directly
   (RLS `profiles_update_own`). Done.
4. If **no session** → stash `profileRow` in `localStorage('llavai-profile-pending')`,
   then `signInWithOtp({ email })` so they get a link and a profile row. The data is
   written on their next authenticated load (4.3). Keeps the funnel low-friction: they
   fill the whole profile *before* needing to check email.
5. In parallel (best-effort): non-financial n8n alert ("profile completed").

### 4.3 The join — flush on authenticated load (`/account`)
On `/account`, once a session is present, before loading the dashboard:
- Read `llavai-profile-pending` (full profile) or, failing that, `llavai-lead` (basics).
- Strip empty/null values so we never clobber existing data, drop `email` (owned by auth).
- `update(clean).eq('id', user.id)`; on success clear the localStorage keys.

This is the entire lead→account "join": same identity, a direct DB write, no string match.

### 4.4 Payments, pipeline, listings (n8n, unchanged)
- `/account` "Subscribe" → n8n `stripe-checkout` webhook → Stripe Checkout → return to
  `/account?checkout=success`; page polls `has_active_subscription()` while the Stripe
  Trigger workflow writes `subscriptions` via service_role.
- Julia's calls write `viewings`; Idealista scrape+score writes `listings`; both
  server-side via service_role (bypass RLS). Both **read** the tenant's profile from
  `profiles` rather than receiving it over a webhook.

## 5. Security (three-perspective)

**Backend / data**
- RLS on every table; anon can only read/write its own rows (`auth.uid() = id/user_id`).
  Verified live: anon `GET /profiles` returns `[]`.
- `viewings`, `listings` (writes), `subscriptions` (writes) have **no** user-write policy
  — only service_role writes them. `messages` insert is constrained to `sender='user'`.
- Storage: private bucket, per-user folder enforced by `storage.foldername(name)[1] = auth.uid`,
  reads via short-lived signed URLs.
- service_role + Stripe secret live in n8n credentials only; never in the repo/browser.

**Frontend**
- Client-side validation is UX only; the real gate is RLS server-side.
- Only the anon key and a public checkout webhook URL ship to the browser.
- No financial PII placed in auth metadata or the JWT.

**Privacy / GDPR (controller responsibilities — see SETUP.md)**
- Minimised PII footprint: financial data + documents touch **only** Supabase (one EU
  processor), not n8n logs. Smaller breach surface for the worst case ("NIE + payslips").
- Still required before production: signed Supabase DPA, document-consent checkbox,
  retention/auto-delete on `documents.expires_at`, privacy policy covering the auth
  session token + Supabase as processor, cookie/consent notice. (Defer specifics to a
  Spanish DP professional — not legal advice.)

## 6. Changes in this branch

- `supabase/schema.sql` — `profiles` gains `max_budget`, `bedrooms`, `preferred_areas`,
  `questions_for_agents`; `handle_new_user` now copies `first_name`/`phone` from metadata.
- `supabase/migration-supabase-first.sql` — idempotent migration to apply the same to the
  already-deployed database (run once in the SQL editor).
- `get-started.html` — loads Supabase, sends magic link + non-financial alert, stashes lead.
- `profile.html` — writes to `profiles` if signed in, else stashes + sends link; alert is
  non-financial only.
- `account.html` — flushes any stashed lead/profile into `profiles` on authenticated load.

## 7. Manual steps still required (one-time, in the dashboards)

1. **Run `supabase/migration-supabase-first.sql`** in the Supabase SQL editor (additive,
   safe to re-run).
2. **Supabase → Auth → URL Configuration**: confirm `https://www.llavai.com/account`,
   `/login`, `/app` are in the redirect allow-list, Site URL = `https://www.llavai.com`.
3. **Custom SMTP** (strongly recommended now that every lead triggers a magic-link email):
   connect `hello@llavai.com` so links don't go to spam and you don't hit the shared-sender
   rate limit. Without it the OTP step is best-effort and may not deliver.
4. **n8n**: point the lead-alert webhook at a workflow that (a) notifies the team and
   (b) reads the full profile from `profiles` by `email`/`id` via service_role when needed.
   Finish Stripe credential/activation steps in `supabase/STRIPE.md`.
</content>
</invoke>
