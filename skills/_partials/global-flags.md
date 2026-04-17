## Global flags

Every kstack skill accepts these four flags. Parse them off the invocation before handling skill-specific arguments, then apply the rules below to every `kubectl` or `kubetail` command the skill generates.

- `--context <ctx>` — Append `--context=<ctx>` to every kubectl/kubetail call. Do not fall back to the current-context when the user supplied one.
- `--namespace <n>` (alias `-n`) — Append `-n <n>` (or `--namespace=<n>`) to every kubectl/kubetail call, and skip any `--all-namespaces` default the skill would otherwise use.
- `--json` — Emit a single structured JSON object instead of prose. Schema is defined per-skill; do not mix prose and JSON in the same run.
- `--dry-run` — Do not execute commands. For each command the skill would run, print `# would run: <command>` and continue. End with "Dry run — no commands executed." No partial execution.

If a skill declares a local flag with the same name (e.g. `/audit-cost` documents its own `--namespace`), the skill body's semantics override this document for that skill only.
