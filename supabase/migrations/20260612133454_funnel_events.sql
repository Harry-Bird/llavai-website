-- APPLIED 2026-06-12 (Harry approved live). version 20260612133454 in schema_migrations.
--
-- First-party funnel analytics sink for the signup-flow instrumentation. Written
-- SERVER-SIDE by n8n (service role) from the public track() webhook — mirrors the
-- lead-capture pattern (browser → n8n → Supabase). No new anon write surface: RLS is
-- ON with NO policies, so anon/authenticated clients can neither read nor write; only
-- the service_role (which bypasses RLS, used by n8n) can insert. No PII is stored —
-- anon_id is a random client-generated id, never an email/name. Keeps with the
-- project's minimal-anon-surface posture (cf. 20260611_revoke_anon_tier_rpcs.sql).
-- The rls_enabled_no_policy advisor INFO on this table is intentional (same pattern
-- as public.property_cache).
create table if not exists public.funnel_events (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  event       text not null,        -- 'form_start' | 'lead_submit' | 'magic_link_clicked' | 'profile_step' | 'profile_complete' ...
  plan        text,                 -- 'essential' | 'pro' | null
  lang        text,                 -- 'en' | 'es' | 'uk'
  anon_id     text,                 -- random client id (localStorage), NOT PII
  step        text,                 -- e.g. profile step name/number; nullable
  path        text,                 -- location.pathname
  referrer    text,                 -- referrer host (no query); nullable
  props       jsonb not null default '{}'::jsonb
);

alter table public.funnel_events enable row level security;
-- Intentionally NO policies: locks out anon + authenticated entirely. service_role bypasses RLS.

create index if not exists funnel_events_event_created_idx
  on public.funnel_events (event, created_at desc);
create index if not exists funnel_events_created_idx
  on public.funnel_events (created_at desc);

comment on table public.funnel_events is
  'First-party funnel analytics written server-side by n8n (service role) from the public track() webhook. RLS on with no policies; no PII (anon_id is a random client id).';

-- ---------------------------------------------------------------------------
-- Rollback:
-- drop table if exists public.funnel_events;
-- ---------------------------------------------------------------------------
