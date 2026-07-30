import AppleLogo from "./AppleLogo.tsx";
import { LINKS } from "../links.ts";

export default function DownloadSection() {
  return (
    <section className="section" id="download">
      <div className="wrap">
        {/* The fine print that used to sit here has been distributed to where
            each part belongs: the hardware and privacy facts to the hero spec
            strip, the links to the footer nav. The close is just the offer. */}
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
        </div>
      </div>
    </section>
  );
}
