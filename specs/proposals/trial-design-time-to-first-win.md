# Trial design — 3 days is shorter than the Barcelona listing week

Status: PROPOSAL (2026-06-11). Analysis of the 3-day card-required trial + concrete changes.

## Problem

Two separate problems, one urgent and one structural:

1. **The advertised trial doesn't exist in production** (audit B1: the published W4
   checkout has no `trial_period_days`; account.html sells "Start with a 3-day free
   trial" and then charges €19 immediately). Until that's fixed, every trial-design
   question is moot and every checkout is a small breach of trust. Ship B1 first.
2. **3 days is shorter than the market's natural rhythm.** Listing volume in
   Barcelona is weekday-clustered, and the user's *aha* is not "I see listings" —
   it's "a listing matching MY narrow search appeared and I got there early."
   A user with a specific search (2-bed, Gràcia, ≤€1,400, pets) may legitimately see
   zero qualifying ≥60 listings in any given 72h window. A Friday-evening signup can
   burn the entire trial over a quiet weekend and get charged Monday having
   experienced nothing. The product is a *radar*; a radar trial must be long enough
   for a blip.

## What's right and should be kept

- **Card-required is correct.** The buyer is high-intent (actively homeless-in-30-days
  expats), the product has real per-user COGS once they forward alerts (scrapes), and
  card-up-front filters tourists. Opt-out (card-required) trials convert a far higher
  share of trial starts than opt-in trials in every published benchmark set; the cost
  is fewer starts, which the Free teaser tier already compensates for (the teaser IS
  the no-card trial).
- **Trial = Essential, never Pro** (the account.html rule). Keep — a Pro trial gives
  away the labour and invites allowance abuse.

## Proposal

1. **Extend 3 → 7 days** (one Stripe `trial_period_days` value; effort ≈ zero on top
   of the B1 fix). 7 days guarantees the trial spans a full weekday listing cycle
   regardless of signup day. Hold price at €19.
2. **Engineer the first session, not just the length.** On trial start, the feed must
   not be empty: trigger an immediate backfill for that user (W2 Feed Backfill exists
   and is single-responsibility precisely for this) so minute one shows real, scored,
   recent listings. An empty radar for the first 24h is the most likely silent
   trial-killer and no length fixes it.
3. **Day-5 "what Julia saw" email** (replaces the roadmap's day-2 trial-ending email
   under the 7-day plan): "In your first 5 days Llavai scored N listings for your
   search; M scored ≥60; the fastest went in X hours." This converts with the user's
   own data and doubles as the cancel-warning required for clean card-required UX
   (charge-surprise is the #1 trial complaint pattern; the email is both ethics and
   conversion).
4. **Don't build annual plans.** A flat search lasts weeks, not years; an annual
   plan either goes unsold or creates refund fights. (Couple/partner sharing is a
   growth lever, not a pricing SKU — see `growth-first-100-users.md`.) A *student
   September plan* could be revisited seasonally; no evidence yet, don't build.

## Exact numbers vs today

| | Today (advertised) | Today (live) | Proposed |
|---|---|---|---|
| Trial length | 3 days | **none — charges €19 instantly** | 7 days |
| Card required | yes | yes | yes (keep) |
| Trial of | Essential | n/a | Essential (keep) |
| Pre-charge notice | none | none | day-5 recap email |
| First-session feed | whenever cron next fills | same | immediate per-user backfill |

Cost of 7 vs 3 days: four more days of feed access (scrape costs pooled across all
users anyway — marginal COGS per extra trial day ≈ €0). Revenue timing shifts 4 days;
no price change.

## Target user / Value

The narrow-search expat who would have seen nothing in 72h. Value: trial→paid
conversion stops being a lottery on signup-day-of-week; users charged on day 7 have
actually seen the radar blip and know what they're paying for — which is also the
retention story (people cancel what they never experienced).

## Effort

**S.** One Stripe parameter (rides on the B1 publish that has to happen anyway), one
n8n trigger reuse for instant backfill, one templated email.

## Risks

- Longer trial = a few users find a flat *during* the free week and never pay. In
  Barcelona's market that's rare inside 7 days even with the radar — and that user
  becomes the best possible referral/testimonial (capture it: see retention proposal).
- 7-day card trials attract slightly more deliberate signups (good) but delay MRR
  recognition by 4 days (irrelevant at this stage).
- Whatever is chosen, **copy and Stripe must say the same number everywhere** —
  the current 3-day copy vs no-trial reality is the cautionary tale.

## How to measure success

- Trial start → paid conversion (target: card-required norm, directionally 40%+;
  measure your own baseline first — there isn't one yet because the trial never ran).
- % of trials that saw ≥1 listing scored ≥60 for *their* search before day 3 vs day 7
  (this validates or refutes the whole 7-day thesis with real data — instrument it).
- Day-5 email open → cancel rate (cancels triggered by the email are *good* churn:
  they were never going to convert happily).
- Refund/dispute rate post-charge (should drop to ~0 with the recap email).
