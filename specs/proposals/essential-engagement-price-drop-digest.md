# The mid-search engagement loop — price drops + "your week on the market" digest

Status: PROPOSAL (2026-06-11). Feature implied by columns that already exist
(`listings.price_drop`, `fine_print`, `profiles.scoring_prefs`) but surfaced nowhere.

## Problem

Essential's churn risk isn't only at success — it's in the *trough of week 2–3*,
when the user has dismissed 30 listings, lost 2 viewings, and starts wondering what
the €19 is doing between feed checks. The product already computes things between
sessions (scores, price drops, fine-print extraction) but never *tells* the user, so
the perceived value equals "how often I remember to open the app." Subscriptions
survive on perceived ongoing work; right now all of Llavai's ongoing work is silent.

The schema is ahead of the surface: Phase 0 added `price_drop` and `fine_print` to
`listings` and `scoring_prefs` to `profiles` — all populated by the pipeline, none
driving any notification or recurring touchpoint.

## Target user

Active Essential/Trial subscribers mid-search (and Pro, who get it as further proof
of the concierge working — pairs with ROADMAP item 9, "surface Julia's work").

## Proposal

### 1. Price-drop alerts on listings the user has already seen
When `price_drop` fires on a listing the user previously viewed or dismissed
*for price-adjacent reasons*, notify: "The 2-bed on Carrer X you passed on dropped
€120 → now €1,280 (€15/m²)." A price drop on a known listing is the single
highest-intent re-engagement trigger in property: it converts a past 'no' into a
fresh 'maybe' with zero new inventory. Implementation respects the dismissal
contract: notify, but do **not** resurrect the listing's status (the audit's R3
lesson — the Spot sync forcing dismissed listings back to 'new' is the anti-pattern;
this proposal is the correct version of the same instinct).

### 2. Weekly "Your week on the market" digest (one email, Sunday evening)
Built entirely from data already in Supabase, per user:
- N new listings matched your search; M scored ≥60; the best you haven't opened.
- Median €/m² for your search this week vs last (from `property_cache`).
- Speed proof: "the fastest match was gone in ~X hours" — quietly re-sells the
  product's core thesis every week.
- For Pro: calls Julia made, outcomes, minutes used (doubles as the allowance
  transparency from `pro-call-economics-and-allowance.md`).
Sunday evening is when next week's viewing plans are made; it's also the lowest
listing-volume moment, so the digest fills the natural weekend dead zone that the
trial proposal identified.

### 3. Fine-print surfacing in the feed card (small UI, big trust)
`fine_print` already extracts deposit months, fees, IBI/community inclusion,
Gran Tenedor, rent-control applicability — deterministic regex, zero LLM cost.
Render the two most decision-relevant flags on the card ("2 months deposit ·
agency fee" / "rent-controlled zone"). This is the "facts laid out clearly — not
buried like Idealista" homepage promise, literally implemented from a column that
exists and is shown nowhere.

## Value (why it retains)

- Makes the subscription's invisible work visible weekly — the strongest known
  antidote to "what am I paying for" churn in monitoring products.
- Price-drop alerts create wins from *old* inventory, increasing the number of
  "Llavai found me something" moments per month without any new scraping.
- The digest is also a forwarding surface (market stats get screenshotted into the
  flat-hunt group chat — see the growth proposal's screenshot thesis).

## Effort

**S–M total.** Digest: one n8n cron + one SQL view + one trilingual email template
(M for the template care). Price-drop notify: the pipeline already computes
`price_drop` on upsert; add a notification branch (S). Fine-print chips: feed-card
UI only (S). No schema changes. Sequence after the NOW roadmap items; the digest
shares its email plumbing with the trial day-5 recap and the retention emails —
build the little email layer once, feed it three proposals.

## Risks

- Email fatigue: hard rule of one weekly digest + only *high-delta* price-drop
  alerts (e.g. ≥5% or ≥€50), all on one unsubscribe preference.
- GDPR/consent for non-transactional email: fold into the same GDPR-pack review as
  everything else; digest to subscribers about their own search is service email,
  but let the professional draw the line.
- Accuracy: a wrong fine-print flag ("no agency fee" that turns out false) burns
  trust — chips should link to/quote the matched source text, and the regex rules
  stay conservative (show nothing over showing wrong).

## How to measure success

- Digest open + click-through rate; week-over-week retention of digest-receivers vs
  holdout (easy at small scale: enable for half the base for a month).
- Price-drop alert → listing reopened → contact/viewing rate.
- Churn rate in weeks 2–4 of subscription before vs after launch (the trough this
  exists to flatten).
- Support/cancel-survey mentions of "wasn't seeing value between sessions" trending
  to zero.
