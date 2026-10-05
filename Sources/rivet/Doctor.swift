import ArgumentParser
import FoundationModels
import RivetKit

@Generable(description: "Tiny guided generation smoke-check payload.")
private struct DoctorGuidedGenerationProbe: Sendable {
    @Guide(description: "Always true when guided generation succeeds.")
    var supported: Bool
}

struct Doctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check that this machine can run Rivet workflows."
    )

    @Flag(help: "Emit machine-readable JSON on stdout.")
    var json = false

    func run() async throws {
        let console = Console()
        let model = SystemLanguageModel.default
        var checks: [DoctorCheck] = [
            DoctorChecks.macOSVersion(),
            DoctorChecks.modelAvailability(model.availability),
        ]
        if model.isAvailable {
            checks.append(await guidedGenerationCheck(model: model))
            let tokenResult: Result<Int, any Error>
            do {
                tokenResult = .success(try await model.tokenCount(for: "rivet doctor smoke check"))
            } catch {
                tokenResult = .failure(error)
            }
            checks.append(DoctorChecks.tokenizer(tokenResult))
        }

        if json {
            print(try DoctorReport.json(checks))
        } else {
            for line in DoctorReport.humanLines(checks, console: console) {
                console.writeLine(line)
            }
        }
        if !checks.allSatisfy(\.passed) {
            throw ExitCode(5)
        }
    }

    private func guidedGenerationCheck(model: SystemLanguageModel) async -> DoctorCheck {
        let session = LanguageModelSession(model: model)
        do {
            let options = GenerationOptions(sampling: .greedy, maximumResponseTokens: 20)
            try await session.respond(
                to: "Return a tiny object with supported set to true.",
                generating: DoctorGuidedGenerationProbe.self,
                options: options
            )
            return DoctorChecks.guidedGeneration(supported: true)
        } catch {
            return DoctorCheck(
                name: "Guided generation",
                passed: false,
                detail: DoctorChecks.failureDetail(error)
            )
        }
    }
}
