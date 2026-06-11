-- W7: call credits & packs backend wiring.
-- Persistent pack/trial credit ledger + consumption/grant RPCs.
-- Value metric is CALLS, never minutes.

-- 1. Re-frame existing columns: calls, not minutes.
comment on column public.subscriptions.call_allowance is
  'Pro monthly included CALLS for the current period (not minutes). Reset by reset_pro_allowance() on Pro create/renew; decremented first by consume_call().';
comment on column public.call_attempts.duration_minutes is
  'Actual Retell call duration in minutes (2dp) for cost analytics only. The call cap is counted in CALLS, never minutes (see subscriptions.call_allowance + call_credit_ledger).';

-- 2. Persistent credit ledger (packs + trial). Balance = sum(delta).
create table if not exists public.call_credit_ledger (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  delta      integer not null,
  reason     text not null check (reason in ('pack_purchase','trial_grant','call_consumed','adjustment')),
  source_ref text,
  created_at timestamptz not null default now()
);
create unique index if not exists call_credit_ledger_source_ref_uq
  on public.call_credit_ledger(source_ref) where source_ref is not null;
create index if not exists call_credit_ledger_user_idx
  on public.call_credit_ledger(user_id, created_at desc);

alter table public.call_credit_ledger enable row level security;
drop policy if exists "ccl_select_own" on public.call_credit_ledger;
create policy "ccl_select_own" on public.call_credit_ledger
  for select using (auth.uid() = user_id);
-- only service_role (bypasses RLS) writes, via the RPCs below.
revoke all on public.call_credit_ledger from anon, authenticated;
grant select on public.call_credit_ledger to authenticated;

-- 3. Internal: is the given user currently Pro? (parametrised twin of is_pro())
create or replace function public.is_pro_uid(p_user_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.subscriptions
    where user_id = p_user_id and plan = 'pro' and status in ('active','trialing')
      and (current_period_end is null or current_period_end > now())
  );
$$;
revoke execute on function public.is_pro_uid(uuid) from anon, public, authenticated;
grant execute on function public.is_pro_uid(uuid) to service_role;

-- 4. call_balance() — the account UI's source of truth for "Julia calls available".
create or replace function public.call_balance()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'is_pro', public.is_pro(),
    'pro_allowance', case when public.is_pro()
        then coalesce((select call_allowance from public.subscriptions where user_id = auth.uid()), 0)
        else 0 end,
    'credits', coalesce((select sum(delta) from public.call_credit_ledger where user_id = auth.uid()), 0)::int,
    'total', (case when public.is_pro()
        then coalesce((select call_allowance from public.subscriptions where user_id = auth.uid()), 0)
        else 0 end)
      + coalesce((select sum(delta) from public.call_credit_ledger where user_id = auth.uid()), 0)::int
  );
$$;
revoke execute on function public.call_balance() from anon, public;
grant execute on function public.call_balance() to authenticated;

create or replace function public.available_calls()
returns integer language sql stable security definer set search_path = public as $$
  select ((public.call_balance())->>'total')::int;
$$;
revoke execute on function public.available_calls() from anon, public;
grant execute on function public.available_calls() to authenticated;

-- 5. consume_call(uid, property) — SERVICE ROLE ONLY. Atomic: Pro allowance first, then credits.
create or replace function public.consume_call(p_user_id uuid, p_property_id text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_ref       text := 'consume:' || p_user_id::text || ':' || coalesce(p_property_id, '');
  v_allowance int;
  v_credits   int;
  v_is_pro    boolean;
begin
  if p_user_id is null then
    return jsonb_build_object('consumed', false, 'reason', 'no_user');
  end if;

  if exists (select 1 from public.call_credit_ledger where source_ref = v_ref) then
    return jsonb_build_object('consumed', true, 'source', 'idempotent');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));  -- serialise per user

  v_is_pro := public.is_pro_uid(p_user_id);
  select call_allowance into v_allowance from public.subscriptions where user_id = p_user_id for update;
  v_allowance := coalesce(v_allowance, 0);
  select coalesce(sum(delta), 0)::int into v_credits from public.call_credit_ledger where user_id = p_user_id;

  if v_is_pro and v_allowance > 0 then
    update public.subscriptions set call_allowance = call_allowance - 1, updated_at = now()
      where user_id = p_user_id;
    return jsonb_build_object('consumed', true, 'source', 'pro_allowance',
      'remaining', (v_allowance - 1) + v_credits);
  elsif v_credits > 0 then
    insert into public.call_credit_ledger(user_id, delta, reason, source_ref)
      values (p_user_id, -1, 'call_consumed', v_ref);
    return jsonb_build_object('consumed', true, 'source', 'credit',
      'remaining', (case when v_is_pro then v_allowance else 0 end) + (v_credits - 1));
  else
    return jsonb_build_object('consumed', false, 'reason', 'no_credit',
      'remaining', (case when v_is_pro then v_allowance else 0 end) + v_credits);
  end if;
