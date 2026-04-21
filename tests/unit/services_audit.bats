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

# Unit tests for src/skills/audit-network/scripts/lib/services.sh.

setup() {
  load '../test_helper.bash'
  common_setup

  SKILL_SCRIPTS="$SRC_ROOT/skills/audit-network/scripts"
  # shellcheck source=/dev/null
  . "$SKILL_SCRIPTS/lib/services.sh"

  FIXTURE_DIR="$TMPDIR_TEST/fixtures"
  mkdir -p "$FIXTURE_DIR"
}

# --- Fixture helpers ---

_write_services() {
  printf '%s' "$1" > "$FIXTURE_DIR/services.json"
}

_write_endpoints() {
  printf '%s' "$1" > "$FIXTURE_DIR/endpoints.json"
}

_write_pods() {
  printf '%s' "$1" > "$FIXTURE_DIR/pods.json"
}

# Service with a selector.
_svc_json() {
  local items=""
  while [ $# -gt 0 ]; do
    local ns="$1" name="$2" selector="$3"
    shift 3
    [ -n "$items" ] && items+=","
    items+="$(printf '{"metadata":{"namespace":"%s","name":"%s"},"spec":{"selector":%s,"type":"ClusterIP"}}' "$ns" "$name" "$selector")"
  done
  printf '{"items":[%s]}' "$items"
}

# ExternalName service (no selector).
_svc_external_json() {
  local ns="$1" name="$2"
  printf '{"items":[{"metadata":{"namespace":"%s","name":"%s"},"spec":{"type":"ExternalName","externalName":"ext.example.com"}}]}' "$ns" "$name"
}

# Endpoints with subsets (has addresses = has ready endpoints).
_ep_json() {
  local items=""
  while [ $# -gt 0 ]; do
    local ns="$1" name="$2" has_addresses="$3"
    shift 3
    [ -n "$items" ] && items+=","
    if [ "$has_addresses" = "true" ]; then
      items+="$(printf '{"metadata":{"namespace":"%s","name":"%s"},"subsets":[{"addresses":[{"ip":"10.0.0.1"}]}]}' "$ns" "$name")"
    else
      items+="$(printf '{"metadata":{"namespace":"%s","name":"%s"},"subsets":[]}' "$ns" "$name")"
    fi
  done
  printf '{"items":[%s]}' "$items"
}

# Endpoints with no subsets at all.
_ep_empty_json() {
  local items=""
  while [ $# -gt 0 ]; do
    local ns="$1" name="$2"
    shift 2
    [ -n "$items" ] && items+=","
    items+="$(printf '{"metadata":{"namespace":"%s","name":"%s"}}' "$ns" "$name")"
  done
  printf '{"items":[%s]}' "$items"
}

# Pod with labels.
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

# --- Tests: services with no endpoints ---

@test "svc: service with empty endpoints reported" {
  _write_services "$(_svc_json app-ns my-svc '{"app":"web"}')"
  _write_endpoints "$(_ep_empty_json app-ns my-svc)"
  _write_pods "$(_pod_json app-ns web-pod '{"app":"web"}')"

  run services::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"my-svc"* ]]
  [[ "$output" == *"no endpoints"* ]] || [[ "$output" == *"no ready endpoints"* ]] || [[ "$output" == *"no matching endpoints"* ]]
}

@test "svc: service with ready endpoints not reported" {
  _write_services "$(_svc_json app-ns my-svc '{"app":"web"}')"
  _write_endpoints "$(_ep_json app-ns my-svc true)"
  _write_pods "$(_pod_json app-ns web-pod '{"app":"web"}')"

  run services::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"my-svc"* ]] || [[ "$output" == *"No issues"* ]]
}

# --- Tests: selector matching zero pods ---

@test "svc: service selector matching zero pods reported" {
  _write_services "$(_svc_json app-ns orphan-svc '{"app":"ghost"}')"
  _write_endpoints "$(_ep_empty_json app-ns orphan-svc)"
  _write_pods "$(_pod_json app-ns web-pod '{"app":"web"}')"

  run services::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"orphan-svc"* ]]
  [[ "$output" == *"zero pods"* ]] || [[ "$output" == *"no pods"* ]] || [[ "$output" == *"0 pods"* ]] || [[ "$output" == *"no matching pods"* ]]
}

@test "svc: service selector matching pods not reported as zero-match" {
  _write_services "$(_svc_json app-ns my-svc '{"app":"web"}')"
  _write_endpoints "$(_ep_json app-ns my-svc true)"
  _write_pods "$(_pod_json app-ns web-pod '{"app":"web"}')"

  run services::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No issues"* ]] || [[ "$output" == *"no issues"* ]]
}

# --- Tests: ExternalName services ---

@test "svc: ExternalName service excluded from checks" {
  _write_services "$(_svc_external_json app-ns ext-svc)"
  _write_endpoints '{"items":[]}'
  _write_pods '{"items":[]}'

  run services::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"ext-svc"* ]]
}

# --- Tests: kubernetes service excluded ---

@test "svc: kubernetes service in default ns excluded" {
  _write_services "$(_svc_json default kubernetes '{"component":"apiserver"}')"
  _write_endpoints "$(_ep_json default kubernetes true)"
  _write_pods '{"items":[]}'

  run services::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"kubernetes"* ]] || [[ "$output" == *"No issues"* ]]
}

# --- Tests: clean cluster ---

@test "svc: all clean — reports no issues" {
  _write_services "$(_svc_json app-ns web-svc '{"app":"web"}')"
  _write_endpoints "$(_ep_json app-ns web-svc true)"
  _write_pods "$(_pod_json app-ns web-pod '{"app":"web"}')"

  run services::render "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No issues"* ]] || [[ "$output" == *"no issues"* ]]
}
