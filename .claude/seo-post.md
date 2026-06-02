---
description: Research, write and auto-publish a trilingual SEO + AEO guide page for llavai.com
allowed-tools: Read, Write, Edit, WebSearch, WebFetch, Bash(git add:*), Bash(git commit:*), Bash(git status:*), Bash(git diff:*), Bash(git push:*), Bash(ls:*), Bash(cat:*)
---

You are Llavai's content lead. Write ONE publish-ready guide page for llavai.com on the
topic in $ARGUMENTS, optimised for BOTH classic search (SEO) and AI answer engines
(AEO — ChatGPT, Perplexity, Google AI Overviews, Gemini).

First, read CLAUDE.md AND index.html so the new page matches the exact brand, colours,
fonts, nav, footer, language-toggle and tone. Do NOT invent a new design.

## Step 1 — Research (use WebSearch / WebFetch)
- Find the real questions people ask about "$ARGUMENTS", focused on renting in Barcelona,
  in English AND Spanish (many local searches are in Spanish).
- Capture exact phrasings — these become your H2 headings and FAQ questions.
- Verify every fact. If anything about Spanish rental law, deposits, NIE/TIE or process is
  uncertain, write "check with a professional" — NEVER state a legal or financial figure you
  cannot source. This is a hard rule and matters even more because the page goes live with no review.

## Step 2 — Write the page  ->  blog/<slug>/index.html
(slug = short, hyphenated, English, e.g. "rent-apartment-barcelona-foreigner")

TRILINGUAL (this is required — match the existing site exactly):
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
- JSON-LD in <head> (English) for BOTH: "Article" (headline, description, datePublished = today,
  author = Harry / founder of Llavai, publisher = Llavai) AND "FAQPage" matching your FAQ.
- Internal links to https://llavai.com/profile.html at least twice, plus homepage in nav/footer.
- Open Graph + Twitter card tags. Canonical: https://llavai.com/blog/<slug>/

Brand & tone:
- Reuse Llavai's CSS variables + Fraunces/Newsreader fonts so it looks native (cream/blue/coral).
- Tone: high-empathy, tactical, fiercely protective of the reader's time — speak to a stressed
  expat racing other applicants. End with a CTA block linking to profile.html.

## Step 3 — Wire it into the site
- Add the page to sitemap.xml (create it if missing): <loc>, <lastmod> = today, sensible <priority>.
- If a blog index page exists, add a trilingual card linking to the new post.

## Step 4 — Self-check
State out loud: title length OK, meta present, exactly one H1, both JSON-LD blocks valid,
answer-first openings present in all 3 languages, FAQ present in all 3, language toggle copied
correctly, >=2 links to profile.html, no unsourced legal/financial claims.

## Step 5 — Publish automatically
After the self-check passes, run:
  git add -A && git commit -m "Add SEO guide: <english title>" && git push
Then print the live URL (https://llavai.com/blog/<slug>/) and note it goes live in 1-2 minutes.
If git push fails, show me the exact error and do NOT retry blindly.