end$$;
revoke execute on function public.consume_call(uuid, text) from anon, public, authenticated;
grant execute on function public.consume_call(uuid, text) to service_role;

-- 6. grant_pack_credits — SERVICE ROLE ONLY, idempotent on source_ref (Stripe event/session id).
create or replace function public.grant_pack_credits(p_user_id uuid, p_credits integer, p_source_ref text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_new int;
begin
  if p_user_id is null or p_credits is null or p_credits <= 0 then
    return jsonb_build_object('granted', false, 'reason', 'bad_args');
  end if;
  begin
    insert into public.call_credit_ledger(user_id, delta, reason, source_ref)
      values (p_user_id, p_credits, 'pack_purchase', p_source_ref);
  exception when unique_violation then
    return jsonb_build_object('granted', false, 'reason', 'duplicate',
      'balance', coalesce((select sum(delta) from public.call_credit_ledger where user_id = p_user_id), 0)::int);
  end;
  select coalesce(sum(delta), 0)::int into v_new from public.call_credit_ledger where user_id = p_user_id;
  return jsonb_build_object('granted', true, 'credits', p_credits, 'balance', v_new);
end$$;
revoke execute on function public.grant_pack_credits(uuid, integer, text) from anon, public, authenticated;
grant execute on function public.grant_pack_credits(uuid, integer, text) to service_role;

-- 7. grant_trial_calls — SERVICE ROLE ONLY, once per account (5 free Julia calls).
create or replace function public.grant_trial_calls(p_user_id uuid, p_calls integer default 5)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_new int;
begin
  if p_user_id is null then return jsonb_build_object('granted', false, 'reason', 'no_user'); end if;
  if exists (select 1 from public.call_credit_ledger where user_id = p_user_id and reason = 'trial_grant') then
    return jsonb_build_object('granted', false, 'reason', 'already_granted');
  end if;
  begin
    insert into public.call_credit_ledger(user_id, delta, reason, source_ref)
      values (p_user_id, coalesce(p_calls, 5), 'trial_grant', 'trial:' || p_user_id::text);
  exception when unique_violation then
    return jsonb_build_object('granted', false, 'reason', 'already_granted');
  end;
  select coalesce(sum(delta), 0)::int into v_new from public.call_credit_ledger where user_id = p_user_id;
  return jsonb_build_object('granted', true, 'credits', coalesce(p_calls, 5), 'balance', v_new);
end$$;
revoke execute on function public.grant_trial_calls(uuid, integer) from anon, public, authenticated;
grant execute on function public.grant_trial_calls(uuid, integer) to service_role;

-- 8. reset_pro_allowance — SERVICE ROLE ONLY (kept for manual/ops use; Pro refill is also
-- handled automatically by the set_pro_call_allowance trigger, see w7_02).
create or replace function public.reset_pro_allowance(p_user_id uuid, p_calls integer default 60)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.subscriptions set call_allowance = coalesce(p_calls, 60), updated_at = now()
    where user_id = p_user_id;
end$$;
revoke execute on function public.reset_pro_allowance(uuid, integer) from anon, public, authenticated;
grant execute on function public.reset_pro_allowance(uuid, integer) to service_role;
