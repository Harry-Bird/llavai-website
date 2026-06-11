-- ============================================================================
-- Llavai — public schema snapshot (Supabase / Postgres)
-- Generated from the LIVE database on 2026-06-11 (project bwgaolpmarlnwbcrklzc).
--
-- This file is the canonical snapshot of production. Earlier partial files
-- (listings.sql, migration-supabase-first.sql) predate it and are superseded.
-- Incremental changes land in supabase/migrations/ going forward; candidate
-- changes awaiting review live in supabase/proposed/.
--
-- Applied migrations at snapshot time (supabase_migrations.schema_migrations):
--   20260609081621  harden_security_definer_functions
--   20260609155330  supabase_first_profile_fields_and_trigger
--   20260609162210  feed_search_clients_view
--   20260609180037  backend_rebuild_phase0_schema
--   20260609180954  feed_search_clients_add_prefs
--   20260609191414  teaser_listings_view
--   20260609193052  viewings_self_manage_policies
--   20260609194023  get_call_client_rpc
--   20260609203025  get_call_client_add_tier
--   20260609210151  w2_call_attempts_post_call_columns
--   20260610231217  business_hours_call_queue
--
-- Security model: Row-Level Security (RLS) is ON for every table. With RLS on
-- and no matching policy, Postgres DENIES access — so the policies below are
-- what grant each signed-in user access to ONLY their own rows. The browser
-- uses the public "anon" key; security comes from RLS, never from hiding the key.
-- The "service_role" key (used ONLY by n8n / server side) bypasses RLS — it must
-- never appear in any front-end file.
-- ============================================================================

-- gen_random_uuid()
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- updated_at helper  (hardened: empty search_path — fully-qualified refs only)
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;

-- ---------------------------------------------------------------------------
-- rls_auto_enable + "ensure_rls" event trigger: any future CREATE TABLE in
-- public gets RLS switched on automatically, so a forgotten "enable row level
-- security" can never silently expose a table.
-- ---------------------------------------------------------------------------
create or replace function public.rls_auto_enable()
returns event_trigger language plpgsql security definer
set search_path = pg_catalog as $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

create event trigger ensure_rls on ddl_command_end
  execute function public.rls_auto_enable();

-- ===========================================================================
-- profiles  (1:1 with auth.users; mirrors the tenant-profile form fields)
-- ===========================================================================
create table if not exists public.profiles (
  id                  uuid primary key references auth.users(id) on delete cascade,
  email               text,
  first_name          text,
  last_name           text,
  phone               text,
  nationality         text,
  residency_status    text,
  moving_in_as        text,
  num_occupants       integer,
  profession          text,
  employment_type     text,
  individual_income   text,
  household_income    text,
  has_nominas         text,
  has_guarantor       text,
  guarantor_details   text,
  viewing_availability text,
  preferred_contact   text,
  telegram_username   text,
  idealista_url       text,
  notes               text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  max_budget          numeric,                    -- max monthly rent (€)
  bedrooms            text,                       -- 'studio' | '1' | '2' | ...
  preferred_areas     text[] default '{}',        -- chosen Barcelona neighbourhoods
  questions_for_agents text,                      -- anything to ask the agency on the call
  -- Supabase-first / backend-rebuild fields (June 2026):
  intended_plan       text,                       -- plan chosen during onboarding ('essential'|'pro')
  pro_status          text default 'none',        -- Pro concierge lifecycle marker
  alert_email_verified boolean default false,     -- Idealista alert-forwarding email confirmed
  include_seasonal    boolean default false,      -- feed pref: show seasonal lets
  include_platform_reposts boolean default false, -- feed pref: show platform reposts
  scoring_prefs       jsonb default '{}'::jsonb,  -- per-user appeal-score weighting overrides
  timezone            text default 'Europe/Madrid',
  booking_buffer_mins integer default 30          -- min lead time Julia leaves before a viewing
);

alter table public.profiles enable row level security;
create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
-- (no INSERT/DELETE for users: rows are created by the trigger below, removed by account deletion cascade)

