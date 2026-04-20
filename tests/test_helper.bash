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

# shellcheck shell=bash
# shellcheck disable=SC2034  # vars like SRC_ROOT/REPO_ROOT/FIXTURES_DIR are consumed by tests that source this file.
# Shared helpers for the kstack bats suite.
#
# Each test's setup() should call common_setup to isolate HOME in a tmpdir.

TEST_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT is the repo top, where install/, scripts/, and src/ live.
# SRC_ROOT points at src/ — the installer payload (lib/, bin/, skills/).
REPO_ROOT="$(cd "$TEST_HELPER_DIR/.." && pwd)"
SRC_ROOT="$REPO_ROOT/src"
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

# stub_git [--fail] — install a git stub in MOCK_BIN that intercepts
# `git ls-remote --tags …` and falls through to real git for everything else.
# Without --fail: emits tags from the space-separated $MOCK_TAGS env var.
# With --fail: `ls-remote` exits 1 (used to simulate network failures).
stub_git() {
  use_mocks
  local mode=ok
  [ "${1:-}" = "--fail" ] && mode=fail
  local real_git
  real_git="$(command -v git)"
  if [ "$mode" = fail ]; then
    write_stub git "
REAL_GIT=$real_git
if [ \"\$1\" = 'ls-remote' ]; then exit 1; fi
exec \"\$REAL_GIT\" \"\$@\"
"
  else
    write_stub git "
REAL_GIT=$real_git
if [ \"\$1\" = 'ls-remote' ]; then
  for t in \$MOCK_TAGS; do
    printf 'abcdef\trefs/tags/%s\n' \"\$t\"
  done
  exit 0
fi
exec \"\$REAL_GIT\" \"\$@\"
"
  fi
}
