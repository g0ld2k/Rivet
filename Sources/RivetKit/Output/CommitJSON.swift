import Foundation

public enum CommitJSON {
    struct Payload: Codable {
        let type: String
        let scope: String?
        let subject: String
        let body: String?
        let breaking: Bool
        let rationale: String

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(scope, forKey: .scope)       // explicit null when nil
            try container.encode(subject, forKey: .subject)
            try container.encode(body, forKey: .body)         // explicit null when nil
            try container.encode(breaking, forKey: .breaking)
            try container.encode(rationale, forKey: .rationale)
        }
    }

    public static func render(commit: ConventionalCommit, rationale: String) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = Payload(type: commit.type, scope: commit.scope, subject: commit.subject,
                              body: commit.body, breaking: commit.isBreaking, rationale: rationale)
        return String(decoding: try encoder.encode(payload), as: UTF8.self)
    }
}
