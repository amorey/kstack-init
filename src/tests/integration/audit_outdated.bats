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

# Integration tests for the /audit-outdated skill's scripts/main.

setup() {
  load '../test_helper.bash'
  common_setup
  use_mocks

  export KSTACK_ROOT="$TMPDIR_TEST/kstack"
  mkdir -p "$KSTACK_ROOT/lib"
  cp "$SRC_ROOT/lib/response.sh"   "$KSTACK_ROOT/lib/"
  cp "$SRC_ROOT/lib/kube-cache.sh" "$KSTACK_ROOT/lib/"
  cp "$SRC_ROOT/lib/state.sh"      "$KSTACK_ROOT/lib/"
  export KSTACK_KUBE_CONTEXT="test-ctx"
  export KSTACK_SKILL_NAME="audit-outdated"

  _stub_kubectl
  _stub_curl
  _stub_pluto_clean
  _seed_backend_pref pluto
}

# Pre-seed the saved backend preference so `main` takes the hot path instead
# of emitting a needs_setup envelope. Tests that want to exercise the
# first-run / stale-preference flow call this with a different backend, or
# unset the file to force prompting.
_seed_backend_pref() {
  local backend="$1"
  mkdir -p "$KSTACK_ROOT/state/audit-outdated"
  printf '%s\n' "$backend" > "$KSTACK_ROOT/state/audit-outdated/deprecated-apis-backend"
}

# Stub pluto so main auto-picks it silently (no user prompt).
# Returns an empty JSON array (no deprecated APIs).
_stub_pluto_clean() {
  write_stub pluto "printf '[]'"
}

# Stub kubectl with a clean cluster: v1.31.2, one node at same version,
# only current API versions.
_stub_kubectl() {
  write_stub kubectl "
args=\"\$*\"
case \"\$args\" in
  *version*)
    printf '{\"serverVersion\":{\"major\":\"1\",\"minor\":\"31\",\"gitVersion\":\"v1.31.2\"}}\n' ;;
  *'get nodes'*)
    printf '{\"kind\":\"NodeList\",\"items\":[{\"metadata\":{\"name\":\"node-0\"},\"status\":{\"nodeInfo\":{\"kubeletVersion\":\"v1.31.2\"}}}]}\n' ;;
  *api-versions*)
    printf 'apps/v1\nv1\nnetworking.k8s.io/v1\nbatch/v1\n' ;;
  *)
    printf '{\"kind\":\"List\",\"items\":[]}\n' ;;
esac
"
}

# Stub curl: returns endoflife.date API response for EOL checks;
# returns deprecation guide HTML for deprecated API web fallback.
_stub_curl() {
  write_stub curl "
args=\"\$*\"
case \"\$args\" in
  *endoflife.date*)
    printf '[{\"name\":\"1.31\",\"eolFrom\":\"2025-10-28\",\"isEol\":false}]'
    ;;
  *deprecation-guide*)
    printf ''
    ;;
  *)
    exit 1 ;;
esac
"
}

@test "main script exists and is executable" {
  [ -x "$SRC_ROOT/skills/audit-outdated/scripts/main" ]
}

@test "main: produces valid response envelope with ok status" {
  run "$SRC_ROOT/skills/audit-outdated/scripts/main"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"kstack":"1"'* ]]
  [[ "$output" == *'"status":"ok"'* ]]
  [[ "$output" == *'"render":"verbatim"'* ]]
}

@test "main: envelope content includes version info" {
  run "$SRC_ROOT/skills/audit-outdated/scripts/main"
  [ "$status" -eq 0 ]
  [[ "$output" == *"v1.31.2"* ]]
}

@test "main: envelope content includes deprecated API section" {
  run "$SRC_ROOT/skills/audit-outdated/scripts/main"
  [ "$status" -eq 0 ]
  # Should mention no deprecated APIs (clean cluster stub)
  [[ "$output" == *"deprecated"* ]] || [[ "$output" == *"Deprecated"* ]]
}

@test "main: --refresh flag accepted" {
  run "$SRC_ROOT/skills/audit-outdated/scripts/main" --refresh
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status":"ok"'* ]]
}

@test "main: --ttl flag accepted" {
  run "$SRC_ROOT/skills/audit-outdated/scripts/main" --ttl=5m
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status":"ok"'* ]]
}