create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- Auto-create a profile row whenever a new auth user is created (magic-link signup).
-- Copies the non-sensitive fields the lead/profile form passed in signInWithOtp's
-- `options.data` (raw_user_meta_data). Financial PII is NEVER put in metadata —
-- it is written straight to this table from the authenticated browser under RLS.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, first_name, phone)
  values (
    new.id,
    new.email,
    nullif(new.raw_user_meta_data->>'first_name',''),
    nullif(new.raw_user_meta_data->>'phone','')
  )
  on conflict (id) do nothing;
  return new;
end; $$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ===========================================================================
-- listings  — scored, high-appeal listings for a user's feed (/app)
-- Written server-side by the n8n pipeline (service_role); users read their own
-- feed under RLS and may update status (seen/saved/dismissed) on their rows.
-- ===========================================================================
create table if not exists public.listings (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users(id) on delete cascade,
  property_id         text not null,              -- Idealista property id (dedupe key)
  source              text not null default 'idealista',
  property_url        text,
  title               text,                       -- address / ubication.title
  price               numeric,
  currency            text default '€',
  area_m2             numeric,
  price_per_m2        numeric,
  rooms               integer,
  bathrooms           integer,
  features            text[] default '{}',        -- e.g. {airConditioning,terrace,exterior,pool,lift}
  photos              text[] default '{}',        -- image URLs (first is the hero)
  photo_count         integer default 0,
  appeal_score        integer not null,           -- 0–100, same formula as the call workflow
  appeal_reason       text,
  advertised_phone    text,
  maps_phone          text,
  agency_name         text,
  user_type           text,
  first_activation    timestamptz,
  status              text not null default 'new'
                      check (status in ('new','seen','called','saved','dismissed')),
  created_at          timestamptz not null default now(),
  -- location
  neighbourhood       text,
  district            text,
  latitude            numeric,
  longitude           numeric,
  address_hidden      boolean,
  -- property detail
  usable_area_m2      numeric,
  floor               text,
  is_exterior         boolean,
  condition           text,
  is_studio           boolean,
  has_lift            boolean,
  furnishing          text,
  pets_allowed        boolean,
  energy_rating       text,
  energy_state        text,
  -- agency / provenance
  agency_total_ads    integer,
  is_private_landlord boolean,
  agency_logo         text,
  external_reference  text,
  is_seasonal         boolean default false,
  is_platform_repost  boolean default false,
  platform            text,
  allows_remote_visit boolean,
  has_360             boolean,
  allows_counter_offer boolean,
  description         text,
  listing_modified_at timestamptz,
  price_drop          jsonb,
  fine_print          jsonb default '{}'::jsonb,  -- deposit/fees/requirements parsed from the description
  raw                 jsonb,                      -- full scraped payload, for reprocessing
  unique (user_id, property_id)
);
create index if not exists listings_feed_idx on public.listings(user_id, status, created_at desc);
create index if not exists listings_feed_flags_idx on public.listings(user_id, is_seasonal, is_platform_repost, appeal_score desc);

alter table public.listings enable row level security;
create policy "listings_select_own" on public.listings for select using (auth.uid() = user_id);
create policy "listings_update_own" on public.listings for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- inserts/deletes are service_role only (the pipeline owns row lifecycle)

-- ===========================================================================
-- viewings  (the pipeline tab on /account)
-- Rows come from two places: Julia / the team server-side via service_role
-- (source='julia' etc.), AND the user's own "add a viewing" form — users
-- DELIBERATELY have insert/update/delete on their own rows (self-managed
-- viewings, source='self'; migration 20260609193052). account.html only ever
-- inserts source='self'. (An earlier version of this file claimed there was
-- "no user-write policy on purpose" — that is no longer true.)
-- ===========================================================================
create table if not exists public.viewings (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  listing_url   text,
  listing_title text,
  neighbourhood text,
  price         numeric,
  agency_name   text,
  agency_phone  text,
  status        text not null default 'matched'
                check (status in ('matched','calling','booked','confirmed','attended','declined','no_answer')),
  viewing_at    timestamptz,
  notes         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  -- backend-rebuild fields (June 2026):
  listing_id    uuid references public.listings(id) on delete set null,
  property_id   text,
  source        text default 'self',              -- 'self' (user-added) vs Julia/team rows
  address       text,
  duration_mins integer default 30,
  confirmed_at  timestamptz
);
create index if not exists viewings_user_idx on public.viewings(user_id, created_at desc);

