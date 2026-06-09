-- ============================================================================
-- Migration: Supabase-first backend
-- Apply ONCE to the already-deployed database (Supabase → SQL editor → New query).
-- Everything here is idempotent and additive — safe to re-run.
--
-- It (1) adds the profile-search columns the /profile form collects but the
-- original schema lacked, and (2) updates the new-user trigger to copy the
-- non-sensitive first_name/phone from the magic-link signup metadata.
-- ============================================================================

-- 1. New columns on profiles (search preferences + agent questions)
alter table public.profiles add column if not exists max_budget           numeric;
alter table public.profiles add column if not exists bedrooms             text;
alter table public.profiles add column if not exists preferred_areas      text[] default '{}';
alter table public.profiles add column if not exists questions_for_agents text;

-- 2. Trigger now copies first_name + phone from signInWithOtp options.data.
--    (Financial PII is never placed in metadata; it is written to this table
--     directly from the authenticated browser under RLS.)
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

-- Trigger binding is unchanged; recreate defensively in case it was dropped.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
-- Done. Verify: profiles now has max_budget, bedrooms, preferred_areas,
-- questions_for_agents; a new magic-link signup creates a profiles row with
-- first_name/phone populated from the form.
-- ============================================================================
