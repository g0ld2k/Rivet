public enum ScopeInference {
    public static func candidates(paths: [String], packageManifest: String?) -> [String] {
        var ordered: [String] = []

        if let manifest = packageManifest {
            for target in targetNames(in: manifest) {
                let owns = paths.contains {
                    $0.hasPrefix("Sources/\(target)/") || $0.hasPrefix("Tests/\(target)/")
                }
                if owns { ordered.append(target) }
            }
        }

        var counts: [String: Int] = [:]
        for path in paths {
            let components = path.split(separator: "/")
            guard components.count > 1 else { continue }
            counts[String(components[0]), default: 0] += 1
        }
        ordered.append(contentsOf: counts.sorted {
            $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key
        }.map(\.key))

        var seen = Set<String>()
        return ordered.filter { seen.insert($0.lowercased()).inserted }
    }

    static func targetNames(in manifest: String) -> [String] {
        let pattern = /\.(?:executableTarget|target|testTarget)\s*\(\s*name:\s*"([^"]+)"/
        return manifest.matches(of: pattern).map { String($0.1) }
    }
}