alter table public.viewings enable row level security;
create policy "viewings_select_own" on public.viewings for select using (auth.uid() = user_id);
create policy "viewings_insert_own" on public.viewings for insert with check (auth.uid() = user_id);
create policy "viewings_update_own" on public.viewings for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "viewings_delete_own" on public.viewings for delete using (auth.uid() = user_id);
-- (proposed tightening: restrict user inserts to source='self' — see supabase/proposed/)

create trigger viewings_set_updated_at before update on public.viewings
  for each row execute function public.set_updated_at();

-- ===========================================================================
-- documents  (metadata; the files live in the private "documents" Storage bucket)
-- ===========================================================================
create table if not exists public.documents (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  doc_type     text not null default 'other'
               check (doc_type in ('nie','passport','payslip','bank_statement','reference','guarantor','contract','other')),
  storage_path text not null,                    -- '{user_id}/{uuid}-filename.pdf'
  file_name    text,
  mime_type    text,
  size_bytes   bigint,
  uploaded_at  timestamptz not null default now(),
  expires_at   timestamptz                       -- optional retention / auto-delete date
);
create index if not exists documents_user_idx on public.documents(user_id, uploaded_at desc);

alter table public.documents enable row level security;
create policy "documents_select_own" on public.documents for select using (auth.uid() = user_id);
create policy "documents_insert_own" on public.documents for insert with check (auth.uid() = user_id);
create policy "documents_delete_own" on public.documents for delete using (auth.uid() = user_id);

-- ===========================================================================
-- messages  (lightweight thread between the renter and the Llavai team)
-- ===========================================================================
create table if not exists public.messages (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  sender     text not null check (sender in ('user','team')),
  body       text not null,
  created_at timestamptz not null default now(),
  read_at    timestamptz
);
create index if not exists messages_user_idx on public.messages(user_id, created_at);

alter table public.messages enable row level security;
create policy "messages_select_own" on public.messages for select using (auth.uid() = user_id);
-- users may send (sender must be 'user'); team replies are inserted via service_role
create policy "messages_insert_own" on public.messages for insert
  with check (auth.uid() = user_id and sender = 'user');

