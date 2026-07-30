import { LINKS, LOCALES } from "../links.ts";

export default function Footer() {
  return (
    <footer>
      <div className="wrap">
        <div className="footer-top">
          <div className="footer-brand">
            <img src="/favicon.svg" alt="" width={24} height={24} />
            <span className="footer-name">Home Rec</span>
            <span className="footer-meta">macOS app</span>
          </div>
        </div>
        <div className="footer-divider" aria-hidden="true" />
        <div className="footer-bottom">
          <div>
            <div className="footer-copy">
              © 2026 Melissa de Britto&ensp;·&ensp;Apache 2.0 License
            </div>
            <div className="footer-legal">
              <a href={LINKS.privacy}>Privacy</a>
              <span className="footer-sep" aria-hidden="true">
                ·
              </span>
              <a href={LINKS.terms}>Terms</a>
              <span className="footer-sep" aria-hidden="true">
                ·
              </span>
              <a href={LINKS.github} target="_blank" rel="noopener">
                GitHub ↗
              </a>
            </div>
          </div>
          <div className="footer-br">
            <div className="footer-also">
              More from The Building Blocks Co.:{" "}
              <a href={LINKS.sumsight} target="_blank" rel="noopener">
                Sumsight ↗
              </a>
            </div>
            {/* The live site's language dropdown, flattened to a static list —
                each entry links to the matching locale page on homerec.app. */}
            <nav className="lang-list" aria-label="Language">
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
          </div>
        </div>
      </div>
    </footer>
  );
}
