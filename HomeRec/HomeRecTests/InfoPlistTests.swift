//
//  InfoPlistTests.swift
//  HomeRecTests
//
//  BL-084: guards the bundle's Info.plist against silent drift.
//
//  These run against the *host app's built bundle*, not the repo — which is the
//  whole point. A checked-in Info.plist sat in this project for months looking
//  authoritative while contributing nothing to the product: `INFOPLIST_FILE` was
//  never set and `GENERATE_INFOPLIST_FILE` was on, so Xcode synthesised the real
//  plist and ignored the file. Two keys that appeared present in the repo
//  (`NSMicrophoneUsageDescription`, `NSAppleEventsUsageDescription`) were absent
//  from every shipped build. Asserting against the repo would have reproduced the
//  same blind spot, so every check here reads the product.
//

import Testing
import Foundation
@testable import HomeRec

@MainActor
struct InfoPlistTests {

    /// The host app's bundle. Unit tests are injected into the app via `TEST_HOST`,
    /// so `Bundle.main` is the app being shipped, not the test bundle.
    private var appBundle: Bundle { Bundle.main }

    private func string(_ key: String) -> String? {
        appBundle.object(forInfoDictionaryKey: key) as? String
    }

    @Test("Bundle identity keys are present in the built product")
    func identityKeysPresent() throws {
        #expect(string("CFBundleIdentifier") == "com.mdebritto.HomeRec")
        #expect(string("CFBundleDisplayName") == "Home Rec")
        #expect(try #require(string("CFBundleShortVersionString")).isEmpty == false)
        #expect(try #require(string("CFBundleVersion")).isEmpty == false)
    }

    /// `LSMinimumSystemVersion` is synthesised from `MACOSX_DEPLOYMENT_TARGET`.
    /// The v1.1 capture work (BL-100/130) relies on macOS 15-only ScreenCaptureKit
    /// API, so a silent downgrade here would produce a bundle that launches on a
    /// system where those calls are unavailable.
    @Test("Deployment floor is macOS 15.0")
    func minimumSystemVersionIsFifteen() {
        #expect(string("LSMinimumSystemVersion") == "15.0")
    }

    /// Regression guard for the defect BL-084 fixed. The repo's `Info.plist` was
    /// not wired in as the bundle's plist, but it *was* picked up as a resource by
    /// the file-system-synchronized group — so every build, including shipped v1.0,
    /// carried a second `Info.plist` under `Contents/Resources/` that macOS never
    /// reads. Restoring any stray plist there would resurrect the same confusion.
    @Test("No stray Info.plist shipped under Contents/Resources")
    func noStrayResourceInfoPlist() {
        let stray = appBundle.url(forResource: "Info", withExtension: "plist")
        #expect(stray == nil, "Found an Info.plist in Resources — macOS ignores it; delete it.")
    }

    /// Usage-description strings must live in the *product*, not merely in the repo.
    /// macOS terminates a process that requests a protected resource without the
    /// matching key, so a key that is present in a file but absent from the bundle
    /// is a crash waiting on the feature that needs it.
    ///
    /// Home Rec requests one protected resource whose string it must declare: the
    /// microphone (BL-130). Screen Recording is gated by TCC without a required
    /// purpose string — and `INFOPLIST_KEY_NSScreenCaptureUsageDescription` is not
    /// on Xcode's allow-list at all, which is what closed BL-080 as impossible.
    @Test("Declared usage descriptions match what the app actually requests")
    func usageDescriptionsMatchCapabilities() {
        // ⚠️ Asserted against the **built product**, never the repo — that is the
        // whole point of this suite. Requesting mic access without this key in
        // the shipped bundle is an immediate TCC *termination*: the app is
        // killed, not denied. And the key looked present for months while living
        // in a file that was not part of the build at all (BL-084).
        let required = ["NSMicrophoneUsageDescription"]
        for key in required {
            #expect(string(key)?.isEmpty == false, "Missing usage description: \(key)")
        }

        // Must explain itself, not merely exist: a vague string is what users
        // read in the system prompt and what App Review rejects.
        #expect(string("NSMicrophoneUsageDescription")?.contains("microphone") == true)

        // The reverse guard: nothing the app cannot justify. NSAppleEventsUsageDescription
        // was carried in the dead file for months with no AppleEvents code anywhere.
        #expect(string("NSAppleEventsUsageDescription") == nil)
    }

