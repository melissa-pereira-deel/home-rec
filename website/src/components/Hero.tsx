import AppleLogo from "./AppleLogo.tsx";
import RecorderCard from "./RecorderCard.tsx";
import { LINKS } from "../links.ts";

/* Flat hero. The WebGL fluid sim that used to sit behind this section is gone,
   along with the radial-gradient mesh under it — a fluid backdrop is the
   opposite register from the Swiss direction, and it was reading as breakage.
   What divides the statement from the product now is a single vertical
   hairline, and the requirements run along a rule at the foot of the section. */

export default function Hero() {
  return (
    <section className="hero">
      <div className="wrap">
        <div className="hero-inner">
          <div className="hero-copy">
            <div className="eyebrow">macOS&ensp;·&ensp;Open Source&ensp;·&ensp;Free</div>
            <h1 className="h-display hero-h1">
              Record what
              <br />
              you're hearing.
            </h1>
            <p className="hero-sub">
              Capture whatever your Mac is playing as a lossless WAV. One
              click. No drivers, no routing, no setup, no account.
            </p>
            <div className="hero-ctas">
              <a href={LINKS.dmg} className="btn btn-red">
                <AppleLogo />
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

          <div className="hero-figure">
            <RecorderCard />
          </div>
        </div>

        <div className="hero-req">
          <span>macOS 15+</span>
          <span>Apple Silicon &amp; Intel</span>
          <span>No account required</span>
        </div>
      </div>
    </section>
  );
}
