-- ============================================================================
-- Llavai — user accounts schema (Supabase / Postgres)
-- Run this in the Supabase SQL editor (Project → SQL → New query) once, in order.
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
-- updated_at helper
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

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
  updated_at          timestamptz not null default now()
);

alter table public.profiles enable row level security;
create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
-- (no INSERT/DELETE for users: rows are created by the trigger below, removed by account deletion cascade)

create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- Auto-create a profile row whenever a new auth user is created (magic-link signup)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email) values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ===========================================================================
-- viewings  (the pipeline — written by Julia / the team server-side; read-only to users)
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
  updated_at    timestamptz not null default now()
);
create index if not exists viewings_user_idx on public.viewings(user_id, created_at desc);

alter table public.viewings enable row level security;
create policy "viewings_select_own" on public.viewings for select using (auth.uid() = user_id);
-- Inserts/updates come from n8n via the service_role key (bypasses RLS). No user-write policy on purpose.

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
-- Done. Verify in Database → Policies that RLS is ON for all four tables.
-- ============================================================================
