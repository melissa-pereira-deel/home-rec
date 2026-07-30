import Liquid from "@/components/canvasui/Liquid.tsx";
import AppleLogo from "./AppleLogo.tsx";
import RecorderCard from "./RecorderCard.tsx";
import { LINKS } from "../links.ts";

/* The hero wears the page's single Canvas UI component: Liquid, tuned way
   down. The dye is the GSTheme backdrop blue, so pointer movement stirs the
   same quiet mesh the app's glass blurs — atmosphere, not spectacle. The
   component pauses off-screen, honors prefers-reduced-motion, and in
   browsers without the html-in-canvas origin trial it degrades to a soft
   fluid glow over plain HTML (content stays untouched and interactive). */

export default function Hero() {
  return (
    <section className="hero">
      <div className="hero-mesh" aria-hidden="true" />
      <Liquid
        color={[0.1, 0.14, 0.38]}
        intensity={0.85}
        blend={3}
        distortion={0.25}
        radius={0.22}
        force={0.9}
        curl={1.4}
        densityDissipation={0.94}
        dyeResolution={512}
      >
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
              <div className="hero-req">
                <span>macOS 15+</span>
                <span className="req-sep" aria-hidden="true" />
                <span>Apple Silicon &amp; Intel</span>
                <span className="req-sep" aria-hidden="true" />
                <span>No account required</span>
              </div>
            </div>

            <RecorderCard />
          </div>
        </div>
      </Liquid>
    </section>
  );
}
