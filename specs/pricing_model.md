# Pricing model — decided 2026-06-11

Decided in a pricing-strategy session (post-launch day). This is the handoff for the next
session: **revamp landing page → build pricing packs → backend wiring.** No HTML or Stripe
changes were made in the strategy session; this doc is the spec to implement against.

Out of public deploy (see `.vercelignore` → `specs/`).

---

## The value metric we're selling: VOLUME OF CALLS MADE *FOR* THE CUSTOMER

The headline value prop is **"Julia makes the agent calls for you — every quality listing,
in native Spanish, so you never make the call you dread."**

We sell the **verb we control (calls made)**, NOT the outcome we don't (viewings booked).
Reason: Julia's call→viewing conversion is currently **<1 in 10**. "We made 40 calls for
you" is always true; "we booked you viewings" is true <10% of the time. Selling calls is
honest, reliable, and is exactly the relief the customer is buying (escape from the
soul-crushing fast Spanish phone calls).

**Why volume isn't spammy:** Julia only calls listings scoring **>60** on the appeal score.
So the prop is "every call worth making, on every flat worth calling about, so you make
none." Curation (>60 gate) + volume together = the premium, honest version.

**Pay-per-viewing is the logical eventual destination but explicitly NOT now** — it waits
until CvR earns it (see roadmap).

---

## Unit economics (the reason this all works)

- Julia (Retell) costs **$0.128/min**, max call length **4.5 min** → **~$0.576 ≈ €0.53 per
  call at the ceiling.** Average is likely €0.20–0.35 (voicemail / short calls).
  (Assumes $0.128/min is all-in; if telephony/LLM billed separately, add — doesn't change
  the conclusion.)
- **You are never underwater on a call.** Even a 150-call/month Pro user costs ~€80 vs €185.
- Therefore the real constraint is **cash-flow timing** (pay Retell as calls happen), NOT
  per-unit margin. Fix = collect up front (prepaid packs, monthly Pro), which the model does.
- Essential = €0 Julia cost (the *user* makes the one-tap call), so it's ~100% margin.

---

## The locked structure — one axis: how much of the calling is done for you

| Tier | Price | Who calls | Julia cost | Margin | Role |
|------|-------|-----------|-----------|--------|------|
| **Essential** | €19/mo | You (one-tap) | €0 | ~100% | Cash engine — KEPT PAID (owner constraint: it's the easiest near-term revenue; no runway to give it away) |
| **Trial** | First **5 Julia calls free** (folded into existing 3-day Essential trial) | Julia (taste) | ~€2.65 | — | Activation. Demonstrates *delegation*, not a booking |
| **Call Packs** | €12 / €49 / €119 for 1 / 5 / 15 calls | Julia (occasional) | ~€0.53/call | ~93–96% | Bridge between Essential & Pro + permanent add-on + Pro overage |
| **Pro** | €185/mo | Julia (everything >60) | ~€16–32 | ~85% | Hands-off concierge; ~60 calls/mo included + overage via packs |
| **White-glove** | Later (~€390+) | Julia + human | — | — | Deferred until a human-in-loop exists |

Differentiator a customer grasps instantly: **do the calling yourself → buy a few →
never touch the phone again.**

### Call pack detail
- Single — "Julia, call this one for me": **€12** (~96% margin). Lowest-friction taste-after-trial.
- 5 calls: **€49** (€9.80/call, ~95% margin).
- 15 calls: **€119** (€7.93/call, ~93% margin). Volume nudge.
- Credits are **per-listing CALLS, not minutes** (consistent with `call_allowance`). Never
  advertise minutes anywhere, customer-facing or internal labels.
- Packs are for **believers** (Pro overage, repeat buyers, trialers who converted) — NOT
  cold skeptics (a skeptic buying a per-call pack is buying a 1-in-10 lottery ticket).

### Pro allowance detail
- Include **~60 calls/month**, framed as coverage not a meter: *"Julia calls every quality
  listing in Barcelona for you — around 60 a month, ~15 a week."*
- Barcelona throws off ~10–15 quality (>60) listings/week → ~40–60 over a 4-week hunt, so 60
  feels abundant and covers virtually everyone.
- Power-hunters who exceed it buy overage **call packs** (the repeat revenue stream the owner
  wanted). `call_allowance` stays counted in **calls** internally.

### Trial detail
- New funnel hook: **"Essential free for 3 days + Julia's first 5 calls on us."**
- Value framing = *"Watch Julia make your first 5 calls — in native Spanish, while you do
  nothing."* The felt value is the delegation/relief, NOT a viewing (5 calls at 1-in-10 ≈ 41%
  chance of a booking, but every miss still removed 5 dreaded phone calls).
