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
}
