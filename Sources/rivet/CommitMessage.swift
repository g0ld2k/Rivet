import ArgumentParser
import Foundation
import RivetKit

struct CommitMessage: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "commit-message",
        abstract: "Generate a Conventional Commit message from staged changes."
    )

    @Flag(help: "Emit machine-readable JSON on stdout instead of the message.")
    var json = false

    @Flag(help: "Report diff budgeting decisions on stderr.")
    var verbose = false

    @Flag(help: "Suppress rationale and progress output on stderr.")
    var quiet = false

    func run() async throws {
        let console = Console()
        do {
            try await execute(console: console)
        } catch let error as RivetError {
            console.error(error.message)
            throw ExitCode(error.exitCode)
        }
    }

    private func execute(console: Console) async throws {
        // Gather
        let git = GitClient()
        guard GitEvidence.isInsideWorkTree(git) else { throw RivetError.notAGitRepository }
        guard try GitEvidence.hasStagedChanges(git) else { throw RivetError.noStagedChanges }
        let changes = try GitEvidence.stagedChanges(git)
        let manifest = try GitEvidence.stagedFileText(git, path: "Package.swift")

        // Analyze (generator init first: availability gate + prewarm overlap budgeting)
        let scopes = ScopeInference.candidates(paths: changes.files.map(\.path), packageManifest: manifest)
        let generator = try CommitMessageGenerator()
        let budgeter = DiffBudgeter(countTokens: { [model = generator.model] text in
            try await model.tokenCount(for: text)
        })
        let pack = try await budgeter.pack(changes: changes)
        if verbose {
            for line in pack.report { console.note("budget: \(line)") }
        }

        // Generate
        if !quiet { console.status("generating commit message…") }
        var draft = try await generator.generate(evidence: pack.text, scopeCandidates: scopes)

        // Validate (one retry on semantic failure)
        var result = CommitValidator.validate(draft.conventionalCommit, scopeCandidates: scopes)
        if !result.violations.isEmpty {
            let feedback = result.violations.map(\.message).joined(separator: "; ")
            if !quiet { console.status("draft rejected (\(feedback)); retrying…") }
            draft = try await generator.generate(evidence: pack.text, scopeCandidates: scopes, feedback: feedback)
            result = CommitValidator.validate(draft.conventionalCommit, scopeCandidates: scopes)
            guard result.violations.isEmpty else {
                throw RivetError.generationFailed(result.violations.map(\.message).joined(separator: "; "))
            }
        }

        // Present — the artifact is the only thing on stdout
        if json {
            print(try CommitJSON.render(commit: result.commit, rationale: draft.rationale))
        } else {
            print(result.commit.formatted())
        }
        if !quiet { console.note(console.paint("rationale: \(draft.rationale)", .dim)) }
    }
}
