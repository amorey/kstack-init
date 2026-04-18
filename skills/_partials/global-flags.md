## Global flags

Every kstack skill accepts these flags. Parse them off the invocation before handling skill-specific arguments, then apply the rules below to every `kubectl` or `kubetail` command the skill generates.

- `--context <ctx>` — Append `--context=<ctx>` to every kubectl/kubetail call. Do not fall back to the current-context when the user supplied one.
- `--namespace <n>` (alias `-n`) — Append `-n <n>` (or `--namespace=<n>`) to every kubectl/kubetail call, and skip any `--all-namespaces` default the skill would otherwise use.
- `--json` — Emit a single structured JSON object instead of prose. Schema is defined per-skill; do not mix prose and JSON in the same run.
- `--dry-run` — Do not execute commands. For each command the skill would run, print `# would run: <command>` and continue. End with "Dry run — no commands executed." No partial execution.
- `--help` — Run `cat {{MAN_PATH}}` and end the turn. The file's last line is the literal sentinel `=== END HELP ===` — as soon as you see that line in the tool result, stop: no summary, no restatement, no further commands.

### Unknown or missing arguments

If the user supplies a flag this skill does not document, respond with exactly one line and stop:

> ``Unknown flag `<flag>`. Run `/<skill> --help` for usage.``

If a required positional argument is missing, respond with exactly one line and stop:

> ``Missing required argument `<arg>` for `/<skill>`. Run `/<skill> --help` for usage.``

Do not print the man page in these cases, do not run kubectl, and do not attempt to infer the user's intent.

If a skill declares a local flag with the same name as one of the flags above (e.g. `/audit-cost` documents its own `--namespace`), the skill body's semantics override this document for that skill only.
