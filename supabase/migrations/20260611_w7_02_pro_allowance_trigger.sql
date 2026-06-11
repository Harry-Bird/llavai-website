-- W7: keep Pro monthly call allowance in sync entirely DB-side, so the Stripe
-- sync (which already upserts plan + current_period_end) drives it with no n8n
-- reset logic and no over-grant race.
--   * Pro activation (insert as pro, or plan flips to pro)  -> set 60
--   * New billing period (current_period_end advances)      -> reset to 60
--   * consume_call decrement (period unchanged)             -> left untouched
create or replace function public.set_pro_call_allowance()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.plan = 'pro' then
    if TG_OP = 'INSERT' then
      if NEW.call_allowance is null then
        NEW.call_allowance := 60;
      end if;
    elsif TG_OP = 'UPDATE' then
      if (OLD.plan is distinct from 'pro')
         or (NEW.call_allowance is null)
         or (NEW.current_period_end is distinct from OLD.current_period_end) then
        NEW.call_allowance := 60;
      end if;
    end if;
  end if;
  return NEW;
end$$;
revoke execute on function public.set_pro_call_allowance() from public, anon, authenticated;

drop trigger if exists trg_set_pro_call_allowance on public.subscriptions;
create trigger trg_set_pro_call_allowance
  before insert or update on public.subscriptions
  for each row execute function public.set_pro_call_allowance();
