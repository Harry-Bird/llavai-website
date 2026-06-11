# Per-language URLs + hreflang — make ES/UK content visible to search

Status: PROPOSAL ONLY (2026-06-11). From the mission marketing audit (M10).

## Problem
Every page serves all three languages on one URL via [data-lang] toggling. Google
indexes a mixed-language DOM under the English title/description; a Ukrainian or
Spanish searcher can never land on their language. hreflang cannot be bolted onto the
current setup — it requires distinct URLs per language. The og:locale alternates that
exist today do nothing for search.

## Target user
Spanish- and Ukrainian-speaking flat-hunters searching in their language ("alquilar
piso Barcelona extranjero", "оренда квартири Барселона") — the UK audience especially
is underserved and was a deliberate product choice.

## Value
Search visibility in 2 additional languages for content that ALREADY exists and is
already translated — the marginal cost is routing, not writing. The blog guides are
AEO surface; today they compete only in English, the most contested language.

## Sketch
- Vercel rewrites: /es/* and /ua/* serve the same static files; a tiny inline script
  reads the path prefix and calls setLang() before paint + sets <html lang>.
- Per-language <title>/<meta description> swapped by the same script (or build-less
  duplication of the head block via a template comment).
- hreflang cluster (en/es/uk + x-default) in every head; sitemap gains the alternates.
- Canonicals: each language URL self-canonical.
- Phase it: index + get-started + blog hub first; guides after.

## Effort
M–L (routing is S; the SEO correctness sweep — titles, descriptions, canonicals,
sitemap, structured-data inLanguage per variant — is the real work). No framework
needed; stays within the no-build-step rule.

## Risks
- Duplicate-content if hreflang/canonicals are wrong — worse than not doing it.
  Mitigate: ship one page first, verify in Search Console, then roll out.
- The lang toggle must keep working (toggle = navigate to the sibling URL).

## How to measure
Search Console: impressions/clicks for es/uk queries; indexed pages per locale path
after 4–6 weeks.
