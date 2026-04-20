#!/usr/bin/env bats

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

# Unit tests for cache_key::context_sha in
# src/skills/cluster-status/scripts/lib/cache-key.sh. The function picks
# sha256sum -> shasum -> tr/cut based on what's on PATH; we cover each
# branch by building a tightly-controlled PATH, and check determinism +
# uniqueness against whichever branch the host resolves to naturally.
#
# Windows note: Git Bash ships sha256sum via MSYS2 coreutils, so the
# sha256sum branch runs on every CI entry. The fallback branch is
# exercised explicitly to make sure the tool remains usable if a future
# environment lacks both hashers.

setup() {
  load '../test_helper.bash'
  common_setup
  # shellcheck source=../../skills/cluster-status/scripts/lib/cache-key.sh
  . "$SRC_ROOT/skills/cluster-status/scripts/lib/cache-key.sh"
}

# _install_tools <tool...>
#   Populate MOCK_BIN with shell wrappers that exec the real binary in
#   place, so a PATH="$MOCK_BIN" subshell can still resolve the listed
#   tools while blocking anything we didn't list. Used to construct a
#   tightly-controlled PATH that excludes one or both hashers.
#
#   Implemented via wrapper scripts (not symlink/copy) because MSYS2
#   binaries on Git Bash dynamically link DLLs resolved from the binary's
#   on-disk location — a copied sha256sum.exe in MOCK_BIN fails to load
#   its shared libraries. A wrapper exec's the real binary in place, so
#   DLL resolution keeps working.
_install_tools() {
  use_mocks
  local tool src bash_abs
  # Absolute bash path in the shebang so the wrapper runs even though
  # MOCK_BIN is the only PATH entry (no env, no bash discoverable).
  bash_abs="$(command -v bash)"
  for tool in "$@"; do
    src="$(command -v "$tool")" || {
      echo "required tool not found on host PATH: $tool" >&2
      return 1
    }
    cat > "$MOCK_BIN/$tool" <<EOF
#!$bash_abs
exec "$src" "\$@"
EOF
    chmod +x "$MOCK_BIN/$tool"
  done
}

@test "context_sha produces non-empty output" {
  out="$(cache_key::context_sha "my-kube-context")"
  [ -n "$out" ]
}

@test "context_sha is deterministic for the same input" {
  a="$(cache_key::context_sha "my-kube-context")"
  b="$(cache_key::context_sha "my-kube-context")"
  [ "$a" = "$b" ]
}

@test "context_sha produces distinct outputs for different inputs" {
  a="$(cache_key::context_sha "context-alpha")"
  b="$(cache_key::context_sha "context-beta")"
  [ "$a" != "$b" ]
}

@test "context_sha handles context names with special characters" {
  # Real kubectl contexts often contain colons, slashes, dots.
  out="$(cache_key::context_sha "arn:aws:eks:us-east-1:123456789:cluster/prod.v2")"
  [ -n "$out" ]
}

@test "sha256sum branch emits 12 lowercase hex chars" {
  command -v sha256sum >/dev/null 2>&1 || skip "sha256sum not on PATH"
  _install_tools awk sha256sum
  out="$(PATH="$MOCK_BIN" cache_key::context_sha "test-context")"
  [[ "$out" =~ ^[0-9a-f]{12}$ ]]
}

@test "sha256sum branch output matches the sha256 prefix" {
  command -v sha256sum >/dev/null 2>&1 || skip "sha256sum not on PATH"
  expected="$(printf '%s' "my-ctx" | sha256sum | awk '{print substr($1,1,12)}')"
  _install_tools awk sha256sum
  out="$(PATH="$MOCK_BIN" cache_key::context_sha "my-ctx")"
  [ "$out" = "$expected" ]
}

@test "shasum branch emits 12 lowercase hex chars when sha256sum is absent" {
  command -v shasum >/dev/null 2>&1 || skip "shasum not on PATH"
  # Isolated PATH excludes sha256sum so the elif branch runs.
  _install_tools awk shasum
  out="$(PATH="$MOCK_BIN" cache_key::context_sha "test-context")"
  [[ "$out" =~ ^[0-9a-f]{12}$ ]]
}

@test "shasum branch matches sha-256 prefix when sha256sum is absent" {
  command -v shasum >/dev/null 2>&1 || skip "shasum not on PATH"
  expected="$(printf '%s' "my-ctx" | shasum -a 256 | awk '{print substr($1,1,12)}')"
  _install_tools awk shasum
  out="$(PATH="$MOCK_BIN" cache_key::context_sha "my-ctx")"
  [ "$out" = "$expected" ]
}

@test "fallback branch sanitizes context name when no hasher is present" {
  # tr + cut but no sha256sum, no shasum. tr -c 'A-Za-z0-9' _ replaces
  # any non-alphanumeric byte with underscore.
  _install_tools tr cut
  out="$(PATH="$MOCK_BIN" cache_key::context_sha "kind-kstack-test")"
  [ "$out" = "kind_kstack_test" ]
}

@test "fallback branch caps output at 40 chars" {
  _install_tools tr cut
  long="abcdefghijabcdefghijabcdefghijabcdefghijabcdefghij" # 50 chars
  out="$(PATH="$MOCK_BIN" cache_key::context_sha "$long")"
  [ "${#out}" -eq 40 ]
}
