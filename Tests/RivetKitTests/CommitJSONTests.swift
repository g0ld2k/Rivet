import Foundation
import Testing
@testable import RivetKit

@Suite struct CommitJSONTests {
    @Test func rendersAllFieldsWithSortedKeys() throws {
        let commit = ConventionalCommit(type: "feat", scope: "RivetKit", isBreaking: true,
                                        subject: "add budgeter", body: "Adds the ladder.",
                                        breakingDescription: "API changed")
        let json = try CommitJSON.render(commit: commit, rationale: "evidence says so")
        let decoded = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        #expect(decoded?["type"] as? String == "feat")
        #expect(decoded?["scope"] as? String == "RivetKit")
        #expect(decoded?["subject"] as? String == "add budgeter")
        #expect(decoded?["breaking"] as? Bool == true)
        #expect(decoded?["rationale"] as? String == "evidence says so")
    }

    @Test func omittedScopeSerializesAsNull() throws {
        let commit = ConventionalCommit(type: "fix", scope: nil, isBreaking: false,
                                        subject: "handle empty diff", body: nil, breakingDescription: nil)
        let json = try CommitJSON.render(commit: commit, rationale: "r")
        #expect(json.contains("\"scope\" : null"))
    }
}
