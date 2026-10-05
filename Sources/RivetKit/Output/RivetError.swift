public struct RivetError: Error, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case internalFailure
        case notAGitRepository
        case noStagedChanges
        case modelUnavailable
        case generationFailed
    }

    public let kind: Kind
    public let message: String

    public var exitCode: Int32 {
        switch kind {
        case .internalFailure: 1
        case .notAGitRepository: 3
        case .noStagedChanges: 4
        case .modelUnavailable: 5
        case .generationFailed: 6
        }
    }

    public static func internalFailure(_ detail: String) -> RivetError {
        RivetError(kind: .internalFailure, message: detail)
    }

    public static var notAGitRepository: RivetError {
        RivetError(kind: .notAGitRepository, message: "not a git repository")
    }

    public static var noStagedChanges: RivetError {
        RivetError(kind: .noStagedChanges, message: "no staged changes — stage files with `git add` first")
    }

    public static func modelUnavailable(_ detail: String) -> RivetError {
        RivetError(kind: .modelUnavailable, message: "model unavailable: \(detail)")
    }

    public static func generationFailed(_ detail: String) -> RivetError {
        RivetError(kind: .generationFailed, message: "generation failed: \(detail)")
    }
}
