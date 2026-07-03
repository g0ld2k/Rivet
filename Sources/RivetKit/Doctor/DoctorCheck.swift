import Foundation
import FoundationModels

public struct DoctorCheck: Equatable, Sendable {
    public let name: String
    public let passed: Bool
    public let detail: String

    public init(name: String, passed: Bool, detail: String) {
        self.name = name
        self.passed = passed
        self.detail = detail
    }
}

public enum DoctorChecks {
    public static func macOSVersion(
        _ version: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) -> DoctorCheck {
        DoctorCheck(
            name: "macOS 27 or later",
            passed: version.majorVersion >= 27,
            detail: "running \(version.majorVersion).\(version.minorVersion)"
        )
    }

    public static func modelAvailability(_ availability: SystemLanguageModel.Availability) -> DoctorCheck {
        switch availability {
        case .available:
            DoctorCheck(name: "On-device model", passed: true, detail: "available")
        case .unavailable(let reason):
            DoctorCheck(name: "On-device model", passed: false, detail: ModelGate.explain(reason))
        }
    }

    public static func guidedGeneration(supported: Bool) -> DoctorCheck {
        DoctorCheck(
            name: "Guided generation",
            passed: supported,
            detail: supported ? "supported" : "not reported by this model"
        )
    }

    public static func tokenizer(_ result: Result<Int, any Error>) -> DoctorCheck {
        switch result {
        case .success(let count):
            DoctorCheck(name: "Tokenizer", passed: true, detail: "smoke prompt measured at \(count) tokens")
        case .failure(let error):
            DoctorCheck(name: "Tokenizer", passed: false, detail: String(describing: error))
        }
    }
}

public enum DoctorReport {
    public static func humanLines(_ checks: [DoctorCheck], console: Console) -> [String] {
        checks.map { check in
            let mark = check.passed ? console.paint("✓", .green) : console.paint("✗", .red)
            return "\(mark) \(check.name): \(check.detail)"
        }
    }

    public static func json(_ checks: [DoctorCheck]) throws -> String {
        struct Entry: Codable {
            let check: String
            let passed: Bool
            let detail: String
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(checks.map { Entry(check: $0.name, passed: $0.passed, detail: $0.detail) })
        return String(decoding: data, as: UTF8.self)
    }
}
