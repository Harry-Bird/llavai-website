#!/usr/bin/env node
// Llavai — Instagram content publisher.
//
// Posts to Llavai's Instagram using the official Instagram Graph API content
// publishing flow (v25.0). Zero dependencies: uses Node 18+ global fetch and a
// tiny built-in .env loader. The site itself stays build-free; this lives under
// scripts/ which is excluded from the public Vercel deploy (.vercelignore).
//
// HOW PUBLISHING WORKS (two steps, per Meta docs):
//   1. Create a media "container":  POST /<IG_USER_ID>/media     (image_url/video_url + caption)
//   2. Publish the container:        POST /<IG_USER_ID>/media_publish  (creation_id)
//   Containers must reach status_code=FINISHED before publishing (we poll).
//   Meta cURLs the media, so image_url/video_url MUST be publicly reachable —
//   host post images in /social-assets/ so they live at https://www.llavai.com/social-assets/...
//
// USAGE
//   node ig-publish.js --check                 Validate token + show 24h publishing limit (read-only, SAFE)
//   node ig-publish.js --next                  Publish the next item whose status is "ready" in queue.json
//   node ig-publish.js --id <itemId>           Publish a specific queue item (ignores its status)
//   node ig-publish.js --next --dry-run        Build + poll the container but DO NOT publish (safe test)
//   node ig-publish.js --refresh-token         Refresh the long-lived token (~60d) and print the new one
//   node ig-publish.js --list                  Show the queue
//
// First run: `node ig-publish.js --check`. If it prints your username + quota, auth works.

'use strict';
const fs = require('fs');
const path = require('path');

const DIR = __dirname;
const ENV_PATH = path.join(DIR, '.env');
const QUEUE_PATH = path.join(DIR, 'queue.json');

// ---- tiny .env loader (no dotenv dependency) --------------------------------
function loadEnv() {
  if (!fs.existsSync(ENV_PATH)) {
    fail(`No .env found at ${ENV_PATH}\n   Copy .env.example to .env and fill it in (see README.md).`);
  }
  for (const line of fs.readFileSync(ENV_PATH, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !line.trim().startsWith('#')) {
      let v = m[2].trim();
      if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
      process.env[m[1]] = v;
    }
  }
}

function cfg() {
  const IG_USER_ID = process.env.IG_USER_ID;
  const TOKEN = process.env.IG_ACCESS_TOKEN;
  const HOST = process.env.GRAPH_HOST || 'graph.instagram.com';
  const VERSION = process.env.GRAPH_VERSION || 'v25.0';
  if (!IG_USER_ID || !TOKEN) fail('IG_USER_ID and IG_ACCESS_TOKEN must be set in .env');
  return { IG_USER_ID, TOKEN, HOST, VERSION };
}

// ---- Graph API helpers ------------------------------------------------------
async function api(method, node, params, { HOST, VERSION, TOKEN }) {
  const url = new URL(`https://${HOST}/${VERSION}/${node}`);
  const body = new URLSearchParams({ access_token: TOKEN, ...params });
  let res;
  if (method === 'GET') {
    for (const [k, v] of body) url.searchParams.set(k, v);
    res = await fetch(url, { method });
  } else {
    res = await fetch(url, { method, body });
  }
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch { json = { raw: text }; }
  if (!res.ok || json.error) {
    const e = json.error || {};
    throw new Error(`Graph API ${res.status}: ${e.message || text}` +
      (e.error_user_msg ? `\n   → ${e.error_user_msg}` : ''));
  }
  return json;
}

// Poll a container until it is ready to publish. Reels need longer (video processing).
async function waitForContainer(id, c, { tries = 30, delayMs = 4000 } = {}) {
  for (let i = 0; i < tries; i++) {
    const { status_code } = await api('GET', id, { fields: 'status_code' }, c);
    if (status_code === 'FINISHED') return;
    if (status_code === 'ERROR' || status_code === 'EXPIRED') {
      throw new Error(`Container ${id} ended in status ${status_code}`);
    }
    process.stdout.write(`   …processing (${status_code}) [${i + 1}/${tries}]\r`);
    await sleep(delayMs);
  }
  throw new Error(`Container ${id} not FINISHED after ${tries} polls — try again later`);
}

