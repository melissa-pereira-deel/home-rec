import Nav from "./components/Nav.tsx";
import Hero from "./components/Hero.tsx";
import Features from "./components/Features.tsx";
import HowItWorks from "./components/HowItWorks.tsx";
import ComingSoon from "./components/ComingSoon.tsx";
import ComingSoonGlass from "./components/ComingSoonGlass.tsx";
import DownloadSection from "./components/DownloadSection.tsx";
import Footer from "./components/Footer.tsx";

/* ?v=glass swaps in the translucent per-app section. Read once at module
   scope — this is a static page with no routing, and the variant is a
   design comparison, not app state. */
const VARIANT = new URLSearchParams(window.location.search).get("v");

export default function App() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Features />
        <HowItWorks />
        {VARIANT === "glass" ? <ComingSoonGlass /> : <ComingSoon />}
        <DownloadSection />
      </main>
      <Footer />
    </>
  );
}
