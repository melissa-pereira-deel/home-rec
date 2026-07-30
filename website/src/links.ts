/* Every link points where it points on the live site today. The prototype is a
   standalone page, so site-relative paths (privacy, terms, locales) are made
   absolute against homerec.app. */

export const LINKS = {
  dmg: "https://github.com/melissa-pereira-deel/home-rec/releases/latest/download/HomeRec.dmg",
  coffee: "https://buymeacoffee.com/melissadebritto",
  releaseNotes: "https://github.com/melissa-pereira-deel/home-rec/releases/latest",
  sha256:
    "https://github.com/melissa-pereira-deel/home-rec/releases/latest/download/HomeRec.dmg.sha256",
  github: "https://github.com/melissa-pereira-deel/home-rec",
  privacy: "https://homerec.app/privacy",
  terms: "https://homerec.app/terms",
  sumsight: "https://www.sumsight.app",
} as const;

export const LOCALES = [
  { href: "https://homerec.app/", label: "English", lang: "en", current: true },
  { href: "https://homerec.app/pt-br/", label: "Português", lang: "pt-BR" },
  { href: "https://homerec.app/es/", label: "Español", lang: "es" },
  { href: "https://homerec.app/de/", label: "Deutsch", lang: "de" },
  { href: "https://homerec.app/nl/", label: "Nederlands", lang: "nl" },
  { href: "https://homerec.app/ja/", label: "日本語", lang: "ja" },
  { href: "https://homerec.app/zh/", label: "繁體中文", lang: "zh-Hant" },
] as const;
