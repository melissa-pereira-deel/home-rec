const STEPS = [
  {
    num: "01",
    title: "Play something",
    desc: "Open any app or website you're working with. Home Rec captures the audio your Mac is playing.",
  },
  {
    num: "02",
    title: "Click Record",
    desc: "Hit the red button in the menu bar popover or the main window. Recording starts immediately. The live timer and waveform confirm audio is flowing.",
  },
  {
    num: "03",
    title: "Done.",
    desc: "Click Stop. Your WAV file lands on the Desktop with a timestamp filename. Click “Reveal in Finder” and drag it wherever you need it.",
  },
];

export default function HowItWorks() {
  return (
    <section className="section">
      <div className="wrap">
        <div className="section-head">
          <div className="eyebrow">How it works</div>
          <h2 className="h-display section-h2">
            Three steps.
            <br />
            That's it.
          </h2>
        </div>
        <div className="steps">
          {STEPS.map((step) => (
            <div key={step.num} className="step">
              <span className="step-num" aria-hidden="true">
                {step.num}
              </span>
              <div className="step-title">{step.title}</div>
              <p className="step-desc">{step.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
