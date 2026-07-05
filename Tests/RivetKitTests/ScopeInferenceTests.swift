import Testing
@testable import RivetKit

@Suite struct ScopeInferenceTests {
    let manifest = """
    let package = Package(
        name: "Rivet",
        targets: [
            .executableTarget(name: "rivet", dependencies: ["RivetKit"]),
            .target(name: "RivetKit"),
            .testTarget(name: "RivetKitTests", dependencies: ["RivetKit"]),
        ]
    )
    """

    @Test func extractsTargetNames() {
        #expect(ScopeInference.targetNames(in: manifest) == ["rivet", "RivetKit", "RivetKitTests"])
    }

    @Test func targetsOwningChangedPathsComeFirst() {
        let paths = ["Sources/RivetKit/Git/GitClient.swift", "Sources/RivetKit/Output/Console.swift"]
        let candidates = ScopeInference.candidates(paths: paths, packageManifest: manifest)
        #expect(candidates.first == "RivetKit")
    }

    @Test func topLevelDirectoriesOrderedByFrequencyThenName() {
        let paths = ["docs/a.md", "scripts/build.sh", "scripts/test.sh"]
        #expect(ScopeInference.candidates(paths: paths, packageManifest: nil) == ["scripts", "docs"])
    }

    @Test func rootFilesYieldNoCandidates() {
        #expect(ScopeInference.candidates(paths: ["README.md"], packageManifest: nil).isEmpty)
    }

    @Test func dedupesCaseInsensitively() {
        let paths = ["Sources/RivetKit/A.swift", "sources/x.swift"]
        let candidates = ScopeInference.candidates(paths: paths, packageManifest: manifest)
        #expect(candidates.filter { $0.lowercased() == "sources" }.count == 1)
    }
}
