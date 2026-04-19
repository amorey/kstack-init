# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

It lives at `src/CLAUDE.md` (not the repo root) so end users running `claude` from the repo root — who have installed kstack in repo-local mode — do not pick up these dev-facing instructions. Contributors editing any file under `src/` still get this context because Claude Code walks up from the edited file to find the nearest CLAUDE.md.

## What this repo is

kstack is a **skill pack** (not an app) distributed to Claude Code and other agent CLIs. The shipped artifacts are `SKILL.md` files plus a handful of helper shell scripts in `src/bin/`. There is no runtime service — everything is POSIX shell rendered/executed at install time or inside an agent session.

## Layout

- `install` (repo root) — the installer. Its `SCRIPT_DIR` is the repo root, so it reads from `src/` and writes outputs (`.kstack/`, `.<agent>/skills/`) alongside itself.
- `src/{bin,lib,skills,scripts,tests,_partials}/` — all other source lives here.
- `src/CLAUDE.md` — this file.
- `assets/`, `README.md`, `.github/` — user-facing metadata, stay at repo root.

All commands and paths below are relative to the repo root.

## Commands

- `./src/scripts/test.sh` — run the fast bats tiers (`src/tests/unit` + `src/tests/integration`). Requires `bats-core` (`brew install bats-core` / `apt install bats`). Pass `--all` to also run the e2e tier.
- `./src/scripts/test-e2e.sh` — run the cluster-backed tier against a kind cluster named `kstack-test`. The kind lifecycle lives in `src/tests/e2e/lib/kind-cluster.sh` and is shared with the eval tier; the bats suite hook `src/tests/e2e/setup_suite.bash` is a thin wrapper around it. No prior `kind` state is required. Set `KSTACK_REUSE_CLUSTER=1` during dev loops to keep the cluster alive across runs. Requires `kind`, `kubectl`, and a running Docker daemon.
- `./src/scripts/test-evals.sh` — run the eval tier: plants fixtures in the kind cluster, invokes skills via `claude -p`, and scores the responses. Requires `ANTHROPIC_API_KEY`, `claude`, `jq`, and `yq` in addition to the e2e prerequisites. Exits 0 with a skip message when `ANTHROPIC_API_KEY` is unset. Env: `KSTACK_EVAL_MAX_RUNS` (override samples per scenario), `KSTACK_EVAL_BUDGET_USD` (hard cost cap). Flags: `--scenario <id>` to run one, `--include-placeholder` to run the smoke scenario.
- `bats src/tests/unit/<file>.bats` — run a single test file. Use `bats -f "<name pattern>" …` to run one test.
- `./install` — render skills into `<repo>/.<agent>/skills/…` for every agent CLI detected on `PATH` (repo-local mode). Reads sources from `src/`, writes outputs next to itself at the repo root.
- `./install --global` — clone/update `~/.config/kstack/upstream/` at the latest release tag and render into `~/.<agent>/skills/kstack-<skill>/…`. Do **not** use the invoker's checkout as the source in global mode; it always pulls canonical upstream.
- `./src/scripts/clean.sh` — remove gitignored install artifacts (`.claude/`, `.codex/`, `.kstack/`, etc.) so `./install` runs against a clean tree.

CI (`.github/workflows/ci.yml`) runs four jobs. `lint` shellchecks the root `install` script plus everything under `src/bin/` (including `entrypoint`), `src/lib/`, `src/scripts/`, `src/skills/cluster-status/scripts/main`, and `src/tests/test_helper.bash` (severity=warning, external-sources on). `bats` runs `src/scripts/test.sh` on Linux, macOS, and Windows (amd64+arm64) for every PR. `bats-e2e` runs `src/scripts/test-e2e.sh` on Linux amd64 only (kind cluster required) and is a required status check. `evals` runs `src/scripts/test-evals.sh` but is `workflow_dispatch`-only — trigger it manually via `gh workflow run ci.yml`.

## Architecture

### Templates → SKILL.md rendering

Skills are authored as `src/skills/<name>/SKILL.md.tmpl`. The repo-root `install` script renders each skill slot in two passes:

1. **`render_skill`** — inlines partials at `{{GLOBAL_FLAGS}}` and `{{ENTRYPOINT}}` markers from `src/skills/_partials/`, then substitutes scalar placeholders `{{ROOT_DIR}}`, `{{SKILL_DIR}}`, `{{SKILL_NAME}}`, `{{AGENT}}`. Writes the resolved `SKILL.md` into the agent-specific skills dir (no intermediate dist/).
2. **`render_help`** — extracts the `<dt>/<dd>` block for `#### /<skill>` from the repo-root `README.md`, appends the `**Global flags**` section, and terminates the file with the literal sentinel `=== END HELP ===`. Output goes to `<skill-slot>/references/help.md` (reachable via `{{SKILL_DIR}}/references/help.md` in templates). The entrypoint handles `--help` by `cat`-ing this file and exiting 10 on the skill's behalf, so every skill gets a consistent help page sourced from the README without per-skill wiring.

`SKILL.md.tmpl` and the README section are the sources of truth — rendered `SKILL.md` and `references/help.md` files are gitignored and must never be hand-edited. Cross-cutting prose (global flags, update notices, preamble dispatch) belongs in a partial, not duplicated into every skill. A new skill needs both a `SKILL.md.tmpl` and a matching `#### /<skill>` section in `README.md`, or `render_help` will exit non-zero during install.

When a skill body needs to invoke a helper, reference it as `{{ROOT_DIR}}/bin/<tool>` so the absolute path is baked in at render time (this is how the same template works under repo-local and global installs).

### Agent table (src/lib/agents.sh)

`src/lib/agents.sh` is the single source of truth mapping agent name → CLI binary to probe → global skills dir → local skills dir. The root `install` script, `src/bin/uninstall`, and the test suite all source it. When adding a new agent, update this file and the table in `README.md`.

### Two install modes

Both modes materialize a symmetric `{{ROOT_DIR}}/{bin,lib,cache}/` layout — the only differences are where `{{ROOT_DIR}}` sits and which skills dir the rendered `SKILL.md` files land in.

- **Repo-local** (`./install`): copies `src/bin/` → `<repo>/.kstack/bin/` and `src/lib/` → `<repo>/.kstack/lib/` (recursive — per-skill helper trees at `src/lib/<skill>/` are supported), writes `<repo>/.kstack/install.conf` from `git describe --tags --exact-match HEAD` (or current branch name), and renders skills into `<repo>/.<agent>/skills/<name>/SKILL.md`. `{{ROOT_DIR}}` = `<repo>/.kstack`. Upgrade via `git pull && ./install` or `<repo>/.kstack/bin/upgrade`.
- **Global** (`./install --global`): maintains `~/.config/kstack/upstream/` at the latest `v*` tag, copies `upstream/src/bin/` → `~/.config/kstack/bin/` and `upstream/src/lib/` → `~/.config/kstack/lib/` (recursive), renders into `~/.<agent>/skills/kstack-<name>/SKILL.md`. `{{ROOT_DIR}}` = `~/.config/kstack`. Upgrade via `~/.config/kstack/bin/upgrade`.

The `bin/` helpers (`check-update`, `upgrade`, `uninstall`, `dismiss-update`, `entrypoint`) assume they sit at `{{ROOT_DIR}}/bin/<name>` and derive `ROOT_DIR` as `dirname "$SCRIPT_DIR"`. Running a helper directly from the source tree (`./src/bin/check-update`) without installing first is unsupported — paths resolve to the repo root rather than `.kstack/`. Keep that invariant when adding helpers.

### Skill entrypoint and `scripts/main` contract

Every rendered `SKILL.md` invokes `{{ROOT_DIR}}/bin/entrypoint --skill-dir={{SKILL_DIR}} --skill-name={{SKILL_NAME}} -- <user args>` as its first action. The entrypoint owns three mechanical jobs: a cached update-check (lib: `src/lib/update-check.sh`), `--help` short-circuit (`cat`s `{{SKILL_DIR}}/references/help.md`), and optional dispatch to `{{SKILL_DIR}}/scripts/main` when that script exists. Exit-code contract: `0` = continue (stdout may be an update notice), `10` = terminal success (stdout is the full response), `11` = terminal user-facing error (stderr is the message), other non-zero = infrastructure failure. The entrypoint is deliberately fail-tolerant: update-check runs in a guarded subshell so its failures never break a skill invocation.

