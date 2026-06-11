-- W7: (1) expose available_calls to W1's call gate (it already calls get_call_client);
--     (2) decrement a credit when an attempt is actually marked 'calling'.

-- (1) add available_calls = (Pro monthly allowance if Pro) + persistent pack/trial credits
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
      'available_calls', (
        (case when exists(
            select 1 from public.subscriptions s
            where s.user_id = p.id and s.plan = 'pro' and s.status in ('active','trialing')
              and (s.current_period_end is null or s.current_period_end > now()))
          then coalesce((select s2.call_allowance from public.subscriptions s2 where s2.user_id = p.id), 0)
          else 0 end)
        + coalesce((select sum(l.delta) from public.call_credit_ledger l where l.user_id = p.id), 0)::int
      ),
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

-- (2) consume a call credit the moment an attempt is actually placed (status -> 'calling').
-- consume_call is idempotent per (user, property), so re-marking can't double-charge.
-- Dormant until W1 goes live (only W1 sets call_attempts.status='calling').
create or replace function public.consume_on_calling()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.status = 'calling' and (TG_OP = 'INSERT' or OLD.status is distinct from 'calling') then
    perform public.consume_call(NEW.user_id, NEW.property_id);
  end if;
  return NEW;
end$$;
revoke execute on function public.consume_on_calling() from public, anon, authenticated;

drop trigger if exists trg_consume_on_calling on public.call_attempts;
create trigger trg_consume_on_calling
  after insert or update on public.call_attempts
  for each row execute function public.consume_on_calling();
