#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  common_setup

  # Build a minimal fake kstack checkout (skills, partials, lib, install, bin).
  FAKE_ROOT="$TMPDIR_TEST/kstack"
  mkdir -p "$FAKE_ROOT/bin" "$FAKE_ROOT/lib" "$FAKE_ROOT/skills/demo" "$FAKE_ROOT/skills/_partials"

  cp "$REPO_ROOT/install" "$FAKE_ROOT/install"
  cp "$REPO_ROOT/lib/agents.sh" "$FAKE_ROOT/lib/agents.sh"
  cp "$FIXTURES_DIR/skills/demo/SKILL.md.tmpl" "$FAKE_ROOT/skills/demo/SKILL.md.tmpl"
  cp "$FIXTURES_DIR/skills/_partials/global-flags.md" "$FAKE_ROOT/skills/_partials/global-flags.md"
  cp "$FIXTURES_DIR/skills/_partials/update-check.md" "$FAKE_ROOT/skills/_partials/update-check.md"
  : > "$FAKE_ROOT/bin/.gitkeep"
  chmod +x "$FAKE_ROOT/install"
}

@test "install --agent claude renders SKILL.md into .claude/skills/demo" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/demo/SKILL.md"
}

@test "install --agent claude uses local paths in template output" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F "install_root: $FAKE_ROOT" "$FAKE_ROOT/.claude/skills/demo/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -F "bin_dir: $FAKE_ROOT/bin" "$FAKE_ROOT/.claude/skills/demo/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "install --agent codex writes to .codex/skills/demo" {
  run "$FAKE_ROOT/install" --agent codex --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.codex/skills/demo/SKILL.md"
}

@test "install --agent=opencode writes to .config/opencode/skills" {
  run "$FAKE_ROOT/install" --agent=opencode --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.config/opencode/skills/demo/SKILL.md"
}

@test "install --agent nosuch exits 1 with 'Unknown agent'" {
  run "$FAKE_ROOT/install" --agent nosuch
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown agent: nosuch"* ]]
}

@test "install --agent without value exits 1" {
  run "$FAKE_ROOT/install" --agent
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing value for --agent"* ]]
}

@test "install rejects unknown option" {
  run "$FAKE_ROOT/install" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option: --bogus"* ]]
}

@test "install creates .cache/kstack in repo-local mode" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -d "$FAKE_ROOT/.cache/kstack" ]
}

@test "install with no skills/ directory exits 1" {
  rm -rf "$FAKE_ROOT/skills"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 1 ]
  [[ "$output" == *"No skills/ directory"* ]]
}

@test "install with missing global-flags partial exits 1" {
  rm "$FAKE_ROOT/skills/_partials/global-flags.md"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing partial"* ]]
}

@test "install with no agents auto-detected falls back to claude" {
  # Empty PATH: no agent CLIs visible.
  run env PATH="/usr/bin:/bin" "$FAKE_ROOT/install" --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/demo/SKILL.md"
}

@test "install --help prints usage and exits 0" {
  run "$FAKE_ROOT/install" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"kstack install"* ]]
  [[ "$output" == *"Usage:"* ]]
}

@test "install replaces stale symlink in skill slot" {
  mkdir -p "$FAKE_ROOT/.claude/skills"
  ln -s /nonexistent "$FAKE_ROOT/.claude/skills/demo" 2>/dev/null || skip "symlinks not supported"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ ! -L "$FAKE_ROOT/.claude/skills/demo" ]
  [ -f "$FAKE_ROOT/.claude/skills/demo/SKILL.md" ]
}

@test "install replaces stale file blocking skill slot" {
  mkdir -p "$FAKE_ROOT/.claude/skills"
  echo "stale" > "$FAKE_ROOT/.claude/skills/demo"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -f "$FAKE_ROOT/.claude/skills/demo/SKILL.md" ]
}
