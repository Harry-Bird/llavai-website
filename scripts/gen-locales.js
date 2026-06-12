/* gen-locales.js — generate monolingual locale pages from the trilingual source.
 *
 * The site's pages carry EN/ES/UA content inline as [data-lang] spans toggled by CSS.
 * That's great for users but invisible to search (one URL, mixed-language source, no
 * hreflang). This script renders each source page, strips the non-target [data-lang]
 * elements, rewrites the head (title/description/og/canonical + hreflang) and the
 * language toggle, and writes a clean monolingual file under /es/ (and later /uk/).
 * It also regenerates sitemap.xml with hreflang <xhtml:link> alternates.
 *
 * It does NOT modify the English originals (those keep their in-place JS toggle); the
 * reciprocal hreflang on the EN pages is added by hand in the head (see commit).
 *
 * Run:  NODE_PATH=/tmp/llavai-verify/node_modules node scripts/gen-locales.js
 * Needs puppeteer-core + system Chrome (dev-only; the site itself stays build-free).
 * Re-run after editing any English source page so the locale copies don't drift.
 */
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const ROOT = path.resolve(__dirname, '..');
const SITE = 'https://www.llavai.com';

// Locales to generate. UA intentionally deferred — until /uk/ exists, an hreflang
// pointing at it would 404 and void the cluster. Add 'uk' here (+ its head map) to ship it.
const LOCALES = ['es'];

// Per-page head translations. Body content is already translated in the source spans;
// only the <head> (title/description) needs locale copy. No invented legal/financial
// figures — terms (fianza, NIE, nómina, zona tensionada, SERPAVI, Incasòl) kept verbatim.
const PAGES = [
  {
    src: 'index.html', en: '/', slug: '',
    es: {
      title: 'Llavai: los mejores pisos de Barcelona, llama en un toque',
      desc: 'Llavai te muestra primero los mejores pisos nuevos de Barcelona: puntuados, claros y con llamada en un toque. O deja que Julia llame a las agencias en español por ti.'
    }
  },
  {
    src: 'blog/index.html', en: '/blog', slug: 'blog',
    es: {
      title: 'Alquilar en Barcelona: guías para extranjeros | Llavai',
      desc: 'Guías prácticas y directas para alquilar en Barcelona siendo extranjero: documentos, la fianza, el NIE, honorarios de agencia y cómo adelantarte a otros.'
    }
  },
  {
    src: 'blog/rent-apartment-barcelona-foreigner/index.html', en: '/blog/rent-apartment-barcelona-foreigner', slug: 'blog/rent-apartment-barcelona-foreigner',
    es: {
      title: 'Cómo alquilar en Barcelona siendo extranjero (2026)',
      desc: 'Guía paso a paso para extranjeros que alquilan en Barcelona: documentos necesarios, fianza, honorarios de agencia, control de alquiler y cómo adelantarte en 2026.'
    }
  },
  {
    src: 'blog/documents-to-rent-barcelona/index.html', en: '/blog/documents-to-rent-barcelona', slug: 'blog/documents-to-rent-barcelona',
    es: {
      title: 'Documentos para alquilar en Barcelona: NIE, nóminas y más (2026)',
      desc: '¿Qué documentos necesitas para alquilar en Barcelona? NIE, nóminas, extractos bancarios y aval bancario explicados: la lista completa que esperan los caseros.'
    }
  },
  {
    src: 'blog/barcelona-rental-deposit-fianza/index.html', en: '/blog/barcelona-rental-deposit-fianza', slug: 'blog/barcelona-rental-deposit-fianza',
    es: {
      title: 'Fianza de alquiler en Barcelona: cómo funciona (2026)',
      desc: '¿Cuánto es la fianza de un alquiler en Barcelona? Reglas de la fianza, registro en el Incasòl, garantías adicionales y cómo recuperarla: la guía 2026 del inquilino.'
    }
  },
  {
    src: 'blog/rental-cover-letter-spanish-barcelona/index.html', en: '/blog/rental-cover-letter-spanish-barcelona', slug: 'blog/rental-cover-letter-spanish-barcelona',
    es: {
      title: 'Carta de presentación de alquiler en español: plantilla Barcelona',
      desc: 'Cómo escribir una carta de presentación en español para un piso en Barcelona: plantilla para copiar, frases clave que generan confianza y qué buscan los caseros.'
    }
  },
  {
    src: 'blog/barcelona-rent-control-zona-tensionada/index.html', en: '/blog/barcelona-rent-control-zona-tensionada', slug: 'blog/barcelona-rent-control-zona-tensionada',
    es: {
      title: 'Control de alquiler en Barcelona: zona tensionada (2026)',
      desc: 'Barcelona es zona tensionada según la Ley de Vivienda. Así funciona el límite del alquiler, qué puede cobrar legalmente el casero y cómo te afecta el índice SERPAVI.'
    }
  },
  {
    src: 'blog/best-neighbourhoods-barcelona-rent-expat/index.html', en: '/blog/best-neighbourhoods-barcelona-rent-expat', slug: 'blog/best-neighbourhoods-barcelona-rent-expat',
    es: {
      title: 'Mejores barrios para alquilar en Barcelona (extranjeros, 2026)',
      desc: '¿Eixample, Gràcia, Poblenou, Sant Martí o Sarrià? Análisis honestos de barrios para extranjeros que alquilan en Barcelona: ambiente, transporte, precios y para quién.'
    }
  },
  {
    src: 'blog/avoid-rental-scams-barcelona/index.html', en: '/blog/avoid-rental-scams-barcelona', slug: 'blog/avoid-rental-scams-barcelona',
    es: {
      title: 'Cómo evitar estafas de alquiler en Barcelona (2026)',
      desc: 'El mercado de alquiler de Barcelona atrae estafadores que buscan extranjeros. Detecta anuncios falsos, caseros fantasma y fraudes de fianza, y protege tu dinero en 2026.'
    }
  }
];

