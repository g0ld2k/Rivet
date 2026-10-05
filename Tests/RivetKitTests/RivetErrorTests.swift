import Testing
@testable import RivetKit

@Suite struct RivetErrorTests {
    @Test func exitCodesMatchContract() {
        #expect(RivetError.internalFailure("x").exitCode == 1)
        #expect(RivetError.notAGitRepository.exitCode == 3)
        #expect(RivetError.noStagedChanges.exitCode == 4)
        #expect(RivetError.modelUnavailable("off").exitCode == 5)
        #expect(RivetError.generationFailed("bad").exitCode == 6)
    }

    @Test func messagesIncludeDetail() {
        #expect(RivetError.modelUnavailable("Apple Intelligence is off").message.contains("Apple Intelligence is off"))
        #expect(RivetError.generationFailed("subject empty").message.contains("subject empty"))
    }
}
