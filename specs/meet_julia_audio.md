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
Drop a web-optimised MP3 at `audio/julia-intro.mp3` (~20–30s, small). The moment it's
committed, the play button self-activates.

### Julia's REAL voice config (read from Retell 2026-06-12 — copy this exactly)
- **Retell agent id:** `agent_774cc5844d7d7824eb70b63fe4` (from the n8n create-call payload;
  from_number `+34931228994`).
- **ElevenLabs voice:** `UOIqAnmS11Reiei1Ytkc` — "Carolina · Natural, Neutral and Clear"
  (Retell wraps it as `custom_voice_731f471c118fb611ab5b3645d0`). **It's a Voice-Library voice.**
- **Model** `eleven_turbo_v2_5` · **voice_temperature** 1.2 · **voice_speed** 1.06 ·
  volume 0.88 · language es-ES · normalize_for_speech on.
- Mapped to ElevenLabs API settings (already wired into the generator):
  `model_id=eleven_turbo_v2_5`, stability 0.4, similarity_boost 0.75, style 0.0,
  use_speaker_boost true, speed 1.06.

### ⚠️ BLOCKER hit 2026-06-12 — and how to clear it
Rendering via the ElevenLabs API returned **HTTP 402**: *"Free users cannot use library
voices via the API."* The standalone ElevenLabs key is **free tier**; Carolina is a library
voice. (Retell can use it because Retell carries its own paid ElevenLabs access.) The voice
IS saved in the account's "My Voices" — only the *free-tier API* path is blocked. Fix, pick one:
- **Path A (likely free):** render manually in the ElevenLabs **dashboard → Text to Speech**
  (web UI isn't API-blocked): voice Carolina, model Turbo v2.5, speed 1.06, stability ~40%,
  similarity 75%, style 0%, paste the script below, download MP3 → `audio/julia-intro.mp3`.
- **Path B ($5):** upgrade the key's account to **ElevenLabs Starter**, then run the generator
  (one command) — settings already match.

### Generator (regenerate if missing — it lives OUTSIDE the repo, ephemeral)
`/tmp/llavai-verify/gen-julia.sh` — reads `ELEVENLABS_API_KEY` from env (never in git),
voice id + matched settings hard-coded, writes `~/llavai-website/audio/julia-intro.mp3`.
Run: `export ELEVENLABS_API_KEY=sk_... && bash /tmp/llavai-verify/gen-julia.sh`.
Retell config reader: `/tmp/llavai-verify/retell-voice.sh` (reads `RETELL_API_KEY`).
**After the MP3 exists:** re-run the overflow/visual check, confirm the player reveals, then
`git add audio/julia-intro.mp3` + commit.

### 🔐 Keys shared in chat 2026-06-12 → ROTATE
The ElevenLabs + Retell API keys were pasted into the session to run the above. They were
used only as transient env vars (never written to repo/disk), but should be **rotated** in
the ElevenLabs and Retell dashboards. (Retell key name was "CLAUDE".)

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
