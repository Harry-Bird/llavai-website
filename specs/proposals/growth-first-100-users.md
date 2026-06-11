# Growth — the zero-budget motion to the first 100 paying users

Status: PROPOSAL (2026-06-11). Channel plan + virality hooks. Content items reuse the
existing `content-queue.md` backlog; nothing here needs paid spend.

## Problem

Pre-revenue, solo, no ad budget — and the buyer is hyper-identifiable: an expat in
(or moving to) Barcelona, mid flat-panic, not fluent in Spanish, losing flats to
faster applicants. They are findable in maybe a dozen specific rooms. The risk is
diffusion: doing a little of every channel instead of owning the two where panic
actually happens. Competitor signal: CasaRadar (Barcelona rental alerts) is already
running the content/SEO playbook against the same persona — the AEO window is open
but not empty.

## Target user

"I've sent 40 Idealista messages and got 2 replies"-stage hunters. They self-identify
publicly, daily, in: Facebook groups (Barcelona expat/housing groups are the densest),
Reddit r/Barcelona housing threads, WhatsApp/Telegram housing groups, Erasmus/student
housing channels (seasonal), and the comment sections of "how to rent in Barcelona"
content. Secondary: people *about* to arrive (searching from abroad — they can't do
viewings or calls themselves, the strongest Pro fit of all).

## Proposals

### 1. The answer-engine play: finish the 3 queued guides, then add the "data" page
The three unwritten guides (neighbourhoods / scams / no-bank-account) map exactly to
panic-stage queries and are already specced in `content-queue.md`. Two additions:
- **Write the scams guide first.** Scam-checking is the only query of the three that
  recurs *during* the search (every suspicious listing triggers one), it carries the
  highest trust transfer, and it naturally demos the product ("Llavai's score flags
  exactly these red flags — see the 'Who's behind it' /25 component").
- **A public "Barcelona Rent Radar" stats page** built from data already collected
  (`listings`/`property_cache`): median time-to-disappear, listings/day by district,
  median €/m² of ≥60-scored flats this week. The `teaser_listings` view proves the
  anonymised-aggregate pattern is already solved. This is the *shareable artifact* —
  the thing people paste into the Facebook thread — and it's an AEO magnet no
  static guide can match because the numbers are alive. One static-HTML page +
  one cron-refreshed JSON. (This is the materially-new angle on the data model:
  the scrape pipeline is also a market-data asset; nobody else publishes
  "how fast flats die in Gràcia".)

### 2. The rooms: helpful-native presence, 30 min/day, two rooms only
Pick the single biggest Facebook housing group + r/Barcelona. The motion: answer
real questions with genuinely complete answers (the guides give infinite material),
link only when directly relevant, sign as founder. Groups ban promoters but tolerate
and eventually celebrate *the person who always knows the answer*. Track signups via
"how did you hear about us" on get-started (one field — the lead capture form exists)
rather than UTM-only, since group links are often retyped.

### 3. Virality hooks built into the product's paper trail
- **Booking confirmations**: every viewing Julia books generates an email + ICS
  calendar invite to the client. Footer line: "Viewing booked by Julia from Llavai —
  she called 1m 40s after this flat was listed." The ICS file gets shared with
  partners/flatmates by nature (viewings are attended in pairs) — each one is an
  in-context demo of the exact wow moment. Zero extra cost; the data
  (`viewings.confirmed_at`, call timestamps) already exists.
- **Partner seat**: flat hunts are mostly two-person. One free read-only invite per
  paid account ("share your search with your partner") puts the product in front of
  a co-decision-maker who is also the next recommender. Costs nothing (RLS shared
  read of one user's feed), removes a real objection ("€19 each?"), and doubles
  word-of-mouth surface per account.
- **The score as a screenshot**: feed cards are already designed objects (94/100,
  Gràcia, €16/m²). Make the card render clean when screenshotted (it already does)
  and add a subtle wordmark — screenshots into group chats are the native sharing
  format of flat hunts; brand every one.

### 4. The arrival-pipeline partnerships (second 50 users)
People who haven't landed yet are the best Pro leads (they literally cannot call or
view). Two zero-budget routes: (a) the human relocation agencies and "flat hunter"
services that charge fixed fees — they decline small/rental-only clients constantly;
a referral handshake costs an email each; (b) HR/people-ops at Barcelona companies
hiring internationals and language schools' welcome packs. One-pager + a referral
code; no integration.

## Value

Each channel reinforces the next: guides earn the right to answer in the rooms;
the rooms surface testimonial material; product paper-trail hooks convert the social
context every user already operates in. All of it survives on €0.

## Effort

Guides: **S each** (queued already). Rent Radar page: **M** (one page + one cron
JSON; respect the teaser anonymisation rules). Rooms: founder time, 30 min/day.
Confirmation-email footer + ICS: **S**. Partner seat: **M** (RLS + invite flow —
the one real engineering item; sequence it after the NOW roadmap). Partnerships
one-pager: **S**.

## Risks

- Group moderation: lead with answers for weeks before any link; one ban is
  permanent in the channel that matters most.
- Rent Radar must never leak identifiable listings (same discipline as
  `teaser_listings` — audit R7 warns exactly about column creep on that surface).
- Partner seat must not become "two hunters, one sub" for unrelated users — limit to
  read-only, one invite, same search profile.
- "Booked by Julia in 1m40s" claims must be real per-event numbers, never canned —
  the moment one is caught inflated the trust story dies.

## How to measure success

- Source attribution on get-started ("how did you hear" + UTM) — review weekly.
- Guides: Search Console impressions/clicks per slug; target the scams guide ranking
  for "barcelona rental scam" variants within 8 weeks.
- Rent Radar: external links/citations (it's working when group answers cite it
  without you), and its signup conversion vs guide pages.
- Per-hook: invites sent per booking email; partner-seat activation rate;
  referral-code redemptions from partnerships.
- Global: weekly paying-user count vs the 100 target — one number, one chart.
