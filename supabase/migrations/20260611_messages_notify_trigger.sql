-- W6: notify ops when a client writes in the account Messages tab (2026-06-11).
-- Fixes the launch-night audit finding: messages was WRITE-ONLY — users (and the
-- W5 [PRO APPLICATION] flow) inserted rows that no human or automation ever read,
-- while the UI promised "we'll reply within 1 business day".
--
-- Design: AFTER INSERT trigger (sender='user' only) fires net.http_post to the
-- n8n W6 webhook (workflow 2USsHXveBY166yTP), which emails ops. Push, not poll:
-- n8n executions = messages sent (~0 quota vs ~4.3k/mo for a 10-min cron).
-- pg_net is async — the insert never waits on n8n; failures never block the user.
--
-- SECRETS REDACTED in this committed copy (repo rule: webhook paths/secrets never
-- in git). The applied version (via MCP, same date) carries the real path+secret;
-- they live in the live trigger function and the n8n IF node only.
--
-- ROLLBACK:
--   drop trigger if exists trg_messages_notify on public.messages;
--   drop function if exists public.notify_new_user_message();

create extension if not exists pg_net;

create or replace function public.notify_new_user_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
begin
  if new.sender = 'user' then
    select email into v_email from auth.users where id = new.user_id;
    perform net.http_post(
      url := 'https://llavai.app.n8n.cloud/webhook/<W6-PATH>?secret=<W6-SECRET>',
      body := jsonb_build_object(
        'id', new.id,
        'user_id', new.user_id,
        'user_email', coalesce(v_email, 'unknown'),
        'message', left(new.body, 2000),
        'created_at', new.created_at),
      headers := '{"Content-Type":"application/json"}'::jsonb
    );
  end if;
  return new;
exception when others then
  return new; -- notification failure must never block the client's message
end$$;

create trigger trg_messages_notify
  after insert on public.messages
  for each row execute function public.notify_new_user_message();

-- Same pattern for document uploads (audit: documents table had zero consumers
-- and no notification — "Julia has your paperwork ready" had no implementation
-- and nobody learned an upload happened). Reuses the same W6 webhook/email.
create or replace function public.notify_new_document()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
begin
  select email into v_email from auth.users where id = new.user_id;
  perform net.http_post(
    url := 'https://llavai.app.n8n.cloud/webhook/<W6-PATH>?secret=<W6-SECRET>',
    body := jsonb_build_object(
      'id', new.id,
      'user_id', new.user_id,
      'user_email', coalesce(v_email, 'unknown'),
      'message', '[DOCUMENT UPLOADED] ' || coalesce(new.doc_type, 'document') || ' — ' || coalesce(new.file_name, ''),
      'created_at', new.uploaded_at),  -- documents uses uploaded_at, not created_at
    headers := '{"Content-Type":"application/json"}'::jsonb
  );
  return new;
exception when others then
  return new;
end$$;

create trigger trg_documents_notify
  after insert on public.documents
  for each row execute function public.notify_new_document();
-- ROLLBACK (documents): drop trigger trg_documents_notify on public.documents;
--                       drop function public.notify_new_document();
