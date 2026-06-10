# Llavai — site context for Claude Code

Llavai is an AI rental concierge for Barcelona. "Julia" (the AI voice agent) calls estate
agents in native Spanish within 60 seconds of a listing going live and books viewings.
Target reader: stressed expats who don't speak fluent Spanish and keep losing flats to
faster applicants.

## Site
- Static HTML, no framework, no build step. Plain HTML/CSS/JS in single files.
- **Homepage is `index.html`** — edit it directly. `index.html (OLD)` is a stale leftover
  from a previous workflow (last touched in commit `ecf0a65`); ignore it. Do NOT copy
  between the two. (Still tracked in git but excluded from the live deploy via
  `.vercelignore`; safe to delete — confirm with the owner first.)
- profile.html is the multi-step tenant onboarding form. `/get-started` is the lead-capture
  entry that feeds into it.
- `signup.html` was deleted (June 2026) — it was an orphaned parallel funnel. `/signup`
  308-redirects to `/get-started` via the `redirects` block in `vercel.json`. Don't recreate it.
- New SEO/AEO guides live at: blog/<slug>/index.html
- Every page is trilingual: English / Spanish / Ukrainian, using the [data-lang] span system
  and the EN/ES/UA setLang() toggle from index.html. Always replicate that exactly.
- The repo auto-deploys to live the moment changes are pushed to the main branch on GitHub
  (Vercel). HTML is served with `must-revalidate`, so a normal reload picks up new deploys.

## Hosting / deploy notes (Vercel)
- Production project: `llavai-website` (team "Harry's projects").
- **`llavai.com` 307-redirects to `www.llavai.com`** — the real production host is the `www`
  subdomain. When verifying the live site with curl, follow redirects (`curl -L`) or hit
  `https://www.llavai.com/` directly, or you'll just read an empty 307 body.
- A push to `main` triggers a production deploy; it typically goes READY in ~1–2 minutes.
- **The repo root is served as-is** (no build step), so every committed file is public on
  www.llavai.com unless listed in `.vercelignore` (currently `.claude/`, `specs/`,
  `supabase/`, `SETUP.md`, `content-queue.md`, `index.html (OLD)`). When adding new
  internal docs/dirs, add them there too. Never commit secrets anywhere in the repo —
  e.g. the secret n8n webhook paths live only in n8n/Retell/Stripe config, never in git.

## Brand
- Colours: Cream canvas #F4EFE5, Deep Blue structure #1B388F, Coral accent #E55B45.
  CSS variables live in each page's `:root` (--cream, --ink, --coral, etc.) — reuse them.
- Fonts: Fraunces (headings), Newsreader (body). Self-hosted via fonts.css.
- Tone: high-empathy, tactical, fiercely protective of the reader's time. Premium, editorial.
- Always reuse the existing nav and footer. Primary CTA everywhere: link to `/get-started`.

## Design vocabulary — the "wow kit" (June 2026; intentional, do NOT "clean up")
The forms/dashboard use a deliberate editorial print language. These are features, not bugs:
- **Stacked-paper cards**: key surfaces (`.dossier`, get-started/login `.card`, account
  `.paywall`) sit slightly rotated (`rotate(-.4deg)`-ish) on offset pseudo-element sheets,
  with a paperclip SVG (`.dclip`). Surface tokens: `--paper:#FBF8F1` (sheets),
  `--field:#FFFDF9` (inputs).
- **Live tenant dossier** (profile.html): sticky aside that renders Julia's call script
  from form state in real time — JS-rendered, trilingual via the `DTXT` dict, aria-hidden
  (decorative mirror of the form). Don't convert it to static data-lang spans.
- **Hand-drawn pen circles**: the `viewDays` week row (`.toggle-group.days`) is borderless
  Fraunces day names; checking one draws a wobbly coral SVG ellipse (`pathLength=100`
  dashoffset animation). Injected by JS at load.
- **Rubber stamps**: rotated bordered uppercase Fraunces chips — `.dstamp` (profile),
  `.pw-stamp` (paywall), account `.badge` statuses. `b-calling` pulses on purpose.
- **Paper-sheet motion**: `sheetIn`/`sheetOut` keyframes for step/tab transitions;
  `.btn-primary`'s hard offset shadow `0 4px 0 var(--ink-deep)` is the site standard —
  never replace with soft shadows.
- All animations stay subordinate to the global `prefers-reduced-motion` kill rule.

## Mobile / responsive (read before touching layout)
- Mobile-first. Layout must work edge-to-edge with no horizontal overflow / zoom-out from
  320px up. Verify at 320, 360, 393, 402, 430, 768.
