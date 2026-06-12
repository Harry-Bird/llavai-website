-- W7 "Essential flip" (owner 2026-06-12): make paying-Essential-with-credit eligible for
-- Julia calls, not just Pro. W1's "Process & Decide" gate is `if (!client.is_pro) skip`,
-- and get_call_client.is_pro is consumed ONLY by that gate (service-role fn, W1-only). So
-- we redefine that field to mean **"Julia MAY CALL this client"** — no edit to the 13.6KB
-- call node needed. TRUE tier is still in `tier`; true Pro = tier='pro'.
--   julia_may_call = (active Pro OR active Essential) AND available_calls > 0.
--   Trial (status 'trialing') and free are excluded → trial never gets Julia even with credit.
--   Note: this also enforces Pro's ~60/mo allowance (then packs) via available_calls.
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
      -- "Julia MAY CALL" gate (W1 reads this as is_pro). NOT the same as true Pro status.
      'is_pro', (
        (
          exists(select 1 from public.subscriptions s
            where s.user_id = p.id and s.plan = 'pro' and s.status in ('active','trialing')
              and (s.current_period_end is null or s.current_period_end > now()))
          or
          exists(select 1 from public.subscriptions s
            where s.user_id = p.id and s.status = 'active'
              and (s.current_period_end is null or s.current_period_end > now()))
        )
        and (
          (case when exists(select 1 from public.subscriptions s
                  where s.user_id = p.id and s.plan = 'pro' and s.status in ('active','trialing')
                    and (s.current_period_end is null or s.current_period_end > now()))
             then coalesce((select s2.call_allowance from public.subscriptions s2 where s2.user_id = p.id), 0)
             else 0 end)
          + coalesce((select sum(l.delta) from public.call_credit_ledger l where l.user_id = p.id), 0)::int
        ) > 0
      ),
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
