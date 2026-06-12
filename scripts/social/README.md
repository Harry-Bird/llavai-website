# Llavai Instagram publisher

A zero-dependency Node tool that posts to Llavai's Instagram via the official
Instagram Graph API (content publishing, v25.0). Lives in `scripts/`, so it's
private — excluded from the public Vercel deploy via `.vercelignore`.

---

## One-time setup (~15 min, you must do these in Meta's UI)

The token-dependent parts can't be automated — they require logging into
Instagram and the Meta dashboard as you. Do this once.

### 1. Make the Instagram account "Professional"
In the Instagram app → **Settings → Account type and tools → Switch to professional
account** → choose **Business** (or Creator). This unlocks the API. No Facebook
Page is required for the Instagram-Login flow below.

### 2. Create a Meta app
- Go to <https://developers.facebook.com/apps> → **Create app**.
- Use case: choose **Other** → app type **Business**.
- In the app dashboard, **Add product → Instagram → "API setup with Instagram login."**

### 3. Connect the account and generate a token
- In **Instagram → API setup with Instagram login**, under *"Generate access tokens,"*
  add/connect your `@llavai` Instagram account (log in when prompted).
- Click **Generate token**. Approve the permissions
  (`instagram_business_basic`, `instagram_business_content_publish`).
- Copy the token. This page also shows your **Instagram user id** — copy that too.

> The generated token is long-lived (~60 days). It can be refreshed before it
> expires with `node ig-publish.js --refresh-token` (see below).

### 4. Save credentials locally (never committed)
```bash
cd scripts/social
cp .env.example .env
# edit .env → paste IG_USER_ID and IG_ACCESS_TOKEN
```
`.env` is git-ignored (see repo `.gitignore`). The token is a secret — keep it out of git.

### 5. Verify
```bash
node ig-publish.js --check
```
If it prints `@llavai` and a publishing quota, you're live.

---

## Posting

Images must be hosted at a public URL — see `/social-assets/README.md`. Then:

```bash
node ig-publish.js --list                 # see the queue
node ig-publish.js --next --dry-run        # build the post but DON'T publish (safe test)
node ig-publish.js --next                  # publish the next "ready" item
node ig-publish.js --id launch-how-it-works   # publish a specific item
```

**Queue lifecycle** (`queue.json`): `draft` → (you set) `ready` → `--next` publishes → `published`.
Edit captions freely; ask Claude to refill the queue any time.

Supported `type`s: `image`, `carousel` (2–10 `image_urls`), `reel` (`video_url`).

## Token maintenance
Long-lived tokens last ~60 days. Refresh before expiry:
```bash
node ig-publish.js --refresh-token   # prints a fresh token → paste into .env
```

## Scheduling (optional, later)
Once `--check` passes and you've posted manually a few times, this can run on a
schedule — either a local cron/launchd job calling `--next`, or (better, since
Llavai already runs n8n) an n8n Schedule trigger that hits the same Graph API
flow. Ask Claude to wire whichever you prefer.

## Safety notes
- This posts only to **your own** account via the official API — it's ToS-compliant.
- Rate limit: 100 published posts / 24h (carousels count as 1). Plenty of headroom.
- Nothing posts without a `ready` status, so the seeded drafts are inert until you opt them in.
