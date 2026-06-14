-- W8.02 — normalise legacy 'spot' plan + make current_tier() an explicit allowlist + safe allowance default
-- (2026-06-14 audit). Low-risk; only affects the 1 legacy 'spot' row (owner test acct) + NEW inserts.

-- 1. Normalise the legacy plan='spot' active subscription (owner test account) to 'essential'
--    so tier resolution stays stable once the function below stops treating "any active sub" as Essential.
update public.subscriptions set plan = 'essential' where plan = 'spot';

-- 2. current_tier(): Essential branch becomes an explicit allowlist (plan='essential') instead of
--    "any active subscription". Pro is matched first; unknown/legacy active plans now resolve to 'free'
--    rather than silently granting Essential. Behaviour for real essential/trial/pro rows is unchanged.
create or replace function public.current_tier()
returns text
language sql
stable security definer
set search_path to 'public'
as $function$
  select case
    when exists (select 1 from public.subscriptions where user_id=auth.uid() and plan='pro'
                 and (status in ('active','trialing') or (status='past_due' and updated_at > now() - interval '7 days'))
                 and (current_period_end is null or current_period_end>now())) then 'pro'
    when exists (select 1 from public.subscriptions where user_id=auth.uid() and plan='essential'
                 and (status='active' or (status='past_due' and updated_at > now() - interval '7 days'))
                 and (current_period_end is null or current_period_end>now())) then 'essential'
    when exists (select 1 from public.subscriptions where user_id=auth.uid() and plan='essential'
                 and status='trialing' and (current_period_end is null or current_period_end>now())) then 'trial'
    else 'free'
  end;
$function$;

-- 3. call_allowance default 300 -> 0. Pro activations set 60 via trigger; Essential calls are credit-gated.
--    Default 0 removes the "latent over-grant" landmine if any path inserts a row bypassing the trigger.
alter table public.subscriptions alter column call_allowance set default 0;

-- ── UNDO ─────────────────────────────────────────────────────────────────────
-- (current_tier old body restored from the audit transcript; the spot row was a test acct)
-- alter table public.subscriptions alter column call_allowance set default 300;
