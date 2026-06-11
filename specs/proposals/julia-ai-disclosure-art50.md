# Julia's AI disclosure — EU AI Act Art. 50 opening script (applies 2 Aug 2026)

Status: PROPOSAL ONLY (2026-06-11). Do NOT edit the Retell agent from this document —
prompt changes go through the normal owner-reviewed draft→publish flow. Legal
specifics must be confirmed by the Spanish DP/legal professional (SETUP.md); nothing
here is legal advice and no penalty figures are stated by design.

## Problem

Article 50(1) of the EU AI Act requires that AI systems intended to interact
directly with natural persons inform those persons they are interacting with an AI,
"unless this is obvious" from context. It applies from **2 August 2026** — about
seven weeks away — and Julia's calls to estate agents are a textbook in-scope case:
a natural-sounding voice agent whose entire design goal is to perform like a human
caller. "Obvious from context" is precisely the exemption Llavai *cannot* claim,
because Julia being convincing is the product. The roadmap already lists this
(item 17) as admin; this proposal turns it into copy + call-flow design so the legal
review starts from a concrete artifact instead of a blank page.

The framing opportunity: most companies will treat the disclosure as a legal mumble.
For Llavai it can be the brand: the agency hears "this tenant is so serious they
hired a 60-second-response concierge." Disclosure done confidently is a *signal of
client quality*, which is exactly what wins viewings.

## Where it sits in the call flow

1. Wait for the agent's pickup greeting ("¿Sí?/Inmobiliaria X, dígame").
2. **First Julia turn = greeting + disclosure + purpose, one breath.** The
   disclosure must come before any substantive ask — at the start of the
   interaction, per Art. 50(1) — but after the human pickup, so it lands as an
   introduction, not an answering-machine preamble.
3. Then the normal pitch (client, listing, availability).
4. If asked "¿eres un robot?/¿una máquina?" at ANY point: confirm immediately and
   plainly, never deflect — a single deceptive deflection is both an Art. 50 breach
   pattern and a brand catastrophe in a small agent community. Scripted fallback
   below.
5. The same disclosure duty applies to **voicemail** drops — include the short form.

## Proposed wording

Load-bearing tokens (present in every variant, first sentence, never A/B'd away):
**"asistente virtual" + "inteligencia artificial" + "Llavai" + the human client's
name**. Variants differ only in framing *after* the disclosure — that's what makes
A/B testing safe: the compliance payload is constant, the persuasion wrapper varies.

### Variant A — direct/professional (default)
- **ES:** «Hola, buenos días. Soy Julia, la asistente virtual con inteligencia
  artificial del servicio Llavai. Llamo en nombre de [NOMBRE], que está muy
  interesado/a en el piso de [CALLE/ZONA] que acaban de publicar. ¿Tiene un
  minuto?»
- **EN (reference):** "Hello, good morning. I'm Julia, the AI virtual assistant
  from the Llavai service. I'm calling on behalf of [NAME], who is very interested
  in the flat on [STREET/AREA] you've just listed. Do you have a minute?"

### Variant B — client-quality framing (test arm)
- **ES:** «Hola, buenos días. Soy Julia, una asistente de inteligencia artificial —
  llamo de parte de [NOMBRE], un inquilino con el perfil completo y verificado en
  Llavai, por el piso de [CALLE/ZONA]. Quiere ser de los primeros en visitarlo.
  ¿Le viene bien ahora?»
- **EN (reference):** "Hello, good morning. I'm Julia, an artificial-intelligence
  assistant — calling for [NAME], a tenant with a complete, verified profile on
  Llavai, about the flat on [STREET/AREA]. They'd like to be among the first to
  view it. Is now a good time?"

### "Are you a robot?" fallback (all variants, non-negotiable)
- **ES:** «Sí, exacto — soy una asistente de inteligencia artificial que trabaja
  para [NOMBRE], un inquilino real con documentación lista. Si lo prefiere, le paso
  sus datos y [NOMBRE] le confirma en persona.»
- **EN:** "Yes, exactly — I'm an AI assistant working for [NAME], a real tenant
  with documents ready. If you prefer, I'll share their details and [NAME] will
  confirm personally."

### Voicemail short form
- **ES:** «Buenos días, soy Julia, asistente virtual de inteligencia artificial de
  Llavai, en nombre de [NOMBRE], interesado/a en el piso de [CALLE/ZONA]. Le
  volveremos a llamar; también puede contactar a [NOMBRE] en [CONTACTO]. Gracias.»

Language note: castellano for v1 (current agent language). A Catalan greeting
variant («Bon dia, sóc la Júlia, assistent virtual d'intel·ligència artificial…»)
is a plausible rapport win with some Barcelona agencies — separate test, later.

## Recording / consent (flag for the professional — do not self-serve this)

Retell post-call processing means call audio/transcripts of agency staff (personal
data of identifiable professionals) are processed. Items for the Spanish DP
professional, not for self-decision: (a) lawful basis + notice duties under
GDPR/LOPDGDD for recording or transcribing commercial calls — Spanish constitutional
case law on participant recording does NOT settle the GDPR notice question for a
company doing it systematically; (b) the AEPD has issued 2026 guidance specifically
on AI voice transcription tools — have the professional review Julia's pipeline
against it; (c) whether a one-line in-call notice («esta llamada puede quedar
registrada para gestionar la visita») is required and sufficient; (d) retention
period for transcripts/`viewings.notes`. Fold into the existing GDPR-pack
engagement (roadmap item 13/17) — one engagement, one set of answers.

## Target user / Value

The "user" here is the estate agent — the counterparty whose cooperation IS the
product. Value: legal compliance before the deadline; differentiated positioning
(confident disclosure as a quality signal); and protection of the core asset —
Llavai's standing with Barcelona agencies, who talk to each other. One viral
"AI pretended to be human" story would poison the well permanently.

## Effort

**S** for the script itself (prompt edit + publish through the existing Retell
draft flow, owner-reviewed). **S/admin** for the legal-review handoff (this doc is
the artifact). A/B measurement: **S** — W2 post-call already stores outcome +
duration per call; tag calls with the variant in call metadata.

## Risks

- Hang-ups on hearing "inteligencia artificial": real, measurable (see below), and
  the reason to A/B framing — but never to soften the disclosure tokens themselves.
- Whisper-fast or end-of-call disclosure to game engagement would defeat Art. 50's
  "clear at the start" requirement — placement is fixed, only framing varies.
- Don't ship Variant B's "verificado" wording unless profile verification genuinely
  exists at that point — never let the pitch outrun the product.
- The 2 Aug 2026 date is statutory; treat the publish of the disclosing prompt as a
  hard deadline item (suggest: live by mid-July, two weeks of buffer + data).

## How to measure success

- **Hard gate:** 100% of outbound calls carry the disclosure in turn one (verify in
  Retell transcripts — sample weekly).
- A/B (variant in call metadata → W2 outcomes): pickup→10s hang-up rate;
  conversation duration; viewing-booked rate per variant.
- "Are you a robot?" frequency over time (expect it to fall as agencies meet Julia
  repeatedly — a proxy for the market normalising, and an early-mover advantage
  measurement).
- Zero complaints/incidents from agencies about disguised AI calling — the metric
  that matters most is the absence of the story.
