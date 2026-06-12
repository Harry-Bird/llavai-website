/* gen-locales.js — generate monolingual locale pages from the trilingual source.
 *
 * The site's pages carry EN/ES/UA content inline as [data-lang] spans toggled by CSS.
 * That's great for users but invisible to search (one URL, mixed-language source, no
 * hreflang). This script renders each source page, strips the non-target [data-lang]
 * elements, rewrites the head (title/description/og/canonical + hreflang) and the
 * language toggle into real navigating links, and writes clean monolingual files under
 * /es/ and /uk/. It also regenerates sitemap.xml with hreflang <xhtml:link> alternates
 * and patches the English originals (reciprocal hreflang + a navigating toggle).
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

const LOCALES = ['es', 'uk'];
const OG_LOCALE = { en: 'en_GB', es: 'es_ES', uk: 'uk_UA' };
const LABEL = { en: 'EN', es: 'ES', uk: 'UA' };

// Per-page head translations. Body content is already translated in the source spans;
// only the <head> needs locale copy. No invented legal/financial figures — terms
// (fianza, NIE, nómina, zona tensionada, SERPAVI, Incasòl, aval bancario) kept verbatim.
const PAGES = [
  {
    src: 'index.html', en: '/', slug: '',
    es: { title: 'Llavai: los mejores pisos de Barcelona, llama en un toque', desc: 'Llavai te muestra primero los mejores pisos nuevos de Barcelona: puntuados, claros y con llamada en un toque. O deja que Julia llame a las agencias en español por ti.' },
    uk: { title: 'Llavai: спершу найкращі квартири Барселони, дзвінок в один дотик', desc: 'Llavai першими показує найкращі нові квартири Барселони: з оцінкою, зрозуміло та з дзвінком в один дотик. Або Julia подзвонить агентствам іспанською замість вас.' }
  },
  {
    src: 'blog/index.html', en: '/blog', slug: 'blog',
    es: { title: 'Alquilar en Barcelona: guías para extranjeros | Llavai', desc: 'Guías prácticas y directas para alquilar en Barcelona siendo extranjero: documentos, la fianza, el NIE, honorarios de agencia y cómo adelantarte a otros.' },
    uk: { title: 'Оренда в Барселоні: гайди для іноземців | Llavai', desc: 'Практичні та чіткі гайди з оренди житла в Барселоні для іноземців: документи, застава (fianza), NIE, комісія агентств і як випередити швидших претендентів.' }
  },
  {
    src: 'blog/rent-apartment-barcelona-foreigner/index.html', en: '/blog/rent-apartment-barcelona-foreigner', slug: 'blog/rent-apartment-barcelona-foreigner',
    es: { title: 'Cómo alquilar en Barcelona siendo extranjero (2026)', desc: 'Guía paso a paso para extranjeros que alquilan en Barcelona: documentos necesarios, fianza, honorarios de agencia, control de alquiler y cómo adelantarte en 2026.' },
    uk: { title: 'Як орендувати житло в Барселоні іноземцю (2026)', desc: 'Покроковий гайд для іноземців, які орендують житло в Барселоні: потрібні документи, застава, комісія агентств, контроль орендної плати та як випередити інших у 2026.' }
  },
  {
    src: 'blog/documents-to-rent-barcelona/index.html', en: '/blog/documents-to-rent-barcelona', slug: 'blog/documents-to-rent-barcelona',
    es: { title: 'Documentos para alquilar en Barcelona: NIE, nóminas y más (2026)', desc: '¿Qué documentos necesitas para alquilar en Barcelona? NIE, nóminas, extractos bancarios y aval bancario explicados: la lista completa que esperan los caseros.' },
    uk: { title: 'Документи для оренди в Барселоні: NIE, nómina та інше (2026)', desc: 'Які документи потрібні для оренди житла в Барселоні? NIE, зарплатні відомості (nómina), банківські виписки та банківська гарантія (aval bancario): повний перелік, який очікують орендодавці.' }
  },
  {
    src: 'blog/barcelona-rental-deposit-fianza/index.html', en: '/blog/barcelona-rental-deposit-fianza', slug: 'blog/barcelona-rental-deposit-fianza',
    es: { title: 'Fianza de alquiler en Barcelona: cómo funciona (2026)', desc: '¿Cuánto es la fianza de un alquiler en Barcelona? Reglas de la fianza, registro en el Incasòl, garantías adicionales y cómo recuperarla: la guía 2026 del inquilino.' },
    uk: { title: 'Застава за оренду в Барселоні: що таке fianza (2026)', desc: 'Скільки становить застава за оренду в Барселоні? Правила fianza, реєстрація в Incasòl, додаткові гарантії та як повернути заставу: гайд для орендаря 2026.' }
  },
  {
    src: 'blog/rental-cover-letter-spanish-barcelona/index.html', en: '/blog/rental-cover-letter-spanish-barcelona', slug: 'blog/rental-cover-letter-spanish-barcelona',
    es: { title: 'Carta de presentación de alquiler en español: plantilla Barcelona', desc: 'Cómo escribir una carta de presentación en español para un piso en Barcelona: plantilla para copiar, frases clave que generan confianza y qué buscan los caseros.' },
    uk: { title: 'Супровідний лист для оренди іспанською: шаблон для Барселони', desc: 'Як написати супровідний лист іспанською для квартири в Барселоні: шаблон для копіювання, ключові фрази, що викликають довіру, і що хочуть бачити орендодавці.' }
  },
  {
    src: 'blog/barcelona-rent-control-zona-tensionada/index.html', en: '/blog/barcelona-rent-control-zona-tensionada', slug: 'blog/barcelona-rent-control-zona-tensionada',
    es: { title: 'Control de alquiler en Barcelona: zona tensionada (2026)', desc: 'Barcelona es zona tensionada según la Ley de Vivienda. Así funciona el límite del alquiler, qué puede cobrar legalmente el casero y cómo te afecta el índice SERPAVI.' },
    uk: { title: 'Контроль орендної плати в Барселоні: zona tensionada (2026)', desc: 'Барселона — це zona tensionada за іспанським Житловим законом. Ось як працює обмеження орендної плати, скільки законно може просити орендодавець і як діє індекс SERPAVI.' }
  },
  {
    src: 'blog/best-neighbourhoods-barcelona-rent-expat/index.html', en: '/blog/best-neighbourhoods-barcelona-rent-expat', slug: 'blog/best-neighbourhoods-barcelona-rent-expat',
    es: { title: 'Mejores barrios para alquilar en Barcelona (extranjeros, 2026)', desc: '¿Eixample, Gràcia, Poblenou, Sant Martí o Sarrià? Análisis honestos de barrios para extranjeros que alquilan en Barcelona: ambiente, transporte, precios y para quién.' },
    uk: { title: 'Найкращі райони для оренди в Барселоні для іноземців (2026)', desc: 'Eixample, Gràcia, Poblenou, Sant Martí чи Sarrià? Чесний огляд районів Барселони для іноземців, які орендують житло: атмосфера, транспорт, ціни та для кого підходить.' }
  },
  {
    src: 'blog/avoid-rental-scams-barcelona/index.html', en: '/blog/avoid-rental-scams-barcelona', slug: 'blog/avoid-rental-scams-barcelona',
    es: { title: 'Cómo evitar estafas de alquiler en Barcelona (2026)', desc: 'El mercado de alquiler de Barcelona atrae estafadores que buscan extranjeros. Detecta anuncios falsos, caseros fantasma y fraudes de fianza, y protege tu dinero en 2026.' },
    uk: { title: 'Як уникнути шахрайства з орендою в Барселоні (2026)', desc: 'Ринок оренди Барселони приваблює шахраїв, які націлені на іноземців. Розпізнайте фейкові оголошення, орендодавців-привидів і шахрайство із заставою, та збережіть свої гроші у 2026.' }
  }
];

// Pages NOT localized (no /es/ or /uk/ version) — in sitemap without alternates.
const ENGLISH_ONLY = [
  { loc: '/get-started', changefreq: 'monthly', priority: '0.9' },
  { loc: '/privacy', changefreq: 'yearly', priority: '0.3' }
];

// language → URL path for a page slug. en → the canonical English path.
function lpath(loc, p) {
  if (loc === 'en') return p.en;
  return p.slug ? '/' + loc + '/' + p.slug : '/' + loc + '/';
}

// 3-way navigating toggle markup (current language active, others link out).
function toggleHTML(current, p) {
  return ['en'].concat(LOCALES).map((loc) => {
    if (loc === current) return '<button type="button" class="active" aria-pressed="true">' + LABEL[loc] + '</button>';
    return '<button type="button" aria-pressed="false" onclick="location.href=\'' + lpath(loc, p) + '\'">' + LABEL[loc] + '</button>';
  }).join('<span class="lang-sep" aria-hidden="true">/</span>');
}

async function transform(page, p, loc) {
  const baseDir = p.en === '/' ? '/' : p.en + '/';
  const cfg = {
    lang: loc, ogLocale: OG_LOCALE[loc], site: SITE, en: p.en, locPath: lpath(loc, p),
    title: p[loc].title, desc: p[loc].desc, baseDir, toggle: toggleHTML(loc, p),
    alts: ['en'].concat(LOCALES).map((l) => ({ hl: l, href: SITE + lpath(l, p) }))
  };
  await page.evaluate((cfg) => {
    document.documentElement.lang = cfg.lang;
    document.body.classList.add(cfg.lang);
    document.querySelectorAll('[src],[href]').forEach((el) => {
      ['src', 'href'].forEach((attr) => {
        const v = el.getAttribute(attr);
        if (!v || /^(https?:|\/\/|\/|#|mailto:|tel:|data:)/i.test(v)) return;
        el.setAttribute(attr, cfg.baseDir + v);
      });
    });
    document.querySelectorAll('[data-lang]').forEach((el) => { if (el.getAttribute('data-lang') !== cfg.lang) el.remove(); });
    document.querySelectorAll('.lang-toggle[role="group"]').forEach((g) => { g.innerHTML = cfg.toggle; });
    // language is fixed by URL now → neutralize the localStorage auto-switch (setLang(s)
    // would otherwise blank-page a returning visitor whose stored lang ≠ this page).
    document.querySelectorAll('script:not([src])').forEach((s) => {
      if (s.textContent.indexOf('llavai-lang') !== -1) s.textContent = s.textContent.replace(/setLang\(\s*s\s*\)/g, 'void 0');
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
    document.head.querySelectorAll('link[rel="alternate"][hreflang]').forEach((l) => l.remove());
    function alt(hl, href) { var l = document.createElement('link'); l.setAttribute('rel', 'alternate'); l.setAttribute('hreflang', hl); l.setAttribute('href', href); document.head.appendChild(l); }
    cfg.alts.forEach((a) => alt(a.hl, a.href));
    alt('x-default', cfg.site + cfg.en);
  }, cfg);
  // Removing head elements (hreflang/data-lang) leaves orphaned whitespace text nodes;
  // collapse runs of blank lines so repeated runs are byte-identical (idempotent).
  const body = await page.evaluate(() => document.documentElement.outerHTML);
  return ('<!DOCTYPE html>\n' + body + '\n').replace(/\n{3,}/g, '\n\n');
}

function buildSitemap() {
  const lines = ['<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">'];
  const xhtml = (p) => ['en'].concat(LOCALES).map((l) =>
    '    <xhtml:link rel="alternate" hreflang="' + l + '" href="' + SITE + lpath(l, p) + '" />')
    .concat('    <xhtml:link rel="alternate" hreflang="x-default" href="' + SITE + p.en + '" />').join('\n');
  const block = (loc, p, pr) => ['  <url>', '    <loc>' + loc + '</loc>', xhtml(p), '    <changefreq>monthly</changefreq>', '    <priority>' + pr + '</priority>', '  </url>'].join('\n');
  for (const p of PAGES) {
    const pr = p.slug === '' ? '1.0' : p.slug === 'blog' ? '0.8' : '0.7';
    lines.push(block(SITE + p.en, p, pr));
    for (const l of LOCALES) lines.push(block(SITE + lpath(l, p), p, pr));
  }
  for (const e of ENGLISH_ONLY) lines.push(['  <url>', '    <loc>' + SITE + e.loc + '</loc>', '    <changefreq>' + e.changefreq + '</changefreq>', '    <priority>' + e.priority + '</priority>', '  </url>'].join('\n'));
  lines.push('</urlset>', '');
  return lines.join('\n');
}

// English originals: reciprocal hreflang + a navigating toggle + neutralized auto-switch.
// Text-based (no DOM round-trip), idempotent.
function patchEnglish() {
  for (const p of PAGES) {
    const f = path.join(ROOT, p.src);
    let html = fs.readFileSync(f, 'utf8');
    // hreflang (strip managed links, re-add)
    html = html.replace(/\n\s*<link rel="alternate" hreflang="[^"]*" href="[^"]*"\s*\/>/g, '');
    const block = ['en'].concat(LOCALES).map((l) => '<link rel="alternate" hreflang="' + l + '" href="' + SITE + lpath(l, p) + '" />')
      .concat('<link rel="alternate" hreflang="x-default" href="' + SITE + p.en + '" />').join('\n');
    const m = html.match(/<link rel="canonical" href="[^"]*"\s*\/>/);
    if (m) html = html.replace(m[0], m[0] + '\n' + block); else console.warn('NO canonical in', p.src);
    // toggle: ES/UA buttons navigate to their locale URLs (idempotent — only matches setLang form)
    for (const loc of LOCALES) {
      html = html.split("onclick=\"setLang('" + loc + "')\"").join("onclick=\"location.href='" + lpath(loc, p) + "'\"");
    }
    // neutralize the on-load auto-switch so the English URL stays English
    html = html.replace(/setLang\(\s*s\s*\)/g, 'void 0');
    fs.writeFileSync(f, html);
    console.log('patched EN', p.src);
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
  patchEnglish();
})();
