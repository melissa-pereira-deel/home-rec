//
//  InstallLocationTests.swift
//  HomeRecTests
//
//  BL-082: bundle-location classification and the two-tier consequence — a hard
//  block for translocation, at most a dismissible note for anything else.
//
//  `classify(_:)` is a pure function of a path, so every branch is covered here
//  with no mocks, no hardware, no permission, and no sleeps. What is *not*
//  covered, and cannot be: real Gatekeeper translocation (needs a quarantined
//  bundle on a mounted disk image), the Finder reveal, and whether a grant
//  actually survives a relaunch. Those are manual, and best run on a non-admin
//  account where the interesting failures live.
//

import Testing
import Foundation
import AppKit
@testable import HomeRec

@MainActor
struct InstallLocationTests {

    // MARK: - classify(_:)

    @Test("Bundle in /Applications classifies as applications")
    func systemApplications() {
        #expect(InstallLocation.classify(URL(fileURLWithPath: "/Applications/Home Rec.app")) == .applications)
    }

    @Test("Bundle in a subfolder of /Applications still classifies as applications")
    func applicationsSubfolder() {
        let url = URL(fileURLWithPath: "/Applications/Utilities/Home Rec.app")
        #expect(InstallLocation.classify(url) == .applications)
    }

    /// `~/Applications` is a deliberate, legitimate choice. It must land in the
    /// soft tier — treating it like translocation is exactly the conflation that
    /// teaches users to ignore the warning that matters.
    @Test("Bundle in ~/Applications classifies as elsewhere, not applications")
    func userApplications() {
        let url = URL(fileURLWithPath: "/Users/someone/Applications/Home Rec.app")
        #expect(InstallLocation.classify(url) == .elsewhere(url))
    }

    @Test("A Gatekeeper AppTranslocation path classifies as translocated")
    func translocatedPath() {
        let url = URL(fileURLWithPath:
            "/private/var/folders/xy/abcdef1234/T/AppTranslocation/"
            + "3F2A1C7E-9B4D-4E1A-8C6F-0D5B2A9E7C31/d/Home Rec.app")
        #expect(InstallLocation.classify(url) == .translocated)
    }

    /// Running straight off the mounted image *without* quarantine (e.g. an image
    /// the user built themselves) is not translocated — it is merely elsewhere.
    /// The block is for the randomised path, not for the volume.
    @Test("Bundle on a mounted volume classifies as elsewhere")
    func mountedVolume() {
        let url = URL(fileURLWithPath: "/Volumes/Home Rec/Home Rec.app")
        #expect(InstallLocation.classify(url) == .elsewhere(url))
    }

    @Test("Bundle in ~/Downloads classifies as elsewhere")
    func downloads() {
        let url = URL(fileURLWithPath: "/Users/someone/Downloads/Home Rec.app")
        #expect(InstallLocation.classify(url) == .elsewhere(url))
    }

    @Test("A DerivedData build classifies as developerBuild")
    func derivedData() {
        let url = URL(fileURLWithPath:
            "/Users/someone/Library/Developer/Xcode/DerivedData/"
            + "HomeRec-abcdefg/Build/Products/Debug/HomeRec.app")
        #expect(InstallLocation.classify(url) == .developerBuild)
    }

    /// `xcodebuild` with a custom `SYMROOT` (CI, scripted builds) produces no
    /// `DerivedData` component — only `Build/Products`.
    @Test("A custom-SYMROOT build directory also classifies as developerBuild")
    func customBuildDirectory() {
        let url = URL(fileURLWithPath: "/tmp/hr-ci/Build/Products/Debug/HomeRec.app")
        #expect(InstallLocation.classify(url) == .developerBuild)
    }

    /// Precedence is fixed deliberately: translocation is the only unrecoverable
    /// state, so a path that somehow looked like both must still block.
    @Test("Translocation wins over a developer-build path match")
    func translocationTakesPrecedence() {
        let url = URL(fileURLWithPath:
            "/private/var/folders/xy/T/AppTranslocation/UUID/d/Build/Products/Debug/HomeRec.app")
        #expect(InstallLocation.classify(url) == .translocated)
    }

    // MARK: - Tiers

    @Test("Only translocation blocks recording")
    func onlyTranslocationBlocks() {
        #expect(InstallLocation.translocated.blocksRecording)
        #expect(InstallLocation.applications.blocksRecording == false)
        #expect(InstallLocation.developerBuild.blocksRecording == false)
        #expect(InstallLocation.elsewhere(URL(fileURLWithPath: "/x/Home Rec.app")).blocksRecording == false)
    }

    @Test("Applications and developer builds have nothing to say")
    func quietTiers() {
        #expect(InstallLocation.applications.explanation == nil)
        #expect(InstallLocation.developerBuild.explanation == nil)
    }

