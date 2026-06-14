# Free Renter Tools — design spec

Status: APPROVED (design), 2026-06-14. Sub-project ③ of the "Llavai signed-in app" program.
Surfaces: public website (logged-out, SEO/lead-gen) + in-app (logged-in, saved/cloud).
Owner directives (skill stack):
- UI via **ui-ux-pro-max**.
- Back-end / full-stack + security via **fullstack-guardian** — run its security checklist BEFORE coding
  (auth, authz, input validation client + server, output encoding/XSS, parameterized queries, no hardcoded
  secrets, log security events). Applies especially to the PII pieces below (storage, share tokens, edge fns).
- ALL public-facing copy (tool pages, CTAs, cover-letter templates, share-page text) via **humanizer**,
  then the Llavai copy voice (British/intl spelling).
- **context-engineering** when authoring any agent/command/subagent prompts.
- Keep the site build-free.

## 1. Context & why

Three free renter tools that (a) deliver standalone value, (b) act as top-of-funnel lead magnets that
capture exactly Llavai's audience (expat renters in Barcelona), and (c) tie back into the paid product.
They are the first thing we build (chosen over the PWA rebuild) because they ship fast on the public
site, are largely independent of the app, and drive signups immediately.

Design language is the premium editorial kit validated in brainstorming (Fraunces/Newsreader, cream
`#F4EFE5` / deep-blue `#1B388F` / coral `#E55B45`, stacked-paper surfaces, line icons, real photography).
The static, no-build site is preserved — vanilla HTML/CSS/JS, with CDN libraries for heavy bits (PDF) and
small server endpoints (Supabase Edge Functions) only where a secret or cross-user read is required.

## 2. Goals / non-goals

**Goals**
- Rent calculator, Cover-letter drafter, Renter's dossier + secure share — each usable logged-out on the
  public site and logged-in in the app.
- Lead capture at the moment of intent (logged-out → contextual magic-link signup that preserves work).
- Privacy-safe handling of sensitive PII (passports, payslips). No anon uploads.
- Trilingual (EN/ES/UK) public pages with `/es/` + `/uk/` locale generation (gen-locales.js).

**Non-goals (this spec)**
- The PWA shell, bottom-nav, dashboard, swipe feed, and push notifications (sub-projects ① and ②).
- Merging arbitrary user PDFs into one file (MVP shares docs via the link; full merge is an enhancement).
- Paid gating beyond the calculator's "act on it" signup nudge (tools are free).

## 3. Tool ① — Rent calculator

- **What:** enter net monthly salary + household income → live green/amber/red affordability bands +
  a draggable "try a rent" verdict, on the Spanish **3× rule** (green ≤ income/3; amber income/3–income/2.5;
  red > income/2.5). Validated interactive prototype exists.
- **Tech:** pure client-side JS. No backend, no storage, no PII. Instant.
- **Surfaces:** public page `/rent-calculator` (trilingual, editorial) + in-app under Profile → Tools.
- **Access (decided):** free to compute. The "**See flats in my band**" CTA converts:
  - logged-in → applies the band as a feed filter (min/max passed to the feed query; optional
    `profiles.target_rent_max int` to persist).
  - logged-out → magic-link signup carrying the band (localStorage `llavai-rent-band`), flushed after auth.
- **SEO:** standalone indexable page; strong programmatic-SEO / lead-magnet surface.

## 4. Tool ② — Cover letter drafter

- **What:** generate a Spanish *carta de presentación*. Inputs prefilled from the profile when signed-in,
  else a short form (name, profession, employment type, income, listing/agent, tone: Warm/Formal/Concise).
  Output is editable; actions: Copy / Download PDF / Add to dossier. Save drafts when signed-in.
- **Engine (decided — template-first, LLM-pluggable):**
  - A Supabase **Edge Function** `draft-cover-letter` is the single entry point.
  - If env secret `LLM_BASE_URL` (+ `LLM_API_KEY`, `LLM_MODEL`) is set → call it (OpenAI-compatible
    `/chat/completions`, or Ollama `/api/generate`) with a Spanish-carta system prompt.
  - Else (default, day one) → render a **deterministic smart template** from the inputs. Zero cost, zero
    setup, works for everyone.
  - The response carries `source: 'llm' | 'template'` so the UI can label "AI-drafted" only when true.
  - **Ollama is NOT yet set up** (owner has it installed, never exposed an endpoint). Exposing it
    (tunnel or hosted) and setting `LLM_BASE_URL` is an optional later owner task — no code change needed.
- **Abuse control:** rate-limit the public path (per-IP/session counter; see §7). The proxy holds the key
  server-side; the browser never sees it.
- **Surfaces:** public page `/cover-letter` (links from the existing cover-letter blog post) + in-app.

## 5. Tool ③ — Renter's dossier + secure share

- **Signed-in:** documents live in Supabase Storage (reuse the existing `documents` table + bucket,
  RLS-own). A dossier = a selection of docs (+ optional cover letter). Actions:
  - **Share link:** create a `dossier_shares` row with an unguessable token → `llavai.app/d/?t=<token>`,
    a read-only page an agent opens (no login). **noindex**, **revocable**, **expiring** (default 7 days),
    **access-logged** (view_count / last_viewed_at).
  - **Download PDF:** client-side (pdf-lib via CDN) — MVP = cover sheet + application summary + cover
    letter; merging the actual document PDFs is a fast-follow (pdf-lib supports it).
