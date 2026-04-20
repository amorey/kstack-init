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

# Unit tests for src/lib/kube-cache.sh. The lib is sourced (not executed) so
# we cover each public function via a prepared $KSTACK_ROOT and kubectl stubs
# that write known payloads to the cache.

setup() {
  load '../test_helper.bash'
  common_setup
  export KSTACK_ROOT="$TMPDIR_TEST/kstack"
  mkdir -p "$KSTACK_ROOT/lib"
  # shellcheck source=../../lib/kube-cache.sh
  . "$SRC_ROOT/lib/kube-cache.sh"
}

# _stub_kubectl emits a stub kubectl that logs every invocation to
# $KUBECTL_LOG and responds to:
#   `config current-context` → $MOCK_CONTEXT (default "test-ctx")
#   `… version …`            → {"serverVersion":{"gitVersion":"v1.30.0"}}
#   `… get <resource> …`     → {"kind":"List","resource":"<resource>"}
_stub_kubectl() {
  use_mocks
  export KUBECTL_LOG="$TMPDIR_TEST/kubectl.log"
  : > "$KUBECTL_LOG"
  write_stub kubectl "
echo \"\$@\" >> '$KUBECTL_LOG'
args=\"\$*\"
case \"\$args\" in
  *'config current-context'*) printf '%s\n' \"\${MOCK_CONTEXT:-test-ctx}\" ;;
  *version*) printf '{\"serverVersion\":{\"gitVersion\":\"v1.30.0\"}}\n' ;;
  *) r=\"\${args#*get }\"; r=\"\${r%% *}\"
     printf '{\"kind\":\"List\",\"resource\":\"%s\"}\n' \"\$r\" ;;
esac
"
}

@test "init: resolves current context when --context is empty" {
  _stub_kubectl
  export MOCK_CONTEXT="my-ctx"
  kube_cache::init
  [ "$KUBE_CACHE_CONTEXT" = "my-ctx" ]
  [ -d "$KUBE_CACHE_DIR" ]
  [ "$KUBE_CACHE_TTL_SECS" = "900" ]  # 15m default
}

@test "init: honors explicit --context" {
  _stub_kubectl
  kube_cache::init --context=other-ctx
  [ "$KUBE_CACHE_CONTEXT" = "other-ctx" ]
}

@test "init: parses --ttl=30s" {
  _stub_kubectl
  kube_cache::init --context=ctx --ttl=30s
  [ "$KUBE_CACHE_TTL_SECS" = "30" ]
}

@test "init: parses --ttl=2h" {
  _stub_kubectl
  kube_cache::init --context=ctx --ttl=2h
  [ "$KUBE_CACHE_TTL_SECS" = "7200" ]
}

@test "init: parses --ttl=1d" {
  _stub_kubectl
  kube_cache::init --context=ctx --ttl=1d
  [ "$KUBE_CACHE_TTL_SECS" = "86400" ]
}

@test "init: --ttl=0s is accepted (force-refetch sentinel)" {
  _stub_kubectl
  kube_cache::init --context=ctx --ttl=0s
  [ "$KUBE_CACHE_TTL_SECS" = "0" ]
}

@test "init: --refresh forces TTL_SECS=0" {
  _stub_kubectl
  kube_cache::init --context=ctx --refresh
  [ "$KUBE_CACHE_TTL_SECS" = "0" ]
}

@test "init: --refresh overrides an explicit --ttl" {
  _stub_kubectl
  kube_cache::init --context=ctx --ttl=1h --refresh
  [ "$KUBE_CACHE_TTL_SECS" = "0" ]
}

@test "init: rejects malformed --ttl with user-kind error" {
  _stub_kubectl
  kube_cache::init --context=ctx --ttl=bogus || true
  [ "$KUBE_CACHE_ERROR_KIND" = "user" ]
  [[ "$KUBE_CACHE_ERROR" == *"Invalid --ttl"* ]]
}

@test "init: rejects unknown arg with user-kind error" {
  _stub_kubectl
  kube_cache::init --context=ctx --not-a-flag || true
  [ "$KUBE_CACHE_ERROR_KIND" = "user" ]
}

