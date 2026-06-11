-- APPLIED 2026-06-11 (launch night, Harry approved live).
-- dashboard SQL editor or ask Claude to apply after approval.
--
-- WHY: weekend Pro alerts die silently. call_queue.expires_at defaults to now()+48h,
-- but the drain (W1.5) only claims Mon-Fri 08:00-18:00 Madrid and expires stale rows
-- BEFORE claiming. A call queued Friday 18:00 expires Sunday 18:00 — before Monday's
-- first claim. 96h covers the longest legal wait (Fri 18:00 -> Mon 08:00 = 62h, or
-- Tue 08:00 = 86h if Monday were skipped).
--
-- NOTE: the W1-GATED-v2 draft also sets expires_at explicitly at insert time, which
-- fixes new rows once published. This default change is the belt-and-braces layer so
-- any future insert path is safe too.
--
-- UNDO:
--   alter table public.call_queue alter column expires_at set default (now() + interval '48 hours');

alter table public.call_queue
  alter column expires_at set default (now() + interval '96 hours');

comment on column public.call_queue.expires_at is
  'Queue entry is abandoned after this. Default 96h: must outlast the longest closed window (Fri 18:00 -> Mon 08:00 Madrid) so weekend alerts survive to the Monday drain (mission F1, 2026-06-11).';
