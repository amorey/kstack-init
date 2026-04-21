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

# Unit tests for src/skills/audit-network/scripts/lib/network-policies.sh.

setup() {
  load '../test_helper.bash'
  common_setup

  SKILL_SCRIPTS="$SRC_ROOT/skills/audit-network/scripts"
  # shellcheck source=/dev/null
  . "$SKILL_SCRIPTS/lib/network-policies.sh"

  # Create fixture directory for JSON files.
  FIXTURE_DIR="$TMPDIR_TEST/fixtures"
  mkdir -p "$FIXTURE_DIR"
}

# --- Fixture helpers ---

# _write_namespaces <json>
#   Write a namespaces.json fixture.
_write_namespaces() {
  printf '%s' "$1" > "$FIXTURE_DIR/namespaces.json"
}

# _write_netpols <json>
#   Write a networkpolicies.json fixture.
_write_netpols() {
  printf '%s' "$1" > "$FIXTURE_DIR/networkpolicies.json"
}

# _write_pods <json>
#   Write a pods.json fixture.
_write_pods() {
  printf '%s' "$1" > "$FIXTURE_DIR/pods.json"
}

# --- Helpers to build minimal k8s JSON ---

# Namespace list with given names.
_ns_json() {
  local items=""
  for ns in "$@"; do
    [ -n "$items" ] && items+=","
    items+="$(printf '{"metadata":{"name":"%s"}}' "$ns")"
  done
  printf '{"items":[%s]}' "$items"
}

# NetworkPolicy targeting a namespace with podSelector.
_netpol_json() {
  local items=""
  while [ $# -gt 0 ]; do
    local ns="$1" match_labels="$2"
    shift 2
    [ -n "$items" ] && items+=","
    items+="$(printf '{"metadata":{"namespace":"%s"},"spec":{"podSelector":{"matchLabels":%s}}}' "$ns" "$match_labels")"
  done
  printf '{"items":[%s]}' "$items"
}

# Default-deny NetworkPolicy (empty podSelector = selects all pods).
_default_deny_netpol_json() {
  local items=""
  for ns in "$@"; do
    [ -n "$items" ] && items+=","
    items+="$(printf '{"metadata":{"namespace":"%s"},"spec":{"podSelector":{}}}' "$ns")"
  done
  printf '{"items":[%s]}' "$items"
}

# Pod list with given (namespace, name, labels) tuples.
_pod_json() {
  local items=""
  while [ $# -gt 0 ]; do
    local ns="$1" name="$2" labels="$3"
    shift 3
    [ -n "$items" ] && items+=","
    items+="$(printf '{"metadata":{"namespace":"%s","name":"%s","labels":%s}}' "$ns" "$name" "$labels")"
  done
  printf '{"items":[%s]}' "$items"
}

# --- Tests: default-deny detection ---

@test "netpol: namespace without any NetworkPolicy reported as no default-deny" {
  _write_namespaces "$(_ns_json default app-ns)"
  _write_netpols '{"items":[]}'
  _write_pods '{"items":[]}'

  run network_policies::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"default"* ]]
  [[ "$output" == *"app-ns"* ]]
  [[ "$output" == *"no default-deny"* ]] || [[ "$output" == *"without default-deny"* ]]
}

@test "netpol: namespace with default-deny not reported" {
  _write_namespaces "$(_ns_json app-ns)"
  _write_netpols "$(_default_deny_netpol_json app-ns)"
  _write_pods '{"items":[]}'

  run network_policies::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  # app-ns should NOT appear in the no-default-deny list
  [[ "$output" != *"app-ns"* ]] || [[ "$output" == *"No issues"* ]] || [[ "$output" == *"no issues"* ]]
}

@test "netpol: kube-system and kube-node-lease excluded from default-deny check" {
  _write_namespaces "$(_ns_json kube-system kube-public kube-node-lease app-ns)"
  _write_netpols "$(_default_deny_netpol_json app-ns)"
  _write_pods '{"items":[]}'

  run network_policies::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"kube-system"* ]]
  [[ "$output" != *"kube-node-lease"* ]]
}

# --- Tests: unprotected pods ---

@test "netpol: pod not matched by any NetworkPolicy is reported" {
  _write_namespaces "$(_ns_json app-ns)"
  _write_netpols "$(_default_deny_netpol_json app-ns)"
  _write_pods "$(_pod_json app-ns lonely-pod '{"app":"orphan"}')"

  # The default-deny covers the namespace, but we also want to report pods
  # not matched by any targeted (non-default-deny) policy. However for the
  # initial simple version: a default-deny with empty podSelector selects ALL
  # pods, so lonely-pod IS matched. Let's test with a targeted policy instead.
  _write_netpols "$(_netpol_json app-ns '{"app":"web"}')"

  run network_policies::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lonely-pod"* ]] || [[ "$output" == *"orphan"* ]] || [[ "$output" == *"not selected"* ]] || [[ "$output" == *"unprotected"* ]]
}

@test "netpol: pod matched by a NetworkPolicy is not reported" {
  _write_namespaces "$(_ns_json app-ns)"
  _write_netpols "$(_netpol_json app-ns '{"app":"web"}')"
  _write_pods "$(_pod_json app-ns web-pod '{"app":"web"}')"

  run network_policies::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"web-pod"* ]]
}

@test "netpol: pod in namespace with default-deny (empty selector) is considered matched" {
  _write_namespaces "$(_ns_json app-ns)"
  _write_netpols "$(_default_deny_netpol_json app-ns)"
  _write_pods "$(_pod_json app-ns any-pod '{"app":"anything"}')"

  run network_policies::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  # Pod should NOT be reported as unprotected — default-deny covers it.
  [[ "$output" != *"any-pod"* ]] || [[ "$output" == *"No issues"* ]] || [[ "$output" == *"no issues"* ]]
}

# --- Tests: clean cluster ---

@test "netpol: all clean — reports no issues" {
  _write_namespaces "$(_ns_json app-ns)"
  _write_netpols "$(_default_deny_netpol_json app-ns)"
  _write_pods "$(_pod_json app-ns web-pod '{"app":"web"}')"

  run network_policies::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No issues"* ]] || [[ "$output" == *"no issues"* ]] || [[ "$output" == *"None"* ]]
}