@test "main: unknown flag returns user error" {
  run "$SRC_ROOT/skills/audit-outdated/scripts/main" --bogus
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status":"error"'* ]]
  [[ "$output" == *'"kind":"user"'* ]]
  [[ "$output" == *"Unknown flag"* ]]
}

@test "main: rejects --context (entrypoint owns resolution)" {
  run "$SRC_ROOT/skills/audit-outdated/scripts/main" --context=foo
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status":"error"'* ]]
  [[ "$output" == *'"kind":"user"'* ]]
  [[ "$output" == *"Unknown flag"* ]]
}

@test "main: missing KSTACK_KUBE_CONTEXT returns infra error" {
  unset KSTACK_KUBE_CONTEXT
  run "$SRC_ROOT/skills/audit-outdated/scripts/main"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status":"error"'* ]]
  [[ "$output" == *'"kind":"infra"'* ]]
}

@test "main: cached web preference emits render:agent with raw deprecation data" {
  _seed_backend_pref web
  # Override curl to return content for both endoflife and deprecation guide
  write_stub curl "
args=\"\$*\"
case \"\$args\" in
  *endoflife.date*)
    printf '[{\"name\":\"1.31\",\"eolFrom\":\"2025-10-28\",\"isEol\":false}]'
    ;;
  *deprecation-guide*)
    printf '#### Deployment\nThe **extensions/v1beta1** API version of Deployment is no longer served as of v1.22.\n'
    ;;
  *)
    exit 1 ;;
esac
"
  run "$SRC_ROOT/skills/audit-outdated/scripts/main"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"render":"agent"'* ]]
  [[ "$output" == *"kubernetes.io"* ]]
  [[ "$output" == *"Active API versions"* ]]
}

@test "main: no cached preference → needs_setup envelope with installed inventory" {
  rm -f "$KSTACK_ROOT/state/audit-outdated/deprecated-apis-backend"
  run "$SRC_ROOT/skills/audit-outdated/scripts/main"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status":"ok"'* ]]
  [[ "$output" == *'"render":"agent"'* ]]
  # agent_context is JSON-escaped when embedded in the outer envelope
  [[ "$output" == *'needs_setup'* ]]
  [[ "$output" == *'installed'* ]]
  [[ "$output" == *"Version Skew"* ]]  # skew block still rendered pre-formatted
}

@test "main: stale preference (tool uninstalled) → needs_setup with stale_preference set" {
  _seed_backend_pref kubent  # seed a choice whose tool isn't stubbed
  run "$SRC_ROOT/skills/audit-outdated/scripts/main"
  [ "$status" -eq 0 ]
  [[ "$output" == *'needs_setup'* ]]
  [[ "$output" == *'stale_preference'* ]]
  [[ "$output" == *"kubent"* ]]
}

@test "main: cached skip preference skips Workflow 2 cleanly" {
  _seed_backend_pref skip
  run "$SRC_ROOT/skills/audit-outdated/scripts/main"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"render":"verbatim"'* ]]
  [[ "$output" == *'skipped'* ]]
  [[ "$output" == *"Version Skew"* ]]
  [[ "$output" == *"Skipped"* ]]
}

@test "main: envelope content includes EOL support status" {
  run "$SRC_ROOT/skills/audit-outdated/scripts/main"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Supported"* ]] || [[ "$output" == *"End-of-life"* ]] || [[ "$output" == *"Unable to fetch"* ]]
}

@test "main: envelope includes agent_context with cache_dir" {
  run "$SRC_ROOT/skills/audit-outdated/scripts/main"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"agent_context"'* ]]
  [[ "$output" == *"cache_dir"* ]]
}

@test "SKILL.md.tmpl: positional free-text is allowed as intent hint" {
  tmpl="$SRC_ROOT/skills/audit-outdated/SKILL.md.tmpl"
  # The Arguments section must document that bare text is a follow-up hint,
  # not an error — and that only flag-shaped tokens trigger the unknown-flag rule.
  run grep -E "follow-up intent hint|intent hint" "$tmpl"
  [ "$status" -eq 0 ]
  run grep -E "bare text must not trigger an error|bare text.*not.*error" "$tmpl"
  [ "$status" -eq 0 ]
  # Guard against regression to the old strict wording.
  run grep -F "respond with the missing/unknown-argument error line" "$tmpl"
  [ "$status" -ne 0 ]
}
