import { useEffect, useRef, useState } from "react";

/* The recorder, flat: opaque surface, hairline rules, mono timecode, red
   record control.

   The waveform was rebuilt. It used to sweep a write head across a dead dotted
   line on its own 9-second modulo loop, lighting only the nine bars behind the
   head and hard-wrapping back to x=0 — which read as a blip cycling on a flat
   line, and the wrap read as the animation running backwards. It also ran on a
   period of its own while the timer counted real elapsed time, so the two
   visibly disagreed.

   Now there is one clock. `elapsed` drives both the timecode and the strip, so
   they cannot disagree by construction. One bar is committed every BAR_MS, and
   a bar's height is a pure function of its absolute index — once written it
   never changes again, which is what makes the strip read as accumulated
   history rather than an oscillating idle line. The strip fills left→right,
   and when it reaches the right edge it does not wrap: it scrolls, the oldest
   bar falling off the left while the newest is cut at the write head. Motion
   is only ever leftward past a fixed head, which is how a live recorder
   monitor actually behaves — and it never restarts.

   Motion honors prefers-reduced-motion (frozen at a partly-filled strip) and
   pauses off-screen via IntersectionObserver. */

/* One bar committed every 90ms — the strip and the timecode share this rate. */
const BAR_MS = 90;
/* 2px bar on a 4px pitch: flat, square-ended, precisely spaced. */
const BAR_W = 2;
const PITCH = 4;
const PAD = 16;

/* 5.4s = exactly 60 bars, which leaves the frozen strip partly filled at every
   card width, so the still frame still shows history behind the head. */
const FROZEN_SECONDS = 5.4;

function formatTimecode(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds - m * 60;
  const whole = Math.floor(s);
  const tenth = Math.floor((s - whole) * 10);
  return `${m}:${String(whole).padStart(2, "0")}.${tenth}`;
}

/** Deterministic pseudo-random so every frame agrees about a given bar. */
function hashNoise(n: number): number {
  const x = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
}

/**
 * Height of the bar at absolute index `i`, 0..1. A pure function of the index
 * — never of time — so a bar committed at t=2s looks identical at t=40s.
 * A slow swell and a slower phrase give it dynamics; the noise gives it grain.
 */
function barAmplitude(i: number): number {
  /* The swell runs ~45 bars (≈4s), so a full window always shows several
     crests rather than sitting inside one long quiet passage; the phrase runs
     ~170 bars underneath it for slower variation. The floor keeps the strip
     alive — real audio has silences, but a dead-looking strip is the exact
     thing the client read as broken. */
  const swell = 0.62 + 0.38 * Math.sin(i * 0.14);
  const phrase = 0.78 + 0.22 * Math.sin(i * 0.037 + 2.1);
  const detail = 0.5 + 0.5 * hashNoise(i);
  return Math.max(0.14, Math.min(1, swell * phrase * detail * 1.55));
}

function TakeThumb({ seed }: { seed: number }) {
  const bars = Array.from({ length: 24 }, (_, i) => {
    const h = 2 + hashNoise(seed * 100 + i) * 9;
    return (
      <rect
        key={i}
        x={i * 3}
        y={7 - h / 2}
        width={1.5}
        height={h}
        fill="currentColor"
      />
    );
  });
  return (
    <svg
      className="take-thumb"
      width="72"
      height="14"
      viewBox="0 0 72 14"
      aria-hidden="true"
    >
      {bars}
    </svg>
  );
}

