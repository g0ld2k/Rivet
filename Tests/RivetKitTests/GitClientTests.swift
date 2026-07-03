import Foundation
import Testing
@testable import RivetKit

/// Creates a fresh git repository in a temporary directory. Shared with GitEvidenceTests.
func makeTempRepo() throws -> URL {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let git = GitClient(workingDirectory: dir)
    try git.run(["init", "-b", "main"])
    try git.run(["config", "user.email", "test@example.com"])
    try git.run(["config", "user.name", "Test"])
    return dir
}

@Suite struct GitClientTests {
    @Test func runsGitInWorkingDirectory() throws {
        let repo = try makeTempRepo()
        let result = try GitClient(workingDirectory: repo).run(["rev-parse", "--is-inside-work-tree"])
        #expect(result.status == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "true")
    }

    @Test func reportsNonZeroStatusOutsideRepo() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = try GitClient(workingDirectory: dir).run(["rev-parse", "--is-inside-work-tree"])
        #expect(result.status != 0)
        #expect(!result.stderr.isEmpty)
    }

    @Test func leavesNonASCIIGitPathsUnescaped() throws {
        let repo = try makeTempRepo()
        let filename = "café.txt"
        try "content".write(to: repo.appending(path: filename), atomically: true, encoding: .utf8)
        try GitClient(workingDirectory: repo).run(["add", filename])

        let result = try GitClient(workingDirectory: repo).run(["ls-files"])
        #expect(result.status == 0)
        #expect(result.stdout == "\(filename)\n")
    }
}
