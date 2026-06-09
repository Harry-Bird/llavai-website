# Llavai — site context for Claude Code

Llavai is an AI rental concierge for Barcelona. "Julia" (the AI voice agent) calls estate
agents in native Spanish within 60 seconds of a listing going live and books viewings.
Target reader: stressed expats who don't speak fluent Spanish and keep losing flats to
faster applicants.

## Site
- Static HTML, no framework, no build step. Plain HTML/CSS/JS in single files.
- **Homepage is `index.html`** — edit it directly. `index.html (OLD)` is a stale leftover
  from a previous workflow (last touched in commit `ecf0a65`); ignore it. Do NOT copy
  between the two. (It is still tracked in git and is safe to delete — confirm with the
  owner first.)
- profile.html is the multi-step tenant onboarding form. `/get-started` is the lead-capture
  entry that feeds into it.
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

## Brand
- Colours: Cream canvas #F4EFE5, Deep Blue structure #1B388F, Coral accent #E55B45.
  CSS variables live in each page's `:root` (--cream, --ink, --coral, etc.) — reuse them.
- Fonts: Fraunces (headings), Newsreader (body). Self-hosted via fonts.css.
- Tone: high-empathy, tactical, fiercely protective of the reader's time. Premium, editorial.
- Always reuse the existing nav and footer. Primary CTA everywhere: link to `/get-started`.

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

## Git / publishing
- Set identity if unset: `git config user.email noreply@anthropic.com && git config user.name Claude`
- Commit and push straight to `main` — never open a PR; pushing to main deploys immediately.
- Cloud sessions that start on a `claude/*` feature branch: after pushing to main, also keep
  that branch in sync (`git push --force-with-lease origin <branch>`) so the stop-hook doesn't
  flag the commits as unverified. (Not needed when working directly on `main`.)
- End commit messages with: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- Commit clear, completed fixes without being asked; the owner prefers fixes land committed.

## Hard rules
- Never invent legal/financial figures about Spanish rentals; verify or defer to a professional.
- No React/npm/build steps for the site itself. Everything copy-paste editable.
