import Foundation
import CommonCrypto
import Security

public enum CredentialError: LocalizedError {
    case tooShort, tooLong, randomness, derivation, malformed, alreadyConfigured
    public var errorDescription: String? {
        switch self {
        case .tooShort: return "密码至少需要 6 个字符。"
        case .tooLong: return "密码不能超过 256 个字符。"
        case .randomness: return "无法生成密码盐值，请重试。"
        case .derivation: return "无法处理密码，请重试。"
        case .malformed: return "密码配置损坏。为保护桌面，已停止进入防窥模式。"
        case .alreadyConfigured: return "退出密码已经设置，请在应用设置中修改。"
        }
    }
}

public struct PasswordCredential: Codable, Equatable {
    public let version: Int
    public let algorithm: String
    public let iterations: UInt32
    public let salt: Data
    public let verifier: Data

    public static let workFactor: UInt32 = 310_000

    public init(password: String) throws {
        guard password.count >= 6 else { throw CredentialError.tooShort }
        guard password.count <= 256 else { throw CredentialError.tooLong }
        var random = Data(count: 32)
        let status = random.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw CredentialError.randomness }
        version = 1
        algorithm = "PBKDF2-HMAC-SHA256"
        iterations = Self.workFactor
        salt = random
        verifier = try Self.derive(password: password, salt: salt, iterations: iterations)
    }

    public func validate() throws {
        guard version == 1, algorithm == "PBKDF2-HMAC-SHA256",
              iterations >= 100_000, iterations <= 2_000_000,
              salt.count == 32, verifier.count == 32 else { throw CredentialError.malformed }
    }

    public func matches(_ password: String) throws -> Bool {
        try validate()
        guard !password.isEmpty, password.count <= 256 else { return false }
        let candidate = try Self.derive(password: password, salt: salt, iterations: iterations)
        var difference: UInt8 = 0
        for (a, b) in zip(candidate, verifier) { difference |= a ^ b }
        return difference == 0
    }

    public static func derive(password: String, salt: Data, iterations: UInt32) throws -> Data {
        let bytes = Array(password.utf8)
        var result = Data(count: 32)
        let status = bytes.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                result.withUnsafeMutableBytes { out in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self), bytes.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations,
                        out.baseAddress!.assumingMemoryBound(to: UInt8.self), out.count)
                }
            }
        }
        guard status == kCCSuccess else { throw CredentialError.derivation }
        return result
    }
}

public struct AuthenticationThrottle {
    public private(set) var failures = 0
    public private(set) var retryAfter = Date.distantPast
    public init() {}
    public func remaining(at date: Date = Date()) -> TimeInterval { max(0, retryAfter.timeIntervalSince(date)) }
    public mutating func failed(at date: Date = Date()) {
        failures += 1
        if failures >= 3 { retryAfter = date.addingTimeInterval(min(30, pow(2, Double(min(failures - 3, 5))))) }
    }
    public mutating func succeeded() { failures = 0; retryAfter = .distantPast }
}
