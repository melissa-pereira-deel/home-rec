import { useEffect, useRef, useState } from "react";

/* The Glass recorder, rebuilt native to the page: glass panel, mono timecode,
   live waveform, red record pill. Mirrors the app's recording state — a thin
   dotted amplitude line with a hot red burst at the write head.

   Motion honors prefers-reduced-motion (frozen frame at 0:08.7) and pauses
   off-screen via IntersectionObserver, matching Canvas UI's own guidance. */

const FROZEN_SECONDS = 8.7;

function formatTimecode(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds - m * 60;
  const whole = Math.floor(s);
  const tenth = Math.floor((s - whole) * 10);
  return `${m}:${String(whole).padStart(2, "0")}.${tenth}`;
}

/** Deterministic pseudo-random so the static (reduced-motion) frame is stable. */
function hashNoise(n: number): number {
  const x = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
}

function TakeThumb({ seed }: { seed: number }) {
  const bars = Array.from({ length: 26 }, (_, i) => {
    const h = 2 + hashNoise(seed * 100 + i) * 9;
    return (
      <rect
        key={i}
        x={i * 2.6}
        y={7 - h / 2}
        width={1.3}
        height={h}
        rx={0.65}
        fill="currentColor"
      />
    );
  });
  return (
    <svg
      className="take-thumb"
      width="68"
      height="14"
      viewBox="0 0 68 14"
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

    function draw(time: number) {
      const c = canvasRef.current;
      const context = ctx;
      if (!c || !context) return;

      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const w = c.clientWidth;
      const h = c.clientHeight;
      if (c.width !== w * dpr || c.height !== h * dpr) {
        c.width = w * dpr;
        c.height = h * dpr;
      }
      context.setTransform(dpr, 0, 0, dpr, 0, 0);
      context.clearRect(0, 0, w, h);

      const mid = h / 2;
      const step = 5;
      const count = Math.floor((w - 24) / step);
      // Write head sweeps left→right and wraps, like the app's monitor strip.
      const headIndex = reduced
        ? Math.floor(count * 0.72)
        : Math.floor(((time / 9000) % 1) * count);

      for (let i = 0; i < count; i += 1) {
        const x = 12 + i * step;
        const distance = headIndex - i;
        const isTrail = distance >= 0 && distance < 9;

        if (isTrail) {
          // Hot red burst trailing the write head.
          const falloff = 1 - distance / 9;
          const jitter = reduced
            ? hashNoise(i * 3.7)
            : 0.35 + 0.65 * Math.abs(Math.sin(time / 90 + i * 1.7));
          const amp = 3 + falloff * jitter * (h * 0.36);
          context.fillStyle = `rgba(242, 58, 58, ${0.45 + 0.55 * falloff})`;
          context.fillRect(x - 1, mid - amp, 2, amp * 2);
        } else {
          // Idle dotted line — quiet signal, matching the app at rest.
          const idle = hashNoise(i * 1.3) * 1.4;
          context.fillStyle = "rgba(242, 58, 58, 0.34)";
          context.fillRect(x - 0.75, mid - 0.75 - idle, 1.5, 1.5 + idle * 2);
        }
      }
    }

    function frame(time: number) {
      if (!running) return;
      const dt = (time - last) / 1000;
      last = time;
      elapsed += dt;
      if (timerRef.current) {
        timerRef.current.textContent = formatTimecode(elapsed);
      }
      draw(time);
      raf = requestAnimationFrame(frame);
    }

    function start() {
      if (running || !visible || reduced) return;
      running = true;
      last = performance.now();
      raf = requestAnimationFrame(frame);
    }

    function stop() {
      running = false;
      cancelAnimationFrame(raf);
    }

    // Static frame for reduced motion (and as the pre-animation paint).
    timer.textContent = formatTimecode(reduced ? FROZEN_SECONDS : 0);
    draw(0);

    const io = new IntersectionObserver((entries) => {
      visible = entries[entries.length - 1]?.isIntersecting ?? true;
      if (visible) start();
      else stop();
    });
    io.observe(canvas);

    const ro = new ResizeObserver(() => draw(performance.now()));
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
              <circle cx="5.5" cy="4" r="1.7" fill="var(--card)" />
              <circle cx="9.5" cy="11" r="1.7" fill="var(--card)" />
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
