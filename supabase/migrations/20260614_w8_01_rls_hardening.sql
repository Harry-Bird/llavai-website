-- W8.01 — RLS init-plan perf + trigger-fn RPC lockdown + missing indexes (2026-06-14 audit)
-- Behaviour-preserving. Safe/additive. Apply via Supabase SQL editor or apply_migration.

-- 1. Perf: wrap auth.uid() in a scalar subselect so it evaluates ONCE per query, not per row.
--    Resolves the auth_rls_initplan advisor across every user-facing table (matters at 100+ users).
alter policy availability_delete_own on public.availability using ((select auth.uid()) = user_id);
alter policy availability_insert_own on public.availability with check ((select auth.uid()) = user_id);
alter policy availability_select_own on public.availability using ((select auth.uid()) = user_id);
alter policy availability_update_own on public.availability using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy call_attempts_select_own on public.call_attempts using ((select auth.uid()) = user_id);
alter policy ccl_select_own on public.call_credit_ledger using ((select auth.uid()) = user_id);
alter policy documents_delete_own on public.documents using ((select auth.uid()) = user_id);
alter policy documents_insert_own on public.documents with check ((select auth.uid()) = user_id);
alter policy documents_select_own on public.documents using ((select auth.uid()) = user_id);
alter policy listings_select_own on public.listings using ((select auth.uid()) = user_id);
alter policy listings_update_own on public.listings using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy messages_insert_own on public.messages with check (((select auth.uid()) = user_id) and (sender = 'user'::text));
alter policy messages_select_own on public.messages using ((select auth.uid()) = user_id);
alter policy profiles_select_own on public.profiles using ((select auth.uid()) = id);
alter policy profiles_update_own on public.profiles using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
alter policy subscriptions_select_own on public.subscriptions using ((select auth.uid()) = user_id);
alter policy viewings_delete_own on public.viewings using ((select auth.uid()) = user_id);
alter policy viewings_insert_own on public.viewings with check (((select auth.uid()) = user_id) and (source = 'self'::text));
alter policy viewings_select_own on public.viewings using ((select auth.uid()) = user_id);
alter policy viewings_update_own on public.viewings using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- 2. Security: notify_new_document / notify_new_user_message are TRIGGER functions and must not be
--    invokable as PostgREST RPCs. Triggers run as the table owner regardless, so W6 is unaffected.
revoke execute on function public.notify_new_document() from anon;
revoke execute on function public.notify_new_document() from authenticated;
revoke execute on function public.notify_new_document() from public;
revoke execute on function public.notify_new_user_message() from anon;
revoke execute on function public.notify_new_user_message() from authenticated;
revoke execute on function public.notify_new_user_message() from public;

-- 3. Perf: cover the unindexed call_queue FK + the hot feed read.
create index if not exists call_queue_listing_id_idx on public.call_queue (listing_id);
create index if not exists listings_user_feed_idx on public.listings (user_id, appeal_score desc, created_at desc) where status <> 'dismissed';

-- ── UNDO ─────────────────────────────────────────────────────────────────────
-- alter policy ... using (auth.uid() = user_id) ...   -- (revert each policy to the bare form)
-- grant execute on function public.notify_new_document() to anon, authenticated;     -- (not recommended)
-- grant execute on function public.notify_new_user_message() to anon, authenticated; -- (not recommended)
-- drop index if exists public.call_queue_listing_id_idx;
-- drop index if exists public.listings_user_feed_idx;
