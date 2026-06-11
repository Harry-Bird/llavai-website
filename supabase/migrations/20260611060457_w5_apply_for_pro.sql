-- W5 Pro application RPC (see specs/w5_pro_application_design.md). Additive.
-- Allowed transition: none/rejected -> applied (idempotent for applied/approved).
-- Approval itself is service-role-only (n8n W5b) — never settable from the browser.
-- Applied 2026-06-11 via MCP (version 20260611060457).

create or replace function public.apply_for_pro()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  cur text;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  select pro_status into cur from profiles where id = uid;
  if cur is null then
    raise exception 'profile not found';
  end if;
  if cur in ('applied','approved') then
    return cur; -- idempotent: re-applying changes nothing
  end if;
  update profiles set intended_plan = 'pro', pro_status = 'applied' where id = uid;
  insert into messages (user_id, sender, body)
    values (uid, 'user', '[PRO APPLICATION] Client applied for Pro from the account page.');
  return 'applied';
end$$;

comment on function public.apply_for_pro() is
  'W5: signed-in client applies for Pro. Sets intended_plan/pro_status and leaves a
   messages row for team triage. Approval is service-role only (n8n W5b).';

revoke execute on function public.apply_for_pro() from anon, public;
grant execute on function public.apply_for_pro() to authenticated;
