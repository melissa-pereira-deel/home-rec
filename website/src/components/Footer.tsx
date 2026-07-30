import { LINKS, LOCALES } from "../links.ts";

/* Rebuilt footer.

   The previous one was a single flex row with `justify-content: space-between`
   and no responsive handling. Below roughly 740px the two columns silently
   stacked, but the right column kept `text-align: right` and the language list
   kept `justify-content: flex-end` — so seven mono links wrapped into ragged
   right-aligned lines with orphans, inside a block that was otherwise
   left-stacked. There was no breakpoint that flipped alignment on wrap.

   The fix is structural, not a patch: an explicit column grid, everything
   left-aligned at every width, and the language list on its own fixed column
   grid with a per-breakpoint column count. Nothing is right-aligned anywhere,
   so there is no alignment left to disagree with the stacking. */

export default function Footer() {
  return (
    <footer>
      <div className="wrap">
        <div className="footer-grid">
          <div className="footer-brand">
            <img src="/favicon.svg" alt="" width={22} height={22} />
            <span className="footer-name">Home Rec</span>
            <span className="footer-meta">macOS app</span>
          </div>

          {/* No column headings: the page adds no copy that was not already
              here, so each column is headed by a rule instead of a label. */}
          <nav className="footer-col footer-links" aria-label="Legal">
            <a href={LINKS.privacy}>Privacy</a>
            <a href={LINKS.terms}>Terms</a>
            <a href={LINKS.github} target="_blank" rel="noopener">
              GitHub ↗
            </a>
          </nav>

          <div className="footer-col footer-also">
            More from The Building Blocks Co.:{" "}
            <a href={LINKS.sumsight} target="_blank" rel="noopener">
              Sumsight ↗
            </a>
          </div>
        </div>

        {/* The live site's language dropdown, flattened to a static list —
            each entry links to the matching locale page on homerec.app. */}
        <nav className="footer-langs" aria-label="Language">
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

        <div className="footer-base">
          © 2026 Melissa de Britto&ensp;·&ensp;Apache 2.0 License
        </div>
      </div>
    </footer>
  );
}
