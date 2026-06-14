---
description: Research, write and auto-publish a trilingual SEO + AEO guide page for llavai.com
allowed-tools: Read, Write, Edit, WebSearch, WebFetch, Bash(git add:*), Bash(git commit:*), Bash(git status:*), Bash(git diff:*), Bash(git push:*), Bash(ls:*), Bash(cat:*), Bash(node:*), Bash(npm:*)
---

You are Llavai's content lead. Write and publish ONE trilingual guide page for www.llavai.com
on the topic in $ARGUMENTS, optimised for BOTH classic search (SEO) and AI answer engines
(AEO — ChatGPT, Perplexity, Google AI Overviews, Gemini).

FIRST, read these — they are the source of truth and OVERRIDE anything below if they conflict:
- CLAUDE.md  (brand, the /es/ + /uk/ locale system, canonical + git rules, hard rules)
- index.html (exact nav, footer, language toggle, design tokens)
Also open one existing post under blog/* and match its structure exactly. Do NOT invent a new design.

## Step 1 — Research (use WebSearch / WebFetch)
- Find the real questions people ask about "$ARGUMENTS", focused on renting in Barcelona,
  in English AND Spanish (many local searches are in Spanish).
- Capture exact phrasings — these become your H2 headings and FAQ questions.
- Verify every fact. HARD RULE: if anything about Spanish rental law, deposits, NIE/TIE or
  process is uncertain, write "check with a professional" — NEVER state a legal or financial
  figure you cannot source. The page goes live with no review.
- Where you CAN source a figure, DO include it with its date and a cited source. Cited
  statistics are the single biggest driver of AI-answer citations — use them wherever they help.

## Step 2 — Write the page  ->  blog/<slug>/index.html
(slug = short, hyphenated, English, e.g. "rent-apartment-barcelona-foreigner")

TRILINGUAL (required — match the existing site exactly):
- Copy the language-toggle system from index.html verbatim: the [data-lang] CSS rules, the
  EN / ES / UA toggle buttons in the nav, and the setLang() script with localStorage.
  (The language CODE is "uk"; the button LABEL shown to visitors is "UA".)
- Wrap EVERY piece of visible text in three spans:
  <span data-lang="en">...</span><span data-lang="es">...</span><span data-lang="uk">...</span>
- Write native-quality Spanish (Barcelona register) and Ukrainian — not literal machine translation.
- <html lang="en"> is the primary; canonical + schema are in English (see below).

AEO rules (most important):
- Open the article with a 40-60 word DIRECT answer to the main question (in all three languages),
  in plain language an AI can quote word-for-word. No throat-clearing.
- Every H2 is a real question; the first 1-2 sentences under it fully answer it on their own.
- FAQ section of 5-8 Q&As, each answer 2-4 self-contained sentences, in all three languages.
- Short paragraphs, plain words, and ONE comparison table or numbered list where it genuinely helps.

SEO + structured data:
- <title> under 60 chars (English), main keyword + "Barcelona". Meta description 150-160 chars.
- Exactly one H1; logical H2/H3 hierarchy.
- JSON-LD in <head> (English) for ALL of: "Article" (headline, description, datePublished = today,
  author = Harry / founder of Llavai, publisher = Llavai), "FAQPage" matching your FAQ,
  "BreadcrumbList", and "Organization" — match the blocks an existing blog/* post uses.
- Internal links to /get-started at least twice (the site's primary CTA), plus the homepage in
  nav/footer, plus 1-2 cross-links to sibling guides in blog/* so the guides interlink.
- Open Graph + Twitter card tags.
- Canonical/OG/Twitter on the WWW host with NO trailing slash:
  https://www.llavai.com/blog/<slug>   (do NOT use non-www llavai.com and do NOT add a trailing
  slash — llavai.com 307-redirects to www, and every existing post + the sitemap use this exact form.)

Brand & tone:
- Reuse Llavai's CSS variables + Fraunces/Newsreader fonts so it looks native (cream/blue/coral).
- Tone: high-empathy, tactical, fiercely protective of the reader's time — speak to a stressed
  expat racing other applicants. End with a CTA block linking to /get-started.

## Step 2.5 — Humanize the copy (REQUIRED — do this BEFORE wiring / locale generation)
The page is published unreviewed, so it must not read as AI-generated. Run the **/humanizer**
skill over all visible copy, then apply Llavai's copy-voice. Do this on blog/<slug>/index.html
BEFORE Step 3 — the /es/ and /uk/ pages are rendered from this file's spans, so they only
inherit humanized text if you fix the source first.
- If the /humanizer skill isn't installed in this environment, apply its checks by hand: remove
  em-dash overuse, rule-of-three padding, promotional/inflated words (crucial, vital, seamless,
  "navigate the complexities", "in today's world", "ever-evolving"), superficial "-ing" sentence
  openers, vague attributions ("studies show" / "experts say" with no source), negative
  parallelisms ("it's not just X, it's Y"), needless passive voice, and filler phrases. Keep
  sentences plain, specific and concrete — how a sharp human writer would actually phrase it.
- Copy-voice: British / international spelling and neutral, internationally-legible idioms.
  Apply the FULL humanizer pass to English; for Spanish and Ukrainian keep it punctuation-level
  (their dash/quote conventions differ — don't strip native dashes). Preserve Llavai's signature
  editorial voice; only strip the decorative AI tells.

## Step 3 — Wire it into the site
- Add a trilingual guide card to the .guides-grid in BOTH index.html AND blog/index.html
  (tag, h3, description, "Read guide →" link in EN/ES/UK), matching the existing cards.
- REGENERATE LOCALES — REQUIRED. The in-place [data-lang] toggle is invisible to search
  (one URL, mixed-language source, no hreflang). The real /es/ + /uk/ monolingual pages,
  reciprocal hreflang, and sitemap.xml are all produced by the generator:
    NODE_PATH=/tmp/llavai-verify/node_modules node scripts/gen-locales.js
  (needs puppeteer-core + system Chrome; install if missing.) The script OWNS /es/, /uk/,
  all hreflang, and sitemap.xml — do NOT hand-edit those files. If it cannot run, STOP and
  report the error; do NOT publish a half-localized post or hand-edit the sitemap.

## Step 4 — Self-check
State out loud, each explicitly: title <60 incl "Barcelona"; meta 150-160; exactly one H1;
all four JSON-LD blocks valid; 40-60w answer-first openings in all 3 languages; FAQ in all 3;
language toggle copied correctly; canonical = https://www.llavai.com/blog/<slug> (www, no slash);
>=2 links to /get-started; copy humanized (no AI tells) + British/intl spelling;
/es/ + /uk/ + sitemap.xml regenerated; no unsourced legal/financial claims.

## Step 5 — Publish automatically
After the self-check passes, commit and push straight to main (never a PR — pushing to main
deploys via Vercel). End the commit message with:
  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  git add -A && git commit -m "Add SEO guide: <english title>" && git push
Then print the live URL (https://www.llavai.com/blog/<slug>) and note it goes live in 1-2 minutes.
If git push fails, show me the exact error and do NOT retry blindly.
