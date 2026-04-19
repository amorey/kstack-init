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

setup() {
  load '../test_helper.bash'
  common_setup

  # Global-mode install layout under $HOME.
  ROOT="$HOME/.config/kstack"
  mkdir -p "$ROOT/bin" "$ROOT/lib" "$ROOT/cache"
  cp "$SRC_ROOT/bin/entrypoint"      "$ROOT/bin/entrypoint"
  cp "$SRC_ROOT/lib/cache.sh"        "$ROOT/lib/cache.sh"
  cp "$SRC_ROOT/lib/update-check.sh" "$ROOT/lib/update-check.sh"
  chmod +x "$ROOT/bin/entrypoint"
  CACHE_FILE="$ROOT/cache/update.json"
  EP="$ROOT/bin/entrypoint"

  # A rendered skill slot — what {{SKILL_DIR}} resolves to post-install.
  SKILL_DIR="$HOME/.claude/skills/demo"
  mkdir -p "$SKILL_DIR/references" "$SKILL_DIR/scripts"
  printf 'help body\n=== END HELP ===\n' > "$SKILL_DIR/references/help.md"

  # Installed version — non-main so the update check engages.
  echo "v1.0.0" > "$ROOT/install.conf"
}

# stub_git (and stub_git --fail) are provided by test_helper.bash.

# ─── --help short-circuit ──────────────────────────────────────

@test "--help prints help body and exits 10" {
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo -- --help
  [ "$status" -eq 10 ]
  [[ "$output" == *"help body"* ]]
  [[ "$output" == *"=== END HELP ==="* ]]
}

@test "--help wins even when other flags are present" {
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo -- --context=foo --help
  [ "$status" -eq 10 ]
  [[ "$output" == *"help body"* ]]
}

@test "--help with missing help.md exits 11 with install-bug message" {
  rm "$SKILL_DIR/references/help.md"
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo -- --help
  [ "$status" -eq 11 ]
  [[ "$output" == *"Help page missing"* ]]
}

@test "--help skips the update check (no notice glued to help output)" {
  stub_git
  export MOCK_TAGS="v9.9.9"  # would produce a notice if update-check ran
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo -- --help
  [ "$status" -eq 10 ]
  [[ "$output" != *"is available"* ]]
}

# ─── update-check preamble ─────────────────────────────────────

@test "update notice is printed on stdout when a newer tag exists" {
  stub_git
  export MOCK_TAGS="v1.0.0 v2.0.0"
  cat > "$CACHE_FILE" <<EOF
{
  "last_check": "2000-01-01T00:00:00Z",
  "latest_known": "v1.0.0"
}
EOF
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo --
  [ "$status" -eq 0 ]
  [[ "$output" == *"kstack v2.0.0 is available"* ]]
}

@test "no notice when cache shows up-to-date" {
  stub_git
  export MOCK_TAGS=""
  now_iso="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  cat > "$CACHE_FILE" <<EOF
{
  "last_check": "$now_iso",
  "latest_known": "v1.0.0"
}
EOF
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo --
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "git ls-remote failure leaves invocation silent (not broken)" {
  stub_git --fail
  rm -f "$CACHE_FILE"
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo --
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "no install.conf → silent preamble" {
  rm "$ROOT/install.conf"
  stub_git
  export MOCK_TAGS="v9.0.0"
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo --
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "install.conf=main → silent preamble (pre-release)" {
  echo "main" > "$ROOT/install.conf"
  stub_git
  export MOCK_TAGS="v9.0.0"
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo --
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ─── scripts/main dispatch ─────────────────────────────────────

@test "no scripts/main → exit 0 with empty stdout (Claude handles body)" {
  stub_git
  export MOCK_TAGS="v1.0.0"
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo --
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "scripts/main exists and exits 10 → entrypoint exits 10 with main's stdout" {
  stub_git
  export MOCK_TAGS="v1.0.0"
  cat > "$SKILL_DIR/scripts/main" <<'EOF'
#!/usr/bin/env bash
echo "snapshot output"
exit 10
EOF
  chmod +x "$SKILL_DIR/scripts/main"
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo --
  [ "$status" -eq 10 ]
  [[ "$output" == *"snapshot output"* ]]
}

@test "scripts/main exit 11 with stderr → entrypoint propagates 11" {
  stub_git
  export MOCK_TAGS="v1.0.0"
  cat > "$SKILL_DIR/scripts/main" <<'EOF'
#!/usr/bin/env bash
echo "user-facing error" >&2
exit 11
EOF
  chmod +x "$SKILL_DIR/scripts/main"
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo --
  [ "$status" -eq 11 ]
  [[ "$output" == *"user-facing error"* ]]
}

@test "scripts/main exit 1 → entrypoint propagates 1" {
  stub_git
  export MOCK_TAGS="v1.0.0"
  cat > "$SKILL_DIR/scripts/main" <<'EOF'
#!/usr/bin/env bash
echo "boom" >&2
exit 1
EOF
  chmod +x "$SKILL_DIR/scripts/main"
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo --
  [ "$status" -eq 1 ]
  [[ "$output" == *"boom"* ]]
}

@test "scripts/main not executable → exit 11" {
  : > "$SKILL_DIR/scripts/main"  # create but do not chmod +x
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo --
  [ "$status" -eq 11 ]
  [[ "$output" == *"not executable"* ]]
}

@test "scripts/main sees KSTACK_* env vars + forwarded argv" {
  cat > "$SKILL_DIR/scripts/main" <<'EOF'
#!/usr/bin/env bash
printf 'root=%s dir=%s name=%s args=%s\n' \
  "${KSTACK_ROOT:-}" "${KSTACK_SKILL_DIR:-}" "${KSTACK_SKILL_NAME:-}" "$*"
exit 10
EOF
  chmod +x "$SKILL_DIR/scripts/main"
  stub_git
  export MOCK_TAGS="v1.0.0"
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo -- --context=dev foo bar
  [ "$status" -eq 10 ]
  [[ "$output" == *"root=$ROOT"* ]]
  [[ "$output" == *"dir=$SKILL_DIR"* ]]
  [[ "$output" == *"name=demo"* ]]
  [[ "$output" == *"args=--context=dev foo bar"* ]]
}

# ─── parser errors ─────────────────────────────────────────────

@test "missing --skill-dir exits 11" {
  run "$EP" --skill-name=demo --
  [ "$status" -eq 11 ]
}

@test "missing --skill-name exits 11" {
  run "$EP" --skill-dir="$SKILL_DIR" --
  [ "$status" -eq 11 ]
}

@test "missing '--' separator exits 11" {
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo
  [ "$status" -eq 11 ]
}

@test "unexpected flag before '--' exits 11" {
  run "$EP" --skill-dir="$SKILL_DIR" --skill-name=demo --bogus -- --help
  [ "$status" -eq 11 ]
  [[ "$output" == *"Unexpected flag"* ]]
}
