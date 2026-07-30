import Nav from "./components/Nav.tsx";
import Hero from "./components/Hero.tsx";
import Features from "./components/Features.tsx";
import HowItWorks from "./components/HowItWorks.tsx";
import ComingSoon from "./components/ComingSoon.tsx";
import DownloadSection from "./components/DownloadSection.tsx";
import Footer from "./components/Footer.tsx";

export default function App() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Features />
        <HowItWorks />
        <ComingSoon />
        <DownloadSection />
      </main>
      <Footer />
    </>
  );
}
