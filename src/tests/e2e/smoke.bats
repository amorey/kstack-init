#!/usr/bin/env bats

load ../test_helper

setup() {
  common_setup
  if [ "${KSTACK_E2E_SKIP:-0}" = "1" ]; then
    skip "e2e prerequisites missing"
  fi
}

@test "kind cluster is reachable via kubectl" {
  run kubectl get nodes --no-headers
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ready"* ]]
}

@test "KUBECONFIG points to the suite tmpdir" {
  [ -n "$KUBECONFIG" ]
  [ -f "$KUBECONFIG" ]
  [[ "$KUBECONFIG" == "$BATS_SUITE_TMPDIR/"* ]]
}

@test "cluster name matches KSTACK_KIND_CLUSTER" {
  run kubectl config current-context
  [ "$status" -eq 0 ]
  [[ "$output" == "kind-$KSTACK_KIND_CLUSTER" ]]
}
