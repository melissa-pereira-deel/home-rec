//
//  InputDeviceEnumerator.swift
//  HomeRec
//
//  Lists microphones and other audio input devices for the capture-source
//  picker (BL-130).
//
//  `AVCaptureDevice.DiscoverySession` alone is enough, and that is load-bearing
//  rather than convenient: `SCStreamConfiguration.microphoneCaptureDeviceID`
//  takes "the uniqueID from AVCaptureDevice" per the SDK header, so the UID this
//  returns is exactly what ScreenCaptureKit wants — no Core Audio lookup and no
//  mapping layer between two identifier spaces.
//
//  ⚠️ Unlike `SCShareableContent`, this is **safe on a zero-click path**:
//  measured with microphone authorization `.notDetermined`, discovery returned
//  real device names and raised no permission dialog. That difference is why the
//  Per-App submenu needs a hard permission gate and this one does not.
//

import AVFoundation

/// One input device the picker can offer.
struct InputDeviceInfo: Identifiable, Sendable, Equatable {
    /// `AVCaptureDevice.uniqueID`, passed straight to `microphoneCaptureDeviceID`.
    var id: String { uid }
    let uid: String
    let name: String
}

@MainActor
protocol InputDeviceEnumerating: AnyObject {
    /// Currently connected input devices, in the order macOS reports them.
    func availableInputDevices() -> [InputDeviceInfo]
}

@MainActor
final class InputDeviceEnumerator: InputDeviceEnumerating {

    func availableInputDevices() -> [InputDeviceInfo] {
        // `.microphone` covers built-in and USB/Thunderbolt interfaces;
        // `.external` picks up devices macOS classifies separately.
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        var seen = Set<String>()
        return session.devices
            // A device can be reported by more than one type.
            .filter { seen.insert($0.uniqueID).inserted }
            // Names come from macOS verbatim — the user recognises "Scarlett 2i2
            // 4th Gen" and would not recognise anything we invented.
            .map { InputDeviceInfo(uid: $0.uniqueID, name: $0.localizedName) }
    }
}
