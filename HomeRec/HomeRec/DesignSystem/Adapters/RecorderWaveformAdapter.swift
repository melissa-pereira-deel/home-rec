//
//  RecorderWaveformAdapter.swift
//  HomeRec
//
//  Turns what the recorder publishes into what the bar renderer wants.
//
//  The recorder publishes ~200 *signed* samples for a polyline that drew the
//  signal above and below a centre line. The bar renderer wants *unsigned*
//  0…1 magnitudes. Converting here, at the view boundary, is what keeps a purely
//  visual change out of the audio path: neither WaveformDownsampler nor
//  RecorderViewModel learns that a renderer changed, so their tests keep holding
//  the contracts they were written to hold.
//

import Foundation

enum RecorderWaveformAdapter {

    /// Bars are 2pt wide with a 1pt gap, so each one occupies 3pt of width.
    private static let barPitch: CGFloat = 3

    /// How many bars fit the main window's waveform: 450pt window less its 40pt
    /// padding on each side.
    static let mainWindowBarCount = barCount(forWidth: 450 - 80)

    /// And the popover's: 280pt less its 16pt padding on each side.
    static let popoverBarCount = barCount(forWidth: 280 - 32)

    static func barCount(forWidth width: CGFloat) -> Int {
        max(1, Int(width / barPitch))
    }

    /// Signed samples in, unsigned 0…1 magnitudes out, resampled to `barCount`.
    ///
    /// Each bar takes the **peak** of its bucket rather than the mean. A mean
    /// flattens speech into a uniform band — the loud and quiet parts of a
    /// sentence average out to the same middling height — while a peak keeps the
    /// transients that make a waveform legible as level.
    ///
    /// Resampling to the bar count rather than handing over all 200 samples is
    /// deliberate. The renderer shows a trailing window of whatever it is given,
    /// so passing 200 samples to a 123-bar view would silently show only the most
    /// recent ~60% of the history — and the popover, being narrower, would show a
    /// different span again. Bucketing keeps both surfaces showing the same
    /// stretch of time, which is what they showed before.
    static func magnitudes(_ signed: [Float], bucketedTo barCount: Int) -> [Float] {
        guard barCount > 0 else { return [] }
        guard !signed.isEmpty else { return Array(repeating: 0, count: barCount) }

        var bars = [Float]()
        bars.reserveCapacity(barCount)

        for index in 0..<barCount {
            let start = (index * signed.count) / barCount
            // `max(start + 1, …)` keeps every bucket non-empty when there are
            // fewer samples than bars, which happens on the first frames of a
            // capture before the buffer has filled.
            let end = min(signed.count, max(start + 1, ((index + 1) * signed.count) / barCount))

            var peak: Float = 0
            for position in start..<end {
                peak = max(peak, abs(signed[position]))
            }
            bars.append(perceptual(min(peak, 1)))
        }

        return bars
    }

    /// Amplitude below which there is nothing worth drawing.
    ///
    /// −60 dBFS is quiet enough to sit under the noise floor of anything the
    /// user is actually trying to record, so nothing real is lost, and drawing
    /// below it would be claiming audio is arriving when it isn't — the one lie
    /// a recorder must not tell.
    private static let floorDB: Float = -60

    /// Linear amplitude → the 0…1 the bar renderer expects, on a **decibel**
    /// scale rather than a linear one.
    ///
    /// This is the difference between a working waveform and a dead one, and it
    /// is not a matter of taste. The renderer maps its input straight onto the
    /// view's height and floors every bar at 2pt, so on the 60pt main-window
    /// waveform anything under 0.033 — that is, under −29.6 dBFS — draws as the
    /// minimum bar and is indistinguishable from silence.
    ///
    /// Real material lives below that line. Measured from a live system-audio
    /// capture: file peak −8.6 dBFS, RMS −38.7 dBFS, instantaneous peaks around
    /// 0.02. Linearly, that is a 1.2pt bar — so a perfectly good recording drew
    /// a flat dotted line. Loudness is perceived logarithmically, so the scale
    /// that matches the ear is also the one that uses the height available.
    private static func perceptual(_ amplitude: Float) -> Float {
        guard amplitude > 0 else { return 0 }
        let db = 20 * log10(amplitude)
        guard db > floorDB else { return 0 }
        return min(1, (db - floorDB) / -floorDB)
    }
}
