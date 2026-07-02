# Rivet v0 Design

**Date:** 2026-07-02
**Status:** Approved for implementation planning

## Product

`rivet` is a macOS 27+ SwiftPM command-line tool that turns repository state into
high-quality project artifacts — locally. v0 ships two commands: `rivet doctor`
and `rivet commit-message`.

Positioning: the product is *developer writing workflows over repository
evidence*. Apple Foundation Models is an implementation detail, mentioned in
"How it works," never in the tagline. `/usr/bin/fm` (Apple's generic Foundation
Models CLI) is neither used, wrapped, nor treated as a fallback; Rivet's value
is everything `fm` does not do — evidence gathering, deterministic analysis,
schema-constrained output, and workflow semantics.

### Principles

- Local developer workflow first. v0 is **on-device only** (`SystemLanguageModel`);
  `PrivateCloudComputeLanguageModel` is explicitly out of scope and may return
  later as an opt-in flag.
- Bounded input, enforced with the real tokenizer (`tokenCount(for:)`), never
  character heuristics.
- Structured output via `@Generable` constrained decoding, not post-hoc parsing.
- Deterministic analysis wherever possible; the model is used only for language
  generation over pre-digested evidence.
- Generation is **reproducible** (greedy sampling → identical output for
  identical input on a given OS version), not "deterministic" — docs use the
  words carefully.
- No repository mutation in v0. Ever.

### Non-goals (v0 and philosophy)

Not a prompt runner, chatbot, agent framework, MCP framework, multi-provider
abstraction, or general automation tool. No plugin system, no config file, no
custom adapters, no `--apply`, no other workflows (release notes, PR summaries,
changelogs are future work — supported by the emergent libraries below, not
designed for now).

## Architecture

Two SwiftPM targets. The Gather → Analyze → Generate → Validate → Present
pipeline is a **convention** each command follows in straight-line code, not a
framework. Extract shared machinery only when a third workflow proves the shape
(rule of three).

```
Package.swift            — platforms: [.macOS(27)]; dependency: swift-argument-parser only
Sources/
  rivet/                 — executable target: thin ArgumentParser commands
    Rivet.swift            root command, version, shared flags
    Doctor.swift
    CommitMessage.swift    straight-line pipeline
  RivetKit/              — library target: all logic, fully unit-testable
    Git/        GitRepository (git plumbing via Process), StagedChanges
    Analysis/   DiffBudgeter, ScopeInference
    Generate/   ModelGate (availability → typed errors), CommitDraft (@Generable),
                CommitMessageGenerator (Instructions + Prompt → one respond call)
    Commit/     ConventionalCommit (format, semantic validation, normalization)
    Output/     Console (TTY/NO_COLOR-aware stderr presentation), ExitCodes
Tests/RivetKitTests/     — fixture-driven; no model required
```

Emergent abstractions earned by workflow #1 and reusable by future workflows:
`Git/`, `DiffBudgeter`, `ModelGate`, `Output/`. These are libraries, not a
pipeline framework.

### Interface decisions

- **Swift Argument Parser, no TUI.** Full-screen TUI rejected for v0: it
  conflicts with pipe-clean stdout, Rivet's workflows are one-shot
  transformations with nothing to navigate, and Swift has no first-party TUI
  stack. The interaction model to emulate is `gh`, not lazygit.
- **stdout is the artifact; stderr is the conversation.** All human-facing
  presentation (color, spinner, rationale, streaming preview via
  `streamResponse`) lives in `Console` and writes to stderr.
- Respect `NO_COLOR` and `isatty`; plain output when not a TTY.

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 2 | Usage error (ArgumentParser default) |
| 3 | Not a git repository |
| 4 | No staged changes |
| 5 | Model unavailable (specific reason on stderr) |
| 6 | Generation or validation failed |

## `rivet doctor`

Checks in order, one ✓/✗ line each, actionable fix text on failure:

1. macOS version ≥ 27.
2. `SystemLanguageModel.default.availability` — each `UnavailableReason` mapped
   to guidance: `.deviceNotEligible` (hardware), `.appleIntelligenceNotEnabled`
   ("enable in System Settings › Apple Intelligence & Siri"), `.modelNotReady`
   ("model assets still downloading; retry shortly").
3. Capabilities include `.guidedGeneration`.
4. Smoke check: `tokenCount(for:)` on a trivial prompt succeeds; report
   measured availability of the tokenizer.

`--json` emits `{check, passed, detail}` records. Exit 0 only if all checks pass
(else 5).

## `rivet commit-message`

### 1. Gather

- Verify cwd is inside a git work tree (`git rev-parse --is-inside-work-tree`);
  exit 3 otherwise.
