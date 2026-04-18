#!/usr/bin/env bats

load ../test_helper

setup() {
  common_setup
  if [ "${KSTACK_E2E_SKIP:-0}" = "1" ]; then
    skip "e2e prerequisites missing"
  fi
  SNAP="$REPO_ROOT/skills/cluster-status/scripts/snapshot"
  export KSTACK_ROOT="$REPO_ROOT"
}

@test "snapshot prose renders a Nodes row for the kind cluster" {
  run "$SNAP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"findings —"* ]]
  [[ "$output" == *"## Nodes ("* ]]
  # kind-kstack-test-control-plane is the default control-plane node name.
  [[ "$output" == *"control-plane"* ]]
}

@test "snapshot --json against kind cluster returns a valid JSON object" {
  run "$SNAP" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.summary and .pod_phases and (.findings | type == "array")' >/dev/null
}

@test "snapshot --dry-run never touches the cluster" {
  run "$SNAP" --dry-run
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | grep -c -F '# would run:')" -eq 4 ]
}
