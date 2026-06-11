-- APPLIED 2026-06-11 (launch night, Harry approved live).
--
-- Why: viewings.listing_id is a foreign key to listings(id) with
-- ON DELETE SET NULL, but it has no index. Every listings delete (and any
-- join/lookup from a listing to its viewings) therefore sequential-scans
-- viewings. Row counts are tiny today, so this is purely preventative — but
-- unindexed FK columns are the classic "fine until it isn't" footgun once the
-- pipeline starts writing at volume.
--
-- Partial index: listing_id is NULL for self-added viewings, so exclude those
-- rows to keep the index minimal.

create index if not exists viewings_listing_idx
  on public.viewings(listing_id) where listing_id is not null;

-- ---------------------------------------------------------------------------
-- Rollback:
-- drop index if exists public.viewings_listing_idx;
-- ---------------------------------------------------------------------------