    @Test("The translocation copy names the disk image and the fix, and is not dismissible")
    func translocationCopy() {
        let text = InstallLocation.translocated.explanation
        #expect(text?.contains("disk image") == true)
        #expect(text?.contains("Applications folder") == true)
        // "Quit" is load-bearing: the running copy is the one that must die for
        // the fix to take, and a user who only drags will be baffled.
        #expect(text?.contains("Quit") == true)
        #expect(InstallLocation.translocated.noticeIsDismissible == false)
    }

    @Test("The elsewhere note is dismissible")
    func elsewhereIsDismissible() {
        let location = InstallLocation.elsewhere(URL(fileURLWithPath: "/Users/someone/Downloads/Home Rec.app"))
        #expect(location.noticeIsDismissible)
        #expect(location.explanation != nil)
    }

    // MARK: - View-model integration

    /// The presenter override keeps these tests off AppKit: the production path
    /// would order a real panel on screen, which a unit test must not do.
    /// Per-suite center — see the note in PermissionProbeTests.
    private let center = NotificationCenter()

    private func makeViewModel(
        _ location: InstallLocation,
        controller: MockRecordingControlling? = nil,
        onNotice: @escaping () -> Void = {}
    ) -> RecorderViewModel {
        RecorderViewModel(
            controller: controller ?? MockRecordingControlling(),
            permissions: MockPermissionProviding(.granted),
            clock: ManualClock(),
            installLocation: MockInstallLocationProviding(location),
            installNoticePresenter: onNotice,
            notificationCenter: center
        )
    }

    @Test("A translocated bundle refuses to record and surfaces the explanation")
    func translocationBlocksRecording() async {
        let controller = MockRecordingControlling()
        let viewModel = makeViewModel(.translocated, controller: controller)

        await viewModel.startRecording()

        #expect(controller.startCount == 0)
        #expect(viewModel.state == .idle)
        #expect(viewModel.showsInstallLocationNotice)
        #expect(viewModel.installNotice?.contains("disk image") == true)
        #expect(viewModel.installLocationBlocksRecording)
    }

    /// The runtime-ordering requirement: a translocated user must never be sent
    /// into the permission flow. They would follow it correctly and the grant would
    /// still evaporate on relaunch.
    @Test("Translocation pre-empts the permission guide and System Settings")
    func translocationPreemptsPermissionGuide() {
        let permissions = MockPermissionProviding(.denied)
        var noticeCount = 0
        let viewModel = RecorderViewModel(
            controller: MockRecordingControlling(),
            permissions: permissions,
            clock: ManualClock(),
            installLocation: MockInstallLocationProviding(.translocated),
            installNoticePresenter: { noticeCount += 1 },
            notificationCenter: center
        )
        // The launch-time notice already fired once; measure from there.
        let baseline = noticeCount

        viewModel.openSystemSettings()

        #expect(noticeCount == baseline + 1)
        #expect(permissions.openSettingsCount == 0)
        #expect(viewModel.grantWatcherIsPolling == false)
    }