- Each call shows in the pipeline/Messages UI (dossier presented, who answered, who ghosted)
  — visible effort is the proof.
- **Cap one free-call batch per account** to bound abuse (~€2.65 cost; ~€530 per 1,000 trialers).

---

## REQUIRED copy fix (do during landing-page revamp)

Current headline promise ends **"…and books the viewings."** With the metric on calls-made,
that overpromises and brushes the hard rule (no overpromising). Shift the lead site-wide to
the verb we own:

> **"Julia calls every agent in Barcelona for you — in native Spanish, within 60 seconds —
> so you never make the call you dread."**

Outcome language ("books your viewings") returns the day CvR earns it. Until then, sell the
calling. Julia still *attempts* booking on every call — we just don't headline/sell it.

---

## Pricing roadmap — staged to CvR (the gating metric)

| CvR | Pricing posture |
|-----|-----------------|
| **< ~15% (now)** | Sell **effort/volume** (calls made for you). Hold Pro at €185. Headline = calling, not booking. |
| **> ~25%** | "Books your viewings" becomes honest. Per-call framing fair. Raise Pro €185 → **€245** once ~5 booked-viewing testimonials exist. |
| **Reliable** | Introduce **pay-per-viewing** / "first viewing free, then pay" (the logical destination). Cost per viewing today ≈ €5.30 at 1-in-10, so it's already affordable to absorb — it's a positioning, not a margin, decision. |

Lifting CvR is higher-ROI than any pricing change — but price *around* today's CvR meanwhile.

---

## Next-session checklist

1. **Landing page revamp** — reframe headline to calls-made prop (copy above). Update the
   pricing section: Essential €19, **add Call Packs**, Pro €185 w/ ~60-call coverage framing.
   Trilingual EN/ES/UA, wow-kit voice. Fix the trial line ("+ Julia's first 5 calls on us").
   Also update `index.html` JSON-LD Product blocks (lines ~70/85) + hero subline (~511).
2. **Pricing packs** — build the Call Packs purchase flow (€12/€49/€119), prepaid call
   credits, Pro overage path.
3. **Backend wiring** — Stripe products/prices for packs; credit ledger (decrement
   `call_allowance` / pack credits per Julia call); trial 5-free-calls grant + per-account
   cap; tie into existing Supabase `current_tier()` / n8n Retell flow.

### Stripe products to create (next session)
- `Llavai Call Pack — 1 call` €12 (one-time)
- `Llavai Call Pack — 5 calls` €49 (one-time)
- `Llavai Call Pack — 15 calls` €119 (one-time)
- (Essential €19/mo and Pro €185/mo already exist.)

---

## Owner constraints captured (do not re-litigate)
- Essential stays **paid** (€19) — easiest near-term revenue; no runway to give away.
- Likes the **Call Pack** as the middle ground; wants to **sell additional packs**.
- **White-glove** deferred until a human is available to place in the loop.
- Julia cost = **$0.128/min, 4.5-min max** call.
- Julia CvR currently **<1 in 10** to a booked viewing — the reason we sell calls, not viewings.
