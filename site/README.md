# Home Rec — Website

Marketing site for **[Home Rec](https://github.com/melissa-pereira-deel/home-rec)**, the one-click macOS audio recorder. Live at **[homerec.app](https://homerec.app)**.

A statically generated, multilingual landing page built with [Astro](https://astro.build) and deployed on [Vercel](https://vercel.com).

> This repo is **just the website**. The macOS app lives in a separate repo: [`home-rec`](https://github.com/melissa-pereira-deel/home-rec).

---

## Design language (July 2026)

Flat / Swiss, studied from [untitled.stream](https://untitled.stream): near-black
ground, a single accent red (`#F23A3A`), and structure carried by hairline rules,
column alignment and whitespace rather than by depth. Single-theme dark by choice
— the near-black ground is the brand, exactly as the app has no light mode.

Notes for anyone editing it:

- **Closed type scale.** 12 / 13 / 15 · 18 · 31 / 37 / 45 / 54 / 78, ratio 1.2,
  with 22 and 26 held in reserve. Two weights only (400, 500). Do not introduce
  an off-scale size to solve a local layout problem.
- **Rules are rare on purpose.** The page runs ~17 of them. A rule separates;
  proximity and a shared left edge group. Before adding one, check whether space
  can do the job.
- **No `text-transform` on translatable copy.** A previous build lower-cased
  labels in CSS, which rendered `macOS` as "macos" and `GitHub` as "github". Set
  the case in the locale JSON instead.
- **One left edge.** Eyebrow, headline, first card, first step, footer brand and
  the legal line all share the gutter. Verify with a computed-style check before
  shipping layout changes.

## Features

- **7 languages** — English (default) plus Português (BR), Español, Deutsch, Nederlands, 日本語, and 繁體中文.
- **SEO-first internationalization** — real, server-rendered HTML per language at its own URL, symmetric `hreflang` annotations (+ `x-default`), per-locale `<title>`/meta/Open Graph/canonical/`<html lang>`, `SoftwareApplication` structured data, and a multilingual sitemap.
- **Manual language switcher** — accessible dropdown in the nav + list in the footer. No IP-based auto-redirect (per [Google's guidance](https://developers.google.com/search/docs/specialty/international/managing-multi-regional-sites)), so indexing and bilingual/VPN visitors aren't disrupted.
- **All copy in JSON** — every translatable string lives in `src/i18n/strings/<locale>.json`. Edit text without touching markup.
- **Zero-JS by default** — Astro ships static HTML; the only inline scripts are Google Analytics, the click tracker, and the hero recorder's canvas waveform (which honours `prefers-reduced-motion` and pauses off-screen).
- **Analytics** — GA4 (`G-56GPLH521X`) with custom events `download_click` and `buy_me_a_coffee_click` fired on the relevant links across every locale.

## URL structure

English is served at the root to preserve its existing URL/SEO; every other locale lives under a subdirectory (which consolidates domain authority under one domain).

| Locale | URL | `hreflang` |
|--------|-----|-----------|
| English | `/` | `en` (+ `x-default`) |
| Português (BR) | `/pt-br/` | `pt-BR` |
| Español | `/es/` | `es` |
| Deutsch | `/de/` | `de` |
| Nederlands | `/nl/` | `nl` |
| 日本語 | `/ja/` | `ja` |
| 繁體中文 | `/zh/` | `zh-Hant` |

## Tech stack

- **[Astro](https://astro.build)** — static site generator (`output: 'static'`)
- **[@astrojs/sitemap](https://docs.astro.build/en/guides/integrations-guide/sitemap/)** — multilingual sitemap
- Plain CSS (no framework) — design tokens + the original handcrafted styles
- **Vercel** — hosting + CI/CD

## Project structure

```
.
├── astro.config.mjs          # site config + sitemap integration
├── vercel.json               # framework: astro (build command + output dir)
├── public/                   # static assets served as-is
│   ├── favicon.ico / .svg
│   ├── apple-touch-icon.png
│   └── robots.txt
└── src/
    ├── layouts/Base.astro        # <head>: SEO, hreflang, GA, fonts, JSON-LD + click tracker
    ├── components/Landing.astro  # page body (all sections + language switcher)
    ├── pages/
    │   ├── index.astro           # English, at /
    │   └── [locale]/index.astro  # generates /pt-br/, /es/, /de/, /nl/, /ja/, /zh/
    ├── styles/global.css         # all site styles
    └── i18n/
        ├── config.ts             # locale list (code, URL path, native label)
        ├── utils.ts              # loads the right strings per locale
        └── strings/
            ├── en.json           # source of truth for the string shape
            ├── pt-BR.json
            ├── es.json
            ├── de.json
            ├── nl.json
            ├── ja.json
            └── zh-Hant.json
```

`en.json` defines the canonical set of keys; the other locale files are type-checked against it, so a missing key fails the build.

## Local development

Requires Node.js 18.20.8+, 20.3+, or 22+.

```bash
npm install
npm run dev       # dev server at http://localhost:4321
npm run build     # static build into dist/
npm run preview   # serve the built dist/ locally
```

## Editing & adding translations

**Edit existing copy:** change the value in `src/i18n/strings/<locale>.json` and rebuild. Strings containing markup (the eyebrow, headings with `<br>`, the footer copyright) are rendered as HTML — keep their tags intact. Everything else is plain text.

**Add a new language:**

1. Add an entry to `LOCALES` in `src/i18n/config.ts` (`code` = BCP-47 tag, `path` = URL segment, `label` = native name).
2. Import its JSON in `src/i18n/utils.ts` and add it to the `STRINGS` map.
3. Create `src/i18n/strings/<code>.json` with all keys from `en.json`.

Routing, hreflang, the sitemap, and the language switcher update automatically.

## Deployment (Vercel)

The Vercel project **`home-rec-site`** is connected to this GitHub repo:

- **Push to `main` → production deploy** to [homerec.app](https://homerec.app).
- **Pull requests → preview deployments** at a unique URL (gated by Vercel deployment protection).
- Build is configured via `vercel.json` (`framework: astro` → `astro build`, output `dist/`), so no dashboard build settings are required.

After a deploy that adds or changes languages, (re)submit `https://homerec.app/sitemap-index.xml` in [Google Search Console](https://search.google.com/search-console).

## Analytics

Google Analytics 4 (`G-56GPLH521X`) loads on every page via `src/layouts/Base.astro`. A small delegated click listener (same file) fires two custom events:

- `download_click` — any link to the `.dmg` (nav, hero, download section)
- `buy_me_a_coffee_click` — any `buymeacoffee.com` link

Both include `link_url` and `link_text` params so clicks can be segmented by button. To track them as conversions, mark them as key events in GA4 (**Admin → Events**).

## License

The Home Rec app is released under the Apache 2.0 License. See the [app repository](https://github.com/melissa-pereira-deel/home-rec) for details.

© The Building Blocks Co.
