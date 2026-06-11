# Landing-hero live dossier — put Julia's call script on the homepage

Status: PROPOSAL ONLY (2026-06-11). Roadmap #20 / project-memory open idea; promoted
here after the mission's marketing audit (P3) confirmed it independently.

## Problem
The homepage hero shows the *feed* (shuffling listing cards + count-up score). That
sells Essential. The differentiator — Julia, a voice agent that calls agencies in
native Spanish — is only ever *described* in text. The single most convincing artifact
in the product, profile.html's live tenant dossier (Julia's call script rendering in
real time as the form fills), is hidden behind signup. The marketing audit judged the
current hero good but the wow kit absent and Julia under-sold.

## Target user
First-visit prospects, especially Pro candidates (the €185 decision needs the "she's
real" moment) and skeptics who've seen ten "AI assistant" landing pages.

## Value
- Shows, not tells: visitors watch «Buenos días — llamo de parte de…» assemble itself
  with their own name/budget typed into two demo fields. Memorable + shareable.
- Converts the existing signature element — zero new design language, maximum reuse of
  DTXT/dossier code already in profile.html.
- Differentiates from CasaRadar etc., which can show alerts but have no Julia.

## Sketch (build-ready)
- Hero right column (or a new section directly under the hero): the stacked-paper
  dossier card with paperclip, a 2-field mini-form (first name, max budget — both
  fake/demo, no data stored), and the script re-rendering on input with the d-fresh
  highlight. Trilingual via the existing DTXT dict. aria-hidden mirror per the
  profile.html pattern. Mobile: stacked below the lede; verify 320–430 + 344.
- CTA underneath: "Build your real dossier → /get-started".
- Do NOT replace the feed deck — A/B judgment for Harry: dossier under hero (safe) vs
  swap hero visual (bolder).

## Effort
M (1 session: extract dossier renderer, demo-ify, restyle, trilingual sweep, mobile
matrix, screenshots). No backend.

## Risks
- Hero complexity/LCP regression — must keep the new block out of the LCP path
  (render below the fold or content-visibility:auto; re-run Lighthouse after).
- Two interactive artifacts above the fold compete — mitigated by placing it as the
  second section ("This is what Julia says when she calls").

## How to measure
Scroll-depth proxy: clicks on the dossier demo fields; /get-started CTR from the new
section's CTA vs the hero CTA (add ?src=dossier); bounce rate before/after.
