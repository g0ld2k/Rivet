import Foundation

public struct StagedFile: Equatable, Sendable {
    public let path: String
    public let status: String
    public let additions: Int?
    public let deletions: Int?
    public let isBinary: Bool

    public var magnitude: Int { (additions ?? 0) + (deletions ?? 0) }

    public init(path: String, status: String, additions: Int?, deletions: Int?, isBinary: Bool) {
        self.path = path
        self.status = status
        self.additions = additions
        self.deletions = deletions
        self.isBinary = isBinary
    }
}

public struct StagedChanges: Equatable, Sendable {
    public let files: [StagedFile]
    public let diff: String

    public init(files: [StagedFile], diff: String) {
        self.files = files
        self.diff = diff
    }
}

public enum GitEvidence {
    public static func isInsideWorkTree(_ git: GitClient) -> Bool {
        (try? git.run(["rev-parse", "--is-inside-work-tree"]))?.status == 0
    }

    public static func repositoryRoot(_ git: GitClient) -> URL? {
        guard let result = try? git.run(["rev-parse", "--show-toplevel"]), result.status == 0 else { return nil }
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    public static func hasStagedChanges(_ git: GitClient) throws -> Bool {
        let result = try git.run(["diff", "--cached", "--quiet"])
        switch result.status {
        case 0: return false
        case 1: return true
        default: throw RivetError.internalFailure("git diff --cached failed: \(result.stderr)")
        }
    }

    public static func stagedChanges(_ git: GitClient) throws -> StagedChanges {
        let nameStatus = try requireSuccess(try git.run(["diff", "--cached", "--name-status"]), context: "git diff --cached --name-status")
        let numstat = try requireSuccess(try git.run(["diff", "--cached", "--numstat"]), context: "git diff --cached --numstat")
        let diff = try requireSuccess(try git.run(["diff", "--cached", "--no-color", "--no-ext-diff"]), context: "git diff --cached --no-color --no-ext-diff")
        let stats = parseNumstat(numstat)
        let files = parseNameStatus(nameStatus).map { entry in
            let stat = stats[entry.path]
            return StagedFile(
                path: entry.path,
                status: entry.status,
                additions: stat?.additions,
                deletions: stat?.deletions,
                isBinary: stat.map { $0.additions == nil && $0.deletions == nil } ?? false
            )
        }
        return StagedChanges(files: files, diff: diff)
    }

    private static func requireSuccess(_ result: GitResult, context: String) throws -> String {
        guard result.status == 0 else {
            throw RivetError.internalFailure("\(context) failed: \(result.stderr)")
        }
        return result.stdout
    }

    static func parseNameStatus(_ text: String) -> [(status: String, path: String)] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { return nil }
            // "R100" → "R"; rename lines list old then new path — keep the new one.
            return (String(parts[0].prefix(1)), String(parts[parts.count - 1]))
        }
    }

    static func parseNumstat(_ text: String) -> [String: (additions: Int?, deletions: Int?)] {
        var result: [String: (additions: Int?, deletions: Int?)] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count >= 3 else { continue }
            // "-" additions/deletions mark binary content.
            result[normalizeNumstatPath(parts[2...].joined(separator: "\t"))] = (Int(parts[0]), Int(parts[1]))
        }
        return result
    }

    private static func normalizeNumstatPath(_ path: String) -> String {
        guard path.contains(" => ") else { return path }
        if let openBrace = path.firstIndex(of: "{"),
           let closeBrace = path.lastIndex(of: "}"),
           openBrace < closeBrace {
            let prefix = path[..<openBrace]
            let bodyStart = path.index(after: openBrace)
            let body = path[bodyStart..<closeBrace]
            let suffixStart = path.index(after: closeBrace)
            let suffix = path[suffixStart...]
            if let arrow = body.range(of: " => ") {
                let newName = body[arrow.upperBound...]
                return "\(prefix)\(newName)\(suffix)"
            }
        }
        return path.range(of: " => ").map { String(path[$0.upperBound...]) } ?? path
    }
}
