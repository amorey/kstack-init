#!/usr/bin/env bash

# Copyright 2026 The Kubetail Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# scripts/test.sh — run the bats test suite.
#
# Default: runs the fast tiers (unit + integration) on every supported OS.
# With --all: additionally runs the e2e tier (requires kind + docker).
#
# Parallelizes across test files when GNU parallel is on PATH (bats --jobs).
# Override with --jobs=N (N=1 disables parallelism).
#
# Requires bats-core (brew install bats-core, or apt install bats).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Detect CPU count across Linux / macOS / Git Bash (Windows).
detect_cpus() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
  elif command -v sysctl >/dev/null 2>&1 && sysctl -n hw.ncpu >/dev/null 2>&1; then
    sysctl -n hw.ncpu
  elif [ -n "${NUMBER_OF_PROCESSORS:-}" ]; then
    echo "$NUMBER_OF_PROCESSORS"
  else
    echo 2
  fi
}

RUN_E2E=0
JOBS=""
for arg in "$@"; do
  case "$arg" in
    --all) RUN_E2E=1 ;;
    --jobs=*) JOBS="${arg#--jobs=}" ;;
    -h|--help)
      cat <<EOF
Usage: scripts/test.sh [--all] [--jobs=N]

  (no flag)  Run fast tiers: tests/unit + tests/integration
  --all      Also run tests/e2e via scripts/test-e2e.sh (requires kind)
  --jobs=N   Run up to N bats files in parallel (default: CPU count, if GNU
             parallel is installed). --jobs=1 forces sequential execution.

Output format: TAP with per-test timing, for incremental feedback in parallel
mode (the default pretty formatter batches a whole file's output at once).
EOF
      exit 0
      ;;
    *)
      echo "unknown flag: $arg" >&2
      exit 2
      ;;
  esac
done

if ! command -v bats >/dev/null 2>&1; then
  echo "bats not found. Install with:" >&2
  echo "  brew install bats-core        # macOS" >&2
  echo "  apt install bats              # Debian/Ubuntu" >&2
  exit 1
fi

# Default to CPU count when GNU parallel is available. bats --jobs requires
# `parallel` on PATH; without it we'd error out, so fall back to sequential
# when it's missing instead of forcing a hard dep.
if [ -z "$JOBS" ]; then
  if command -v parallel >/dev/null 2>&1; then
    JOBS="$(detect_cpus)"
  else
    JOBS=1
  fi
fi

BATS_ARGS="--formatter tap --timing"
if [ "$JOBS" -gt 1 ]; then
  BATS_ARGS="$BATS_ARGS --jobs $JOBS"
fi

# shellcheck disable=SC2086  # intentional word-split on BATS_ARGS
bats $BATS_ARGS "$REPO_ROOT/tests/unit" "$REPO_ROOT/tests/integration"

if [ "$RUN_E2E" = "1" ]; then
  exec "$(dirname "$0")/test-e2e.sh"
fi
