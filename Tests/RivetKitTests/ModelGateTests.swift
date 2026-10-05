import Foundation
import FoundationModels
import Testing
@testable import RivetKit

@Suite struct ModelGateTests {
    @Test func explainsEveryUnavailableReason() {
        #expect(ModelGate.explain(.deviceNotEligible).contains("hardware"))
        #expect(ModelGate.explain(.appleIntelligenceNotEnabled).contains("System Settings"))
        #expect(ModelGate.explain(.modelNotReady).contains("Try again"))
    }

    @Test func rivetErrorsPassThroughUnchanged() {
        let original = RivetError.noStagedChanges
        #expect(GenerationFailure.rivetError(from: original) == original)
    }

    @Test func unknownErrorsBecomeGenerationFailed() {
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        let mapped = GenerationFailure.rivetError(from: error)
        #expect(mapped.kind == .generationFailed)
        #expect(mapped.exitCode == 6)
    }

    @Test func assetsUnavailableBecomesModelUnavailable() {
        let error = LanguageModelSession.GenerationError.assetsUnavailable(.init(debugDescription: "assets missing"))
        let mapped = GenerationFailure.rivetError(from: error)
        #expect(mapped.kind == .modelUnavailable)
        #expect(mapped.exitCode == 5)
    }

    @Test func rateLimitedBecomesGenerationFailed() {
        let error = LanguageModelSession.GenerationError.rateLimited(.init(debugDescription: "too many requests"))
        let mapped = GenerationFailure.rivetError(from: error)
        #expect(mapped.kind == .generationFailed)
        #expect(mapped.exitCode == 6)
        #expect(mapped.message.contains("rate-limiting"))
    }

    @Test func exceededContextWindowReportsBudgetingBug() {
        let error = LanguageModelSession.GenerationError.exceededContextWindowSize(.init(debugDescription: "too long"))
        let mapped = GenerationFailure.rivetError(from: error)
        #expect(mapped.kind == .generationFailed)
        #expect(mapped.message.contains("budgeting bug"))
    }

    @Test func unsupportedGuideReportsPromptGuidanceFailure() {
        let error = LanguageModelSession.GenerationError.unsupportedGuide(.init(debugDescription: "bad guide"))
        let mapped = GenerationFailure.rivetError(from: error)
        #expect(mapped.kind == .generationFailed)
        #expect(mapped.message.contains("guidance"))
    }
}
