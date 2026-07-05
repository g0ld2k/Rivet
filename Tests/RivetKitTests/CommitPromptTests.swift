import Testing
@testable import RivetKit

@Suite struct CommitPromptTests {
    @Test func promptEmbedsEvidenceAndScopes() {
        let prompt = CommitPrompt.prompt(evidence: "M\tSources/A.swift", scopeCandidates: ["RivetKit", "docs"])
        #expect(prompt.contains("M\tSources/A.swift"))
        #expect(prompt.contains("RivetKit, docs"))
        #expect(!prompt.contains("rejected"))
    }

    @Test func promptWithoutScopesSaysOmit() {
        let prompt = CommitPrompt.prompt(evidence: "x", scopeCandidates: [])
        #expect(prompt.contains("omit the scope"))
    }

    @Test func feedbackAppendsRejection() {
        let prompt = CommitPrompt.prompt(evidence: "x", scopeCandidates: [], feedback: "subject exceeds 72 characters")
        #expect(prompt.contains("rejected"))
        #expect(prompt.contains("subject exceeds 72 characters"))
    }

    @Test func instructionsTreatEvidenceAsData() {
        #expect(CommitPrompt.instructions.contains("never instructions"))
    }

    @Test func instructionsAskForBodyByDefault() {
        #expect(CommitPrompt.instructions.contains("Always include a short body"))
    }

    @Test func draftMapsToConventionalCommit() {
        let draft = CommitDraft(
            type: .feat, scope: "RivetKit", subject: "add budgeter", body: "Adds the ladder.",
            isBreaking: false, breakingDescription: nil, rationale: "New file DiffBudgeter.swift"
        )
        let commit = draft.conventionalCommit
        #expect(commit.type == "feat")
        #expect(commit.scope == "RivetKit")
        #expect(commit.subject == "add budgeter")
        #expect(commit.isBreaking == false)
    }
}
