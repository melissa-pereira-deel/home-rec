import AppKit
import SwiftUI
import GlassKit
import StageKit
import PocketOperatorKit

/// A viewer for the three design systems.
///
/// A design system nobody can look at cannot be reviewed, so each kit ships a
/// public gallery view and this app is the one place they are all rendered.
/// It is deliberately the *only* thing that depends on all three: the kits
/// have no knowledge of each other, so extracting one into its own repository
/// stays a directory move plus deleting a case from the enum below.
///
/// Run:      swift run DesignSystemGallery
/// Capture:  DSG_SNAPSHOT=<dir> swift run DesignSystemGallery
///           (writes one PNG per kit, then quits — same cacheDisplay approach
///           the prototype uses, which needs no Screen Recording permission)

enum Kit: String, CaseIterable, Identifiable {
    case glass = "GlassKit"
    case stage = "StageKit"
    case pocketOperator = "PocketOperatorKit"

    var id: String { rawValue }

    /// One line on what the kit is for — the gallery is also a menu.
    var blurb: String {
        switch self {
        case .glass: "Home Rec — translucent panels, one accent, hairline structure"
        case .stage: "Prototype harness — chrome that frames and drives concepts"
        case .pocketOperator: "Hardware instrument — chassis, keys, segment displays"
        }
    }
}

struct GalleryRoot: View {
    @State private var kit: Kit = .glass

    var body: some View {
        VStack(spacing: 0) {
            picker
            Divider().overlay(Color.white.opacity(0.08))
            Group {
                switch kit {
                case .glass: GlassKitGallery()
                case .stage: StageKitGallery()
                case .pocketOperator: PocketOperatorKitGallery()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1180, minHeight: 700)
        .background(Color(red: 0.03, green: 0.03, blue: 0.035))
    }

    private var picker: some View {
        HStack(spacing: 18) {
            ForEach(Kit.allCases) { candidate in
                Button {
                    kit = candidate
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.rawValue)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        Text(candidate.blurb)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .foregroundStyle(kit == candidate ? .white : .white.opacity(0.55))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        kit == candidate ? Color.white.opacity(0.08) : .clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(kit == candidate ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.03, green: 0.03, blue: 0.035))
    }
}

// MARK: - Snapshot

/// Renders each kit's gallery to a PNG. Uses AppKit's `cacheDisplay` rather
/// than a screen capture so it runs without the Screen Recording permission —
/// the same reason the concept prototype does it this way.
@MainActor
func runSnapshot(into directory: String) {
    try? FileManager.default.createDirectory(
        atPath: directory, withIntermediateDirectories: true
    )
    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(900))
        for kit in Kit.allCases {
            NotificationCenter.default.post(name: .dsgSelectKit, object: kit)
            try? await Task.sleep(for: .milliseconds(700))
            capture(to: "\(directory)/\(kit.rawValue).png")
        }
        NSApp.terminate(nil)
    }
}

@MainActor
private func capture(to path: String) {
    guard
        let window = NSApp.windows.first(where: { $0.isVisible }),
        let view = window.contentView,
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
    else { return }
    view.cacheDisplay(in: view.bounds, to: rep)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
}

extension Notification.Name {
    static let dsgSelectKit = Notification.Name("DSGSelectKit")
}

struct SnapshotAwareRoot: View {
    @State private var kit: Kit?

    var body: some View {
        GalleryRootDriven(forced: kit)
            .onReceive(NotificationCenter.default.publisher(for: .dsgSelectKit)) { note in
                kit = note.object as? Kit
            }
    }
}

/// Same content, but able to be driven externally during a snapshot run.
struct GalleryRootDriven: View {
    let forced: Kit?
    @State private var local: Kit = .glass

    var body: some View {
        let active = forced ?? local
        VStack(spacing: 0) {
            Group {
                switch active {
                case .glass: GlassKitGallery()
                case .stage: StageKitGallery()
                case .pocketOperator: PocketOperatorKitGallery()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1180, minHeight: 700)
        .background(Color(red: 0.03, green: 0.03, blue: 0.035))
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let dir = ProcessInfo.processInfo.environment["DSG_SNAPSHOT"] {
            runSnapshot(into: dir)
        }
    }
}

let snapshotting = ProcessInfo.processInfo.environment["DSG_SNAPSHOT"] != nil

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Unbundled SwiftPM executables launch as background agents; without this the
// window never comes forward and a snapshot run captures nothing.
app.setActivationPolicy(.regular)

let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 1320, height: 860),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "Design Systems — Gallery"
window.center()
window.contentView = NSHostingView(
    rootView: AnyView(snapshotting ? AnyView(SnapshotAwareRoot()) : AnyView(GalleryRoot()))
)
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()
