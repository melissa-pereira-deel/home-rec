import AppleLogo from "./AppleLogo.tsx";
import { LINKS } from "../links.ts";

export default function DownloadSection() {
  return (
    <section className="section" id="download">
      <div className="wrap">
        <div className="dl-wrap">
          <div className="eyebrow">Ready to start?</div>
          <h2 className="h-display dl-h2">It's all yours.</h2>
          <p className="dl-sub">
            Free now, free always. Built by one person. If Home Rec earns a spot
            on your Mac, you can buy me a coffee — but it's a gift, not a fee.
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
          <div className="dl-fine">
            <span>macOS 15 (Sequoia) or later</span>
            <span className="dl-fine-dot" aria-hidden="true" />
            <span>Apple Silicon &amp; Intel</span>
            <span className="dl-fine-dot" aria-hidden="true" />
            <span>Signed &amp; notarized</span>
            <span className="dl-fine-dot" aria-hidden="true" />
            <span>No telemetry</span>
            <span className="dl-fine-dot" aria-hidden="true" />
            <a href={LINKS.releaseNotes} target="_blank" rel="noopener">
              Release notes ↗
            </a>
            <span className="dl-fine-dot" aria-hidden="true" />
            <a href={LINKS.sha256} target="_blank" rel="noopener">
              SHA-256 ↗
            </a>
            <span className="dl-fine-dot" aria-hidden="true" />
            <a href={LINKS.github} target="_blank" rel="noopener">
              Open source on GitHub ↗
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}
