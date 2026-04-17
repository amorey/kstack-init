#!/usr/bin/env bash
# scripts/test.sh — run the bats test suite.
#
# Requires bats-core (brew install bats-core, or apt install bats).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v bats >/dev/null 2>&1; then
  echo "bats not found. Install with:" >&2
  echo "  brew install bats-core        # macOS" >&2
  echo "  apt install bats              # Debian/Ubuntu" >&2
  exit 1
fi

exec bats "$REPO_ROOT/tests/unit" "$REPO_ROOT/tests/integration"
