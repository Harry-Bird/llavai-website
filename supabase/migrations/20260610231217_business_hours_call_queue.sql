-- Migration 20260610231217_business_hours_call_queue  (APPLIED to live 2026-06-10 23:12 UTC)
-- Business-hours gate for Julia: calls requested outside Mon–Fri 08:00–18:00
-- Europe/Madrid are queued here by n8n W1 and fired by the drain workflow W1.5.
-- Users get read-only visibility of their own queued calls; all writes are
-- service-role only.

create table public.call_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id text not null,
  listing_id uuid references public.listings(id) on delete set null,
  retell_payload jsonb not null,
  reason text not null default 'after_hours',
  status text not null default 'pending'
    check (status in ('pending','processing','called','failed','expired','cancelled')),
  created_at timestamptz not null default now(),
  not_before timestamptz,
  expires_at timestamptz not null default now() + interval '48 hours',
  processed_at timestamptz,
  retell_call_id text,
  last_error text,
  unique (user_id, property_id)
);
create index call_queue_drain_idx on public.call_queue (status, created_at);
alter table public.call_queue enable row level security;
create policy call_queue_select_own on public.call_queue
  for select using ((select auth.uid()) = user_id);

comment on table public.call_queue is
  'Off-hours (and future retry) call queue. Writes are service-role only (n8n W1 inserts,
   drain workflow W1.5 claims/fires). Gate: Mon-Fri 08:00-18:00 Europe/Madrid, enforced
   in both W1 and the drain. unique(user_id, property_id) mirrors call_attempts dedup.';
