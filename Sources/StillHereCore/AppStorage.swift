import Foundation
import CryptoKit

public struct Preferences: Codable, Equatable {
    public var wallpaperFilename: String?
    public var keepAwake: Bool = true
    public init() {}
}

public struct AppStorage {
    public let directory: URL
    public let commandScope: String

    public init(directory: URL? = nil) {
        let custom = ProcessInfo.processInfo.environment["STILLHERE_DATA_DIR"]
        self.directory = directory ?? custom.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("StillHere", isDirectory: true)
        commandScope = SHA256.hash(data: Data(self.directory.standardizedFileURL.path.utf8))
            .prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    public func prepare() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    public func loadCredential() throws -> PasswordCredential? {
        let url = directory.appendingPathComponent("credential.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let value = try JSONDecoder().decode(PasswordCredential.self, from: Data(contentsOf: url))
            try value.validate()
            return value
        } catch { throw CredentialError.malformed }
    }

    public func saveCredential(_ credential: PasswordCredential, initialOnly: Bool = false) throws {
        try credential.validate()
        try prepare()
        let url = directory.appendingPathComponent("credential.json")
        if initialOnly && FileManager.default.fileExists(atPath: url.path) { throw CredentialError.alreadyConfigured }
        try save(credential, filename: "credential.json")
    }

    public func loadPreferences() -> Preferences {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("preferences.json")),
              let value = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        return value
    }

    public func save<T: Encodable>(_ value: T, filename: String) throws {
        try prepare()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = directory.appendingPathComponent(filename)
        try encoder.encode(value).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
