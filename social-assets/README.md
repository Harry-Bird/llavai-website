# social-assets — PUBLIC image folder for Instagram posts

This folder is **served publicly** at `https://www.llavai.com/social-assets/…`
(it is intentionally NOT in `.vercelignore`).

The Instagram publishing API does not accept file uploads — it fetches your image
from a public URL. So:

1. Drop a post image here, e.g. `launch.jpg` (JPEG, ≤ 8 MB, recommended 1080×1350 portrait).
2. Commit + push to `main` → Vercel serves it within ~1–2 min.
3. Put the full URL in `scripts/social/queue.json`, e.g.
   `https://www.llavai.com/social-assets/launch.jpg`
4. Set that queue item's `status` to `ready` and run `node scripts/social/ig-publish.js --next`.

Only put files you're happy to be publicly reachable in here.
