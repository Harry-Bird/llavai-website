-- PROPOSED — NOT YET APPLIED. Review, then apply via migration and move to ../migrations/.
--
-- Why: viewings_insert_own currently lets a signed-in user insert a viewing
-- row with ANY source value (e.g. source='julia'), letting them forge rows
-- that look team-/Julia-created in their own pipeline (cosmetic today, but it
-- also flips the self-managed delete affordance and could confuse n8n logic
-- that branches on source). User-created rows should always be source='self'.
--
-- Verified against the front end (2026-06-11): the ONLY user-side insert is
-- account.html addViewing() (line ~916), which sends an explicit
--   { ..., source:'self', status:'booked', ... }
-- row — so this check cannot break it. Inserts that omit source also pass,
-- because WITH CHECK evaluates the row AFTER the column default ('self') is
-- applied. Julia/team writes come through n8n with the service_role key,
-- which bypasses RLS entirely — unaffected.

drop policy "viewings_insert_own" on public.viewings;
create policy "viewings_insert_own" on public.viewings
  for insert with check (auth.uid() = user_id and source = 'self');

-- ---------------------------------------------------------------------------
-- Rollback:
-- drop policy "viewings_insert_own" on public.viewings;
-- create policy "viewings_insert_own" on public.viewings
--   for insert with check (auth.uid() = user_id);
-- ---------------------------------------------------------------------------