- **Watch for grid/flex min-width blowouts.** Grid and flex items default to `min-width:auto`,
  which refuses to shrink a track below its content's intrinsic size. A child with a fixed
  `width` (e.g. the hero's `.sample`/`.sample-stack` at `width:380px`) will force its whole
  column wider than the phone and drag the rest of the layout out with it. Fix the cause with
  `min-width: 0` on the grid/flex items (see `.hero-grid > *`) — do NOT just paper over it
  with `overflow-x: hidden/clip`, which only clips the symptom and ends up cutting real
  content off the right edge (which is what *makes* users zoom out).
- `html { overflow-x: clip }` is kept as a safety net for purely decorative overhang (e.g.
  the rotated card-shadow pseudo-elements). `clip` (not `hidden`) is used so it doesn't break
  the sticky header. It is a backstop, not the fix — content must genuinely fit first.
- **Verify overflow by measuring, not by eyeballing CSS.** Drive headless Chrome and compare
  `document.documentElement.scrollWidth` to `window.innerWidth`, and list any element whose
  `getBoundingClientRect().right` exceeds the viewport. Chrome is at
  `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`; `puppeteer-core` (pointed at
  system Chrome) works without downloading a browser. The earlier "it's the decoration" guess
  was wrong; one measurement found the real grid blowout immediately.

## Signed-in UX conventions (June 2026 UX overhaul — keep these intact)
- **Tier-aware account UI** (`account.html`): `current_tier()` RPC → global `TIER`
  ('free'|'trial'|'essential'|'pro'), fetched once in `showDash()` and re-fetched after
  Stripe activation. `applyTierUI()` renders the plan badge (`#planPill`) and toggles the
  Pro cross-sell (`#pipelineUpsell`, `#docsUpsell`, `#upgradeLink`). **Pro wording is the
  static-HTML default; applyTierUI swaps copy for non-Pro.** Rule: never promise Julia
  (concierge calling) to non-Pro users — 'trial' is a trial of *Essential*, not Pro.
  Upgrade enquiries go through `askAboutPro()` → Messages tab with a prefilled message
  (zero extra backend; the team sees it in the messages table).
- **Errors shown to users are friendly + trilingual** via `friendly(kind, rawError)` in
  account.html (raw Supabase errors go to console only). Never surface `error.message`
  or use `alert()`.
- **Custom radio/checkbox chips** (profile.html `.card-option`/`.toggle-chip`): inputs are
  visually hidden with the clip-path pattern, NOT `display:none` (that breaks keyboard
  access — this was a shipped bug). Keep the `input:focus-visible+label` rings.
- **Forms submit on Enter**: login/get-started inputs live inside `<form onsubmit>`.
  Any new form must too.
- **Icons are inline SVG** (Lucide-style, 24 viewBox, stroke currentColor) — no emoji icons.
- **Destructive actions** confirm() and/or offer undo (listing dismiss has a 6s undo that
  restores the previous `status` from `data-status`).
- **Account tabs** implement full WAI-ARIA (aria-selected, roving tabindex, arrow keys) —
  keep the pattern complete if adding tabs.
- **localStorage keys in use**: `llavai-lang`, `llavai-tab`, `llavai-next`, `llavai-lead`,
  `llavai-profile-pending`, `llavai-profile-draft` (profile form autosave; cleared on submit).
- Verify signed-in pages headlessly with puppeteer-core + system Chrome against
  `python3 -m http.server` (see `/tmp/llavai-verify/` pattern: console/pageerror capture,
  Enter-submit, keyboard chips, tier simulation via `TIER='essential'; applyTierUI()`).
- **Screenshotting account.html without auth**: the auth check redirects mid-session and
  kills puppeteer's execution context. Block it with request interception
  (`page.setRequestInterception(true)` + abort any URL matching `/supabase/i`), then
  force-show the dashboard (`hidden=false` on `#dash`, hide `.gate`) and toggle
  `.tab`/`.panel` active classes per tab. Visual check only — no live data renders.

## Backend (Supabase-first)
- The logged-in pages (signup/login/app/account) talk to **Supabase** directly from the
  browser (anon key; security = RLS). Supabase is the **source of truth**. **n8n**
  (`llavai.app.n8n.cloud`, service-role credential) is the automation layer: forwarded
  Idealista alerts → client feed, Julia's Retell calls + post-call updates, Stripe sync.
  Google Sheets is the legacy store, being decommissioned.
- Architecture, state and per-feature designs live in `specs/backend_rebuild_architecture.md`
  and `specs/*_design.md` (kept out of the public deploy — see `.vercelignore`). Claude's
  project memory holds n8n credential IDs and the current open-task queue.
- n8n Cloud gotcha: MCP `update_workflow` saves a **draft** — always `publish_workflow`
  afterwards or production keeps running the old version. Retell mirrors this: PATCHing the
  agent edits its draft; live calls use the *published* agent version.

## Git / publishing
- Set identity if unset: `git config user.email noreply@anthropic.com && git config user.name Claude`
- Commit and push straight to `main` — never open a PR; pushing to main deploys immediately.
- Cloud sessions that start on a `claude/*` feature branch: after pushing to main, also keep
  that branch in sync (`git push --force-with-lease origin <branch>`) so the stop-hook doesn't
  flag the commits as unverified. (Not needed when working directly on `main`.)
- End commit messages with: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- Commit clear, completed fixes without being asked; the owner prefers fixes land committed.
- Backend sessions usually run in a git worktree (`.claude/worktrees/…`) and push straight
  to origin/main. In any other checkout, `git pull` before relying on `specs/*.md` — they
  may have moved underneath you.

## Hard rules
- Never invent legal/financial figures about Spanish rentals; verify or defer to a professional.
- No React/npm/build steps for the site itself. Everything copy-paste editable.
