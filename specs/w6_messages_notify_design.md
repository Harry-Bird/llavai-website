# W6 — Messages → ops notification (design, 2026-06-11)

## Problem (found by Harry, launch night)
The account Messages tab and the W5 Pro-application flow both insert into
`public.messages` — and **nothing reads it**. 7 user messages (2026-06-08 → 11)
sat unread, incl. one `[PRO APPLICATION]`. UI promises "we'll reply within
1 business day". All 7 turned out to be Harry's own test accounts — no real
customer harmed, but the funnel's highest-intent surface was a black hole.

## Three perspectives

**[Backend]** Postgres `AFTER INSERT` trigger on `public.messages`
(`new.sender='user'` only) → `net.http_post` (pg_net, async) → n8n W6 webhook
→ SMTP email to harry.bird@llavai.com with the message, sender email, and
copy-paste reply instructions (insert `sender='team'` row via Supabase editor;
the account page polls and renders team rows).
- Push, not poll: n8n executions = messages sent (~0 quota). The 10-min-cron
  alternative would cost ~4.3k executions/mo — more than the whole Starter plan.
- pg_net is async and the trigger body is wrapped in `exception when others
  then return new` — a notification failure can never block or slow a client's
  message insert.

**[Frontend]** No change needed. account.html already inserts + renders both
senders and polls for team replies while the tab is open.

**[Security]**
- Webhook path is random (`messages-notify-c7e1b9d4`) AND gated by a
  `?secret=` check in the n8n IF node — forged POSTs get HTTP 200 (onReceived)
  but reach nothing; no email-spam vector.
- Secret + path live ONLY in the live DB trigger and the n8n IF node; the
  committed migration copy is redacted (repo rule).
- Message body truncated to 2000 chars in the payload; body lands in email —
  treat as untrusted text (plain-text email, no HTML injection surface).
- Trigger function is SECURITY DEFINER (needs auth.users read for the email);
  not callable directly — only fires via insert, which RLS already restricts
  to `auth.uid() = user_id AND sender='user'`.

## Pieces
| Piece | ID / file | State |
|---|---|---|
| n8n W6 workflow | `2USsHXveBY166yTP` | DRAFT — needs publish (Harry authorization) |
| DB trigger migration | `supabase/migrations/20260611_messages_notify_trigger.sql` (redacted copy) | NOT APPLIED — needs Harry authorization |
| Backlog | 7 unread messages | all Harry's test accounts — no action |

## Go-live order
1. Publish W6 → 2. Apply trigger migration → 3. End-to-end test: send a message
from the account page → email arrives. ROLLBACK: drop trigger + function,
unpublish W6.
