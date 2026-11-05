import Foundation

public struct CaptureCompatibility: Codable {
    public let osBuild: String
    public let validatedAt: Date
    public let normalCaptureControlPassed: Bool
    public let legacyCapturePassed: Bool
    public let screenCaptureKitPassed: Bool
    public let focusPreserved: Bool

    public init(osBuild: String, normalCaptureControlPassed: Bool, legacyCapturePassed: Bool,
                screenCaptureKitPassed: Bool, focusPreserved: Bool) {
        self.osBuild = osBuild
        validatedAt = Date()
        self.normalCaptureControlPassed = normalCaptureControlPassed
        self.legacyCapturePassed = legacyCapturePassed
        self.screenCaptureKitPassed = screenCaptureKitPassed
        self.focusPreserved = focusPreserved
    }

    public func isUsable(on build: String) -> Bool {
        osBuild == build && normalCaptureControlPassed && legacyCapturePassed && screenCaptureKitPassed && focusPreserved
    }

    public static func fromProbe(_ json: [String: Any], currentBuild: String) -> CaptureCompatibility? {
        guard json["status"] as? String == "completed", json["os"] as? String == currentBuild else { return nil }
        func kind(_ name: String) -> String? {
            guard let sample = json[name] as? [String: Any], sample["status"] as? String == "captured" else { return nil }
            return sample["classification"] as? String
        }
        return CaptureCompatibility(osBuild: currentBuild,
            normalCaptureControlPassed: kind("normal_legacy") == "privacy_overlay_visible" && kind("normal_sck") == "privacy_overlay_visible",
            legacyCapturePassed: kind("protected_legacy") == "underlying_desktop",
            screenCaptureKitPassed: kind("protected_sck") == "underlying_desktop",
            focusPreserved: json["probeTookKeyboardFocus"] as? Bool == false)
    }
}
