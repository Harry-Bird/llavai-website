-- W7 change (owner decision 2026-06-11): the 5 free trial calls are USER-CLAIMED via a
-- button, not auto-granted at trial start. The user decides when to start them; once
-- claimed the credits sit in the ledger and get spent on the next qualifying listings.

-- User-callable claim: authenticated, keyed to auth.uid(), once per account, Essential-only.
create or replace function public.claim_trial_calls()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_tier text; v_new int;
begin
  if uid is null then
    return jsonb_build_object('granted', false, 'reason', 'not_authenticated');
  end if;
  v_tier := public.current_tier();
  if v_tier not in ('trial','essential') then
    return jsonb_build_object('granted', false, 'reason', 'not_eligible');
  end if;
  if exists (select 1 from public.call_credit_ledger where user_id = uid and reason = 'trial_grant') then
    return jsonb_build_object('granted', false, 'reason', 'already_claimed');
  end if;
  begin
    insert into public.call_credit_ledger(user_id, delta, reason, source_ref)
      values (uid, 5, 'trial_grant', 'trial:' || uid::text);
  exception when unique_violation then
    return jsonb_build_object('granted', false, 'reason', 'already_claimed');
  end;
  select coalesce(sum(delta),0)::int into v_new from public.call_credit_ledger where user_id = uid;
  return jsonb_build_object('granted', true, 'credits', 5, 'balance', v_new);
end$$;
revoke execute on function public.claim_trial_calls() from anon, public;
grant execute on function public.claim_trial_calls() to authenticated;

-- Expose can_claim_trial to the account UI so it knows whether to show the claim button.
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
      + coalesce((select sum(delta) from public.call_credit_ledger where user_id = auth.uid()), 0)::int,
    'can_claim_trial', (
       public.current_tier() in ('trial','essential')
       and not exists (select 1 from public.call_credit_ledger where user_id = auth.uid() and reason = 'trial_grant')
    )
  );
$$;
revoke execute on function public.call_balance() from anon, public;
grant execute on function public.call_balance() to authenticated;
