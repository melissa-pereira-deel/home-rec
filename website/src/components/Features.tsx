/* Feature icons are the live site's SVGs, recolored to the Glass metal grey. */

const FEATURES = [
  {
    title: "Menu bar, always there",
    desc: "Home Rec lives in your menu bar and stays running when you close the window. One click opens a compact popover — waveform, timer, record button. Trigger a recording without switching focus.",
    icon: (
      <svg className="feat-icon" viewBox="0 0 36 36" fill="none" aria-hidden="true">
        <rect x="1.5" y="7" width="33" height="22" rx="3.5" stroke="currentColor" strokeWidth="2" />
        <path d="M1.5 13.5h33" stroke="currentColor" strokeWidth="2" />
        <circle cx="27" cy="10.25" r="2.5" fill="currentColor" />
      </svg>
    ),
  },
  {
    title: "Lossless WAV, every time",
    desc: "48kHz stereo PCM. No compression. No codec artifacts. Whatever goes in comes out exactly as it sounded — ready for Ableton, Logic Pro, any DAW, any audio editor, no questions asked.",
    icon: (
      <svg className="feat-icon" viewBox="0 0 36 36" fill="none" aria-hidden="true">
        <path
          d="M3 18 Q6.5 7, 10 18 Q13.5 29, 17 18 Q20.5 7, 24 18 Q27.5 29, 33 18"
          stroke="currentColor"
          strokeWidth="2.2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    ),
  },
  {
    title: "Live waveform feedback",
    desc: "Real-time amplitude visualization confirms audio is actually flowing — not just a blinking dot. The waveform appears in both the popover and the main window so you always know signal is good.",
    icon: (
      <svg className="feat-icon" viewBox="0 0 36 36" fill="none" aria-hidden="true">
        <rect x="3" y="26" width="4" height="7" rx="1.5" fill="currentColor" opacity="0.35" />
        <rect x="9" y="17" width="4" height="16" rx="1.5" fill="currentColor" opacity="0.55" />
        <rect x="15" y="9" width="4" height="24" rx="1.5" fill="currentColor" />
        <rect x="21" y="13" width="4" height="20" rx="1.5" fill="currentColor" opacity="0.75" />
        <rect x="27" y="21" width="4" height="12" rx="1.5" fill="currentColor" opacity="0.45" />
      </svg>
    ),
  },
  {
    title: "Zero setup. Works immediately.",
    desc: "No virtual audio drivers. No loopback routing. No Audio MIDI Setup. Grant the Screen Recording permission once — and that's it. Works on Apple Silicon and Intel without any configuration.",
    icon: (
      <svg className="feat-icon" viewBox="0 0 36 36" fill="none" aria-hidden="true">
        <path
          d="M18 3L21.8 13.2L32 18L21.8 22.8L18 33L14.2 22.8L4 18L14.2 13.2L18 3Z"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinejoin="round"
        />
      </svg>
    ),
  },
];

export default function Features() {
  return (
    <section className="section">
      <div className="wrap">
        <div className="section-head">
          <div className="eyebrow">Features</div>
          <h2 className="h-display section-h2">
            Built for how you
            <br />
            actually work.
          </h2>
        </div>
        <div className="feat-grid">
          {FEATURES.map((feature) => (
            <div key={feature.title} className="glass feat-card">
              {feature.icon}
              <div className="feat-title">{feature.title}</div>
              <p className="feat-desc">{feature.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