-- ===========================================================================
-- subscriptions  (Stripe state, written ONLY by n8n's Stripe-sync workflow)
-- Tier is derived from (plan, status): see current_tier() below and STRIPE.md.
-- ===========================================================================
create table if not exists public.subscriptions (
  user_id                uuid primary key references auth.users(id) on delete cascade,
  stripe_customer_id     text,
  stripe_subscription_id text,
  status                 text default 'inactive',  -- Stripe status: active|trialing|canceled|...
  plan                   text,                     -- 'essential' | 'pro'
  current_period_end     timestamptz,
  updated_at             timestamptz not null default now(),
  call_allowance         integer                   -- Pro call-minutes cap for the period
);

alter table public.subscriptions enable row level security;
create policy "subscriptions_select_own" on public.subscriptions for select using (auth.uid() = user_id);
-- no user writes: only the service_role (Stripe sync) mutates this table

-- ===========================================================================
-- availability  (weekly free windows; Julia books viewings only inside them)
-- ===========================================================================
create table if not exists public.availability (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  weekday    integer not null check (weekday >= 0 and weekday <= 6),  -- 0=Sunday
  start_time time not null,
  end_time   time not null,
  created_at timestamptz not null default now()
);
create index if not exists availability_user_idx on public.availability(user_id, weekday);

alter table public.availability enable row level security;
create policy "availability_select_own" on public.availability for select using (auth.uid() = user_id);
create policy "availability_insert_own" on public.availability for insert with check (auth.uid() = user_id);
create policy "availability_update_own" on public.availability for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "availability_delete_own" on public.availability for delete using (auth.uid() = user_id);

-- ===========================================================================
-- property_cache  (server-only scrape cache, keyed by portal property id)
-- RLS is ON with NO policies and table privileges are revoked from anon /
-- authenticated — only the service_role (n8n) can touch it.
-- ===========================================================================
create table if not exists public.property_cache (
  property_id text primary key,
  source      text not null default 'idealista',
  raw         jsonb,
  parsed      jsonb,
  appeal_base integer,
  scraped_at  timestamptz not null default now(),
  expires_at  timestamptz
);

alter table public.property_cache enable row level security;
revoke all on public.property_cache from anon, authenticated;

-- ===========================================================================
-- call_attempts  (one row per Julia dial; dedup key = user × property)
-- Written by n8n (service_role); users see their own call history read-only.
-- ===========================================================================
create table if not exists public.call_attempts (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  property_id          text not null,
  retell_call_id       text,
  status               text not null default 'queued'
                       check (status in ('queued','calling','completed','failed','skipped')),
  skip_reason          text,
  created_at           timestamptz not null default now(),
  -- W2 post-call columns (migration 20260609210151):
  duration_minutes     numeric,
  disconnection_reason text,
  ended_at             timestamptz,
  unique (user_id, property_id)
);
comment on column public.call_attempts.duration_minutes is
  'Retell call duration in minutes (2dp). Feeds the Pro call-minutes cap (subscriptions.call_allowance).';
create index if not exists call_attempts_user_idx on public.call_attempts(user_id, created_at desc);
create unique index if not exists call_attempts_retell_call_id_uq
  on public.call_attempts(retell_call_id) where retell_call_id is not null;

alter table public.call_attempts enable row level security;
create policy "call_attempts_select_own" on public.call_attempts for select using (auth.uid() = user_id);

-- ===========================================================================
-- call_queue  (business-hours gate; migration 20260610231217)
-- ===========================================================================
create table if not exists public.call_queue (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  property_id    text not null,
  listing_id     uuid references public.listings(id) on delete set null,
  retell_payload jsonb not null,
  reason         text not null default 'after_hours',
  status         text not null default 'pending'
                 check (status in ('pending','processing','called','failed','expired','cancelled')),
  created_at     timestamptz not null default now(),
  not_before     timestamptz,
  expires_at     timestamptz not null default now() + interval '48 hours',
  processed_at   timestamptz,
  retell_call_id text,
  last_error     text,
  unique (user_id, property_id)
);
comment on table public.call_queue is
  'Off-hours (and future retry) call queue. Writes are service-role only (n8n W1 inserts,
   drain workflow W1.5 claims/fires). Gate: Mon-Fri 08:00-18:00 Europe/Madrid, enforced
   in both W1 and the drain. unique(user_id, property_id) mirrors call_attempts dedup.';
create index if not exists call_queue_drain_idx on public.call_queue(status, created_at);

alter table public.call_queue enable row level security;
create policy "call_queue_select_own" on public.call_queue
  for select using ((select auth.uid()) = user_id);

-- ===========================================================================
-- VIEWS
-- ===========================================================================

-- feed_search_clients — which clients the n8n scraper should search for, plus
-- their feed prefs. security_invoker=true + grants stripped to service_role
-- only: the browser can never read other people's search criteria through it.
create or replace view public.feed_search_clients
with (security_invoker = true) as
select
  p.id as user_id,
  p.idealista_url,
  p.max_budget,
  p.bedrooms,
  p.preferred_areas,
  p.scoring_prefs,
  p.include_seasonal,
  p.include_platform_reposts
from public.profiles p
join public.subscriptions s on s.user_id = p.id
where s.status in ('active','trialing')
  and (s.current_period_end is null or s.current_period_end > now())
  and p.idealista_url is not null and p.idealista_url <> '';
revoke all on public.feed_search_clients from anon, authenticated;

