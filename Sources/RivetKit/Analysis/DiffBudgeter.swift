public struct EvidencePack: Sendable {
    public let text: String
    public let report: [String]

    public init(text: String, report: [String]) {
        self.text = text
        self.report = report
    }
}

public struct DiffBudgeter: Sendable {
    public let tokenBudget: Int
    public let countTokens: @Sendable (String) async throws -> Int

    public init(tokenBudget: Int = 3_000, countTokens: @escaping @Sendable (String) async throws -> Int) {
        self.tokenBudget = tokenBudget
        self.countTokens = countTokens
    }

    public func pack(changes: StagedChanges) async throws -> EvidencePack {
        var report: [String] = []

        var summaryLines = ["Staged files:"]
        for file in changes.files {
            let stat = file.isBinary ? "binary" : "+\(file.additions ?? 0) -\(file.deletions ?? 0)"
            summaryLines.append("\(file.status)\t\(file.path)\t(\(stat))")
        }
        var text = summaryLines.joined(separator: "\n") + "\n"
        let summaryTokens = try await countTokens(text)
        if summaryTokens > tokenBudget {
            throw RivetError.internalFailure("evidence summary exceeds token budget: \(summaryTokens) tokens > budget \(tokenBudget)")
        }

        let binaries = Set(changes.files.filter(\.isBinary).map(\.path))
        let magnitudes = Dictionary(uniqueKeysWithValues: changes.files.map { ($0.path, $0.magnitude) })
        let ordered = DiffSplitter.split(changes.diff).sorted {
            let (l, r) = (magnitudes[$0.path] ?? 0, magnitudes[$1.path] ?? 0)
            return l != r ? l > r : $0.path < $1.path
        }

        for section in ordered {
            if GeneratedPaths.isGenerated(section.path) {
                report.append("excluded (generated): \(section.path)")
                continue
            }
            if binaries.contains(section.path) {
                report.append("excluded (binary): \(section.path)")
                continue
            }

            let fullCandidate = text + "\n" + section.content + "\n"
            if try await countTokens(fullCandidate) <= tokenBudget {
                text = fullCandidate
                report.append("included (full): \(section.path)")
                continue
            }

            let headers = section.content
                .split(separator: "\n")
                .filter { $0.hasPrefix("diff --git ") || $0.hasPrefix("@@") }
                .joined(separator: "\n")
            let headerCandidate = text + "\n" + headers + "\n"
            if try await countTokens(headerCandidate) <= tokenBudget {
                text = headerCandidate
                report.append("included (hunk headers only): \(section.path)")
            } else {
                report.append("elided (over budget): \(section.path)")
            }
        }

        return EvidencePack(text: text, report: report)
    }
}
