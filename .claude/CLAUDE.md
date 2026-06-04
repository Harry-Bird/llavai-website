# Llavai — site context for Claude Code

Llavai is an AI rental concierge for Barcelona. "Julia" (the AI voice agent) calls estate
agents in native Spanish within 60 seconds of a listing going live and books viewings.
Target reader: stressed expats who don't speak fluent Spanish and keep losing flats to
faster applicants.

## Site
- Static HTML, no framework, no build step. Plain HTML/CSS/JS in single files.
- Existing pages: `index.html (OLD)` is the live homepage (NOT `index (2).html`). Always edit `index.html (OLD)` for homepage changes — e.g. adding guide cards to the guides-grid section. profile.html is the tenant onboarding form.
- New SEO/AEO guides live at: blog/<slug>/index.html
- Every page is trilingual: English / Spanish / Ukrainian, using the [data-lang] span system
  and the EN/ES/UA setLang() toggle from index.html. Always replicate that exactly.
- The repo auto-deploys to live the moment changes are pushed to the main branch on GitHub.
- Publishing is automatic: after writing a page, commit and push directly to main. Never open a PR — always push straight to main so the page deploys immediately.

## Brand
- Colours: Cream canvas #F4EFE5, Deep Blue structure #1B388F, Coral accent #E55B45.
- Fonts: Fraunces (headings), Newsreader (body). Reuse the CSS variables in existing pages.
- Tone: high-empathy, tactical, fiercely protective of the reader's time. Premium, editorial.
- Always reuse the existing nav and footer. Primary CTA everywhere: link to profile.html.

## Git setup (run at the start of every session)
- `git config user.email noreply@anthropic.com && git config user.name Claude`
- After every push to main, also push to the current feature branch: `git push --force-with-lease origin <branch>`
- This keeps the branch in sync and prevents the stop-hook from flagging unverified commits.

## Hard rules
- Never invent legal/financial figures about Spanish rentals; verify or defer to a professional.
- Mobile-first: inherit existing responsive CSS; layout must work at 375px.
- No React/npm/build steps. Everything copy-paste editable.
