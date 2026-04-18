#!/usr/bin/env bash
# scripts/test-e2e.sh — run the e2e (cluster-backed) bats tier.
#
# Spins up a kind cluster via tests/e2e/setup_suite.bash, runs the tests,
# and tears the cluster down. Set KSTACK_REUSE_CLUSTER=1 to keep the
# cluster alive across runs for faster iteration.
#
# Requires: bats-core, kind, kubectl, docker.
set -eu

SRC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v bats >/dev/null 2>&1; then
  echo "bats not found. Install with:" >&2
  echo "  brew install bats-core        # macOS" >&2
  echo "  apt install bats              # Debian/Ubuntu" >&2
  exit 1
fi

exec bats "$SRC_ROOT/tests/e2e"
