# "Meet Julia" — recorded voice intro (Phase 1)

Shipped 2026-06-11. Solves the "first-timers don't know who Julia is" gap by introducing
her on the landing page, with a play button to hear her real voice.

Out of public deploy (`.vercelignore` → `specs/`).

## What's live now (index.html)
- **Hero clarifier** — first Julia mention now reads "let Julia — Llavai's AI voice agent —
  call every agent for you…" (EN/ES/UK).
- **`#julia` section** between hero and tiers ("Meet Julia."): stamp, explanation paragraph,
  3 chips (60s · native Barcelona Spanish · books around your calendar), and a **trilingual
  transcript** — so the explanation lands whether or not anyone plays the audio.
- **Audio player** wired to `audio/julia-intro.mp3`. Progressive enhancement: the play
  button **only appears once the MP3 is present and playable** (JS reveals on `canplay`,
  hides on `error`). Until the file exists the section shows text + transcript only — no
  broken button. (One harmless console 404 for the missing file until it's added; gone once
  it is.)
- Player: play/pause toggle, animated soundwave (subordinate to `prefers-reduced-motion`),
  `aria-pressed` state, keyboard-focusable. Verified EN/ES/UK, 344–1100px, no overflow.

## TO DO — generate `audio/julia-intro.mp3`
Drop a web-optimised MP3 at `audio/julia-intro.mp3` (mono, ~20–30s, small). The moment it's
committed, the play button self-activates.

**Match the real Julia voice** (don't use a generic TTS voice): render the script through the
same voice the Retell agent uses — get the Retell agent's `voice_id` + provider
(ElevenLabs / OpenAI / PlayHT / …) and TTS the script with it, or capture audio from a real
Retell call. Keys stay in n8n/Retell config, **never in git**.

### Approved-pending script (matches the on-page transcript)
**Intro (English, warm):**
> "Hi — I'm Julia, the voice behind Llavai. When a great flat goes live in Barcelona, I call
> the agent for you — in native Spanish, within sixty seconds — so you never make the call
> you dread. Here's how I sound when I do…"

**Demo (native Barcelona Spanish — the wow):**
> "Hola, buenas tardes. Le llamo por el piso que acaba de salir en Gràcia. Tengo un inquilino
> con contrato indefinido y nómina, muy interesado — ¿sería posible concertar una visita?"

(English intro so the expat audience understands who she is, then a real-call snippet in
Spanish as proof. If we later want ES/UK spoken intros too, add `julia-intro-es.mp3` etc. and
pick by `llavai-lang`. Demo line stays Spanish — it's the demonstration.)

## Phase 2 (deferred) — live "Talk to Julia" demo
Owner chose recorded first, live demo later. When we do it: Retell web-call SDK + a
token-minting endpoint via **n8n webhook** (API key server-side), a **separate landing-page
Julia agent** (own prompt), minute caps + one-per-visitor + Turnstile/captcha for cost/abuse
control, and **EU AI Act disclosure** (she states she's an AI up front) — tie to the mid-July
AI Act review item.
