import XCTest
@testable import StillHereCore

final class PasswordTests: XCTestCase {
    func testExistingWallpaperPreferencesSurviveGalleryUpgradeAndReload() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = AppStorage(directory: folder)
        try store.prepare()
        try Data(#"{"wallpaperFilename":"wallpaper-personal.png","keepAwake":false}"#.utf8)
            .write(to: folder.appendingPathComponent("preferences.json"))
        var preferences = store.loadPreferences()
        XCTAssertEqual(preferences.wallpaperFilename, "wallpaper-personal.png")
        XCTAssertFalse(preferences.keepAwake)
        XCTAssertNil(preferences.builtInWallpaperID)
        preferences.wallpaperFilename = nil
        preferences.builtInWallpaperID = "meeting"
        try store.save(preferences, filename: "preferences.json")
        let reloaded = store.loadPreferences()
        XCTAssertEqual(reloaded.builtInWallpaperID, "meeting")
        XCTAssertNil(reloaded.wallpaperFilename)
        XCTAssertFalse(reloaded.keepAwake)
    }
    func testPBKDF2MatchesIndependentReferenceVector() throws {
        let key = try PasswordCredential.derive(password: "password", salt: Data("salt".utf8), iterations: 4096)
        XCTAssertEqual(key.map { String(format: "%02x", $0) }.joined(),
                       "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a")
    }

    func testSaltedVerifierAcceptsOnlyCorrectPasswordAndStoresNoPlaintext() throws {
        let a = try PasswordCredential(password: "test-secret-123")
        let b = try PasswordCredential(password: "test-secret-123")
        XCTAssertNotEqual(a.salt, b.salt)
        XCTAssertNotEqual(a.verifier, b.verifier)
        XCTAssertTrue(try a.matches("test-secret-123"))
        XCTAssertFalse(try a.matches("wrong-secret"))
        XCTAssertFalse(try a.matches(""))
        let json = String(decoding: try JSONEncoder().encode(a), as: UTF8.self)
        XCTAssertFalse(json.contains("test-secret-123"))
    }

    func testUnicodePasswordRoundTrip() throws {
        let value = try PasswordCredential(password: "在场密码六六六")
        XCTAssertTrue(try value.matches("在场密码六六六"))
        XCTAssertFalse(try value.matches("在场密码六六"))
    }

    func testCredentialCannotBeOverwrittenByInitializationAndHasPrivatePermissions() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = AppStorage(directory: folder)
        let value = try PasswordCredential(password: "test-secret-123")
        try store.saveCredential(value, initialOnly: true)
        XCTAssertEqual(try store.loadCredential(), value)
        XCTAssertThrowsError(try store.saveCredential(value, initialOnly: true))
        let attributes = try FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent("credential.json").path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testCorruptCredentialFailsClosed() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = AppStorage(directory: folder)
        try store.prepare()
        try Data("{}".utf8).write(to: folder.appendingPathComponent("credential.json"))
        XCTAssertThrowsError(try store.loadCredential())
    }

    func testFailedAttemptsDelayAuthenticationAndSuccessResetsDelay() {
        var throttle = AuthenticationThrottle()
        let date = Date(timeIntervalSince1970: 100)
        throttle.failed(at: date); throttle.failed(at: date)
        XCTAssertEqual(throttle.remaining(at: date), 0)
        throttle.failed(at: date)
        XCTAssertEqual(throttle.remaining(at: date), 1)
        for _ in 0..<10 { throttle.failed(at: date) }
        XCTAssertEqual(throttle.remaining(at: date), 30)
        throttle.succeeded()
        XCTAssertEqual(throttle.remaining(at: date), 0)
    }

    func testMissingVisibleCoverControlCannotQualifyCapture() throws {
        func sample(_ kind: String) -> [String: Any] { ["status": "captured", "classification": kind] }
        var probe: [String: Any] = ["status": "completed", "os": "test-build", "probeTookKeyboardFocus": false,
            "normal_legacy": sample("underlying_desktop"), "normal_sck": sample("underlying_desktop"),
            "protected_legacy": sample("underlying_desktop"), "protected_sck": sample("underlying_desktop")]
        XCTAssertFalse(try XCTUnwrap(CaptureCompatibility.fromProbe(probe, currentBuild: "test-build")).isUsable(on: "test-build"))
        probe["normal_legacy"] = sample("privacy_overlay_visible")
        probe["normal_sck"] = sample("privacy_overlay_visible")
        XCTAssertTrue(try XCTUnwrap(CaptureCompatibility.fromProbe(probe, currentBuild: "test-build")).isUsable(on: "test-build"))
        XCTAssertNil(CaptureCompatibility.fromProbe(probe, currentBuild: "different-build"))
    }
}
