-- ============================================================================
-- Llavai — Spot (self-serve listings feed) schema
-- Run AFTER supabase/schema.sql, in the Supabase SQL editor.
--
-- This powers the higher-margin self-serve product: the n8n pipeline scrapes
-- Idealista, scores each listing with the SAME appeal formula as the call
-- workflow, and writes listings scoring > 70 here (server-side via the
-- service_role key). The web app (/app) reads each user's own feed under RLS.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- listings  — scored, high-appeal listings for a user's feed
-- ---------------------------------------------------------------------------
create table if not exists public.listings (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users(id) on delete cascade,
  property_id       text not null,                 -- Idealista property id (dedupe key)
  source            text not null default 'idealista',
  property_url      text,
  title             text,                          -- address / ubication.title
  price             numeric,
  currency          text default '€',
  area_m2           numeric,
  price_per_m2      numeric,
  rooms             integer,
  bathrooms         integer,
  features          text[] default '{}',           -- e.g. {airConditioning,terrace,exterior,pool,lift}
  photos            text[] default '{}',           -- image URLs (first is the hero)
  photo_count       integer default 0,
  appeal_score      integer not null,
  appeal_reason     text,                          -- the per-component breakdown string
  advertised_phone  text,                          -- Idealista "toNumber"  → call button 1
  maps_phone        text,                          -- Google Maps Places    → call button 2 (later)
  agency_name       text,
  user_type         text,                          -- professional / private
  first_activation  timestamptz,                   -- listing's first-seen time (freshness)
  status            text not null default 'new'
                    check (status in ('new','seen','called','saved','dismissed')),
  created_at        timestamptz not null default now(),
  unique (user_id, property_id)
);
create index if not exists listings_feed_idx on public.listings(user_id, status, created_at desc);

alter table public.listings enable row level security;
-- users read their own feed; n8n writes via service_role (bypasses RLS)
create policy "listings_select_own" on public.listings for select using (auth.uid() = user_id);
-- let users curate their own feed (mark seen / called / saved / dismissed)
create policy "listings_update_own" on public.listings for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- subscriptions  — gates the paid self-serve tier (filled by Stripe webhook)
-- ---------------------------------------------------------------------------
create table if not exists public.subscriptions (
  user_id                uuid primary key references auth.users(id) on delete cascade,
  stripe_customer_id     text,
  stripe_subscription_id text,
  status                 text default 'inactive',  -- active | trialing | past_due | canceled | inactive
  plan                   text,
  current_period_end     timestamptz,
  updated_at             timestamptz not null default now()
);

alter table public.subscriptions enable row level security;
create policy "subscriptions_select_own" on public.subscriptions for select using (auth.uid() = user_id);
-- writes come only from the Stripe webhook handler via service_role. No user write policy.

-- Convenience: does the current signed-in user have an active subscription?
create or replace function public.has_active_subscription()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.subscriptions
    where user_id = auth.uid()
      and status in ('active','trialing')
      and (current_period_end is null or current_period_end > now())
  );
$$;

-- ============================================================================
-- Done. The web app: getSession() -> has_active_subscription() -> read listings.
-- ============================================================================
