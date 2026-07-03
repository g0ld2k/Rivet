import Testing
@testable import RivetKit

@Suite struct DiffSplitterTests {
    let diff = """
    diff --git a/Sources/A.swift b/Sources/A.swift
    index 1111111..2222222 100644
    --- a/Sources/A.swift
    +++ b/Sources/A.swift
    @@ -1,2 +1,3 @@
     let a = 1
    +let b = 2
    diff --git a/docs/guide.md b/docs/guide.md
    @@ -5,1 +5,2 @@
    +New paragraph.
    """

    @Test func splitsIntoPerFileSections() {
        let sections = DiffSplitter.split(diff)
        #expect(sections.count == 2)
        #expect(sections[0].path == "Sources/A.swift")
        #expect(sections[0].content.hasPrefix("diff --git a/Sources/A.swift"))
        #expect(sections[0].content.contains("+let b = 2"))
        #expect(sections[1].path == "docs/guide.md")
    }

    @Test func emptyDiffYieldsNoSections() {
        #expect(DiffSplitter.split("").isEmpty)
    }

    @Test func parsesPostImagePathContainingBSlash() {
        let diff = """
        diff --git a/a b/c.swift b/a b/c.swift
        @@ -1 +1 @@
        -old
        +new
        """

        let sections = DiffSplitter.split(diff)

        #expect(DiffSplitter.pathFromHeader("diff --git a/a b/c.swift b/a b/c.swift") == "a b/c.swift")
        #expect(sections.map(\.path) == ["a b/c.swift"])
    }

    @Test func generatedPathDetection() {
        #expect(GeneratedPaths.isGenerated("Package.resolved"))
        #expect(GeneratedPaths.isGenerated("ios/Podfile.lock"))
        #expect(GeneratedPaths.isGenerated("App.xcodeproj/project.pbxproj"))
        #expect(GeneratedPaths.isGenerated("Sources/A.swift") == false)
    }
}
