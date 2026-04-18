# Skill templates

Every kstack skill lives under `skills/<name>/` and is authored as a `SKILL.md.tmpl` file. The `install` script resolves placeholders into a concrete `SKILL.md` at install time and writes it into each agent's skill directory. `install` has two modes — repo-local (default; writes into `<repo>/.<agent>/skills/<name>/`) and global (`--global`; writes into `~/.<agent>/skills/kstack-<name>/` and installs helpers at `~/.config/kstack/bin/`).

## Placeholders

| Placeholder         | Repo-local resolves to                           | Global resolves to                                   | Notes                                          |
|---------------------|--------------------------------------------------|------------------------------------------------------|------------------------------------------------|
| `{{INSTALL_ROOT}}`  | `<repo>`                                         | `~/.config/kstack`                                   | The root that owns `bin/` for this install     |
| `{{BIN_DIR}}`       | `<repo>/bin`                                     | `~/.config/kstack/bin`                               | Stable absolute path to compiled helpers       |
| `{{MAN_PATH}}`      | `<repo>/.<agent>/skills/<name>/SKILL.man`        | `~/.<agent>/skills/kstack-<name>/SKILL.man`          | Absolute path to this skill's rendered man page|
| `{{SKILL_NAME}}`    | bare skill name                                  | bare skill name                                      | e.g. `cluster-status` (drives slash command)   |
| `{{AGENT}}`         | `claude` / `codex` / …                           | `claude` / `codex` / …                               | Target agent                                   |
| `{{GLOBAL_FLAGS}}`  | inlined partial content                          | inlined partial content                              | See Partials                                   |
| `{{UPDATE_CHECK}}`  | inlined partial content                          | inlined partial content                              | See Partials                                   |

## Rules

1. `SKILL.md.tmpl` is the source of truth. `SKILL.md` is generated — never edit it by hand.
2. `install` inlines any partials, then runs literal `sed`-style substitution of the scalar placeholders, and writes the resolved `SKILL.md` directly into the agent's skill directory (no intermediate dist/ dir, no symlinks). Repo-local writes to `<repo>/.<agent>/skills/<name>/SKILL.md`; global writes to `~/.<agent>/skills/kstack-<name>/SKILL.md`.
3. Agent install paths come from the table in the top-level `README.md`.
4. When a skill body shells out to a compiled helper, use `{{BIN_DIR}}/<tool>` so the absolute path is baked in at install time.
5. Repo-local install artifacts (`<repo>/.<agent>/skills/<name>/`) are gitignored — only `.tmpl` sources are tracked.
6. Alongside each `SKILL.md`, `install` renders a `SKILL.man` from the top-level `README.md`'s per-skill `<dt>/<dd>` section plus the global-flags table. The file ends with the literal line `=== END HELP ===`. The `{{GLOBAL_FLAGS}}` partial instructs the skill to `cat {{MAN_PATH}}` on `--help` and to treat the sentinel as end-of-turn. Every skill directory listed in `skills/` must have a matching section in the top-level `README.md`; `install` aborts otherwise.

## Partials

Cross-cutting prose that every skill needs (e.g. the global-flags contract) lives under `skills/_partials/` and is inlined at render time via a dedicated placeholder.

- `_partials/` is **not** a skill directory — `install` enumerates only dirs that contain a `SKILL.md.tmpl`, so the underscore-prefixed folder is silently skipped.
- Each partial is referenced from a `SKILL.md.tmpl` via a `{{NAME}}` marker on its own line. `install` replaces the marker with the file's verbatim contents before running scalar substitutions.
- Current partials:
  - `_partials/global-flags.md` → `{{GLOBAL_FLAGS}}` (the four global flags documented in the top-level `README.md`).
  - `_partials/update-check.md` → `{{UPDATE_CHECK}}` (instructs the agent to run `bin/check-update`, `bin/upgrade`, `bin/dismiss-update` on the user's behalf).
- Partials are kept placeholder-free. If a future partial needs `{{BIN_DIR}}` etc., that's fine — scalar substitution runs after the inline, so they resolve normally.

## Minimum template shape

```markdown
---
name: {{SKILL_NAME}}
description: <one-line outcome + differentiator>
agent: {{AGENT}}
install_root: {{INSTALL_ROOT}}
bin_dir: {{BIN_DIR}}
---

{{UPDATE_CHECK}}

{{GLOBAL_FLAGS}}

<body>
```

Follow `/cluster-status` as the reference implementation once it lands — its structure is the pattern the other skills copy.
