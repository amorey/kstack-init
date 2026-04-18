# shellcheck shell=bash
# shellcheck disable=SC2034  # vars like REPO_ROOT/CHECKOUT_ROOT/FIXTURES_DIR are consumed by tests that source this file.
# Shared helpers for the kstack bats suite.
#
# Each test's setup() should call common_setup to isolate HOME in a tmpdir.

TEST_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT points at src/ — the source tree root that holds lib/, bin/,
# skills/, scripts/ etc. CHECKOUT_ROOT is the actual repo top, one level up,
# where the user-facing install script and README.md live.
REPO_ROOT="$(cd "$TEST_HELPER_DIR/.." && pwd)"
CHECKOUT_ROOT="$(cd "$REPO_ROOT/.." && pwd)"
FIXTURES_DIR="$TEST_HELPER_DIR/fixtures"

common_setup() {
  TMPDIR_TEST="${BATS_TEST_TMPDIR:-$(mktemp -d)}"
  export HOME="$TMPDIR_TEST/home"
  mkdir -p "$HOME"
}

# Prepend a dedicated mock dir to PATH. Stubs placed here shadow system commands.
use_mocks() {
  MOCK_BIN="$TMPDIR_TEST/mock-bin"
  mkdir -p "$MOCK_BIN"
  export PATH="$MOCK_BIN:$PATH"
}

# Write a one-off stub to MOCK_BIN. The body is shell source executed as the stub.
write_stub() {
  local name="$1" body="$2"
  cat > "$MOCK_BIN/$name" <<EOF
#!/usr/bin/env bash
$body
EOF
  chmod +x "$MOCK_BIN/$name"
}

assert_file_exists() {
  if [ ! -e "$1" ]; then
    echo "expected file to exist: $1" >&2
    return 1
  fi
}
