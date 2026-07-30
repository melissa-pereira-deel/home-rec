import AppleLogo from "./AppleLogo.tsx";
import { LINKS } from "../links.ts";

export default function DownloadSection() {
  return (
    <section className="section" id="download">
      <div className="wrap">
        {/* The fine print used to run as one wrapping, centered, dot-separated
            row. Rebuilt as a spec column; the release-notes and checksum links
            moved to the footer, where the rest of the site's links live. */}
        <div className="dl-grid">
          <div>
            <div className="eyebrow">Ready to start?</div>
            <h2 className="h-display dl-h2">It's all yours.</h2>
            <p className="dl-sub">
              Free now, free always. Built by one person. If Home Rec earns a
              spot on your Mac, you can buy me a coffee — but it's a gift, not
              a fee.
            </p>
            <div className="dl-ctas">
              <a href={LINKS.dmg} className="btn btn-red">
                <AppleLogo size={14} />
                Download for macOS
              </a>
              <a
                href={LINKS.coffee}
                className="btn btn-ghost"
                target="_blank"
                rel="noopener"
              >
                Buy me a coffee
              </a>
            </div>
          </div>

          <ul className="spec-list">
            <li>macOS 15 (Sequoia) or later</li>
            <li>Apple Silicon &amp; Intel</li>
            <li>Signed &amp; notarized</li>
            <li>No telemetry</li>
            <li>
              <a href={LINKS.github} target="_blank" rel="noopener">
                Open source on GitHub ↗
              </a>
            </li>
          </ul>
        </div>
      </div>
    </section>
  );
}
