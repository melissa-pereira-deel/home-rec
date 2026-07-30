// Central locale configuration for homerec.app.
// English is the default and lives at the site root (no path prefix);
// every other locale lives under a subdirectory. `code` is the BCP-47
// value used for <html lang>, hreflang and og:locale. `path` is the URL
// segment. `label` is the native name shown in the language switcher.

export const SITE = 'https://homerec.app';
export const DEFAULT_LOCALE = 'en';

export type LocaleCode = 'en' | 'pt-BR' | 'es' | 'de' | 'nl' | 'ja' | 'zh-Hant';

export interface LocaleDef {
  code: LocaleCode;
  path: string; // '' for the default locale (served at root)
  label: string; // native name shown in the full language list / menu
  short: string; // 2-letter code shown in the compact nav switcher
}

export const LOCALES: LocaleDef[] = [
  { code: 'en', path: '', label: 'English', short: 'EN' },
  { code: 'pt-BR', path: 'pt-br', label: 'Português', short: 'PT' },
  { code: 'es', path: 'es', label: 'Español', short: 'ES' },
  { code: 'de', path: 'de', label: 'Deutsch', short: 'DE' },
  { code: 'nl', path: 'nl', label: 'Nederlands', short: 'NL' },
  { code: 'ja', path: 'ja', label: '日本語', short: 'JA' },
  { code: 'zh-Hant', path: 'zh', label: '繁體中文', short: 'ZH' },
];

export const NON_DEFAULT_LOCALES = LOCALES.filter((l) => l.code !== DEFAULT_LOCALE);

// URL path for a locale segment: '' -> '/', 'pt-br' -> '/pt-br/'.
export function localeUrl(path: string): string {
  return path ? `/${path}/` : '/';
}
