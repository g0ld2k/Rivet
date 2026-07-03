import Testing
@testable import RivetKit

@Suite struct ConventionalCommitTests {
    @Test func formatsHeaderWithScopeAndBreakingMarker() {
        let commit = ConventionalCommit(
            type: "feat", scope: "RivetKit", isBreaking: true,
            subject: "add diff budgeter", body: nil, breakingDescription: "EvidencePack API changed"
        )
        #expect(commit.formatted() == """
        feat(RivetKit)!: add diff budgeter

        BREAKING CHANGE: EvidencePack API changed
        """)
    }

    @Test func formatsPlainHeaderAndWrappedBody() {
        let longBody = String(repeating: "word ", count: 30).trimmingCharacters(in: .whitespaces)
        let commit = ConventionalCommit(
            type: "fix", scope: nil, isBreaking: false,
            subject: "handle empty diff", body: longBody, breakingDescription: nil
        )
        let formatted = commit.formatted()
        #expect(formatted.hasPrefix("fix: handle empty diff\n\n"))
        #expect(formatted.split(separator: "\n").allSatisfy { $0.count <= 72 })
    }

    @Test func normalizeTrimsAndLowercasesAndStripsTrailingPeriod() {
        let commit = ConventionalCommit(
            type: "docs", scope: "  ", isBreaking: false,
            subject: "  Update the README. ", body: " ", breakingDescription: nil
        )
        let normalized = CommitValidator.normalize(commit)
        #expect(normalized.subject == "update the README")
        #expect(normalized.scope == nil)
        #expect(normalized.body == nil)
    }

    @Test func validateFlagsEmptyAndOverlongSubjects() {
        let empty = ConventionalCommit(type: "fix", scope: nil, isBreaking: false,
                                       subject: "", body: nil, breakingDescription: nil)
        #expect(!CommitValidator.validate(empty, scopeCandidates: []).violations.isEmpty)

        let long = ConventionalCommit(type: "fix", scope: nil, isBreaking: false,
                                      subject: String(repeating: "a", count: 80),
                                      body: nil, breakingDescription: nil)
        #expect(CommitValidator.validate(long, scopeCandidates: []).violations
            .contains { $0.message.contains("72") })
    }

    @Test func validateFlagsInvalidTypes() {
        let invalidTypes = ["banana", "Feat", "fi x", "fix\nfeat"]
        for type in invalidTypes {
            let commit = ConventionalCommit(type: type, scope: nil, isBreaking: false,
                                            subject: "add thing", body: nil, breakingDescription: nil)
            #expect(CommitValidator.validate(commit, scopeCandidates: []).violations
                .contains { $0.message.contains("type") })
        }
    }

    @Test func validateFlagsSubjectsContainingNewlines() {
        let subjects = [
            "handle empty diff\nwith detail",
            "handle empty diff\rwith detail",
            "add thing\n",
            "\radd thing",
        ]
        for subject in subjects {
            let commit = ConventionalCommit(type: "fix", scope: nil, isBreaking: false,
                                            subject: subject, body: nil, breakingDescription: nil)
            #expect(CommitValidator.validate(commit, scopeCandidates: []).violations
                .contains { $0.message.contains("newline") })
        }
    }

    @Test func validateDropsUnknownScopeSilently() {
        let commit = ConventionalCommit(type: "feat", scope: "Nonsense", isBreaking: false,
                                        subject: "add thing", body: nil, breakingDescription: nil)
        let result = CommitValidator.validate(commit, scopeCandidates: ["RivetKit", "docs"])
        #expect(result.commit.scope == nil)
        #expect(result.violations.isEmpty)
    }

    @Test func validateKeepsKnownScopeCaseInsensitively() {
        let commit = ConventionalCommit(type: "feat", scope: "rivetkit", isBreaking: false,
                                        subject: "add thing", body: nil, breakingDescription: nil)
        let result = CommitValidator.validate(commit, scopeCandidates: ["RivetKit"])
        #expect(result.commit.scope == "rivetkit")
    }

    @Test func validateDropsUnsafeScopesAndReportsViolation() {
        let unsafeScopes = ["Rivet)Kit", "Rivet\nKit", "Rivet\rKit", "api\r", "\napi"]
        for scope in unsafeScopes {
            let commit = ConventionalCommit(type: "feat", scope: scope, isBreaking: false,
                                            subject: "add thing", body: nil, breakingDescription: nil)
            let result = CommitValidator.validate(commit, scopeCandidates: [scope])
            #expect(result.commit.scope == nil)
            #expect(result.violations.contains { $0.message.contains("scope") })
        }
    }

    @Test func wrapRespectsWidthAndExistingNewlines() {
        let wrapped = CommitValidator.wrap("aaa bbb ccc", width: 7)
        #expect(wrapped == "aaa bbb\nccc")
        #expect(CommitValidator.wrap("one\ntwo", width: 72) == "one\ntwo")
    }
}
