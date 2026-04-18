# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

kstack is a **skill pack** (not an app) distributed to Claude Code and other agent CLIs. The shipped artifacts are `SKILL.md` files plus a handful of helper shell scripts in `bin/`. There is no runtime service — everything is POSIX shell rendered/executed at install time or inside an agent session.

## Commands

- `./scripts/test.sh` — run the fast bats tiers (`tests/unit` + `tests/integration`). Requires `bats-core` (`brew install bats-core` / `apt install bats`). Pass `--all` to also run the e2e tier.
- `./scripts/test-e2e.sh` — run the cluster-backed tier against a kind cluster named `kstack-test`. The kind lifecycle lives in `tests/e2e/lib/kind-cluster.sh` and is shared with the eval tier; the bats suite hook `tests/e2e/setup_suite.bash` is a thin wrapper around it. No prior `kind` state is required. Set `KSTACK_REUSE_CLUSTER=1` during dev loops to keep the cluster alive across runs. Requires `kind`, `kubectl`, and a running Docker daemon.
- `./scripts/test-evals.sh` — run the eval tier: plants fixtures in the kind cluster, invokes skills via `claude -p`, and scores the responses. Requires `ANTHROPIC_API_KEY`, `claude`, `jq`, and `yq` in addition to the e2e prerequisites. Exits 0 with a skip message when `ANTHROPIC_API_KEY` is unset. Env: `KSTACK_EVAL_MAX_RUNS` (override samples per scenario), `KSTACK_EVAL_BUDGET_USD` (hard cost cap). Flags: `--scenario <id>` to run one, `--include-placeholder` to run the smoke scenario.
- `bats tests/unit/<file>.bats` — run a single test file. Use `bats -f "<name pattern>" …` to run one test.
- `./install` — render skills into `<repo>/.<agent>/skills/…` for every agent CLI detected on `PATH` (repo-local mode).
- `./install --global` — clone/update `~/.config/kstack/src/` at the latest release tag and render into `~/.<agent>/skills/kstack-<skill>/…`. Do **not** use the invoker's checkout as the source in global mode; it always pulls canonical upstream.
- `./scripts/clean.sh` — remove gitignored install artifacts (`.claude/`, `.codex/`, `.kstack/`, etc.) so `./install` runs against a clean tree.

CI (`.github/workflows/ci.yml`) runs four jobs. `lint` shellchecks `install`, every script under `bin/`, `lib/`, and `scripts/`, plus `tests/test_helper.bash` (severity=warning, external-sources on). `bats` runs `scripts/test.sh` on Linux, macOS, and Windows (amd64+arm64) for every PR. `bats-e2e` runs `scripts/test-e2e.sh` on Linux amd64 only (kind cluster required) and is a required status check. `evals` runs `scripts/test-evals.sh` but is `workflow_dispatch`-only — trigger it manually via `gh workflow run ci.yml`.

## Architecture

### Templates → SKILL.md rendering

Skills are authored as `skills/<name>/SKILL.md.tmpl`. The `install` script renders each skill slot in two passes:

1. **`render_skill`** — inlines partials at `{{GLOBAL_FLAGS}}` and `{{UPDATE_CHECK}}` markers from `skills/_partials/`, then substitutes scalar placeholders `{{INSTALL_ROOT}}`, `{{BIN_DIR}}`, `{{HELP_PATH}}`, `{{SKILL_NAME}}`, `{{AGENT}}`. Writes the resolved `SKILL.md` into the agent-specific skills dir (no intermediate dist/).
2. **`render_help`** — extracts the `<dt>/<dd>` block for `#### /<skill>` from `README.md`, appends the `**Global flags**` section, and terminates the file with the literal sentinel `=== END HELP ===`. Output goes to `<skill-slot>/references/help.md`, and its absolute path is what `{{HELP_PATH}}` resolves to. The `--help` flag in the global-flags partial is wired to `cat` this file and stop on the sentinel, so every skill gets a consistent help page sourced from the README.

