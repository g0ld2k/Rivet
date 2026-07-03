import ArgumentParser

@main
struct Rivet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rivet",
        abstract: "Local-first developer writing workflows over repository evidence.",
        version: "0.1.0",
        subcommands: [Doctor.self]
    )
}
