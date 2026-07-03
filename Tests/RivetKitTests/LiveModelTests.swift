import Foundation
import Testing
@testable import RivetKit

/// Live on-device generation smoke test. Skipped unless RIVET_LIVE_MODEL=1
/// (requires eligible hardware with Apple Intelligence enabled).
@Suite struct LiveModelTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RIVET_LIVE_MODEL"] == "1"))
    func generatesADraftFromTinyEvidence() async throws {
        let evidence = """
        Staged files:
        M\tSources/App/Login.swift\t(+3 -0)

        diff --git a/Sources/App/Login.swift b/Sources/App/Login.swift
        @@ -10,0 +11,3 @@
        +func validatePassword(_ candidate: String) -> Bool {
        +    candidate.count >= 12
        +}
        """
        let generator = try CommitMessageGenerator()
        let draft = try await generator.generate(evidence: evidence, scopeCandidates: ["App"])
        #expect(!draft.subject.isEmpty)
        #expect(!draft.rationale.isEmpty)
    }
}
