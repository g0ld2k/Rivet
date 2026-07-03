public struct FileDiff: Equatable, Sendable {
    public let path: String
    public let content: String

    public init(path: String, content: String) {
        self.path = path
        self.content = content
    }
}

public enum DiffSplitter {
    public static func split(_ diff: String) -> [FileDiff] {
        var sections: [FileDiff] = []
        var currentPath: String?
        var currentLines: [String] = []

        func flush() {
            if let path = currentPath {
                sections.append(FileDiff(path: path, content: currentLines.joined(separator: "\n")))
            }
        }

        for line in diff.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("diff --git ") {
                flush()
                currentPath = pathFromHeader(String(line))
                currentLines = [String(line)]
            } else if currentPath != nil {
                currentLines.append(String(line))
            }
        }
        flush()
        return sections
    }

    static func pathFromHeader(_ header: String) -> String {
        // "diff --git a/X b/Y" → Y (the post-image path)
        let prefix = "diff --git a/"
        guard header.hasPrefix(prefix) else { return header }

        let paths = header.dropFirst(prefix.count)
        var searchStart = paths.startIndex
        var firstPostImagePathStart: String.Index?

        while let range = paths.range(of: " b/", range: searchStart..<paths.endIndex) {
            let preImagePath = paths[..<range.lowerBound]
            let postImagePathStart = range.upperBound
            let postImagePath = paths[postImagePathStart...]

            if preImagePath == postImagePath {
                return String(postImagePath)
            }

            if firstPostImagePathStart == nil {
                firstPostImagePathStart = postImagePathStart
            }
            searchStart = postImagePathStart
        }

        guard let firstPostImagePathStart else { return header }
        return String(paths[firstPostImagePathStart...])
    }
}

public enum GeneratedPaths {
    static let exactNames: Set<String> = ["Package.resolved"]
    static let suffixes = [".lock", ".pbxproj", ".xcuserstate"]

    public static func isGenerated(_ path: String) -> Bool {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return exactNames.contains(name) || suffixes.contains { name.hasSuffix($0) }
    }
}
