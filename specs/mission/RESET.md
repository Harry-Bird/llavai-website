# Mission reset guide — how to undo anything from this mission

This file is for Harry. Every checkpoint tag below marks a known-good state. If anything
looks wrong on the live site, you can roll back in one copy-paste command — no git
knowledge needed. Tags are never deleted, history is never rewritten.

## How to roll back (pick one)

**Option A — undo everything since a tag, safely (recommended):**
```
cd ~/llavai-website && git revert --no-edit <tag>..main && git push
```
This creates new commits that undo the changes (nothing is lost) and deploys the
rolled-back site automatically.

**Option B — inspect an old state without changing anything:**
```
cd ~/llavai-website && git checkout -b recovery <tag>
```
Look around, then `git checkout main` to come back.

## Tags

| Tag | What it represents | Rollback command |
|---|---|---|
| `pre-mission` | State before this mission touched anything (commit 2406434, 2026-06-11) | `git revert --no-edit pre-mission..main && git push` |
| `checkpoint/reliability-start` | Before reliability workstream (29d94fc — audit only at that point) | `git revert --no-edit checkpoint/reliability-start..main && git push` |
| `checkpoint/conversion-start` | Before the marketing/conversion edits (ed033cb) | `git revert --no-edit checkpoint/conversion-start..main && git push` |
| `checkpoint/webapp-start` | Before the signed-in web-app fixes (e6feb50) | `git revert --no-edit checkpoint/webapp-start..main && git push` |
| `checkpoint/reliability-done` | Reliability workstream complete (drafts built, runbook written) | reference point |
| `checkpoint/conversion-done` | Conversion + perf workstream complete | reference point |
| `checkpoint/webapp-done` | Web-app workstream complete | reference point |
| `checkpoint/mission-done` | Final mission state incl. LAUNCH-REPORT.md | `git revert --no-edit pre-mission..checkpoint/mission-done && git push` undoes the whole mission |

(Workstream tags `checkpoint/<name>-start` / `checkpoint/<name>-done` are added here as
each workstream begins/ends.)

## n8n rollback (workflows)
- Anything this mission builds in n8n is a **never-published draft** — drafts do not run
  in production, so there is nothing to roll back unless YOU publish one.
- If you published something and want it undone: open the workflow in n8n → version
  history → republish the previous version (or unpublish the workflow entirely).
- The exact previous-version IDs for anything touched are recorded per-item under
  NEEDS HARRY in `specs/mission/LOG.md`.

## Retell rollback (Julia)
- This mission only edits Retell **drafts**, never publishes. Live calls always use the
  published agent version, so production Julia is untouched.
- If a draft looks wrong: Retell dashboard → Julia Next Gen → discard draft / re-publish
  the current live version.

## Supabase rollback (database)
- Only **additive** migrations are applied (new tables/columns/RPCs/policies) — they
  cannot break existing data. Each one's exact undo SQL is recorded in LOG.md DECISIONS.
- Anything destructive was NOT applied; it lives in `supabase/proposed/` for your review.

## Stripe
- Read-only all mission. Nothing to roll back.
