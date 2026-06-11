# W5 — Pro application → approval: technical design

Status: DESIGNED 2026-06-11 (overnight). The €185/mo Pro tier currently has no
application path (audit M3; last open Phase-3 item in `backend_rebuild_architecture.md`).
Model per rebuild spec §2: **Apply → Harry approves → Stripe Pro checkout**, no trial.

## 1. Flow

1. Signed-in client clicks **Apply for Pro** (account.html, where the Pro cross-sell
   already lives: `#pipelineUpsell` / `#docsUpsell` / `askAboutPro()`).
2. Frontend calls new RPC `apply_for_pro()` → sets `profiles.intended_plan='pro'`,
   `pro_status='applied'`, inserts a `messages` row (team already triages messages) —
   one transaction, no new notify infrastructure needed. Best-effort POST to a small
   n8n webhook for an instant ops email (same non-financial-alert pattern as lead capture).
3. UI flips to an "APPLICATION RECEIVED" rubber stamp (existing `.pw-stamp` vocabulary);
   `applyTierUI()` reads `pro_status` to render applied/approved/rejected states.
4. Harry approves via **manual-execution n8n workflow** (never published, like W2 Setup):
   input `{email, action: 'approve'|'reject'}` → service-role PATCH `pro_status` →
   on approve: create the Pro Stripe checkout session (price_1TgUXvF7TyaJ4FziJhqXMovY,
   no trial) and email the client the link. Because it runs only when Harry triggers it,
   the outbound email is owner-initiated — compatible with the no-unattended-contact rule.
5. Client pays → existing W3 sync maps the Pro price → `plan='pro'` → `current_tier()`
   returns 'pro' → Julia activates. No new sync code.

## 2. Three perspectives

**[Backend]**
- Additive migration `w5_apply_for_pro`:
  - RPC `apply_for_pro()` — security definer, search_path public: requires `auth.uid()`;
    allowed transition only `pro_status in ('none','rejected') → 'applied'` (idempotent:
    'applied'/'approved' return current state, no error); sets `intended_plan='pro'`;
    inserts `messages(user_id, sender='user', body='[PRO APPLICATION] …')`.
  - **Column-level guard:** `revoke update (pro_status) on public.profiles from authenticated`
    — today `profiles_update_own` lets a user write ANY column incl. `pro_status`
    (self-approval). Harmless-ish (tier is derived from a real Stripe sub, which only
    follows an approval-issued link) but cheap to close. `intended_plan` stays user-writable
    (the profile form legitimately writes it). NOTE: this revoke is technically not
    additive → goes in `supabase/proposed/`, NOT applied tonight.
- n8n **W5a "Pro — Application Alert"** (draft, tiny): webhook → validate user exists +
  pro_status='applied' (service-role read) → ops email to harry.bird@llavai.com. Misses
  are harmless (the messages row is the source of truth; this is just speed).
- n8n **W5b "Pro — Approve / Reject (manual)"** (NEVER published; manual executions only):
  `{email, action}` → look up profile (service-role) → PATCH `pro_status` →
  approve-branch: Stripe checkout session (Pro price, `metadata.plan='pro'`,
  `subscription_data.metadata.user_id`) → email client the checkout link (Fraunces-plain
  text, trilingual not required for v1 — match the client's `profiles` language if cheap).

**[Frontend]** (after tonight's frontend agent finishes account.html, to avoid collisions)
- Apply CTA in the Pro cross-sell blocks; states from `pro_status`:
  none → "Apply for Pro" button; applied → stamp "APPLICATION RECEIVED — we'll reply
  within 1 business day"; approved → "Approved — check your email for your checkout link"
  (+ re-send goes through askAboutPro()); rejected → keep `askAboutPro()` path.
  All trilingual via data-lang; no alert(); Enter-safe.

**[Security]**
- Approval power lives only in service-role (n8n W5b) — never the browser.
- `apply_for_pro` validates transitions server-side; rate-abuse bounded (idempotent, own
  row only). Messages insert stays constrained to `sender='user'`.
- W5a webhook: secret-ish path, validates against DB before emailing; payload is
  email-only (non-financial). W5b is unpublished — manual executions only, no public surface.
- Checkout link generated per-application; paying without approval is impossible to
  reach normally and harmless economically (it's full price; W3 stamps plan from price).

## 3. Build order (tonight, drafts)

1. Migration `w5_apply_for_pro` (RPC + messages insert) — additive, can apply tonight.
2. W5a + W5b in n8n as drafts (W5b is *meant* to stay unpublished even after go-live).
3. Frontend CTA — only after the frontend-fixes agent has pushed, then verify headlessly.

## 4. Rollout (NEEDS HARRY)

Publish W5a; W5b stays manual. Test: apply with a test account → messages row + ops email
→ run W5b approve → receive checkout link → pay with a test card in the production-mode
equivalent → confirm `current_tier()='pro'`. Rollback: unpublish W5a; RPC is inert without
the CTA; revoke file in proposed/ can simply not be applied.