-- teaser_listings — the blurred free-tier teaser feed on /app.
--
-- *** SECURITY DEFINER IS INTENTIONAL — DO NOT "FIX" IT. ***
-- This view deliberately runs with the owner's rights (security_invoker=false)
-- so it can read ALL users' listings rows past RLS and serve an anonymised
-- teaser to every signed-in user (granted to `authenticated`; anon has no
-- grant). That also means EVERY COLUMN ADDED HERE LEAKS TO ALL SIGNED-IN
-- USERS: it must never expose property_id, user_id, exact price, URLs,
-- phones, addresses or anything else identifying. Price is bucketed into
-- €200 bands and only coarse attributes are projected.
create or replace view public.teaser_listings
with (security_invoker = false) as
select
  neighbourhood, district, appeal_score, rooms, bathrooms, area_m2,
  condition, energy_rating, has_lift, photo, price_min, price_max, created_at
from (
  select distinct on (l.property_id)
    l.property_id,
    l.neighbourhood,
    l.district,
    l.appeal_score,
    l.rooms,
    l.bathrooms,
    l.area_m2,
    l.condition,
    l.energy_rating,
    l.has_lift,
    l.photos[1] as photo,
    case when l.price is null then null::integer
         else (floor(l.price / 200.0) * 200)::integer end as price_min,
    case when l.price is null then null::integer
         else (floor(l.price / 200.0) * 200 + 200)::integer end as price_max,
    l.created_at
  from public.listings l
  where l.appeal_score >= 60
    and coalesce(l.is_seasonal, false) = false
    and coalesce(l.is_platform_repost, false) = false
    and l.created_at > now() - interval '21 days'
  order by l.property_id, l.created_at desc
) t
order by appeal_score desc, created_at desc;
revoke all on public.teaser_listings from anon;
grant select on public.teaser_listings to authenticated;

-- ===========================================================================
-- RPCs (called from the browser via supabase.rpc(...) unless noted)
-- All are SECURITY DEFINER with a pinned search_path (migration
-- 20260609081621) so they read subscriptions/profiles past RLS but can't be
-- search_path-hijacked.
-- ===========================================================================

-- current_tier() → 'pro' | 'essential' | 'trial' | 'free' for the caller.
-- Drives the tier-aware account UI (account.html applyTierUI()).
create or replace function public.current_tier()
returns text language sql stable security definer set search_path = public as $$
  select case
    when exists (select 1 from public.subscriptions where user_id=auth.uid() and plan='pro'
                 and status in ('active','trialing') and (current_period_end is null or current_period_end>now())) then 'pro'
    when exists (select 1 from public.subscriptions where user_id=auth.uid()
                 and status='active' and (current_period_end is null or current_period_end>now())) then 'essential'
    when exists (select 1 from public.subscriptions where user_id=auth.uid()
                 and status='trialing' and (current_period_end is null or current_period_end>now())) then 'trial'
    else 'free'
  end;
$$;

-- is_pro() → does the caller have an active/trialing Pro subscription?
create or replace function public.is_pro()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.subscriptions
    where user_id = auth.uid()
      and plan = 'pro'
      and status in ('active','trialing')
      and (current_period_end is null or current_period_end > now())
  );
$$;

-- has_active_subscription() → the /app paywall check (any paid/trialing plan).
create or replace function public.has_active_subscription()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.subscriptions
    where user_id = auth.uid()
      and status in ('active','trialing')
      and (current_period_end is null or current_period_end > now())
  );
$$;

-- NOTE (audit R8): current_tier / is_pro / has_active_subscription are
-- currently executable by public+anon as well as authenticated. They only ever
-- key off auth.uid() (null for anon), but the proposed hardening in
-- supabase/proposed/ revokes anon/public EXECUTE anyway.

-- apply_for_pro() → W5: signed-in client applies for the Pro tier
-- (migration 20260611060457; design in specs/w5_pro_application_design.md).
-- Allowed transition: none/rejected → 'applied' only (idempotent for
-- applied/approved). Approval itself is service-role only (n8n W5b) — never
-- settable from the browser. Executable by authenticated only (anon revoked).
create or replace function public.apply_for_pro()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  cur text;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  select pro_status into cur from profiles where id = uid;
  if cur is null then
    raise exception 'profile not found';
  end if;
  if cur in ('applied','approved') then
    return cur; -- idempotent: re-applying changes nothing
  end if;
  update profiles set intended_plan = 'pro', pro_status = 'applied' where id = uid;
  insert into messages (user_id, sender, body)
    values (uid, 'user', '[PRO APPLICATION] Client applied for Pro from the account page.');
  return 'applied';