const OG_LOCALE = { es: 'es_ES', uk: 'uk_UA' };
const HTML_LANG = { es: 'es', uk: 'uk' };
// Pages NOT localized (no /es/ version) — included in sitemap without alternates.
const ENGLISH_ONLY = [
  { loc: '/get-started', lastmod: '2026-06-04', changefreq: 'monthly', priority: '0.9' },
  { loc: '/privacy', lastmod: '2026-06-09', changefreq: 'yearly', priority: '0.3' }
];

function esPath(slug) { return slug ? '/es/' + slug : '/es/'; }

async function transform(page, p, loc) {
  // EN page's base dir, so relative asset paths can be absolutized (a /es/ page sits one
  // dir deeper, so `images/x.webp` would 404 — rewrite to an absolute root path).
  const baseDir = p.en === '/' ? '/' : p.en + '/';
  const cfg = { lang: HTML_LANG[loc], ogLocale: OG_LOCALE[loc], site: SITE, en: p.en, locPath: esPath(p.slug), title: p[loc].title, desc: p[loc].desc, baseDir };
  await page.evaluate((cfg) => {
    document.documentElement.lang = cfg.lang;
    document.body.classList.add(cfg.lang);
    // absolutize relative src/href so assets resolve from the deeper /es/ path
    document.querySelectorAll('[src],[href]').forEach((el) => {
      ['src', 'href'].forEach((attr) => {
        const v = el.getAttribute(attr);
        if (!v || /^(https?:|\/\/|\/|#|mailto:|tel:|data:)/i.test(v)) return;
        el.setAttribute(attr, cfg.baseDir + v);
      });
    });
    // strip every non-target language element → monolingual source
    document.querySelectorAll('[data-lang]').forEach((el) => {
      if (el.getAttribute('data-lang') !== cfg.lang) el.remove();
    });
    // language toggle → EN link back + active locale (UA dropped until /uk/ exists)
    var label = cfg.lang.toUpperCase() === 'UK' ? 'UA' : cfg.lang.toUpperCase();
    document.querySelectorAll('.lang-toggle[role="group"]').forEach((g) => {
      g.innerHTML =
        '<button type="button" aria-pressed="false" onclick="location.href=\'' + cfg.en + '\'">EN</button>' +
        '<span class="lang-sep" aria-hidden="true">/</span>' +
        '<button type="button" class="active" aria-pressed="true">' + label + '</button>';
    });
    // Neutralize the on-load localStorage language auto-switch. The toggle no longer
    // calls setLang, but the inline `if(s==='es'||s==='uk') setLang(s)` would still fire
    // for a returning visitor — and setLang('uk') on a Spanish-only page strips all
    // content (blank page). The language is fixed by the URL now, so make it a no-op.
    document.querySelectorAll('script:not([src])').forEach((s) => {
      if (s.textContent.indexOf('llavai-lang') !== -1) {
        s.textContent = s.textContent.replace(/setLang\(\s*s\s*\)/g, 'void 0');
      }
    });
    function set(sel, attr, val) { var el = document.head.querySelector(sel); if (el) el.setAttribute(attr, val); }
    document.title = cfg.title;
    set('meta[name="description"]', 'content', cfg.desc);
    set('link[rel="canonical"]', 'href', cfg.site + cfg.locPath);
    set('meta[property="og:url"]', 'content', cfg.site + cfg.locPath);
    set('meta[property="og:title"]', 'content', cfg.title);
    set('meta[property="og:description"]', 'content', cfg.desc);
    set('meta[property="og:locale"]', 'content', cfg.ogLocale);
    set('meta[name="twitter:title"]', 'content', cfg.title);
    set('meta[name="twitter:description"]', 'content', cfg.desc);
    // hreflang cluster: en + this locale + x-default (no uk yet)
    document.head.querySelectorAll('link[rel="alternate"][hreflang]').forEach((l) => l.remove());
    function alt(hl, href) { var l = document.createElement('link'); l.setAttribute('rel', 'alternate'); l.setAttribute('hreflang', hl); l.setAttribute('href', href); document.head.appendChild(l); }
    alt('en', cfg.site + cfg.en);
    alt(cfg.lang, cfg.site + cfg.locPath);
    alt('x-default', cfg.site + cfg.en);
  }, cfg);
  return '<!DOCTYPE html>\n' + await page.evaluate(() => document.documentElement.outerHTML) + '\n';
}

function buildSitemap() {
  const lines = ['<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">'];
  const xhtml = (p) => LOCALES.concat(['en']).map((l) => {
    const href = l === 'en' ? SITE + p.en : SITE + esPath(p.slug);
    return '    <xhtml:link rel="alternate" hreflang="' + l + '" href="' + href + '" />';
  }).concat(['    <xhtml:link rel="alternate" hreflang="x-default" href="' + SITE + p.en + '" />']).join('\n');
  const urlBlock = (loc, p, pr) => ['  <url>', '    <loc>' + loc + '</loc>', xhtml(p), '    <changefreq>monthly</changefreq>', '    <priority>' + pr + '</priority>', '  </url>'].join('\n');
  // EN localized pages + their /es/ counterparts
  for (const p of PAGES) {
    const pr = p.slug === '' ? '1.0' : p.slug === 'blog' ? '0.8' : '0.7';
    lines.push(urlBlock(SITE + p.en, p, pr));
    for (const l of LOCALES) lines.push(urlBlock(SITE + esPath(p.slug), p, pr));
  }
  // English-only pages (no alternates)
  for (const e of ENGLISH_ONLY) {
    lines.push(['  <url>', '    <loc>' + SITE + e.loc + '</loc>', '    <changefreq>' + e.changefreq + '</changefreq>', '    <priority>' + e.priority + '</priority>', '  </url>'].join('\n'));
  }
  lines.push('</urlset>', '');
  return lines.join('\n');
}

// Add reciprocal hreflang to the English source pages (text insert after <canonical>,
// no DOM round-trip). Idempotent: strips any managed alternate links first, then re-adds.
function patchEnglishHreflang() {
  for (const p of PAGES) {
    const f = path.join(ROOT, p.src);
    let html = fs.readFileSync(f, 'utf8');
    html = html.replace(/\n\s*<link rel="alternate" hreflang="[^"]*" href="[^"]*"\s*\/>/g, '');
    const block = ['en'].concat(LOCALES).map((l) => {
      const href = l === 'en' ? SITE + p.en : SITE + esPath(p.slug);
      return '<link rel="alternate" hreflang="' + l + '" href="' + href + '" />';
    }).concat('<link rel="alternate" hreflang="x-default" href="' + SITE + p.en + '" />').join('\n');
    const m = html.match(/<link rel="canonical" href="[^"]*"\s*\/>/);
    if (!m) { console.warn('NO canonical match in', p.src); continue; }
    html = html.replace(m[0], m[0] + '\n' + block);
    fs.writeFileSync(f, html);
    console.log('hreflang →', p.src);
  }
}

(async () => {
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new' });
  for (const p of PAGES) {
    for (const loc of LOCALES) {
      const page = await browser.newPage();
      await page.goto('file://' + path.join(ROOT, p.src), { waitUntil: 'domcontentloaded' });
      const html = await transform(page, p, loc);
      const outRel = p.slug ? loc + '/' + p.slug + '/index.html' : loc + '/index.html';
      const outAbs = path.join(ROOT, outRel);
      fs.mkdirSync(path.dirname(outAbs), { recursive: true });
      fs.writeFileSync(outAbs, html);
      console.log('wrote', outRel);
      await page.close();
    }
  }
  fs.writeFileSync(path.join(ROOT, 'sitemap.xml'), buildSitemap());
  console.log('wrote sitemap.xml');
  await browser.close();
  patchEnglishHreflang();
})();