export default function RecorderCard() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const timerRef = useRef<HTMLSpanElement>(null);
  const [reduced, setReduced] = useState(false);

  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReduced(query.matches);
    const onChange = () => setReduced(query.matches);
    query.addEventListener("change", onChange);
    return () => query.removeEventListener("change", onChange);
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    const timer = timerRef.current;
    if (!canvas || !timer) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let raf = 0;
    let running = false;
    let visible = true;
    let elapsed = reduced ? FROZEN_SECONDS : 0;
    let last = performance.now();

    function draw(seconds: number) {
      const c = canvasRef.current;
      const context = ctx;
      if (!c || !context) return;

      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const w = c.clientWidth;
      const h = c.clientHeight;
      if (w === 0 || h === 0) return;
      if (c.width !== w * dpr || c.height !== h * dpr) {
        c.width = w * dpr;
        c.height = h * dpr;
      }
      context.setTransform(dpr, 0, 0, dpr, 0, 0);
      context.clearRect(0, 0, w, h);

      const mid = h / 2;
      const usable = Math.max(PITCH * 8, w - PAD * 2);
      const right = PAD + usable;
      const capacity = Math.floor(usable / PITCH);

      /* The single clock: bar position is derived from the same `seconds` that
         prints in the timecode. The fractional part is kept so the strip moves
         continuously instead of stepping. */
      const exactBars = (seconds * 1000) / BAR_MS;
      const written = Math.floor(exactBars);

      /* Once the tape has run past the window it scrolls: `shift` is how many
         bars have passed off the left edge. Before that it stays 0 and the
         strip simply fills. */
      const shift = Math.max(0, exactBars - capacity);
      const headX = PAD + Math.min(exactBars, capacity) * PITCH;

      /* The tape ahead of the head — a flat hairline, not a dotted idle
         waveform, so nothing ahead of the head pretends to be signal. */
      if (headX < right - 0.5) {
        context.fillStyle = "rgba(255, 255, 255, 0.1)";
        context.fillRect(headX, mid - 0.5, right - headX, 1);
      }

      /* History. Only the bars currently inside the window are visited. */
      const firstVisible = Math.max(0, Math.floor(shift) - 1);
      for (let i = firstVisible; i <= written; i += 1) {
        const x = PAD + (i - shift) * PITCH;
        if (x < PAD - PITCH || x > right) continue;
        const half = Math.max(1, barAmplitude(i) * (h * 0.42));
        /* Two flat values, no gradient falloff: the bar being cut right now,
           and everything already committed behind it. */
        context.fillStyle =
          i === written ? "#f23a3a" : "rgba(242, 58, 58, 0.72)";
        context.fillRect(x, mid - half, BAR_W, half * 2);
      }

      /* The write head, as a 1px rule. In the scrolling phase it is pinned to
         the right edge and the history moves leftward past it. */
      context.fillStyle = "rgba(242, 58, 58, 0.9)";
      context.fillRect(Math.min(headX, right - 1), 0, 1, h);
    }

    function frame(time: number) {
      if (!running) return;
      const dt = (time - last) / 1000;
      last = time;
      elapsed += dt;
      if (timerRef.current) {
        timerRef.current.textContent = formatTimecode(elapsed);
      }
      draw(elapsed);
      raf = requestAnimationFrame(frame);
    }

    function start() {
      if (running || !visible || reduced) return;
      running = true;
      /* Reset the delta clock so time spent off-screen is not counted — the
         timecode and the strip stay in step across a pause. */
      last = performance.now();
      raf = requestAnimationFrame(frame);
    }

    function stop() {
      running = false;
      cancelAnimationFrame(raf);
    }

    // Static frame for reduced motion (and as the pre-animation paint).
    timer.textContent = formatTimecode(elapsed);
    draw(elapsed);

    const io = new IntersectionObserver((entries) => {
      visible = entries[entries.length - 1]?.isIntersecting ?? true;
      if (visible) start();
      else stop();
    });
    io.observe(canvas);

    const ro = new ResizeObserver(() => draw(elapsed));
    ro.observe(canvas);

    start();

    return () => {
      stop();
      io.disconnect();
      ro.disconnect();
    };
  }, [reduced]);

  return (
    <div className="recorder-wrap">
      <div className="rec-status">
        <span className="rec-dot" aria-hidden="true" />
        recording
      </div>
      <div
        className="recorder"
        role="img"
        aria-label="Home Rec app showing a recording in progress with a live timer and waveform"
      >
        <div className="recorder-head">
          <span className="recorder-title">home rec</span>
          <span className="recorder-format">
            wav · 48kHz
            <svg
              width="15"
              height="15"
              viewBox="0 0 15 15"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.4"
              strokeLinecap="round"
              aria-hidden="true"
            >
              <path d="M1.5 4h12M1.5 11h12" />
              <circle cx="5.5" cy="4" r="1.7" fill="var(--surface)" />
              <circle cx="9.5" cy="11" r="1.7" fill="var(--surface)" />
            </svg>
          </span>
        </div>

        <div className="recorder-timer">
          <span ref={timerRef}>0:00.0</span>
        </div>

        <div className="recorder-wave">
          <canvas ref={canvasRef} aria-hidden="true" />
        </div>

        <div className="recorder-action">
          <span className="rec-pill">
            <span className="rec-glyph" aria-hidden="true" />
            stop
          </span>
        </div>

        <div className="recorder-recent-head">
          <span>recent</span>
          <span>all takes →</span>
        </div>

        <div className="take">
          <TakeThumb seed={1} />
          <span className="take-name">kitchen radio, morning</span>
          <span className="take-len">2:34</span>
        </div>
        <div className="take">
          <TakeThumb seed={2} />
          <span className="take-name">chorus idea — take 3</span>
          <span className="take-len">0:41</span>
        </div>
        <div className="take">
          <TakeThumb seed={3} />
          <span className="take-name">voice memo 14</span>
          <span className="take-len">0:19</span>
        </div>
      </div>
    </div>
  );
}
