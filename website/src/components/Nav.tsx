import AppleLogo from "./AppleLogo.tsx";
import { LINKS } from "../links.ts";

export default function Nav() {
  return (
    <nav className="nav">
      <div className="wrap nav-inner">
        <a href="/" className="nav-logo">
          <img src="/favicon.svg" alt="" width={27} height={27} />
          <span className="logo-name">Home Rec</span>
        </a>
        <div className="nav-actions">
          <span className="nav-meta">wav · 48khz · lossless</span>
          <a href={LINKS.dmg} className="btn btn-red btn-sm">
            <AppleLogo size={11} />
            Download for macOS
          </a>
        </div>
      </div>
    </nav>
  );
}
