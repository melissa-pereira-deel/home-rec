# Notarization (BL-032)

Notarization is Apple's automated malware scan for apps distributed outside the
Mac App Store. Without it, downloaders see "cannot be opened because the
developer cannot be verified" and most give up before first launch.
`scripts/build-dmg.sh` notarizes both the app and the DMG on every release.

## One-time setup

1. Create an **app-specific password** at <https://appleid.apple.com> →
   Sign-In and Security → App-Specific Passwords.

2. Store a notarytool profile in your Keychain (keeps the password out of
   scripts and CI):

   ```bash
   xcrun notarytool store-credentials "HomeRecNotary" \
     --apple-id "you@example.com" \
     --team-id "S3J47F2UXA"
   ```

   Leave `--password` out. notarytool then asks for it at a secure prompt, so it
   never lands in shell history or in the process list. The credentials are
   checked with Apple before they are saved.

   **The team is `S3J47F2UXA`**, the one that signs Home Rec. An Apple ID can
   belong to more than one team, and a profile stored against another one can
   fail with the same 401 as a dead password.

After this, tools reference it by name: `--keychain-profile "HomeRecNotary"`.

## When the notary service returns 401

A 401 means Apple refused the sign-in. Nothing is wrong with the build. There
are four causes. A lock names itself in the error text; the other three can look
identical:

- **The app-specific password was revoked**, by hand or by Apple.
- **The Apple ID's password changed.** That revokes *every* app-specific
  password at once, so this is an ordinary event, not an edge case. A reset done
  to get back into the account counts.
- **The Apple ID is locked.** Apple locks accounts for security reasons, and the
  401 says so. This was the cause on 2026-09-17. Unlocking can mean resetting the
  password, which brings in the cause above.
- **The profile names the wrong team.** It must be `S3J47F2UXA`.

`scripts/build-dmg.sh` checks the profile before it builds anything, so all four
show up in seconds rather than after a full archive and signing pass.

## Refreshing the profile

1. **If the account is locked, unlock it first** at <https://iforgot.apple.com>.
   Nothing below works until then.
2. Create a new app-specific password at <https://appleid.apple.com> →
   Sign-In and Security → App-Specific Passwords. Revoke the old one there if it
   is still listed.
3. Store it under the same name, which replaces the old profile. The password is
   prompted, as in setup:

   ```bash
   xcrun notarytool store-credentials "HomeRecNotary" \
     --apple-id "you@example.com" \
     --team-id "S3J47F2UXA"
   ```

4. Confirm it signs in. This must list past submissions, not an error. It is the
   same call the build script's pre-flight makes:

   ```bash
   xcrun notarytool history --keychain-profile "HomeRecNotary"
   ```

## Per-release flow (handled by `scripts/build-dmg.sh`)

```bash
# Pre-flight: stops here, before building, if the profile cannot sign in
xcrun notarytool history --keychain-profile "HomeRecNotary"

# App
ditto -c -k --keepParent HomeRec.app HomeRec.zip
xcrun notarytool submit HomeRec.zip --keychain-profile "HomeRecNotary" --wait
xcrun stapler staple HomeRec.app

# DMG (notarize the container too)
xcrun notarytool submit HomeRec.dmg --keychain-profile "HomeRecNotary" --wait
xcrun stapler staple HomeRec.dmg
```

## Verify

```bash
xcrun notarytool history --keychain-profile "HomeRecNotary"   # status: Accepted
xcrun stapler validate HomeRec.dmg                            # The validate action worked!
spctl --assess --verbose HomeRec.app                          # accepted
```

If notarization is rejected, fetch the log:

```bash
xcrun notarytool log <submission-id> --keychain-profile "HomeRecNotary"
```

Common causes: Hardened Runtime not enabled, missing `--timestamp`, or an
unsigned nested binary.

## Security

- The signing identity and notary credentials live **only** in your Keychain.
- Never commit app-specific passwords, `.p12` files, or private keys. The repo's
  pre-commit hook and `.gitignore` guard against leaking secrets; keep it that way.
