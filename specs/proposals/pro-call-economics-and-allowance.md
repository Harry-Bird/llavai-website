# Pro call economics — put a number on `call_allowance` before the first real Pro user

Status: PROPOSAL (2026-06-11). Analysis + recommended limits. No build, no config change.

## Problem

Pro is **€185/mo flat** with usage-based COGS (Retell minutes + Apify scrapes) and the
cap column — `subscriptions.call_allowance` — exists but is **enforced nowhere**
(audit/ROADMAP item 11 confirms: "call_allowance enforcement belongs in the drain's
re-verify step", not yet built). Today one Pro user with a broad Idealista saved
search defines your margin, and you've published no fair-use terms to fall back on
when you need to throttle them.

The asymmetry matters because the *user* controls volume: they configure the Idealista
saved-search that feeds W1. A search for "Barcelona, any size, ≤€2,000" can plausibly
forward 10–20 alerts/day in this market; W1 will scrape every one (paying-tier rule)
and call every one that passes ≥60 + gates.

## Unit costs (estimates — verify against your own consoles before locking numbers)

- **Retell**: published base $0.07/min voice engine; realistic all-in (LLM + voice +
  telephony) **$0.13–$0.31/min** per Retell's own 2026 cost breakdown. Call ~€-equiv
  **€0.12–€0.29/min**. A typical agent call (greeting → pitch → availability →
  book/decline) ≈ 2–4 min → **≈ €0.40–€0.90 per connected call** (mid-case ~€0.60).
  No-answers cost near zero minutes but still burn a dial attempt.
- **Apify**: per-listing scrape cost is small but non-zero and *already mitigated* by
  `property_cache` (24h TTL). Action: read the actual €/scrape from the Apify console
  and write it next to these numbers — do not let it stay folklore. (Not invented
  here deliberately.)
- Fixed per-user costs: ~€0 (Supabase/n8n are pooled plan costs).

## Scenarios at €185/mo (mid-case €0.60/connected call, ~3 min)

| Pro user profile | Calls/mo | Call COGS | Gross margin |
|---|---|---|---|
| Focused search (2 calls/day eligible) | ~60 | ~€36 | **~80%** |
| Active search (5/day) | ~150 | ~€90 | ~51% |
| Broad search, worst case (10/day) | ~300 | ~€180 | **~3%** |
| Same worst case at Retell's top rate (€0.90) | ~300 | ~€270 | **negative** |

The product is healthy in the median and unbounded in the tail. Classic flat-rate +
metered-COGS shape; the fix is a cap, not a price change.

## Proposal — exact numbers

1. **Set `call_allowance` = 150 minutes/month** (≈ 50 connected calls at ~3 min).
   Worst case COGS at the cap: 150 min × €0.29 ≈ **€44** → minimum ~76% gross margin.
   A genuine flat-hunter rarely needs >50 *agent conversations* a month; if they do,
   their saved search is misconfigured, which is a concierge-quality conversation,
   not a billing one.
2. **Daily soft cap: 10 calls/day** (already implied by ROADMAP item 11) — protects
   against a runaway saved-search burst and spreads Julia across business hours.
3. **Decrement on connected minutes only** (W2 already records `duration_minutes`) —
   no-answers and `callback_later` retries don't consume the allowance.
4. **At 80% of allowance**: dashboard notice + email — "Julia has used 120 of your
   150 concierge minutes this month; reply if your search needs tuning." At 100%:
   queue instead of call, notify, offer (a) search-narrowing help or (b) a top-up
   (same €3/call mechanics as `julia-on-demand-bridge-tier.md`).
5. **Publish it as a feature, not small print**: "Up to 150 concierge minutes a
   month — more than any human relocation agent will give you for €185." (Human
   Barcelona flat-finder services charge one-off fees typically in the high hundreds
   to thousands of euros; verify a current quote before using a specific figure in copy.)

## Target user / Value

Pro users get a *defined* service level (today the implicit promise is infinite,
which you can't keep); Harry gets a margin floor (~76%) and a script for the awkward
throttling conversation before it ever happens. Investors/your own planning get a
real per-user contribution number.

## Effort

**S–M.** The enforcement point is already designed (drain re-verify step,
`business_hours_call_queue_design.md` §"call_allowance enforcement"); the column
exists; W2 already writes `duration_minutes`. Remaining: the sum-per-period check,
two notification emails, and pricing-page copy. The copy change is one line.

## Risks

- A cap announced *after* someone hits it feels like a bait-and-switch — publish the
  number before the first Pro user is approved (W5 is not yet live: this is the last
  free moment to do it).
- Too-low a cap undercuts the concierge story; 150 min is deliberately generous vs
  the median (~60 calls/mo scenario uses ~120 min less than the cap).
- Don't meter *scrapes* user-visibly — feed completeness is the Essential promise;
  only concierge minutes are metered.

## How to measure success

- Distribution of actual connected minutes per Pro user per month (expect p50 well
  under 100; watch p95).
- % of Pro users who ever see the 80% warning (target <10% — if higher, raise the cap
  or fix search-tuning onboarding).
- Gross margin per Pro user, monthly, from real Retell invoices vs this model —
  replace the estimate column with actuals after month 1.
