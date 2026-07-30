const APPS = ["Ableton Live", "Logic Pro", "GarageBand", "Any app"];

/* Variant of ComingSoon: same grid, same copy, translucent surface.
   Reached with ?v=glass — the flat version stays the default.

   Glass only reads as glass when there is something behind it to
   refract, so the card sits over a contained ambient wash instead of
   the flat ground. The wash is clipped to the section and stays under
   the card's own blur, so nothing bleeds into the neighbouring
   sections' flat register. */
export default function ComingSoonGlass() {
  return (
    <section className="section">
      <div className="wrap">
        <div className="per-app-stage">
          <div className="per-app-ambient" aria-hidden="true" />
          {/* Same marginal-label grid as every section head: the status tag sits
              in the margin column, the statement in the main column. */}
          <div className="per-app-card per-app-card--glass">
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
      </div>
    </section>
  );
}