    /// BL-034 (Sparkle). `SUFeedURL` and `SUPublicEDKey` are third-party keys with
    /// no `INFOPLIST_KEY_` equivalent — the same allow-list that closed BL-080 as
    /// impossible. Reaching the product therefore required re-introducing a real
    /// `INFOPLIST_FILE`, the thing BL-084 deleted.
    ///
    /// Both halves are asserted, because the risk was never "does the file get
    /// read" — it was that setting `INFOPLIST_FILE` might *replace* the generated
    /// plist rather than merge under it, silently dropping the bundle identifier
    /// and the deployment floor while the build still succeeded. Measured on
    /// Xcode 16 / 2026-08-01: with `GENERATE_INFOPLIST_FILE` still YES, Xcode
    /// merges, and the generated keys survive intact.
    ///
    /// The file lives at `HomeRec/Info.plist` — one level *above* the source
    /// directory on purpose. `HomeRec/HomeRec/` is a file-system-synchronized
    /// group, so a plist placed there is also copied into `Contents/Resources/`,
    /// which is exactly the inert second plist BL-084 removed.
    @Test("Sparkle's feed keys reach the product without displacing generated keys")
    func sparkleFeedKeysMergeWithGeneratedKeys() throws {
        let feed = try #require(string("SUFeedURL"), "SUFeedURL absent — INFOPLIST_FILE is not wired in")
        // Sparkle will refuse a plaintext feed, and an appcast fetched over HTTP
        // is an update channel anyone on the path can rewrite.
        #expect(feed.hasPrefix("https://"), "the appcast must be fetched over TLS")
        #expect(string("SUPublicEDKey")?.isEmpty == false)

        // The merge half. These are generated, not present in `Info.plist`; if
        // the file had replaced rather than merged, they would be gone.
        #expect(string("CFBundleIdentifier") == "com.mdebritto.HomeRec")
        #expect(string("LSMinimumSystemVersion") == "15.0")
    }

    /// `SUPublicEDKey` must be a real Ed25519 public key in the shipped bundle.
    ///
    /// The two halves of the Sparkle keypair are set in different places at
    /// different times: the private half by `generate_keys` into the login
    /// Keychain, the public half by hand into `HomeRec/Info.plist`. Only the
    /// private half has any natural feedback — `sign_update` fails loudly
    /// without it. A wrong public half fails **silently and permanently**: the
    /// build succeeds, `sign_update` succeeds, the appcast is signed, the app
    /// launches, and every copy of that release then rejects every update it is
    /// ever offered. That is the cohort-stranding failure BL-034 exists to
    /// prevent, reintroduced by the mechanism meant to fix it.
    ///
    /// ⚠️ **What this cannot check:** whether the key is *ours*. A different but
    /// well-formed Ed25519 key passes everything below. Verifying identity means
    /// comparing against the private half, and CI has no Keychain and must not
    /// have one — so that check lives in `scripts/build-dmg.sh`, which runs
    /// `generate_keys -p` at release time. Structure is guarded here on every
    /// PR; identity is guarded there on every release. Neither is sufficient
    /// alone.
    @Test("The Sparkle public key is a real Ed25519 key, not a placeholder")
    func sparklePublicKeyIsWellFormed() throws {
        let key = try #require(string("SUPublicEDKey"), "SUPublicEDKey is missing from the built product")

        #expect(
            key.localizedCaseInsensitiveContains("placeholder") == false,
            "SUPublicEDKey is still the spike placeholder. Run Sparkle's generate_keys and paste the real public key into HomeRec/Info.plist — see docs/distribution/sparkle-setup.md."
        )

        // `Data(base64Encoded:)` rejects invalid characters outright, so a
        // hand-mangled or half-pasted key fails here rather than at a user's
        // machine months later.
        let decoded = try #require(
            Data(base64Encoded: key),
            "SUPublicEDKey is not valid base64 — Sparkle refuses to start the updater with an unparseable key."
        )
        #expect(decoded.count == 32, "An Ed25519 public key is 32 bytes; this decoded to \(decoded.count).")
    }
}