    /// Regression guard for a defect found in manual testing of v1.0.1: the
    /// translocation block correctly showed its panel, but the activation observer
    /// still fired the authoritative permission probe — which raises the system
    /// prompt — because permission on a translocated bundle is never `.granted`, so
    /// the BL-085 "skip when granted" guard never tripped. A translocated user was
    /// shown the block *and* pushed into the permission flow at once, the exact harm
    /// BL-082a exists to prevent.
    @Test("Activation never probes permission on a translocated bundle")
    func translocationSuppressesActivationProbe() async {
        let permissions = MockPermissionProviding(.denied)
        let viewModel = RecorderViewModel(
            controller: MockRecordingControlling(),
            permissions: permissions,
            clock: ManualClock(),
            installLocation: MockInstallLocationProviding(.translocated),
            installNoticePresenter: {},
            notificationCenter: center
        )
        await settle()
        let baseline = permissions.checkCount

        // Two activations: the first is launch (swallowed for everyone); the
        // second is the one that would probe — and must not, when translocated.
        for _ in 0..<2 {
            center.post(name: NSApplication.didBecomeActiveNotification, object: nil)
            await settle()
        }

        #expect(permissions.checkCount == baseline,
                "A translocated bundle must not run the prompting probe on any activation")
        #expect(viewModel.canRecord == false)
    }

    /// The panel is a fallback for when no window can carry the block — found in
    /// the v1.0.1 manual pass stating the same fact twice: main window and panel,
    /// side by side, which reads as two faults. With a window on screen the panel
    /// must stand down; the window is the canonical surface.
    ///
    /// Both directions are asserted through the presenter seam, which counts
    /// presentations without materialising an `NSPanel` mid-suite.
    @Test("The floating panel yields to a visible main window")
    func panelYieldsToVisibleWindow() async {
        var presentations = 0
        let viewModel = makeViewModel(.translocated, onNotice: { presentations += 1 })

        viewModel.mainWindowDidAppear()
        presentations = 0          // measure from the window being up

        viewModel.showInstallLocationNotice()

        // The block state is still surfaced — the window renders it. Only the
        // duplicate panel is suppressed.
        #expect(viewModel.showsInstallLocationNotice)
        #expect(presentations == 0)
    }

    /// The panel's one remaining job. Without it, a translocated relaunch that
    /// opens no window is a silently dead app: nothing records, nothing explains.
    @Test("The floating panel presents when no window can carry the block")
    func panelPresentsWithoutAWindow() async {
        var presentations = 0
        let viewModel = makeViewModel(.translocated, onNotice: { presentations += 1 })
        #expect(viewModel.visibleWindowCount == 0)
        presentations = 0

        viewModel.showInstallLocationNotice()

        #expect(presentations == 1)
    }

    /// Closing the last window hands the block back to the panel.
    @Test("Losing the last window re-presents the panel while blocked")
    func lastWindowClosingRePresentsPanel() async {
        var presentations = 0
        let viewModel = makeViewModel(.translocated, onNotice: { presentations += 1 })
        viewModel.mainWindowDidAppear()
        presentations = 0

        viewModel.mainWindowDidDisappear()

        #expect(viewModel.visibleWindowCount == 0)
        #expect(presentations == 1)
    }

    /// The same, for a bundle that is merely elsewhere: no window, no block, and
    /// therefore nothing to re-present. Only the hard block earns the fallback.
    @Test("Losing the last window does not present anything when not blocked")
    func lastWindowClosingIsQuietWhenNotBlocked() async {
        var presentations = 0
        let viewModel = makeViewModel(.applications, onNotice: { presentations += 1 })
        viewModel.mainWindowDidAppear()
        presentations = 0

        viewModel.mainWindowDidDisappear()

        #expect(presentations == 0)
    }

    /// BL-086 acceptance: every surface renders the one canonical string. The
    /// views read `installNotice`, so pinning it to `InstallLocation.explanation`
    /// is what stops a second hardcoded copy drifting in.
    @Test("The block message is the canonical string, not a copy")
    func blockMessageIsCanonical() {
        let viewModel = makeViewModel(.translocated)
        #expect(viewModel.installNotice == InstallLocation.translocated.explanation)
    }

    @Test("Dismissing the hard block does not make it go away")
    func hardBlockSurvivesDismissal() async {
        let controller = MockRecordingControlling()
        let viewModel = makeViewModel(.translocated, controller: controller)

        viewModel.dismissInstallLocationNotice()
        #expect(viewModel.installNotice != nil)

        await viewModel.startRecording()
        #expect(controller.startCount == 0)
        #expect(viewModel.showsInstallLocationNotice)
    }

    @Test("A bundle in /Applications never warns and records normally")
    func applicationsNeverWarns() async {
        let controller = MockRecordingControlling()
        let viewModel = makeViewModel(.applications, controller: controller)

        #expect(viewModel.installNotice == nil)
        #expect(viewModel.showsInstallLocationNotice == false)

        await viewModel.startRecording()
        #expect(viewModel.state == .recording)
        #expect(controller.startCount == 1)
    }

    @Test("A developer build never warns and records normally")
    func developerBuildNeverWarns() async {
        let controller = MockRecordingControlling()
        let viewModel = makeViewModel(.developerBuild, controller: controller)

        #expect(viewModel.installNotice == nil)
        #expect(viewModel.showsInstallLocationNotice == false)

        await viewModel.startRecording()
        #expect(viewModel.state == .recording)
        #expect(controller.startCount == 1)
    }

    @Test("A bundle elsewhere notes but never blocks, and the note can be dismissed for good")
    func elsewhereNotesButNeverBlocks() async {
        let controller = MockRecordingControlling()
        let url = URL(fileURLWithPath: "/Users/someone/Applications/Home Rec.app")
        let viewModel = makeViewModel(.elsewhere(url), controller: controller)

        #expect(viewModel.installNotice != nil)
        #expect(viewModel.installLocationBlocksRecording == false)
        // Nothing is presented at launch for the soft tier.
        #expect(viewModel.showsInstallLocationNotice == false)

        await viewModel.startRecording()
        #expect(viewModel.state == .recording)
        #expect(controller.startCount == 1)

        viewModel.dismissInstallLocationNotice()
        #expect(viewModel.installNotice == nil)
    }

    // The positive counterpart — `.elsewhere` still opening System Settings and the
    // permission guide — is deliberately not asserted here: exercising it would
    // materialise the real guide panel and start a live poll loop inside the test
    // process. The behaviour is unchanged from BL-081 and covered by its tests.
}
