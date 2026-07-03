import Foundation
import Testing
@testable import RivetKit

@Suite struct GitEvidenceParserTests {
    @Test func parsesNameStatusIncludingRenames() {
        let fixture = """
        M\tSources/RivetKit/Git/GitClient.swift
        A\tSources/RivetKit/Output/Console.swift
        D\told/Removed.swift
        R100\told/Name.swift\tnew/Name.swift
        """
        let entries = GitEvidence.parseNameStatus(fixture)
        #expect(entries.count == 4)
        #expect(entries[0].status == "M")
        #expect(entries[0].path == "Sources/RivetKit/Git/GitClient.swift")
        #expect(entries[3].status == "R")
        #expect(entries[3].path == "new/Name.swift")
    }

    @Test func parsesNumstatIncludingBinary() {
        let fixture = """
        12\t3\tSources/RivetKit/Git/GitClient.swift
        -\t-\tAssets/icon.png
        """
        let stats = GitEvidence.parseNumstat(fixture)
        #expect(stats["Sources/RivetKit/Git/GitClient.swift"]?.additions == 12)
        #expect(stats["Sources/RivetKit/Git/GitClient.swift"]?.deletions == 3)
        #expect(stats["Assets/icon.png"]?.additions == nil)
    }
}

@Suite struct GitEvidenceRepoTests {
    @Test func detectsStagedChangesEndToEnd() throws {
        let repo = try makeTempRepo()
        let git = GitClient(workingDirectory: repo)
        #expect(GitEvidence.isInsideWorkTree(git))
        #expect(try GitEvidence.hasStagedChanges(git) == false)

        try "let answer = 42\n".write(to: repo.appending(path: "Answer.swift"), atomically: true, encoding: .utf8)
        try git.run(["add", "Answer.swift"])
        #expect(try GitEvidence.hasStagedChanges(git) == true)

        let changes = try GitEvidence.stagedChanges(git)
        #expect(changes.files.count == 1)
        #expect(changes.files[0].path == "Answer.swift")
        #expect(changes.files[0].status == "A")
        #expect(changes.files[0].additions == 1)
        #expect(changes.files[0].isBinary == false)
        #expect(changes.diff.contains("diff --git"))
    }

    @Test func nonRepoIsNotInsideWorkTree() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        #expect(GitEvidence.isInsideWorkTree(GitClient(workingDirectory: dir)) == false)
    }

    @Test func repositoryRootResolvesFromSubdirectory() throws {
        let repo = try makeTempRepo()
        let sub = repo.appending(path: "Sources")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        // NSTemporaryDirectory() is behind a symlink on macOS; compare resolved paths.
        let root = GitEvidence.repositoryRoot(GitClient(workingDirectory: sub))
        #expect(root?.resolvingSymlinksInPath().path == repo.resolvingSymlinksInPath().path)
    }
}
