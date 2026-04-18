#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  common_setup

  # Stage a fake repo with the script + some artifacts to clean.
  # Mirror the real layout: script lives at <repo>/src/scripts/clean.sh.
  FAKE_REPO="$TMPDIR_TEST/fake-repo"
  mkdir -p "$FAKE_REPO/src/scripts"
  cp "$SRC_ROOT/scripts/clean.sh" "$FAKE_REPO/src/scripts/clean.sh"
  chmod +x "$FAKE_REPO/src/scripts/clean.sh"
  CLEAN="$FAKE_REPO/src/scripts/clean.sh"
}

@test "clean.sh removes every listed path that exists" {
  mkdir -p "$FAKE_REPO/.claude/skills" "$FAKE_REPO/.kstack/cache" "$FAKE_REPO/.codex"

  run "$CLEAN"
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_REPO/.claude" ]
  [ ! -e "$FAKE_REPO/.kstack" ]
  [ ! -e "$FAKE_REPO/.codex" ]
}

@test "clean.sh reports 'Nothing to clean.' when nothing present" {
  run "$CLEAN"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to clean."* ]]
}

@test "clean.sh leaves non-listed paths alone" {
  mkdir -p "$FAKE_REPO/src" "$FAKE_REPO/.claude"
  run "$CLEAN"
  [ "$status" -eq 0 ]
  [ -d "$FAKE_REPO/src" ]
  [ ! -e "$FAKE_REPO/.claude" ]
}

@test "clean.sh prints 'removed' line per path" {
  mkdir -p "$FAKE_REPO/.claude" "$FAKE_REPO/.codex"
  run "$CLEAN"
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed .claude"* ]]
  [[ "$output" == *"removed .codex"* ]]
}
