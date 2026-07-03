# Rivet

Local-first developer writing workflows over repository evidence, for macOS 27+.

Rivet turns repository state into high-quality project artifacts. The first
workflow generates evidence-based [Conventional Commit](https://www.conventionalcommits.org)
messages from your staged changes — analyzed deterministically, written by the
on-device model, validated before you see it. Nothing leaves your Mac, and
Rivet never modifies your repository.

## Requirements

- macOS 27 or later on Apple silicon
- Apple Intelligence enabled (System Settings › Apple Intelligence & Siri)

## Usage

```sh
rivet doctor                 # verify this machine can run Rivet workflows
rivet commit-message         # propose a commit message for staged changes
rivet commit-message --json  # machine-readable output
rivet commit-message -h      # all flags
```

The commit message is the only thing written to stdout, so it composes:

```sh
git commit -eF <(rivet commit-message --quiet)
```

Rationale and progress go to stderr; suppress them with `--quiet`. Use
`--verbose` to see exactly which diff content was included in the model's
evidence and which was elided to stay within the on-device token budget.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 2 | Usage error |
| 3 | Not a git repository |
| 4 | No staged changes |
| 5 | Model unavailable (run `rivet doctor`) |
| 6 | Generation or validation failed |

## How it works

Each workflow follows the same shape: gather bounded evidence (only the staged
file list, stats, and diff), analyze it deterministically, make one
schema-constrained call to Apple's on-device Foundation Models, validate the
result, and print it. The model writes prose; it never chooses actions.

## Building

```sh
swift build
swift test                          # everything except live generation
RIVET_LIVE_MODEL=1 swift test       # include the on-device generation smoke test
```