end$$;

revoke execute on function public.apply_for_pro() from anon, public;
grant execute on function public.apply_for_pro() to authenticated;

-- get_call_client(p_email) → everything Julia's call workflow needs about a
-- client, as one jsonb blob (profile, tier, availability windows).
-- SERVICE-ROLE ONLY: execute is revoked from public/anon/authenticated — it
-- looks clients up by email and must never be callable from the browser.
create or replace function public.get_call_client(p_email text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(
    (select jsonb_build_object(
      'found', true,
      'user_id', p.id,
      'email', p.email,
      'first_name', p.first_name,
      'last_name', p.last_name,
      'phone', p.phone,
      'profession', p.profession,
      'employment_type', p.employment_type,
      'individual_income', p.individual_income,
      'household_income', p.household_income,
      'has_nominas', p.has_nominas,
      'has_guarantor', p.has_guarantor,
      'guarantor_details', p.guarantor_details,
      'moving_in_as', p.moving_in_as,
      'num_occupants', p.num_occupants,
      'viewing_availability', p.viewing_availability,
      'questions_for_agents', p.questions_for_agents,
      'notes', p.notes,
      'scoring_prefs', coalesce(p.scoring_prefs, '{}'::jsonb),
      'include_seasonal', coalesce(p.include_seasonal, false),
      'include_platform_reposts', coalesce(p.include_platform_reposts, false),
      'alert_email_verified', coalesce(p.alert_email_verified, false),
      'is_pro', exists(
         select 1 from public.subscriptions s
         where s.user_id = p.id and s.plan = 'pro'
           and s.status in ('active','trialing')
           and (s.current_period_end is null or s.current_period_end > now())),
      'tier', case
        when exists (select 1 from public.subscriptions s
                     where s.user_id = p.id and s.plan = 'pro'
                       and s.status in ('active','trialing')
                       and (s.current_period_end is null or s.current_period_end > now())) then 'pro'
        when exists (select 1 from public.subscriptions s
                     where s.user_id = p.id and s.status = 'active'
                       and (s.current_period_end is null or s.current_period_end > now())) then 'essential'
        when exists (select 1 from public.subscriptions s
                     where s.user_id = p.id and s.status = 'trialing'
                       and (s.current_period_end is null or s.current_period_end > now())) then 'trial'
        else 'free'
      end,
      'availability', coalesce(
         (select jsonb_agg(jsonb_build_object('weekday', a.weekday, 'start', a.start_time, 'end', a.end_time) order by a.weekday)
          from public.availability a where a.user_id = p.id), '[]'::jsonb)
    )
    from public.profiles p
    where lower(p.email) = lower(p_email)
    limit 1),
    jsonb_build_object('found', false)
  )
$$;
revoke execute on function public.get_call_client(text) from public, anon, authenticated;

-- ===========================================================================
-- Storage: private "documents" bucket + per-user folder policies
-- Files are stored as  {auth.uid}/{uuid}-filename  so the first path segment
-- is the owner's id. storage.foldername(name)[1] returns that segment.
-- NOTE: create the bucket first (Storage → New bucket → name "documents",
-- Public = OFF), then run these policies.
-- ===========================================================================
create policy "documents_storage_read_own" on storage.objects for select
  using (bucket_id = 'documents' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "documents_storage_insert_own" on storage.objects for insert
  with check (bucket_id = 'documents' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "documents_storage_delete_own" on storage.objects for delete
  using (bucket_id = 'documents' and auth.uid()::text = (storage.foldername(name))[1]);

-- ============================================================================
-- Done. Verify in Database → Policies that RLS is ON for all ten tables.
-- ============================================================================
