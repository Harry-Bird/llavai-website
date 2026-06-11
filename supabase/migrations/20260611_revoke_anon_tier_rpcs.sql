-- APPLIED 2026-06-11 (launch night, Harry approved live).
--
-- Why (audit R8): current_tier(), is_pro() and has_active_subscription() are
-- SECURITY DEFINER and currently executable by PUBLIC and anon as well as
-- authenticated (live proacl: {=X, anon=X, authenticated=X, service_role=X}).
-- They key off auth.uid(), which is NULL for anon, so today an anon caller
-- only ever gets 'free'/false back — but there is no reason to expose
-- definer-rights functions to unauthenticated callers at all, and any future
-- edit that adds a parameter or relaxes the uid dependence would silently
-- become anon-reachable. Principle of least privilege: only signed-in
-- browsers (and the service role) need these.
--
-- Site impact: none. account.html / app.html only call these RPCs after a
-- session exists (authenticated role). Verified no anon-context callers in
-- the repo.

revoke execute on function public.current_tier() from public, anon;
revoke execute on function public.is_pro() from public, anon;
revoke execute on function public.has_active_subscription() from public, anon;

-- keep (re-assert) the grants the site actually uses
grant execute on function public.current_tier() to authenticated, service_role;
grant execute on function public.is_pro() to authenticated, service_role;
grant execute on function public.has_active_subscription() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Rollback:
-- grant execute on function public.current_tier() to public, anon;
-- grant execute on function public.is_pro() to public, anon;
-- grant execute on function public.has_active_subscription() to public, anon;
-- ---------------------------------------------------------------------------
