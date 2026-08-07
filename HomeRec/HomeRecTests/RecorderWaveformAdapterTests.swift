//
//  RecorderWaveformAdapterTests.swift
//  HomeRecTests
//
//  The signed-to-magnitude conversion behind the bar renderer.
//
//  This is the only new logic the design-system migration introduced — everything
//  else is styling, which no unit test can judge. So it is worth testing
//  properly: it sits between an audio path that is frozen by its own tests and a
//  renderer that is vendored, and it is the one place a visual change could
//  introduce a behavioural bug.
//

import Testing
import Foundation
@testable import HomeRec

struct RecorderWaveformAdapterTests {

    @Test("Signed input becomes unsigned magnitudes")
    func magnitudesAreUnsigned() {
        let signed: [Float] = [-0.8, 0.4, -0.2, 0.6]
        let bars = RecorderWaveformAdapter.magnitudes(signed, bucketedTo: 4)

        #expect(bars.allSatisfy { $0 >= 0 })
        // Louder in, taller out — the mapping is monotonic even though it is
        // no longer linear.
        #expect(bars[0] > bars[1])
        #expect(bars[1] > bars[2])
        #expect(bars[3] > bars[1])
    }

    /// The bug this exists to prevent: real program material sits far below full
    /// scale, and a linear mapping put it under the renderer's 2pt minimum bar.
    /// Measured from a live capture, instantaneous peaks were ~0.02 (−34 dBFS)
    /// with the file peaking at −8.6 dBFS — audible, healthy audio that drew as
    /// a flat dotted line, indistinguishable from silence.
    @Test("Quiet-but-present audio is clearly visible, not floored")
    func quietAudioIsVisible() {
        // −34 dBFS, the level that rendered as nothing.
        let bars = RecorderWaveformAdapter.magnitudes([0.02], bucketedTo: 1)

        // On a 60pt view the renderer floors anything under 0.033 to 2pt.
        // This has to clear that by a wide margin to read as signal.
        #expect(bars[0] > 0.3, "−34 dBFS must be visible, got \(bars[0])")
        #expect(bars[0] < 0.9, "−34 dBFS must not read as near-clipping")
    }

    /// Loud and quiet must stay distinguishable after the curve is applied —
    /// a mapping that made everything visible by making everything full-height
    /// would trade one lie for another.
    @Test("Level differences survive the curve")
    func levelsRemainDistinguishable() {
        let quiet = RecorderWaveformAdapter.magnitudes([0.01], bucketedTo: 1)[0]
        let mid = RecorderWaveformAdapter.magnitudes([0.1], bucketedTo: 1)[0]
        let loud = RecorderWaveformAdapter.magnitudes([1.0], bucketedTo: 1)[0]

        #expect(quiet < mid)
        #expect(mid < loud)
        #expect(loud == 1)
    }

    /// Below the floor there is nothing worth drawing, and drawing it would be a
    /// lie about incoming audio in a recorder.
    @Test("Sub-floor noise still reads as silence")
    func subFloorIsSilent() {
        // −80 dBFS: below the −60 dBFS floor.
        #expect(RecorderWaveformAdapter.magnitudes([0.0001], bucketedTo: 1)[0] == 0)
    }

    /// The renderer maps a sample to a fraction of the view's height, so anything
    /// above 1 would draw outside the frame.
    @Test("Out-of-range input is clamped to 1")
    func magnitudesAreClamped() {
        let bars = RecorderWaveformAdapter.magnitudes([-4.0, 2.5], bucketedTo: 2)

        #expect(bars == [1, 1])
    }

    /// Mirrors the view model's contract: it publishes 200 zeros at rest and
    /// resets to them on stop. Zeros must stay zeros so the renderer draws its
    /// minimum-height bars — silence, rather than a signal that isn't there.
    @Test("Silence stays silent")
    func zeroInputStaysZero() {
        let bars = RecorderWaveformAdapter.magnitudes(Array(repeating: 0, count: 200),
                                                      bucketedTo: 123)

        #expect(bars.count == 123)
        #expect(bars.allSatisfy { $0 == 0 })
    }

    /// The whole reason bucketing exists rather than handing the renderer all 200
    /// samples: both surfaces must show the same stretch of time.
    @Test("Output length is always the requested bar count")
    func bucketingProducesExactlyBarCount() {
        let signed = (0..<200).map { Float($0) / 200 }

        for barCount in [1, 7, 82, 123, 200] {
            #expect(RecorderWaveformAdapter.magnitudes(signed, bucketedTo: barCount).count == barCount)
        }
    }

    @Test("Empty input still fills the bar count, with silence")
    func emptyInputProducesBarCountZeros() {
        let bars = RecorderWaveformAdapter.magnitudes([], bucketedTo: 12)

        #expect(bars == Array(repeating: 0, count: 12))
    }

    /// A mean would average a sentence's loud and quiet parts into one middling
    /// band. The peak is what keeps a transient visible after downsampling.
    @Test("Each bar takes its bucket's peak, not its mean")
    func bucketsTakeThePeak() {
        // Two buckets of four. A single loud sample in each must survive.
        let signed: [Float] = [0.1, 0.1, 0.9, 0.1,
                               0.2, -0.7, 0.2, 0.2]
        let bars = RecorderWaveformAdapter.magnitudes(signed, bucketedTo: 2)

        // Compare against the peaks put through the same curve: a mean would
        // land well below these, and the first bucket must stay the taller one.
        #expect(bars == [RecorderWaveformAdapter.magnitudes([0.9], bucketedTo: 1)[0],
                         RecorderWaveformAdapter.magnitudes([0.7], bucketedTo: 1)[0]])
        #expect(bars[0] > bars[1])
    }

    /// The first frames of a capture arrive before the buffer has filled, so the
    /// bucket arithmetic has to survive having fewer samples than bars.
    @Test("Fewer samples than bars still yields one bar each")
    func fewerSamplesThanBars() {
        let bars = RecorderWaveformAdapter.magnitudes([0.5, 0.25], bucketedTo: 8)

        #expect(bars.count == 8)
        #expect(bars.allSatisfy { $0 > 0 })
    }

    /// The bar count is derived from the surfaces' real widths, so a change to
    /// either would otherwise silently rescale the visible time window.
    @Test("Bar counts follow the 3pt bar pitch")
    func barCountsMatchSurfaceWidths() {
        #expect(RecorderWaveformAdapter.mainWindowBarCount == 123)   // (450 - 80) / 3
        #expect(RecorderWaveformAdapter.popoverBarCount == 82)       // (280 - 32) / 3
    }
}
