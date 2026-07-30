const APPS = ["Ableton Live", "Logic Pro", "GarageBand", "Any app"];

export default function ComingSoon() {
  return (
    <section className="section">
      <div className="wrap">
        {/* Same marginal-label grid as every section head: the status tag sits
            in the margin column, the statement in the main column. */}
        <div className="per-app-card">
          <div>
            <div className="badge">Coming soon</div>
          </div>
          <div>
            <h2 className="h-display per-app-h2">
              Record one app.
              <br />
              Leave the rest alone.
            </h2>
            <p className="per-app-desc">
              Per-application audio capture built for DJs, producers, and
              beatmakers. Record just the app you're working in — no Slack
              pings, no background audio creeping into your mix. Finally.
            </p>
            <div className="chips" aria-label="Supported apps">
              {APPS.map((app) => (
                <div key={app} className="chip">
                  {app}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
