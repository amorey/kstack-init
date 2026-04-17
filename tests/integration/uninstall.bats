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

@test "uninstall exits 1 when not invoked from ~/.config/kstack/bin" {
  local elsewhere="$TMPDIR_TEST/elsewhere/bin"
  mkdir -p "$elsewhere" "$TMPDIR_TEST/elsewhere/lib"
  cp "$REPO_ROOT/bin/uninstall" "$elsewhere/uninstall"
  cp "$REPO_ROOT/lib/agents.sh" "$TMPDIR_TEST/elsewhere/lib/agents.sh"
  chmod +x "$elsewhere/uninstall"

  run "$elsewhere/uninstall" --force
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
