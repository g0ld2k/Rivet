import Testing
@testable import RivetKit

@Suite struct DiffBudgeterTests {
    /// Fake tokenizer: ~1 token per 4 characters, like real BPE order-of-magnitude.
    static let fakeCount: @Sendable (String) async throws -> Int = { $0.count / 4 }

    func changes(diff: String, files: [StagedFile]) -> StagedChanges {
        StagedChanges(files: files, diff: diff)
    }

    let smallDiff = """
    diff --git a/Sources/A.swift b/Sources/A.swift
    @@ -1,2 +1,3 @@
    +let b = 2
    """

    @Test func includesFullDiffWhenUnderBudget() async throws {
        let files = [StagedFile(path: "Sources/A.swift", status: "M", additions: 1, deletions: 0, isBinary: false)]
        let pack = try await DiffBudgeter(tokenBudget: 1_000, countTokens: Self.fakeCount)
            .pack(changes: changes(diff: smallDiff, files: files))
        #expect(pack.text.contains("+let b = 2"))
        #expect(pack.report.contains { $0.contains("included (full): Sources/A.swift") })
        #expect(try await Self.fakeCount(pack.text) <= 1_000)
    }

    @Test func degradesToHunkHeadersWhenOverBudget() async throws {
        let bigBody = String(repeating: "+let filler = 0\n", count: 400)
        let diff = "diff --git a/Sources/Big.swift b/Sources/Big.swift\n@@ -1,1 +1,400 @@\n" + bigBody
        let files = [StagedFile(path: "Sources/Big.swift", status: "M", additions: 400, deletions: 0, isBinary: false)]
        let pack = try await DiffBudgeter(tokenBudget: 120, countTokens: Self.fakeCount)
            .pack(changes: changes(diff: diff, files: files))
        #expect(!pack.text.contains("+let filler = 0"))
        #expect(pack.text.contains("@@ -1,1 +1,400 @@"))
        #expect(pack.report.contains { $0.contains("hunk headers only") })
    }

    @Test func elidesEntirelyWhenEvenHeadersDoNotFit() async throws {
        let hunks = (1...200).map { "@@ -\($0),1 +\($0),1 @@" }.joined(separator: "\nx\n")
        let diff = "diff --git a/Sources/Huge.swift b/Sources/Huge.swift\n" + hunks
        let files = [StagedFile(path: "Sources/Huge.swift", status: "M", additions: 200, deletions: 200, isBinary: false)]
        let pack = try await DiffBudgeter(tokenBudget: 40, countTokens: Self.fakeCount)
            .pack(changes: changes(diff: diff, files: files))
        #expect(pack.report.contains { $0.contains("elided (over budget): Sources/Huge.swift") })
        // The summary survives even when all content is elided.
        #expect(pack.text.contains("Sources/Huge.swift"))
    }

    @Test func excludesGeneratedAndBinaryContent() async throws {
        let diff = """
        diff --git a/Package.resolved b/Package.resolved
        @@ -1,1 +1,2 @@
        +  "version" : 3
        diff --git a/icon.png b/icon.png
        Binary files a/icon.png and b/icon.png differ
        """
        let files = [
            StagedFile(path: "Package.resolved", status: "M", additions: 1, deletions: 0, isBinary: false),
            StagedFile(path: "icon.png", status: "A", additions: nil, deletions: nil, isBinary: true),
        ]
        let pack = try await DiffBudgeter(tokenBudget: 1_000, countTokens: Self.fakeCount)
            .pack(changes: changes(diff: diff, files: files))
        #expect(!pack.text.contains("\"version\" : 3"))
        #expect(pack.report.contains { $0.contains("excluded (generated): Package.resolved") })
        #expect(pack.report.contains { $0.contains("excluded (binary): icon.png") })
    }

    @Test func largestChangesGetBudgetFirst() async throws {
        let diff = """
        diff --git a/small.swift b/small.swift
        @@ -1,1 +1,2 @@
        +tiny
        diff --git a/large.swift b/large.swift
        @@ -1,1 +1,50 @@
        \(String(repeating: "+line\n", count: 50))
        """
        let files = [
            StagedFile(path: "small.swift", status: "M", additions: 1, deletions: 0, isBinary: false),
            StagedFile(path: "large.swift", status: "M", additions: 50, deletions: 0, isBinary: false),
        ]
        let pack = try await DiffBudgeter(tokenBudget: 10_000, countTokens: Self.fakeCount)
            .pack(changes: changes(diff: diff, files: files))
        let largeIndex = pack.text.range(of: "diff --git a/large.swift")!.lowerBound
        let smallIndex = pack.text.range(of: "diff --git a/small.swift")!.lowerBound
        #expect(largeIndex < smallIndex)
    }

    @Test func throwsWhenSummaryAloneExceedsBudget() async throws {
        let files = (1...20).map {
            StagedFile(
                path: "Sources/Generated/VeryLongGeneratedFileNameNumber\($0).swift",
                status: "M",
                additions: 1,
                deletions: 0,
                isBinary: false
            )
        }

        do {
            let pack = try await DiffBudgeter(tokenBudget: 1, countTokens: Self.fakeCount)
                .pack(changes: changes(diff: "", files: files))
            Issue.record("Expected summary to exceed budget, returned \(try await Self.fakeCount(pack.text)) tokens")
        } catch let error as RivetError {
            #expect(error.kind == .internalFailure)
            #expect(error.message.contains("summary exceeds token budget"))
            #expect(error.message.contains("budget 1"))
        } catch {
            Issue.record("Expected RivetError.internalFailure, got \(error)")
        }
    }

    @Test func appliesPromptEnvelopeWhenCheckingBudget() async throws {
        let files = [StagedFile(path: "Sources/A.swift", status: "M", additions: 1, deletions: 0, isBinary: false)]
        let count: @Sendable (String) async throws -> Int = { text in
            text.contains("prompt wrapper") ? text.count : 1
        }

        do {
            let pack = try await DiffBudgeter(
                tokenBudget: 20,
                countTokens: count,
                promptEnvelope: { "prompt wrapper\n\($0)" }
            ).pack(changes: changes(diff: smallDiff, files: files))
            Issue.record("Expected wrapped prompt to exceed budget, returned \(pack.text)")
        } catch let error as RivetError {
            #expect(error.kind == .internalFailure)
            #expect(error.message.contains("summary exceeds token budget"))
        } catch {
            Issue.record("Expected RivetError.internalFailure, got \(error)")
        }
    }
}
