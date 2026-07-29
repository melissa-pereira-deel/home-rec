import Foundation

/// Concepts under review; raw value doubles as the 1–4 keyboard shortcut.
enum ConceptID: Int, CaseIterable, Identifiable {
    case pocketOperator = 1
    case dictaphone
    case braun
    case glassShelf

    var id: Int { rawValue }

    /// Stage-chrome label. Uppercase SF Mono to stay out of the concepts' way.
    var label: String {
        switch self {
        case .pocketOperator: "1 POCKET OP"
        case .dictaphone: "2 DICTAPHONE"
        case .braun: "3 BRAUN"
        case .glassShelf: "4 GLASS"
        }
    }
}

enum ScreenID {
    case recorder
    case library
}

/// The simulated recording lifecycle. Mirrors the real app's `RecordingState`
/// (idle/starting/recording/stopping) plus the prototype-only `saved` beat and
/// a fake permission `disarmed` state.
enum TransportState: Equatable {
    case disarmed
    case idle
    case starting
    case recording(startedAt: Date)
    case stopping
    case saved(FakeRecording)

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isSaved: Bool {
        if case .saved = self { return true }
        return false
    }

    static func == (lhs: TransportState, rhs: TransportState) -> Bool {
        switch (lhs, rhs) {
        case (.disarmed, .disarmed), (.idle, .idle), (.starting, .starting),
             (.stopping, .stopping):
            true
        case let (.recording(a), .recording(b)):
            a == b
        case let (.saved(a), .saved(b)):
            a.id == b.id
        default:
            false
        }
    }
}
