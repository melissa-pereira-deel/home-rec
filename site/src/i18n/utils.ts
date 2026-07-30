import type { LocaleCode } from './config';
import en from './strings/en.json';
import ptBR from './strings/pt-BR.json';
import es from './strings/es.json';
import de from './strings/de.json';
import nl from './strings/nl.json';
import ja from './strings/ja.json';
import zhHant from './strings/zh-Hant.json';

// `en` defines the canonical shape. Typing every other locale as `typeof en`
// makes the compiler flag any translation file that is missing a key.
export type Strings = typeof en;

const STRINGS: Record<LocaleCode, Strings> = {
  en,
  'pt-BR': ptBR,
  es,
  de,
  nl,
  ja,
  'zh-Hant': zhHant,
};

export function getStrings(code: LocaleCode): Strings {
  return STRINGS[code];
}