- **Logged-out:** **client-side packaging, no upload** — add files locally, generate a PDF in the browser,
  download. To get a *shareable link* (cloud), sign up. Privacy-safe by construction.
- **Share resolver:** a Supabase **Edge Function** `get-dossier-share?t=<token>` runs as service-role,
  validates token (exists, not expired, not revoked), increments view_count, and returns the dossier
  title + `[{name, type, signed_url (short-TTL)}]` + cover-letter body. The public `/d/` page (static
  HTML) fetches this and renders read-only. RLS still blocks anon from reading `dossier_shares`/`documents`
  directly — the Edge Function is the only gated reader.

## 6. Data model (additive — Supabase)

Reuse: `documents` (+ storage bucket), `profiles`.

```
-- new (optional): saved cover-letter drafts — created first (dossier_shares FKs it)
create table public.cover_letters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_ref text, tone text, body text not null,
  source text,                                -- 'llm' | 'template'
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- new: dossier share links
create table public.dossier_shares (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text unique not null,                 -- unguessable (>=128 bits base62)
  title text,
  doc_ids uuid[] not null default '{}',
  cover_letter_id uuid references public.cover_letters(id) on delete set null,
  expires_at timestamptz not null default now() + interval '7 days',
  revoked boolean not null default false,
  view_count int not null default 0,
  last_viewed_at timestamptz,
  created_at timestamptz not null default now()
);
-- optional: persist calculator target for feed filtering
alter table public.profiles add column if not exists target_rent_max int;
```

RLS: `dossier_shares` + `cover_letters` → owner-only (`(select auth.uid()) = user_id`) for all verbs;
service_role full (for the resolver). No anon/authenticated read of shares — the Edge Function is the
sole token-gated reader. Follow the wrapped-`(select auth.uid())` pattern (W8 perf migration).

## 7. Security & privacy

- Sensitive PII throughout → **no anonymous uploads**; logged-out dossier is client-side only.
- Share tokens: ≥128-bit random, URL-safe; expiring (default 7d, user-settable); revocable; the share
  page is `noindex,nofollow`; resolver returns only the selected docs as short-TTL signed URLs; optional
  visible "shared via Llavai · for {agent}" watermark; access-logged.
- Cover-letter proxy: key server-side only; **rate-limit** the public path (e.g. a `tool_usage(ip_hash,
  tool, day, count)` table or edge KV; cap N/day/IP) to bound LLM cost/abuse.
- Storage bucket: RLS-own; signed URLs only; never list other users' objects.
- Implementation runs the **fullstack-guardian** security checklist before coding each component: auth +
  authz checks, input validation on client AND server, output encoding, parameterized queries, secrets only
  in env (never in client/source), and logging of security-relevant events (share access, revocations).

## 8. Lead capture

Every logged-out tool ends in a contextual magic-link signup that **preserves the in-progress work** and
flushes it into the new account after auth (existing `llavai-profile-pending` pattern):
- calculator → `llavai-rent-band` → applied as feed filter post-auth.
- cover letter → `llavai-cover-draft` → saved to `cover_letters`.
- dossier → local files stay client-side until signup, then offered for upload.

## 9. Surfaces, SEO, i18n, build-free

- New public pages: `/rent-calculator`, `/cover-letter`, `/dossier`, and the read-only `/d/` share view.
  Trilingual via `[data-lang]`; regenerate `/es/` + `/uk/` with `scripts/gen-locales.js` (add to LOCALES
  page maps). `/d/` is noindexed and excluded from sitemap.
- In-app: the same tools under Profile → Tools (and the calculator CTA wired to the feed).
- Build-free: vanilla JS; PDF via pdf-lib CDN; the only server code is the two Edge Functions under
  `supabase/functions/` (already `.vercelignore`d). No framework, no bundler.
- UI implemented via **ui-ux-pro-max** against the premium kit.

## 10. Build order (each independently shippable)

1. **Rent calculator** (public + in-app feed filter) — fastest, pure client, immediate SEO/lead value.
2. **Cover letter** (Edge Function proxy + template; LLM via env when ready) — public + in-app.
3. **Renter's dossier + secure share** (storage reuse, `dossier_shares`, resolver Edge Function, PDF) —
   most complex; logged-in cloud + logged-out client-side.

## 11. Owner / follow-up tasks

- (Optional) Expose Ollama as a reachable endpoint and set `LLM_BASE_URL`/`LLM_API_KEY`/`LLM_MODEL` to
  upgrade the cover letter from template to AI. Until then the template ships.
- Confirm Supabase Storage bucket + `documents` schema are share-ready (they exist from the app today).
- Supabase plan upgrade (audit C1) still recommended before storing more PII at volume.

## 12. Rollback

All schema is additive (new tables + one nullable column) — drop the new tables / column to revert.
Public pages are new files (delete to remove). Edge Functions are independently deployable/removable.
No change to existing billing, feed, or call paths.
