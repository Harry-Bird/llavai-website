---
name: overnight-backend-audit
description: Overnight autonomous run — fullstack-guardian audit of the Llavai frontend + backend, fix verified breaks, continue building the backend, and produce a product roadmap for morning review.
---

# Overnight: Audit → Fix → Build → Roadmap

You are running unattended overnight. Harry will review your work in the morning.
Work continuously through the phases below; do not stop after the audit.

<CRITICAL_CONSTRAINTS>
1. **Every push to `main` deploys live immediately.** Commit only changes verified by
   running/measuring (headless Chrome pattern in CLAUDE.md), never by eyeballing.
2. **NO OUTBOUND CONTACT, NOTHING GOES LIVE, EVERYTHING REVERSIBLE.**
   No client or estate agency may be contacted tonight — Retell must not fire.
   - **Build freely as drafts:** create/update n8n workflows (`update_workflow` saves a
     draft) and edit Retell agent drafts. But NEVER `publish_workflow`, never publish a
     Retell agent version, and never call any Retell call-creation endpoint.
   - **Never execute/test any workflow** whose path could place a call, send an email/SMS/
     WhatsApp, or write to systems an agent or client sees. Test with pinned/mock data only.
   - **Stripe: read-only.** No product/price/coupon/subscription changes.
   - **Supabase: additive migrations only** (new tables/columns/RPCs/policies via migration
     files + MCP). No DROP/DELETE/UPDATE of existing data. Anything destructive or
     irreversible → write up under `NEEDS HARRY` instead of doing it.
   - For every built-but-unpublished piece, log exact go-live steps (what to publish,
     in what order, how to roll back) under `NEEDS HARRY`.
3. **Never commit secrets.** Any new internal file/dir must be added to `.vercelignore`
   (the repo root is served publicly as-is). `specs/` is already ignored — keep overnight
   artifacts there.
4. **Durable state lives in files, not conversation.** Context may be compacted at any
   time. After every completed item, update `specs/overnight/LOG.md`. If you ever feel
   "lost", re-read LOG.md and the audit file and resume from QUEUED.
</CRITICAL_CONSTRAINTS>

## Phase 0 — Orient
- Invoke the `fullstack-dev-skills:fullstack-guardian` skill (Skill tool) now and apply
  its discipline for the entire session.
- Read: `specs/backend_rebuild_architecture.md`, `specs/backend_architecture_design.md`,
  `specs/w2_retell_post_call_design.md`, `supabase/schema.sql`,
  `supabase/migration-supabase-first.sql`.
- Create `specs/overnight/LOG.md` with sections:
  `STATUS` (1 short paragraph, always current — this is what Harry reads first),
  `DONE`, `IN PROGRESS`, `QUEUED`, `NEEDS HARRY`.

## Phase 1 — Deep audit (fan out, isolated contexts)
Spawn one subagent per area (parallel where independent); each returns structured
findings only, not raw dumps:

1. **Frontend pages** — index, get-started, login, profile, account, app, blog, 404:
   console/page errors, broken links/handlers, `data-lang` trilingual gaps, mobile
   overflow (mobile UA + `isMobile:true`, widths incl. 344px — per CLAUDE.md).
2. **Supabase vs frontend reality** — every table/RPC the pages actually call
   (e.g. `current_tier()`) vs what exists in schema; RLS coverage per table; run
   Supabase MCP `get_advisors` (security + performance) and `get_logs` for recent errors.
3. **n8n automation layer** — list workflows on `llavai.app.n8n.cloud`; for the documented
   flows (Idealista alerts → feed, Retell post-call, Stripe sync): published-vs-draft
   drift, missing error handling, recent failed executions. Read-only.
4. **Stripe ↔ tiers** — products/prices vs the tier logic in account.html
   ('free'|'trial'|'essential'|'pro'). Read-only.
5. **Spec vs built** — everything designed in `specs/*.md` that has no working
   implementation = the "missing backend pieces" list.

Before recording any finding as BROKEN, re-verify it yourself (one re-check kills
hallucinated findings). Then write `specs/overnight/AUDIT_<date>.md` grouped as:
**❌ Broken** / **🕳 Missing** / **⚠️ Risky** — each with evidence (`file:line`,
workflow/execution id, or SQL) and a suggested fix. Seed `QUEUED` in LOG.md from it,
ordered by user impact.

## Phase 2 — Fix verified breaks
Smallest/safest first. For each: fix → verify by measurement → commit (repo commit
conventions in CLAUDE.md) → log in DONE.

## Phase 3 — Continue building the backend
**Owner-requested, pre-seed at top of QUEUED:**
- **Business-hours call gate + queue** — Julia must only place calls Mon–Fri 08:00–18:00
  Europe/Madrid. Any call trigger outside that window (e.g. an Idealista alert at night)
  must NOT call: enqueue it instead (Supabase table, e.g. `call_queue`: payload, listing
  ref, client ref, created_at, scheduled_for, status) and have a scheduled n8n flow drain
  the queue in FIFO order at the next business-hours opening. The gate check belongs at
  the entry of every call-placing path so no future flow can bypass it. Build the n8n
  parts as drafts only (per constraints); SQL migration is additive so it can ship tonight.

Then work the rest of QUEUED (missing pieces + open spec tasks). For each item:
implement → verify → commit → update LOG.md before starting the next. SQL as migration
files in `supabase/` and applied via Supabase MCP (additive only — see constraints).
n8n/Retell work: build it fully as a draft, validate with mock/pinned data, then log
exact publish + rollback steps under NEEDS HARRY and move on. Nothing goes live tonight.

## Phase 4 — Product roadmap
Write `specs/overnight/ROADMAP.md`: **Now / Next / Later**. Every item must cite
evidence from tonight's audit or the specs (the user problem it solves, effort guess,
dependencies). No generic SaaS filler — ground it in what you actually saw.

Then return to Phase 3 and keep working QUEUED until empty, refreshing STATUS each cycle.

<KEY_REMINDERS>
Re-read before every commit:
- Verified by running/measuring, not eyeballing?
- New files public on deploy? → `.vercelignore`.
- Frontend touched? → trilingual `data-lang` + "wow kit" design vocabulary intact.
- **No outbound contact tonight**: no n8n publish, no Retell publish or call creation,
  no workflow executions with real side-effects, no Stripe writes, no destructive SQL.
  Drafts only; go-live steps → NEEDS HARRY.
- `specs/overnight/LOG.md` updated — STATUS must read true right now.
Morning handoff = LOG.md STATUS + AUDIT + ROADMAP.
</KEY_REMINDERS>
