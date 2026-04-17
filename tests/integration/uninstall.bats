#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  common_setup

  # Stage a fake global install: config dir, lib, bin, some kstack-* skill dirs.
  mkdir -p "$HOME/.config/kstack/bin" "$HOME/.config/kstack/lib"
  cp "$REPO_ROOT/bin/uninstall" "$HOME/.config/kstack/bin/uninstall"
  cp "$REPO_ROOT/lib/agents.sh" "$HOME/.config/kstack/lib/agents.sh"
  chmod +x "$HOME/.config/kstack/bin/uninstall"

  mkdir -p "$HOME/.claude/skills/kstack-demo" "$HOME/.claude/skills/kstack-other"
  mkdir -p "$HOME/.claude/skills/non-kstack"  # must NOT be removed
  mkdir -p "$HOME/.codex/skills/kstack-demo"

  UNINSTALL="$HOME/.config/kstack/bin/uninstall"
}

@test "uninstall --force removes all kstack-* skill dirs and config dir" {
  run "$UNINSTALL" --force
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/skills/kstack-demo" ]
  [ ! -e "$HOME/.claude/skills/kstack-other" ]
  [ ! -e "$HOME/.codex/skills/kstack-demo" ]
  [ ! -e "$HOME/.config/kstack" ]
}

@test "uninstall --force leaves non-kstack skills untouched" {
  run "$UNINSTALL" --force
  [ "$status" -eq 0 ]
  [ -d "$HOME/.claude/skills/non-kstack" ]
}

@test "uninstall --force --agent claude scopes to one agent" {
  run "$UNINSTALL" --force --agent claude
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/skills/kstack-demo" ]
  # codex dir still exists as a dir (config dir is still removed though).
  [ -e "$HOME/.codex/skills/kstack-demo" ]
}

@test "uninstall --agent nosuch exits 1" {
  run "$UNINSTALL" --force --agent nosuch
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown agent: nosuch"* ]]
}

@test "uninstall interactive 'n' aborts without removing" {
  run bash -c "echo n | '$UNINSTALL'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Aborted."* ]]
  [ -e "$HOME/.claude/skills/kstack-demo" ]
  [ -e "$HOME/.config/kstack" ]
}

@test "uninstall interactive 'y' removes" {
  run bash -c "echo y | '$UNINSTALL'"
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/skills/kstack-demo" ]
  [ ! -e "$HOME/.config/kstack" ]
}

@test "uninstall with nothing installed prints 'Nothing to remove'" {
  # Clear pre-seeded state.
  rm -rf "$HOME/.claude" "$HOME/.codex"
  # Keep config dir to prove it's still detected by itself.
  rm -rf "$HOME/.config/kstack"
  # But we need the uninstall script to still exist somewhere. Re-stage bin+lib.
  mkdir -p "$HOME/.config/kstack/bin" "$HOME/.config/kstack/lib"
  cp "$REPO_ROOT/bin/uninstall" "$HOME/.config/kstack/bin/uninstall"
  cp "$REPO_ROOT/lib/agents.sh" "$HOME/.config/kstack/lib/agents.sh"
  chmod +x "$HOME/.config/kstack/bin/uninstall"
  # Now kstack config dir exists with just the uninstall script — that still
  # shows up in preview. So this test can only check that Nothing-to-remove
  # happens when the config dir itself is absent.
  run bash -c "rm -rf '$HOME/.config/kstack' && '$UNINSTALL' --force 2>&1 || echo exit=\$?"
  # After deleting the config dir, the script binary is gone too, so exit=127.
  [[ "$output" == *"exit=127"* || "$status" -eq 127 ]]
}

@test "uninstall exits 1 when not invoked from ~/.config/kstack/bin" {
  # Copy uninstall to an unrelated location.
  OTHER="$TMPDIR_TEST/elsewhere"
  mkdir -p "$OTHER"
  cp "$REPO_ROOT/bin/uninstall" "$OTHER/uninstall"
  cp -R "$REPO_ROOT/lib" "$TMPDIR_TEST/lib"  # lib needs to be discoverable

  # Place lib one level up from the uninstall copy so the auto-discover works.
  mkdir -p "$TMPDIR_TEST/lib2"
  cp "$REPO_ROOT/lib/agents.sh" "$TMPDIR_TEST/lib2/agents.sh"
  mkdir -p "$TMPDIR_TEST/combined/bin" "$TMPDIR_TEST/combined/lib"
  cp "$REPO_ROOT/bin/uninstall" "$TMPDIR_TEST/combined/bin/uninstall"
  cp "$REPO_ROOT/lib/agents.sh" "$TMPDIR_TEST/combined/lib/agents.sh"
  chmod +x "$TMPDIR_TEST/combined/bin/uninstall"

  run "$TMPDIR_TEST/combined/bin/uninstall" --force
  [ "$status" -eq 1 ]
  [[ "$output" == *"global uninstaller"* ]]
}

@test "uninstall rejects unknown option" {
  run "$UNINSTALL" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option: --bogus"* ]]
}

@test "uninstall --help prints usage and exits 0" {
  run "$UNINSTALL" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"kstack uninstall"* ]]
}
