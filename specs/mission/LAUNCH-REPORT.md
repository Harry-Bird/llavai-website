# Launch report — production-ready + launch-grade mission (2026-06-11)

One day, four parallel audits, then execution. Everything below is either LIVE
(verified by measurement before and after deploy) or a NEVER-PUBLISHED draft waiting
for your click. Nothing was published to n8n/Retell, nothing written to Stripe, no
client or agency was contacted, every change is reversible (see RESET.md).

## What changed, in plain English

### Reliability (the product keeps its promise)
- **Found the worst hidden bug: weekend Pro alerts silently died.** A call queued
  Friday evening expired Sunday (48h limit) before the Monday drain ever looked at it
  — no alert, and that property was blocked for that user forever. Fixed three ways:
  the new W1-GATED v2 draft stamps a 96h expiry on queue rows, the new Drain v2 draft
  emails you whenever anything expires AND frees the blocked slot, and a
  belt-and-braces DB default change sits in supabase/proposed/. **Goes live when you
  run cutover #1/#2 in the checklist below.**
- **The checkout webhook no longer accepts junk** (W4 v2 draft): bad emails, fake
  user ids and attacker-supplied redirect URLs get a 400 before Stripe is ever
  called. Also closes the open-redirect.
- **Anyone who guessed the inbox webhook path could forge alerts** (suppress a real
  client's alert via dedup, burn Apify money, make Julia dial). W1-GATED v2 adds a
  secret-header gate; CloudMailin sends the header after a 1-minute config step.
- **Pro call costs get a ceiling**: Drain v2 enforces subscriptions.call_allowance
  (currently NULL = unlimited, so nothing changes until you set values — economics
  proposal has recommended numbers).
- **The drain stops burning your n8n quota**: was ticking 24/7 (~4,300 executions/mo
  — more than a Starter plan allows in total); v2 runs only Mon–Fri 8–18 (~1,300).

### Conversion (the site sells what the product actually does)
- **Every "win the flat" claim is gone** in all three languages (6 places). Llavai
  books viewings; the copy now says exactly that. Julia is only promised where Pro is
  being sold.
- **The featured plan's button finally goes to signup** — it sent new visitors to the
  *sign-in* page, skipping lead capture entirely. Highest-intent click on the site.
- **The free trial is finally marketed**: hero, mobile sticky bar and the signup form
  now say "free 3-day trial · €19/mo after · cancel anytime" (it was hidden behind
  email capture, while the sticky bar said a contradictory "it's free").
- **The newest blog guide was invisible to Google** (canonical pointed through a
  double redirect) — fixed, sitemap fixed, and the blog hub now actually lists all 6
  guides (it showed 4). Guides interlink (related-guides block) instead of being
  dead ends.
- **Homepage speed**: the hero no longer hides its text for 1.6s (Lighthouse perf
  mobile was 84 with runs as low as 77; now 86–99 across runs, desktop 98, a11y 100,
  SEO 100). Demo images are WebP (-214KB); the listing deck holds still for an
  opening beat, which also reads better.

### Web app (paying users get a premium, trilingual product)
- **The paid feed spoke English to Spanish/Ukrainian users** — facts ("3 bed · 2
  bath"), feature chips, "/mo", "· agent", the dismiss button. All trilingual now,
  same for the teaser, documents tab (raw "bank_statement" → proper labels), and the
  profile review step ("Couple (2)" → "Pareja (2)").
- **Julia's work is now visible** (the Pro retention story): queued off-hours calls
  show in the pipeline as a QUEUED stamp with "Julia calls the moment offices open",
  and her post-call summaries (already stored, never shown) render under each viewing.
- A11y/polish: email-setup got proper keyboard tabs + focus rings + the wow-kit
  treatment it lacked; progress dots no longer clip on Z-Fold-width screens; tier
  cards joined the stacked-paper design language with a JULIA CALLS stamp.

## What remains 🔴 / important and why
1. **The three n8n cutovers are built but not live** — drafts can't take effect
   without your publish (by design: no-publish rule). Until cutover #2, weekend
   alerts still die silently. ~15 min total.
2. **W3 (Stripe→tier sync) has never fired in production** — unprovable without a
   real checkout (your action C8). The first real customer should not be the test.
3. **EU AI Act disclosure: statutory deadline 2 Aug 2026** (~7 weeks). Script is
   written (proposal #1) — needs your legal review, then a Retell draft.
4. **call_allowance is unlimited** until you choose numbers — a single heavy Pro
   user can run €185/mo to negative margin (economics proposal).
5. **Sheets stack still half-alive** (Profile Creation runs an old version; ops
   lead-emails ride on Sheets) — Phase 4 plan exists, needs a session.

## NEEDS HARRY — full ordered checklist
See **specs/mission/LOG.md §NEEDS HARRY** — 15 items in execution order, each with
verification steps and copy-paste rollback (n8n version ids recorded). Order: A1–A3
cutovers → B4–B7 quick clicks → C8–C9 verifications → D10–D15 business decisions.

## Proposals index (specs/proposals/ — nothing built, your call)
1. julia-ai-disclosure-art50.md — the legal must-do, framed as a brand asset
2. pro-call-economics-and-allowance.md — margin floor before the first Pro user
3. trial-design-time-to-first-win.md — 3→7 days + instant backfill
4. julia-on-demand-bridge-tier.md — metered calls between €19 and €185
5. growth-first-100-users.md — zero-budget acquisition motion
6. retention-after-the-keys.md — pause/referral/success-event lifecycle
7. essential-engagement-price-drop-digest.md — make the subscription visibly work
8. landing-hero-live-dossier.md — the strongest homepage move (build-ready sketch)
9. per-language-urls-hreflang.md — unlock ES/UK search visibility

## Paper trail
- **Decisions** (what was chosen, why, alternatives): LOG.md §DECISIONS (D0–D7).
- **Rollback**: RESET.md — every tag with its copy-paste command; n8n rollbacks are
  per-item in the NEEDS HARRY runbook.
- **Audit evidence**: specs/mission/AUDIT.md (all four areas, with healthy lists so
  the next session doesn't re-check).
- **Verification scripts** (rerunnable): /tmp/llavai-verify/mission-*.js, a1–a6
  (note: /tmp is volatile — they exist today, regenerate from LOG references if gone).
