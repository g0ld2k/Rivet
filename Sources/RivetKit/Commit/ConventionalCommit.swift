import Foundation

public struct ConventionalCommit: Equatable, Sendable {
    public var type: String
    public var scope: String?
    public var isBreaking: Bool
    public var subject: String
    public var body: String?
    public var breakingDescription: String?

    public init(type: String, scope: String?, isBreaking: Bool,
                subject: String, body: String?, breakingDescription: String?) {
        self.type = type
        self.scope = scope
        self.isBreaking = isBreaking
        self.subject = subject
        self.body = body
        self.breakingDescription = breakingDescription
    }

    public func formatted() -> String {
        var header = type
        if let scope { header += "(\(scope))" }
        if isBreaking { header += "!" }
        header += ": \(subject)"

        var parts = [header]
        if let body, !body.isEmpty {
            parts.append(CommitValidator.wrap(body))
        }
        if isBreaking, let breakingDescription, !breakingDescription.isEmpty {
            parts.append(CommitValidator.wrap("BREAKING CHANGE: \(breakingDescription)"))
        }
        return parts.joined(separator: "\n\n")
    }
}

public enum CommitValidator {
    public struct Violation: Equatable, Sendable {
        public let message: String
        public init(message: String) { self.message = message }
    }

    public static func normalize(_ commit: ConventionalCommit) -> ConventionalCommit {
        var c = commit
        c.subject = c.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        while c.subject.hasSuffix(".") { c.subject = String(c.subject.dropLast()) }
        if let first = c.subject.first, first.isUppercase {
            c.subject = first.lowercased() + c.subject.dropFirst()
        }
        c.scope = c.scope?.trimmingCharacters(in: .whitespacesAndNewlines)
        if c.scope?.isEmpty == true { c.scope = nil }
        c.body = c.body?.trimmingCharacters(in: .whitespacesAndNewlines)
        if c.body?.isEmpty == true { c.body = nil }
        c.breakingDescription = c.breakingDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        if c.breakingDescription?.isEmpty == true { c.breakingDescription = nil }
        return c
    }

    public static func validate(
        _ commit: ConventionalCommit,
        scopeCandidates: [String]
    ) -> (commit: ConventionalCommit, violations: [Violation]) {
        var c = normalize(commit)
        var violations: [Violation] = []
        let allowedTypes: Set<String> = [
            "feat", "fix", "docs", "style", "refactor", "perf",
            "test", "build", "ci", "chore", "revert",
        ]
        if !allowedTypes.contains(c.type) {
            violations.append(Violation(message: "type is invalid"))
        }
        if c.subject.isEmpty {
            violations.append(Violation(message: "subject is empty"))
        }
        if c.subject.count > 72 {
            violations.append(Violation(message: "subject exceeds 72 characters"))
        }
        if c.subject.rangeOfCharacter(from: .newlines) != nil {
            violations.append(Violation(message: "subject contains newline"))
        }
        if let scope = c.scope {
            if scope.contains(")") || scope.rangeOfCharacter(from: .newlines) != nil {
                c.scope = nil
                violations.append(Violation(message: "scope contains unsafe characters"))
            } else {
                let known = Set(scopeCandidates.map { $0.lowercased() })
                // Unknown scope is dropped, not rejected — the message stays valid without one.
                if !known.contains(scope.lowercased()) { c.scope = nil }
            }
        }
        return (c, violations)
    }

    public static func wrap(_ text: String, width: Int = 72) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            let words = line.split(separator: " ")
            var lines: [String] = []
            var current = ""
            for word in words {
                if current.isEmpty {
                    current = String(word)
                } else if current.count + 1 + word.count <= width {
                    current += " " + word
                } else {
                    lines.append(current)
                    current = String(word)
                }
            }
            lines.append(current)
            return lines.joined(separator: "\n")
        }.joined(separator: "\n")
    }
}
