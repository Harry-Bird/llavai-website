# Retention after the keys — designing for a product that succeeds itself out of revenue

Status: PROPOSAL (2026-06-11). Lifecycle design; no build implied yet.

## Problem

Llavai's success event — client signs a lease — is also its cancellation event. Every
happy customer churns; only the unlucky retain. Left alone this caps LTV at roughly
(search duration × price): maybe 1–3 months of Essential (€19–€57) or 1–2 months of
Pro (€185–€370). The instinct to fight churn here is wrong; the right move is to
**harvest the success moment** (referral + proof), **park the relationship** (pause,
not cancel), and **own the calendar of Spanish tenancy** (predictable re-activation
triggers that the data model already half-supports).

## Target user

Every subscriber at the moment `viewings` → a signed flat (today this moment isn't
even captured — see proposal 1), plus every cancelled/paused account 10–11 months
later when renewal season hits.

## Proposals (in priority order)

### 1. Capture the win: an "I got the flat!" event
There is currently no signal for success — users just cancel. Add a one-tap
"I signed for this one" on a viewing/listing (a `viewings.status`/profile flag —
schema barely changes). Everything below hangs off this event. It also produces the
single most valuable marketing asset a pre-revenue product can have: a count —
"N flats won through Llavai" — and the testimonial ask at peak gratitude.

### 2. Pause, don't cancel (Stripe `pause_collection`)
On cancel intent, offer: "Pause for up to 6 months — your tenant dossier, documents,
scoring preferences and viewing history stay exactly as you left them." For a mover
population (expats re-move often; temporary contracts, seasonal rentals, flatmate
changes) the *profile* is the asset: rebuilding the dossier is the pain they'll pay
to skip. A paused account at €0 with a stored card and a warm profile is worth far
more than a deleted one. Stripe's portal (already roadmap item 12) supports this
natively — it's configuration plus copy, not engineering.

### 3. Referral at the success moment, denominated in the product
The ask fires on the "I got the flat" event, when goodwill peaks and — crucially —
when the user is *inside* the most flat-desperate social graph in the city (their
also-searching friends, the people they told about every viewing). Offer shape:
**"Give a friend their first month of Essential free; when you come back for your
next move, your first month is free too."** Both sides denominated in product, zero
cash out, and the give-side reward (future free month) is itself a re-activation
hook. No referral engine needed at this scale: a personal code in the success email
and a Stripe coupon is enough for the first 100 users.

### 4. The tenancy calendar: scheduled re-activation, not services
Spanish tenancies create predictable future moments: renewal/notice windows, deposit
(fianza) return at exit, the next move. At the success event, ask one question —
"when does your contract start?" — and schedule two emails:
- **Month 10–11**: "Renewal season — know your options; if you're moving, your
  Llavai profile is ready. Unpause in one click."
- **At exit / move date**: deposit-return guide (the fianza blog post already exists)
  + reactivation.
This is a cron and two templates, and it converts churned users into a future-quarter
pipeline — the only acquisition channel with zero CAC and 100% product familiarity.

### 5. What NOT to build: a post-move-in services marketplace
Utilities setup, empadronamiento help, internet deals, furniture — tempting,
adjacent, and a trap for a solo founder: each is an ops business with new suppliers,
new liability, and none reuses Julia/the feed/the scraper. The only acceptable
version is **content** (a "first 30 days in your new flat" guide — AEO surface,
retention email payload, zero ops) and possibly a single affiliate link if one ever
proves itself. Contract-review services in particular edge into legal advice —
out, per the hard rule on legal matters.

## Value (why it retains / why it pays)

- Pause converts terminal churn into dormancy with a stored card.
- Success-referral mines the highest-intent acquisition channel (flat-hunters'
  friends are flat-hunters) at €19 of deferred product cost per converted pair.
- Tenancy-calendar emails create a second LTV cycle (~12 months later) from users
  already won. If even 15% of successful users return for move #2, LTV rises ~50%
  on those cohorts with no new spend.

## Effort

**S overall, spread out.** #1 one status + UI tap (S). #2 Stripe portal config +
copy (S, rides roadmap item 12). #3 success email + coupon (S). #4 two scheduled
emails + one date field (S). #5 is a decision, not work.

## Risks

- Pause abuse (pause→unpause monthly to dodge billing): cap pause length, one pause
  per 12 months.
- Scheduled emails must respect consent/unsubscribe — fold into the GDPR pack work
  (roadmap item 13); defer specifics to the Spanish DP professional.
- The success event is self-reported; some users will cancel without tapping it.
  Sweeten it: tapping triggers the referral gift and a "your search, by the numbers"
  recap they'll want to screenshot.

## How to measure success

- % of cancellations converted to pauses (target ≥25%).
- Success-event capture rate vs raw cancellations (instrument before judging churn).
- Referral sends per success event; referred-signup conversion.
- Reactivation rate of paused/lapsed accounts at month 10–12 (the long game — first
  data in ~a year, which is exactly why the date capture should start now).
