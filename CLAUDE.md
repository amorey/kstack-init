# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

kstack is a **skill pack** (not an app) distributed to Claude Code and other agent CLIs. The shipped artifacts are `SKILL.md` files plus a handful of helper shell scripts in `bin/`. There is no runtime service — everything is POSIX shell rendered/executed at install time or inside an agent session.

## Commands

- `./scripts/test.sh` — run the fast bats tiers (`tests/unit` + `tests/integration`). Requires `bats-core` (`brew install bats-core` / `apt install bats`). Pass `--all` to also run the e2e tier.
- `./scripts/test-e2e.sh` — run the cluster-backed tier against a kind cluster named `kstack-test`. The fixture is managed by `tests/e2e/setup_suite.bash`; no prior `kind` state is required. Set `KSTACK_REUSE_CLUSTER=1` during dev loops to keep the cluster alive across runs. Requires `kind`, `kubectl`, and a running Docker daemon.
- `bats tests/unit/<file>.bats` — run a single test file. Use `bats -f "<name pattern>" …` to run one test.
- `./install` — render skills into `<repo>/.<agent>/skills/…` for every agent CLI detected on `PATH` (repo-local mode).
- `./install --global` — clone/update `~/.config/kstack/src/` at the latest release tag and render into `~/.<agent>/skills/kstack-<skill>/…`. Do **not** use the invoker's checkout as the source in global mode; it always pulls canonical upstream.
- `./scripts/clean.sh` — remove gitignored install artifacts (`.claude/`, `.codex/`, `.kstack/`, etc.) so `./install` runs against a clean tree.

CI (`.github/workflows/ci.yml`) runs `scripts/test.sh` on Linux, macOS, and Windows (amd64+arm64) for every PR. A separate `bats-e2e` job runs `scripts/test-e2e.sh` on Linux amd64 only (kind cluster required) and is a required status check.

## Architecture

### Templates → SKILL.md rendering

Skills are authored as `skills/<name>/SKILL.md.tmpl`. The `install` script:

1. Inlines partials at `{{GLOBAL_FLAGS}}` and `{{UPDATE_CHECK}}` markers from `skills/_partials/`.
2. Substitutes scalar placeholders: `{{INSTALL_ROOT}}`, `{{BIN_DIR}}`, `{{SKILL_NAME}}`, `{{AGENT}}`.
3. Writes the resolved `SKILL.md` into the agent-specific skills dir (no intermediate dist/).

`SKILL.md.tmpl` is the source of truth — rendered `SKILL.md` files are gitignored and must never be hand-edited. Cross-cutting prose (global flags, update notices) belongs in a partial, not duplicated into every skill.

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
- `tests/e2e/` — cluster-backed tests. `tests/e2e/setup_suite.bash` owns the kind cluster lifecycle via bats' `setup_suite`/`teardown_suite` hooks; tests inherit `KUBECONFIG` and talk to the cluster directly. Only fires under `scripts/test-e2e.sh` — never under `scripts/test.sh`.
- `tests/fixtures/` — minimal skill + partial fixtures used by integration tests (so tests aren't coupled to real skill contents).

When adding a helper under `bin/` or a partial under `skills/_partials/`, add a test that exercises it through `install`, not just via direct invocation — the rendering pipeline is where most regressions land.