async function publishItem(item, c, { dryRun }) {
  const caption = item.caption || '';
  let creationId;

  if (item.type === 'image') {
    requireUrl(item.image_url, 'image_url');
    const params = { image_url: item.image_url, caption };
    if (item.alt_text) params.alt_text = item.alt_text;
    log(`Creating image container…`);
    creationId = (await api('POST', `${c.IG_USER_ID}/media`, params, c)).id;
    await waitForContainer(creationId, c);

  } else if (item.type === 'reel') {
    requireUrl(item.video_url, 'video_url');
    const params = { media_type: 'REELS', video_url: item.video_url, caption };
    if (item.cover_url) params.cover_url = item.cover_url;
    log(`Creating reel container…`);
    creationId = (await api('POST', `${c.IG_USER_ID}/media`, params, c)).id;
    await waitForContainer(creationId, c, { tries: 60, delayMs: 5000 }); // video takes longer

  } else if (item.type === 'carousel') {
    const urls = item.image_urls || [];
    if (urls.length < 2 || urls.length > 10) fail('carousel needs 2–10 image_urls');
    const childIds = [];
    for (let i = 0; i < urls.length; i++) {
      requireUrl(urls[i], `image_urls[${i}]`);
      log(`Creating carousel item ${i + 1}/${urls.length}…`);
      const child = await api('POST', `${c.IG_USER_ID}/media`,
        { image_url: urls[i], is_carousel_item: 'true' }, c);
      await waitForContainer(child.id, c);
      childIds.push(child.id);
    }
    log(`Creating carousel container…`);
    creationId = (await api('POST', `${c.IG_USER_ID}/media`,
      { media_type: 'CAROUSEL', children: childIds.join(','), caption }, c)).id;
    await waitForContainer(creationId, c);

  } else {
    fail(`Unknown item type: ${item.type} (use image | carousel | reel)`);
  }

  if (dryRun) {
    log(`DRY RUN — container ${creationId} is ready but NOT published.`);
    return { dryRun: true, creationId };
  }
  log(`Publishing…`);
  const published = await api('POST', `${c.IG_USER_ID}/media_publish`, { creation_id: creationId }, c);
  log(`✅ Published. Media id: ${published.id}`);
  return { id: published.id };
}

// ---- queue ------------------------------------------------------------------
function readQueue() {
  if (!fs.existsSync(QUEUE_PATH)) return { items: [] };
  return JSON.parse(fs.readFileSync(QUEUE_PATH, 'utf8'));
}
function writeQueue(q) { fs.writeFileSync(QUEUE_PATH, JSON.stringify(q, null, 2) + '\n'); }

// ---- commands ---------------------------------------------------------------
async function cmdCheck(c) {
  const me = await api('GET', 'me', { fields: 'user_id,username' }, c);
  log(`Authenticated as @${me.username} (id ${me.user_id || c.IG_USER_ID})`);
  try {
    const lim = await api('GET', `${c.IG_USER_ID}/content_publishing_limit`,
      { fields: 'quota_usage,config' }, c);
    const d = lim.data && lim.data[0] || {};
    log(`24h publishing used: ${d.quota_usage ?? '?'} / ${d.config?.quota_total ?? 100}`);
  } catch (e) { log(`(could not read publishing limit: ${e.message})`); }
  log('Auth OK — you are ready to publish.');
}

async function cmdRefreshToken(c) {
  // Instagram Login long-lived tokens refresh via this endpoint (token must be >24h old).
  const r = await api('GET', 'refresh_access_token', { grant_type: 'ig_refresh_token' }, c);
  log(`New long-lived token (expires in ~${Math.round((r.expires_in || 0) / 86400)} days):\n`);
  console.log(r.access_token);
  log(`\n→ Paste this into IG_ACCESS_TOKEN in .env`);
}

function cmdList() {
  const q = readQueue();
  if (!q.items.length) return log('Queue is empty.');
  for (const it of q.items) {
    console.log(`  [${it.status.padEnd(9)}] ${it.id.padEnd(20)} ${it.type.padEnd(8)} ${oneLine(it.caption)}`);
  }
  log(`\nStatuses: draft → ready → published. Only "ready" items are published by --next.`);
}

async function cmdPublish(c, { which, dryRun }) {
  const q = readQueue();
  let item;
  if (which.id) item = q.items.find(i => i.id === which.id);
  else item = q.items.find(i => i.status === 'ready');
  if (!item) fail(which.id ? `No queue item with id "${which.id}"` : 'No item with status "ready" in the queue');

  log(`Selected: ${item.id} (${item.type})`);
  const result = await publishItem(item, c, { dryRun });
  if (!dryRun && result.id) {
    item.status = 'published';
    item.published_id = result.id;
    item.published_at = new Date().toISOString();
    writeQueue(q);
    log(`Queue updated → ${item.id} marked published.`);
  }
}

// ---- utils ------------------------------------------------------------------
const sleep = ms => new Promise(r => setTimeout(r, ms));
const log = m => console.log(`• ${m}`);
function fail(m) { console.error(`✗ ${m}`); process.exit(1); }
function requireUrl(u, name) {
  if (!u || !/^https?:\/\//.test(u)) fail(`${name} must be a public http(s) URL (Meta fetches it). Got: ${u}`);
  if (/localhost|127\.0\.0\.1/.test(u)) fail(`${name} points at localhost — Meta can't reach it. Host it on www.llavai.com/social-assets/.`);
}
const oneLine = s => (s || '').replace(/\s+/g, ' ').slice(0, 50);

// ---- main -------------------------------------------------------------------
(async () => {
  const args = process.argv.slice(2);
  const has = f => args.includes(f);
  const valOf = f => { const i = args.indexOf(f); return i >= 0 ? args[i + 1] : undefined; };

  loadEnv();
  const c = cfg();

  try {
    if (has('--check')) return await cmdCheck(c);
    if (has('--refresh-token')) return await cmdRefreshToken(c);
    if (has('--list')) return cmdList();
    if (has('--next') || has('--id')) {
      return await cmdPublish(c, { which: { id: valOf('--id') }, dryRun: has('--dry-run') });
    }
    console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(15, 33).join('\n'));
  } catch (e) {
    fail(e.message);
  }
})();
