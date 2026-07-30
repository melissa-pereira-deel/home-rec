import { LINKS, LOCALES } from "../links.ts";

/* Three bands: brand + navigation + language on one row, then the legal line
   with the sister-product credit set to its right in the same register.

   The previous version stacked Privacy/Terms/GitHub as a vertical column,
   which left three short links marooned in a wide track, and laid all seven
   locales out flat — a full row that divides into no column count without
   orphaning one. Both are now horizontal, and the locales are a disclosure. */

const CURRENT = LOCALES.find((locale) => "current" in locale) ?? LOCALES[0];

export default function Footer() {
  return (
    <footer>
      <div className="wrap">
        <div className="footer-top">
          <div className="footer-brand">
            <img src="/favicon.svg" alt="" width={22} height={22} />
            <span className="footer-name">Home Rec</span>
            <span className="footer-meta">macOS app</span>
          </div>

          <nav className="footer-links" aria-label="Site">
            <a href={LINKS.privacy}>Privacy</a>
            <a href={LINKS.terms}>Terms</a>
            <a href={LINKS.github} target="_blank" rel="noopener">
              GitHub ↗
            </a>
          </nav>

          {/* `details` gives a real disclosure with keyboard support and no
              script; each entry still links to its locale page as before. */}
          <details className="lang-menu">
            <summary>
              {CURRENT.label}
              <svg
                width="9"
                height="6"
                viewBox="0 0 9 6"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.3"
                strokeLinecap="round"
                aria-hidden="true"
              >
                <path d="M1 1.25 4.5 4.75 8 1.25" />
              </svg>
            </summary>
            <nav aria-label="Language">
              {LOCALES.map((locale) => (
                <a
                  key={locale.lang}
                  href={locale.href}
                  hrefLang={locale.lang}
                  lang={locale.lang}
                  aria-current={"current" in locale ? true : undefined}
                >
                  {locale.label}
                </a>
              ))}
            </nav>
          </details>
        </div>

        <div className="footer-base">
          <span>© 2026 Melissa de Britto&ensp;·&ensp;Apache 2.0 License</span>
          <span className="footer-also">
            More from The Building Blocks Co.:{" "}
            <a href={LINKS.sumsight} target="_blank" rel="noopener">
              Sumsight ↗
            </a>
          </span>
        </div>
      </div>
    </footer>
  );
}