@test "init: no current-context is user-kind error" {
  use_mocks
  write_stub kubectl '
if [ "$1" = "config" ] && [ "$2" = "current-context" ]; then
  exit 1
fi
printf "{}\n"
'
  kube_cache::init || true
  [ "$KUBE_CACHE_ERROR_KIND" = "user" ]
  [[ "$KUBE_CACHE_ERROR" == *"current context"* ]]
}

@test "init: missing KSTACK_ROOT is infra-kind error" {
  _stub_kubectl
  unset KSTACK_ROOT
  kube_cache::init --context=ctx || true
  [ "$KUBE_CACHE_ERROR_KIND" = "infra" ]
}

@test "init: returns non-zero on any error" {
  _stub_kubectl
  run kube_cache::init --context=ctx --ttl=bogus
  [ "$status" -ne 0 ]
}

@test "init: context sha changes with context name" {
  _stub_kubectl
  kube_cache::init --context=alpha
  local a="$KUBE_CACHE_DIR"
  kube_cache::init --context=beta
  [ "$a" != "$KUBE_CACHE_DIR" ]
}

@test "ensure_list: writes cache file and passes extra args through" {
  _stub_kubectl
  kube_cache::init --context=ctx
  kube_cache::ensure_list pods --all-namespaces
  local f="$KUBE_CACHE_DIR/pods.json"
  [ -f "$f" ]
  grep -q '"resource":"pods"' "$f"
  grep -q -- '--all-namespaces' "$KUBECTL_LOG"
}

@test "ensure_list: skips kubectl when file is fresh" {
  _stub_kubectl
  kube_cache::init --context=ctx --ttl=1h
  kube_cache::ensure_list nodes
  local first
  first="$(wc -l < "$KUBECTL_LOG")"
  kube_cache::ensure_list nodes
  local second
  second="$(wc -l < "$KUBECTL_LOG")"
  [ "$first" = "$second" ]
}

@test "ensure_list: ttl=0 forces a refetch on every call" {
  _stub_kubectl
  kube_cache::init --context=ctx --ttl=0s
  kube_cache::ensure_list nodes
  kube_cache::ensure_list nodes
  # two get-nodes invocations, plus any current-context probe
  local n
  n="$(grep -c 'get nodes' "$KUBECTL_LOG" || true)"
  [ "$n" = "2" ]
}

@test "ensure_list: returns non-zero when kubectl fails and leaves no stale file" {
  use_mocks
  write_stub kubectl '
if [ "$1" = "config" ]; then printf "ctx\n"; exit 0; fi
exit 7
'
  kube_cache::init --context=ctx
  run kube_cache::ensure_list pods
  [ "$status" -ne 0 ]
  [ ! -f "$KUBE_CACHE_DIR/pods.json" ]
  [ ! -f "$KUBE_CACHE_DIR/pods.json.tmp" ]
}

@test "ensure_version: writes cluster.json" {
  _stub_kubectl
  kube_cache::init --context=ctx
  kube_cache::ensure_version
  grep -q "v1.30.0" "$KUBE_CACHE_DIR/cluster.json"
}

@test "path: returns <dir>/<name>.json without fetching" {
  _stub_kubectl
  kube_cache::init --context=ctx
  : > "$KUBECTL_LOG"
  local p
  p="$(kube_cache::path pods)"
  [ "$p" = "$KUBE_CACHE_DIR/pods.json" ]
  # No kubectl call.
  [ ! -s "$KUBECTL_LOG" ]
}

@test "format_duration: seconds granularity under 1m" {
  [ "$(kube_cache::format_duration 0)"  = "0s"  ]
  [ "$(kube_cache::format_duration 1)"  = "1s"  ]
  [ "$(kube_cache::format_duration 59)" = "59s" ]
}

@test "format_duration: minutes granularity under 1h" {
  [ "$(kube_cache::format_duration 60)"   = "1m"  ]
  [ "$(kube_cache::format_duration 125)"  = "2m"  ]
  [ "$(kube_cache::format_duration 3599)" = "59m" ]
}

@test "format_duration: hours granularity under 1d" {
  [ "$(kube_cache::format_duration 3600)"  = "1h"  ]
  [ "$(kube_cache::format_duration 7200)"  = "2h"  ]
  [ "$(kube_cache::format_duration 86399)" = "23h" ]
}

@test "format_duration: days granularity at/over 1d" {
  [ "$(kube_cache::format_duration 86400)"  = "1d" ]
  [ "$(kube_cache::format_duration 259200)" = "3d" ]
}
