import FoundationModels

@Generable(description: "Conventional Commit type.")
public enum CommitType: String, CaseIterable, Sendable {
    case feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
}

@Generable(description: "A Conventional Commit derived strictly from staged-change evidence.")
public struct CommitDraft: Sendable {
    @Guide(description: "The commit type that best matches the staged change.")
    public var type: CommitType

    @Guide(description: "Affected area of the codebase. Pick one of the candidate scopes listed in the prompt, or omit if none fits.")
    public var scope: String?

    @Guide(description: "Imperative-mood summary of the change, under 60 characters, no trailing period. Example: add diff budgeting ladder")
    public var subject: String

    @Guide(description: "Optional short prose body explaining what changed and why. Omit for trivial changes.")
    public var body: String?

    @Guide(description: "True only when the change breaks existing behavior, APIs, or configuration.")
    public var isBreaking: Bool

    @Guide(description: "If breaking: one line describing what breaks. Otherwise omit.")
    public var breakingDescription: String?

    @Guide(description: "One or two sentences citing the concrete evidence (files, hunks) behind this message.")
    public var rationale: String

    public init(type: CommitType, scope: String?, subject: String, body: String?,
                isBreaking: Bool, breakingDescription: String?, rationale: String) {
        self.type = type
        self.scope = scope
        self.subject = subject
        self.body = body
        self.isBreaking = isBreaking
        self.breakingDescription = breakingDescription
        self.rationale = rationale
    }
}

extension CommitDraft {
    public var conventionalCommit: ConventionalCommit {
        ConventionalCommit(
            type: type.rawValue,
            scope: scope,
            isBreaking: isBreaking,
            subject: subject,
            body: body,
            breakingDescription: breakingDescription
        )
    }
}