A skill opts into automatic shell dispatch by shipping an executable `scripts/main`. The entrypoint `exec`s it with the forwarded user args and exports `KSTACK_ROOT`, `KSTACK_SKILL_DIR`, `KSTACK_SKILL_NAME`. The script owns its own global-flag parsing (the `{{GLOBAL_FLAGS}}` partial stays Claude's contract, but Claude won't be reprocessing args when `scripts/main` handles the full response), and it should return exit `10` when its stdout is the finished response so Claude knows to print verbatim and end the turn. Skills without a `scripts/main` (LLM-reasoning skills like `/investigate`) get the preamble only and then run their SKILL.md body as usual.

### Bootstrap duplication

`src/scripts/install.sh` is the source for the `curl … | bash` bootstrap hosted at `https://www.kubestack.xyz/install.sh`. A verbatim copy lives in the `kubetail-website` repo's static assets and is **not automatically synced** — when you edit this file, copy it over manually.

### Install root layout

An install materializes `{{ROOT_DIR}}/{bin,lib,cache,state,install.conf}` — `~/.config/kstack/...` globally, `<repo>/.kstack/...` repo-locally. `bin/` and `lib/` are copies of the `src/` tree (rerun `./install` to pick up changes). `cache/` holds the update-check cache and is managed by `src/lib/cache.sh` (a single-branch function keyed off `dirname "$SCRIPT_DIR"`). `state/` holds per-context learned state. The `/forget` skill clears the `cache/` and `state/` subtrees; `/cleanup-cluster` clears in-cluster resources (anything labeled `kstack.kubetail.com/owned-by=kstack`).

## Tests

- `src/tests/unit/` — sourced-function tests (e.g. `agents.bats` sources `src/lib/agents.sh`).
- `src/tests/integration/` — end-to-end CLI tests that build a fake kstack checkout under `$BATS_TEST_TMPDIR` and run `install` against it with an isolated `$HOME`. See `src/tests/test_helper.bash` (`common_setup`, `use_mocks`, `write_stub`). The fakes mirror the real repo layout: the `install` script at the fake root plus `src/lib/`, `src/bin/`, `src/skills/`, etc. underneath.
- `src/tests/e2e/` — cluster-backed tests. `src/tests/e2e/lib/kind-cluster.sh` owns the kind lifecycle (shared with the eval tier); `src/tests/e2e/setup_suite.bash` is the bats `setup_suite`/`teardown_suite` wrapper. Tests inherit `KUBECONFIG` and talk to the cluster directly. Only fires under `src/scripts/test-e2e.sh` — never under `src/scripts/test.sh`.
- `src/tests/evals/` — skill evaluation scenarios. Each `scenarios/<id>/` is a self-contained package: `scenario.yaml` (metadata + claude flags), `fixture.yaml` (kubectl manifests), `prompt.txt` (user turn), `expected.yaml` (keyword/structured/judge rubric), optional `wait.sh`. Runner libs live under `src/tests/evals/lib/` and are driven by `src/scripts/test-evals.sh`. Artifacts (transcripts, judge outputs, state snapshots) land under `src/tests/evals/artifacts/<id>/` and are gitignored. See `src/tests/evals/README.md` for the full authoring guide.
- `src/tests/fixtures/` — minimal skill + partial fixtures used by integration tests (so tests aren't coupled to real skill contents).

The bats helper `src/tests/test_helper.bash` exposes two root vars: `SRC_ROOT` resolves to `src/` (the source tree root — tests reference it as `$SRC_ROOT/lib/…`, `$SRC_ROOT/bin/…`, etc.), and `REPO_ROOT` resolves to the actual repo top, where the user-facing `install` script lives.

When adding a helper under `src/bin/` or a partial under `src/skills/_partials/`, add a test that exercises it through `install`, not just via direct invocation — the rendering pipeline is where most regressions land.
