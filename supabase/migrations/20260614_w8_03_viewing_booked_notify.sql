-- W8.03 — in-app client notification when Julia books a viewing (2026-06-14 audit, C3 partial)
-- Inserts a sender='team' message (surfaces in the account Messages tab) when a viewing flips to
-- 'booked' via Julia. In-app only — no email, so no marketing consent required. Server-side trigger
-- (SECURITY DEFINER) because the messages RLS WITH CHECK forbids the browser inserting sender<>'user'.

create or replace function public.notify_viewing_booked()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if new.status = 'booked'
     and new.status is distinct from old.status
     and coalesce(new.source,'') = 'julia' then
    insert into public.messages (user_id, sender, body)
    values (
      new.user_id,
      'team',
      'Julia booked you a viewing'
        || coalesce(' — ' || nullif(new.address, ''), coalesce(' in ' || nullif(new.neighbourhood, ''), ''))
        || coalesce(' on ' || to_char(new.viewing_at at time zone 'Europe/Madrid', 'FMDay DD Mon at HH24:MI'), '')
        || '. Open the Viewings tab for the full details.'
    );
  end if;
  return new;
end
$function$;

drop trigger if exists trg_notify_viewing_booked on public.viewings;
create trigger trg_notify_viewing_booked
  after update on public.viewings
  for each row execute function public.notify_viewing_booked();

-- Trigger fn must not be RPC-exposed (auto-granted EXECUTE to anon/authenticated otherwise).
revoke execute on function public.notify_viewing_booked() from anon;
revoke execute on function public.notify_viewing_booked() from authenticated;
revoke execute on function public.notify_viewing_booked() from public;

-- ── UNDO ─────────────────────────────────────────────────────────────────────
-- drop trigger if exists trg_notify_viewing_booked on public.viewings;
-- drop function if exists public.notify_viewing_booked();
