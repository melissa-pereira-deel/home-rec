# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Home Rec, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please use [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) to submit a report directly through this repository.

### What to include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response timeline

- **Acknowledgment:** Within 48 hours
- **Assessment:** Within 7 days
- **Fix:** Dependent on severity, typically within 30 days

## Scope

This policy applies to the Home Rec macOS application and its source code in this repository.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.1.x   | Yes       |
| 1.0.x   | Security fixes only |
| < 1.0   | No        |

## Security Considerations

Home Rec captures system audio with Apple's ScreenCaptureKit, and can also
capture a single application's audio or a microphone. The app:

- Requires explicit Screen Recording permission granted by the user
- Requires explicit Microphone permission before recording from an input device
- Stores recordings locally on the user's filesystem only
- Does not collect analytics, telemetry, or usage data
- Runs **without the App Sandbox**, which ScreenCaptureKit system-audio capture
  requires. A deliberate, documented trade-off rather than an oversight.

### Network activity

Added in 1.1.0, Home Rec makes exactly one kind of network request: it checks
`https://homerec.app/appcast.xml` for a newer version, and downloads an update
if the user installs one. Nothing else leaves the machine — no recording, no
filename, no usage data.

That request necessarily reveals the user's IP address to the host, as any web
request does. It sends **no system profile** — Sparkle's profiling is off, and
the bundle declares only `SUFeedURL` and `SUPublicEDKey` — and no identifier.

### Update integrity

Updates are signed with an Ed25519 key held only by the developer and verified
against the public key embedded in the app before anything is installed. An
update whose signature does not match is refused, and the feed is HTTPS-only —
Sparkle rejects a plaintext feed outright.

Because the app is unsandboxed, a maliciously signed update would run with the
user's full privileges. The signing key is therefore treated as the most
sensitive asset in the project: it lives in the developer's login Keychain, is
never written to this repository, and a release build verifies that the key
shipped in the app matches the one that signs the update before publishing.
