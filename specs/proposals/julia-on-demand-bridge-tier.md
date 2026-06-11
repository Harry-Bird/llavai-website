# Julia On-Demand — a bridge across the €19 → €185 canyon

Status: PROPOSAL (2026-06-11, business-model analyst). Builds nothing; changes nothing.

## Problem

The ladder today is €0 → €19 → €185. That last step is a **9.7× price jump** with
nothing in between, and the two rungs sell *different products*: Essential sells
information ("see the best flats first"), Pro sells labour ("Julia calls for you").
A user who loves the €19 feed but flinches at €185 has nowhere to go — and the flinch
is structural, not just price: Pro also requires an application, an approval wait, and
an emailed checkout link (W5 design), in a product whose whole pitch is *speed*.

Meanwhile the marginal cost of one Julia call is tiny (see
`pro-call-economics-and-allowance.md`: roughly **€0.40–€0.90 per ~3-min call** at
Retell's published $0.13–$0.31/min all-in range). There is room to sell single calls
at consumer prices with software margins.

## Target user

Essential/Trial subscribers who hit the moment of truth: a 90-scored flat appears in
the feed, the one-tap number is right there — and they freeze, because their Spanish
isn't good enough to win a phone negotiation with a busy agent. Today that user either
churns ("the feed shows me flats I can't win") or stalls below Pro.

## The proposal

**Sell single Julia calls to Essential users as a metered add-on — user-triggered,
not automatic.**

- New button on each feed listing card (Essential/Trial): **"Ask Julia to call"**.
- Pricing test (cheapest to ship first): **pack of 5 calls for €15** (€3/call),
  sold via a Stripe Payment Link / one-time checkout; balance tracked in the
  existing `subscriptions.call_allowance` column (it exists, unenforced — this gives
  it a second job). Optional later: a named **Plus tier at €49/mo incl. 8 calls**
  once pack demand is proven — don't build the tier first.
- The call itself reuses the W1 Retell path and the business-hours `call_queue`;
  only the *trigger* differs (button → webhook with listing_id, instead of
  forwarded-alert automation).

**Why this does not cannibalise Pro.** Pro's value is *automation + speed*: Julia
calls within ~60s of listing publication, before the user has even seen it, on every
≥60 listing. On-demand calls happen minutes-to-hours later, when the human notices
the listing — in a market where flats get 50–100 applicants in 24h and the best ones
go in 60–90 minutes, that delay is exactly the gap Pro closes. The upsell line writes
itself: *"Julia called 3 hours after this flat went live and it was gone. On Pro she
calls in 60 seconds."* Every on-demand call that loses a flat is a Pro sales pitch
that the user paid €3 to hear.

**Pro friction, reframed.** Keep apply→approve (capacity control is right for a solo
founder), but position it as **concierge intake with a stated cap**, not vetting:
"We take a maximum of N Pro clients at a time so Julia answers for you in 60 seconds —
applications answered within 1 business day." Scarcity reads premium; silence reads
broken. (W5 design already promises 1 business day — keep that promise visible on the
homepage Pro card too, which today shows no price at all; see findings.)

## Exact numbers vs today

| | Today | Proposed |
|---|---|---|
| Free | €0 teaser | unchanged |
| Essential | €19/mo | €19/mo + optional call packs |
| Bridge | — (nothing) | **5 Julia calls / €15** (€3/call), cap 4 packs/mo |
| Pro | €185/mo flat, auto-calls | unchanged |
| Per-call margin | n/a | €3 price − ~€0.40–€0.90 COGS ≈ **70–87%** |
| Max bridge ARPU | €19 | €19 + €60 = **€79/mo** (heavy user, still < ½ Pro) |

A heavy pack buyer at €79/mo self-identifies as a Pro lead; the cap (4 packs/mo)
exists so the rational answer to "I keep buying packs" is "upgrade".

## Effort (solo founder + Claude)

**M.** Frontend button + balance display (account.html, existing tier plumbing);
one n8n webhook that validates tier + decrements allowance + enqueues into the
existing call pipeline; one Stripe Payment Link + a small sync to credit packs.
No new agent, no new scraping, no new tables (uses `call_attempts` + `call_allowance`).
Prerequisite: ship the ROADMAP "NOW" items first (W1 published path, business-hours
queue, error handling) — never sell per-unit calls on a pipeline that can fail silently.

## Risks

- **Expectation risk:** a paid call that reaches voicemail/no-answer feels like a
  ripped-off €3. Rule: only decrement allowance on a *connected* call (W2 post-call
  status is already recorded); show the outcome + Julia's notes in the dashboard.
- **Ops exposure:** more calls = more chances for Julia to embarrass the brand before
  the prompt is battle-tested. Mitigate: launch to existing Essential users via email,
  not on the public pricing page, for the first month.
- **Complexity creep:** resist building the Plus tier until packs prove demand.
  A tier is marketing surface, support surface, and Stripe surface; a pack is a button.

## How to measure success

- Pack attach rate among Essential actives (target: ≥15% buy ≥1 pack in month 1 of exposure).
- On-demand call → viewing-booked rate vs Pro auto-call rate (the delta is the Pro pitch).
- Pack-buyer → Pro application conversion within 60 days.
- Essential churn among pack buyers vs non-buyers (hypothesis: packs *reduce* churn —
  the feed stops being a list of flats they can't win).
