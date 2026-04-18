#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  common_setup
}

@test "snapshot script exists and is executable" {
  [ -x "$REPO_ROOT/skills/cluster-status/scripts/snapshot" ]
}
