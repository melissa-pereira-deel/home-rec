import Foundation

/// Library filter, store-held so it survives screen switches. Chips derive
/// from the full format set (every shipping format gets a chip).
enum LibraryFilter: Equatable {
    case all
    case format(FakeFormat)
    case thisWeek

    var label: String {
        switch self {
        case .all: "all"
        case .format(let format): format.rawValue
        case .thisWeek: "this week"
        }
    }

    /// `now` injected — snapshot determinism forbids `Date.now` in predicates.
    func matches(_ recording: FakeRecording, now: Date) -> Bool {
        switch self {
        case .all: true
        case .format(let format): recording.format == format
        case .thisWeek: recording.date > now.addingTimeInterval(-7 * 86_400)
        }
    }

    static var chips: [LibraryFilter] {
        [.all] + FakeFormat.allCases.map { .format($0) } + [.thisWeek]
    }
}

/// Library stress seeds: how many takes the fake library holds.
enum LibrarySeed: Int, CaseIterable {
    case empty = 0
    case three = 3
    case eight = 8
    case fifty = 50
}
