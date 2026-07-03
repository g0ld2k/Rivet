import ArgumentParser
import FoundationModels
import RivetKit

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
            checks.append(DoctorChecks.guidedGeneration(supported: true))
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
}
