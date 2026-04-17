#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  common_setup
  . "$REPO_ROOT/lib/agents.sh"
}

@test "agent_cli maps claude to claude" {
  run agent_cli claude
  [ "$status" -eq 0 ]
  [ "$output" = "claude" ]
}

@test "agent_cli maps factory to droid" {
  run agent_cli factory
  [ "$status" -eq 0 ]
  [ "$output" = "droid" ]
}

@test "agent_cli maps kiro to kiro-cli" {
  run agent_cli kiro
  [ "$status" -eq 0 ]
  [ "$output" = "kiro-cli" ]
}

@test "agent_cli returns non-zero for unknown agent" {
  run agent_cli nosuch
  [ "$status" -ne 0 ]
}

@test "agent_skills_dir_global claude" {
  run agent_skills_dir_global claude
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/.claude/skills" ]
}

@test "agent_skills_dir_global opencode uses \$HOME/.config/opencode" {
  run agent_skills_dir_global opencode
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/.config/opencode/skills" ]
}

@test "agent_skills_dir_global returns non-zero for unknown" {
  run agent_skills_dir_global nosuch
  [ "$status" -ne 0 ]
}

@test "agent_skills_dir_local uses passed repo root" {
  run agent_skills_dir_local /opt/kstack claude
  [ "$status" -eq 0 ]
  [ "$output" = "/opt/kstack/.claude/skills" ]
}

@test "agent_skills_dir_local opencode" {
  run agent_skills_dir_local /opt/kstack opencode
  [ "$status" -eq 0 ]
  [ "$output" = "/opt/kstack/.config/opencode/skills" ]
}

@test "is_known_agent accepts all KNOWN_AGENTS" {
  for a in claude codex opencode cursor factory slate kiro hermes; do
    run is_known_agent "$a"
    [ "$status" -eq 0 ] || { echo "$a should be known"; return 1; }
  done
}

@test "is_known_agent rejects unknown" {
  run is_known_agent nosuch
  [ "$status" -ne 0 ]
}

@test "is_known_agent rejects prefix substring (claude-foo)" {
  run is_known_agent claude-foo
  [ "$status" -ne 0 ]
}

@test "KNOWN_AGENTS lists all eight agents" {
  set -- $KNOWN_AGENTS
  [ "$#" -eq 8 ]
}