`SKILL.md.tmpl` and the README section are the sources of truth — rendered `SKILL.md` and `references/help.md` files are gitignored and must never be hand-edited. Cross-cutting prose (global flags, update notices) belongs in a partial, not duplicated into every skill. A new skill needs both a `SKILL.md.tmpl` and a matching `#### /<skill>` section in `README.md`, or `render_help` will exit non-zero during install.

When a skill body needs to invoke a helper, reference it as `{{BIN_DIR}}/<tool>` so the absolute path is baked in at render time (this is how the same template works under repo-local and global installs).

### Agent table (lib/agents.sh)

`lib/agents.sh` is the single source of truth mapping agent name → CLI binary to probe → global skills dir → local skills dir. `install`, `uninstall`, and the test suite all source it. When adding a new agent, update this file and the table in `README.md`.

### Two install modes

- **Repo-local** (`./install`): renders into `<repo>/.<agent>/skills/<name>/SKILL.md`. `{{INSTALL_ROOT}}` = repo root, `{{BIN_DIR}}` = `<repo>/bin`. Upgrade via `git pull && ./install`.
- **Global** (`./install --global`): maintains `~/.config/kstack/src/` at the latest `v*` tag, copies `bin/` → `~/.config/kstack/bin/` and `lib/` → `~/.config/kstack/lib/`, renders into `~/.<agent>/skills/kstack-<name>/SKILL.md`. Upgrade via `~/.config/kstack/bin/upgrade`.

The `bin/` helpers (`check-update`, `upgrade`, `uninstall`, `dismiss-update`) detect their mode by comparing `SCRIPT_DIR` to `$HOME/.config/kstack/bin`. Keep that invariant when adding helpers.

### Bootstrap duplication

`scripts/install.sh` is the source for the `curl … | bash` bootstrap hosted at `https://www.kubestack.xyz/install.sh`. A verbatim copy lives in the `kubetail-website` repo's static assets and is **not automatically synced** — when you edit this file, copy it over manually.

### Cache / state paths

Per-context cache + learned state live under `~/.config/kstack/{cache,state}/` (global) or `<repo>/.kstack/{cache,state}/` (repo-local). `lib/cache.sh` resolves the correct paths based on caller location. The `/forget` skill clears these; `/cleanup-cluster` clears in-cluster resources (anything labeled `kstack.kubetail.com/owned-by=kstack`).

## Tests

- `tests/unit/` — sourced-function tests (e.g. `agents.bats` sources `lib/agents.sh`).
- `tests/integration/` — end-to-end CLI tests that build a fake kstack checkout under `$BATS_TEST_TMPDIR` and run `install` against it with an isolated `$HOME`. See `tests/test_helper.bash` (`common_setup`, `use_mocks`, `write_stub`).
- `tests/e2e/` — cluster-backed tests. `tests/e2e/lib/kind-cluster.sh` owns the kind lifecycle (shared with the eval tier); `tests/e2e/setup_suite.bash` is the bats `setup_suite`/`teardown_suite` wrapper. Tests inherit `KUBECONFIG` and talk to the cluster directly. Only fires under `scripts/test-e2e.sh` — never under `scripts/test.sh`.
- `tests/evals/` — skill evaluation scenarios. Each `scenarios/<id>/` is a self-contained package: `scenario.yaml` (metadata + claude flags), `fixture.yaml` (kubectl manifests), `prompt.txt` (user turn), `expected.yaml` (keyword/structured/judge rubric), optional `wait.sh`. Runner libs live under `tests/evals/lib/` and are driven by `scripts/test-evals.sh`. Artifacts (transcripts, judge outputs, state snapshots) land under `tests/evals/artifacts/<id>/` and are gitignored. See `tests/evals/README.md` for the full authoring guide.
- `tests/fixtures/` — minimal skill + partial fixtures used by integration tests (so tests aren't coupled to real skill contents).

When adding a helper under `bin/` or a partial under `skills/_partials/`, add a test that exercises it through `install`, not just via direct invocation — the rendering pipeline is where most regressions land.
