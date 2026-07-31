//
//  AudioSource.swift
//  HomeRec
//
//  What to capture audio from (BL-100). `AudioSourceManager` owns selection
//  and persistence; `ScreenCaptureAudioManager` resolves a source into the
//  matching SCContentFilter at capture setup time.
//

import Foundation

nonisolated enum AudioSource: Codable, Sendable, Equatable {
    case systemAll
    case app(bundleID: String)
}

/// The *category* a source belongs to, which is what the menu renders as a row.
///
/// One row per kind, always — so the menu's shape never changes in response to
/// what the world does (an app launching, a mic being plugged in). Only the
/// contents behind a row change (BL-111).
nonisolated enum AudioSourceKind: Hashable, Sendable, CaseIterable {
    /// Everything the Mac plays. A singleton: it needs no submenu.
    case systemAll
    /// One running app, chosen from a list enumerated at runtime.
    case app
    // BL-130 adds `.microphone`, also runtime-enumerated.
}

nonisolated extension AudioSource {
    /// ⚠️ Exhaustive switch with **no `default`** on purpose: adding a case to
    /// `AudioSource` must fail to compile until someone classifies it. This is
    /// the guarantee BL-111 chose instead of a provider registry, which would
    /// have been an array — and an array is not exhaustiveness.
    var kind: AudioSourceKind {
        switch self {
        case .systemAll: return .systemAll
        case .app:       return .app
        }
    }
}
