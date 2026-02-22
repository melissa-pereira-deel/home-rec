//
//  WaveformView.swift
//  HomeRec
//
//  Live waveform visualization for audio recording
//

import SwiftUI

/// A Shape that draws a waveform line from amplitude samples
struct WaveformView: Shape {
    var samples: [Float]

    var animatableData: [Float] {
        get { samples }
        set { samples = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard samples.count > 1 else {
            return Path { path in
                path.move(to: CGPoint(x: 0, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
            }
        }

        let stepX = rect.width / CGFloat(samples.count - 1)
        let midY = rect.midY
        let amplitude = rect.height / 2

        return Path { path in
            for (index, sample) in samples.enumerated() {
                let x = CGFloat(index) * stepX
                let clamped = min(max(CGFloat(sample), -1), 1)
                let y = midY - clamped * amplitude

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}
