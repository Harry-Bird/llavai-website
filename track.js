// First-party funnel analytics — fire-and-forget beacons to the n8n ingest webhook,
// which validates against an event allow-list and writes to public.funnel_events with
// the service role (see supabase/migrations/20260612133454_funnel_events.sql and the
// "Llavai — Funnel Events Ingest" n8n workflow). No PII is sent: anon_id is a random,
// per-browser id, never an email/name. Analytics must NEVER break the page — every call
// is wrapped so a failure is silent.
(function () {
  var ENDPOINT = 'https://llavai.app.n8n.cloud/webhook/f3a9c1e7-2b84-4d16-a0f5-9e6c3b1d7a42';

  function anonId() {
    try {
      var k = 'llavai-aid', v = localStorage.getItem(k);
      if (!v) {
        v = (window.crypto && crypto.randomUUID)
          ? crypto.randomUUID()
          : 'a-' + Math.random().toString(36).slice(2) + Date.now().toString(36);
        localStorage.setItem(k, v);
      }
      return v;
    } catch (e) { return null; }
  }

  function langNow() {
    try {
      return document.body.classList.contains('es') ? 'es'
        : document.body.classList.contains('uk') ? 'uk' : 'en';
    } catch (e) { return null; }
  }

  window.track = function (event, extra) {
    try {
      var payload = {
        event: event,
        anon_id: anonId(),
        lang: langNow(),
        path: location.pathname,
        referrer: (document.referrer || '').split('?')[0].slice(0, 160)
      };
      if (extra) { for (var k in extra) { if (extra[k] != null) payload[k] = extra[k]; } }
      var body = JSON.stringify(payload);
      // text/plain keeps it a CORS-"simple" request → no preflight, no response needed.
      if (navigator.sendBeacon) {
        navigator.sendBeacon(ENDPOINT, new Blob([body], { type: 'text/plain;charset=UTF-8' }));
      } else {
        fetch(ENDPOINT, { method: 'POST', headers: { 'Content-Type': 'text/plain;charset=UTF-8' }, body: body, keepalive: true }).catch(function () {});
      }
    } catch (e) { /* swallow — never break the page for analytics */ }
  };

  // One-shot per page load (form_start, magic_link_clicked, profile_start, ...)
  var fired = {};
  window.trackOnce = function (event, extra) {
    if (fired[event]) return;
    fired[event] = 1;
    window.track(event, extra);
  };
})();