- Require staged changes (`git diff --cached --quiet` fails); exit 4 otherwise.
- Read **only**: staged name-status, staged numstat, staged diff
  (`git diff --cached` family, plumbing-safe flags, `-c core.quotePath=false`).
  Nothing else — no HEAD log, no remotes, no unstaged state.

### 2. Analyze (deterministic)

- **Scope candidates**: top-level directory names of changed paths; plus SwiftPM
  target names parsed from `Package.swift` when the changed paths fall under
  `Sources/<Target>` or `Tests/<Target>`. Pure function of paths → ordered
  candidate list; fully unit-tested.
- **DiffBudgeter** builds a bounded evidence pack with a deterministic
  degradation ladder:
  1. Always include: file list + numstat.
  2. Exclude generated/lock content by pattern (`Package.resolved`, `*.lock`,
     `*.pbxproj`, binary files) — listed by name only.
  3. Include full hunks while under budget, prioritizing files by change
     magnitude.
  4. Over budget: degrade to per-file hunk headers + counts, then numstat only.
  - Budget enforced with `SystemLanguageModel.tokenCount(for:)` against the
    assembled prompt; the token budget is a tunable constant (context window is
    not hardcoded; 26-era window was 4,096 tokens and 27's is unverified).
  - `--verbose` reports every budgeting decision and elision.

### 3. Generate

- `ModelGate` checks availability first and maps failure to exit 5 with the
  doctor-style reason.
- `prewarm()` is issued as soon as the gate passes, overlapping model load with
  analysis.
- One `respond(generating: CommitDraft.self)` call on a fresh
  `LanguageModelSession`:
  - `CommitDraft` is `@Generable`: enum `type` (`feat, fix, docs, style,
    refactor, perf, test, build, ci, chore, revert` — constrained decoding makes
    invalid types unrepresentable), `@Guide`-annotated `subject`, optional
    `body`, optional `scope` (free string, validated post-hoc), `isBreaking:
    Bool`, short `rationale`.
  - Stable task text in `Instructions`; evidence pack in `Prompt` (instructions
    outrank prompt content — partial defense against adversarial diff text).
  - `GenerationOptions(samplingMode: .greedy, maximumResponseTokens: bounded)`.
  - Guardrails: `.permissiveContentTransformations` (reduces false positives
    when transforming user content such as diffs).
- Typed error mapping: `guardrailViolation`, `refusal` (surface its
  `.explanation`), `rateLimited`, `timeout` → distinct stderr messages, exit 6;
  `contextSizeExceeded` indicates a DiffBudgeter bug and says so.

### 4. Validate (semantic only)

Structure is guaranteed by constrained decoding; remaining checks:

- Subject: non-empty, ≤ 72 chars, no trailing period; lowercase first word
  normalization per Conventional Commits convention.
- Scope: must be in the computed candidate list, else dropped (message remains
  valid without a scope).
- Body: wrapped at 72 columns; `BREAKING CHANGE:` footer emitted when
  `isBreaking`.
- On semantic failure: one retry with the violation appended to the prompt;
  second failure → exit 6 with the draft and reason on stderr.

### 5. Present

- stdout: the formatted Conventional Commit message, nothing else — pipe-clean
  always (`git commit -eF <(rivet commit-message)` works day one).
- stderr: progress spinner, streamed draft preview, and rationale (suppress
  with `--quiet`).
- `--json`: `{type, scope, subject, body, breaking, rationale}` to stdout
  instead of the formatted message.
- No repository mutation.

## Testing strategy

- Foundation Models cannot run in CI (requires eligible hardware with Apple
  Intelligence enabled), so everything except the live `respond` call is
  deterministic and covered by plain unit tests in `RivetKitTests`: git output
  parsing, scope inference, budgeting ladder, conventional-commit formatting,
  semantic validation, prompt assembly (snapshot fixtures of real diffs).
- The generate step is a narrow `internal` function — prompt in, `CommitDraft`
  out — so tests exercise both sides without the model. This is a test seam,
  not a provider abstraction; it stays internal.
- A small manually-run integration test (guarded by an env var) exercises the
  live model on developer machines.

## Foundation Models API notes (verified against macOS 27 SDK, module 2.0.55)

- `LanguageModel` protocol is new in 27; `LanguageModelSession` is generic over
  `some LanguageModel`. Rivet needs no provider abstraction of its own.
- `SystemLanguageModel.init(adapter:)` is obsoleted in 27 — target 27 API
  shapes, not 26-era examples.
- `ContextOptions.reasoningLevel` (new in 27) defaults are fine for commit
  messages; not exposed as a flag in v0.
- `tokenCount(for:)` requires 26.4+; fine under a 27 floor.
