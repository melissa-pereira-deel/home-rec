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
| 0.3.x   | Yes       |
| < 0.3   | No        |

## Security Considerations

Home Rec uses Apple's ScreenCaptureKit API to capture system audio. The app:

- Requires explicit Screen Recording permission granted by the user
- Does not transmit any data over the network
- Stores recordings locally on the user's filesystem only
- Does not collect analytics, telemetry, or usage data
- Does not access microphone input (system audio output only)
