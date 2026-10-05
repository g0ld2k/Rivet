import FoundationModels

public struct CommitMessageGenerator {
    public let model: SystemLanguageModel
    private let session: LanguageModelSession

    /// Gates on model availability (throws `RivetError.modelUnavailable`) and
    /// starts prewarming so model load overlaps diff analysis.
    public init() throws {
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        try ModelGate.ensureAvailable(model)
        self.model = model
        self.session = LanguageModelSession(model: model, instructions: CommitPrompt.instructions)
        session.prewarm()
    }

    public func generate(
        evidence: String,
        scopeCandidates: [String],
        feedback: String? = nil
    ) async throws -> CommitDraft {
        let prompt = CommitPrompt.prompt(evidence: evidence, scopeCandidates: scopeCandidates, feedback: feedback)
        let options = GenerationOptions(sampling: .greedy, maximumResponseTokens: 500)
        do {
            let response = try await session.respond(to: prompt, generating: CommitDraft.self, options: options)
            return response.content
        } catch {
            throw GenerationFailure.rivetError(from: error)
        }
    }
}
