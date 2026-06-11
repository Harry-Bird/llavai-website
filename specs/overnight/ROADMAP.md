# Llavai product roadmap — drafted overnight 2026-06-11

Grounded in `AUDIT_2026-06-10.md` + the specs. Effort: S (<½ day), M (1–2 days), L (week+).

## NOW — this week (revenue + safety; mostly approve/publish, not build)

1. **Ship the trial you're already advertising.** account.html sells "3-day free trial";
   live checkout charges €19 instantly (audit B1 — W4 draft never published). One click +
   one test checkout. Effort S. *This is the single highest-leverage item on the list.*
2. **Close the agent-hijack hole.** Unpublish "Retell Agent Manager" — unauthenticated
   webhook that can rewrite Julia's prompt (R1). Effort S.
3. **Publish the Retell agent draft** — ships your 06-09 prompt edits AND moves post-call
   data off Sheets into the dashboard pipeline (B3/W2 cutover). Effort S.
4. **Business-hours calling** — reviewed + published from tonight's build (call_queue is
   live; W1 draft + drain workflow await your review). Protects the brand with every
   agency Julia rings. Effort S to ship, built tonight.
5. **Kill the double-call risk**: confirm CloudMailin → W1 only, retire Start Call v2.5 +
   Spot sync (R2/R3 — Spot can resurrect listings users dismissed). Effort S.
6. **W3 sync correctness before trials flow**: status race ('trial' recorded as 'active'),
   stray €0 price, verify webhook fires in the production Stripe mode — W3 has NEVER
   executed (M4/R4/R5). Effort S–M. Without this, tier UI lies to trial users.
7. **W5 Pro apply→approve** — the €185/mo product currently has no application path at
   all (M3). Apply CTA in account.html → pro_status flow → approval email with Pro
   checkout link. Effort M. *Direct revenue unlock; everything else assumes it.*

## NEXT — 2–4 weeks (close the loop, stop the silent failures)

8. **n8n error handling everywhere** (M2): errorWorkflow on the new stack + a stale-
   'queued'/'calling' attempts sweep → ops email. A failed call must never strand a Pro
   client silently. Effort S–M.
9. **Surface Julia's work in the dashboard**: render `viewings.notes` (call summaries
   already stored, escaped, untranslated-safe — B12) + "Queued — Julia calls when
   offices open" from `call_queue` select-own. Effort S. *Pro customers should SEE the
   concierge working — it's the retention story.*
10. **Sheets decommission (Phase 4)**: Profile Creation → Supabase (it already lost a
    real lead on 06-04 to a Sheets schema error), confirm_viewing logger, Call outcomes
    v3, Recall v1, one-time CSV export, then credential removal. Effort M.
11. **Call economics guardrails**: `call_allowance` enforcement in the drain re-verify
    step + callback_later retries reusing `call_queue` (reason field is ready). Daily
    per-user cap. Effort M. Protects margin at €185/mo flat pricing.
12. **Subscription lifecycle**: Stripe customer portal (self-serve cancel), trial-ending
    email (day 2), dunning on payment failure. Effort M. Required before paid acquisition.
13. **GDPR pack** (C7–C13): Supabase DPA, document-consent checkbox, retention auto-delete
    (W6 — table column already exists), privacy policy + cookie notice, custom SMTP for
    hello@llavai.com (also fixes magic-link deliverability — C4). Effort M, mostly admin.
    Defer specifics to the Spanish DP professional per SETUP.md.

## LATER — 1–3 months (growth)

14. **Second listing source** (Fotocasa or Habitaclia): everything is Idealista-only;
    one source outage = product outage (silent gap #7). The W1 classify/scrape pipeline
    was built single-responsibility precisely to add sources. Effort L.
15. **Admin/ops mini-dashboard**: Pro approvals (W5), call review, message triage,
    queue health — replaces "a manual action / simple admin call". Effort M–L.
16. **Spanish public holidays in the call gate** (`holidays` table, both gates check it) —
    design §4. Effort S.
17. **AI-disclosure / call-recording compliance review** for Julia's calls to agencies
    (silent gap #4) — pairs with the DP professional engagement. Admin, not code.
18. **Webhook hardening**: Retell signature verification (n8n Variables), SPF/DKIM check
    on forwarded alerts, rate limiting on public endpoints (B10, silent gap #8). Effort M.
19. **Content queue**: the 3 unwritten guides (neighbourhoods, scams, no-bank-account) —
    each is AEO surface for the exact panic-Googling expat persona. Effort S each.
20. **Landing-hero live dossier** (open idea from project memory): bring the profile
    page's signature dossier element to the homepage hero as the wow moment. Effort M.

## Sequencing logic
NOW is almost entirely *publishing things that already exist* — the audit's core finding
is that the product is further along than production is. NEXT makes failure loud and the
concierge visible. LATER buys growth only after the loop is closed. Suggested first
morning: items 1–5 (≈30 min of clicking with tonight's NEEDS-HARRY checklist), then 7.
