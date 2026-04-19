#!/usr/bin/env bash

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

# cluster-info.sh — fetch high-level cluster identity for /cluster-status.
#
# Sourced, not executed. Exposes cluster_info::fetch, which takes a context
# name and prints four "key: value" lines to stdout. On failure it writes a
# diagnostic to stderr and returns non-zero; the caller decides how to exit.

cluster_info::fetch() {
  local context="$1"

  local server
  if ! server="$(kubectl --context="$context" config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)" || [ -z "$server" ]; then
    printf 'Unable to resolve API server address for context `%s`.\n' "$context" >&2
    return 1
  fi

  local version_json
  if ! version_json="$(kubectl --context="$context" version -o json 2>/dev/null)"; then
    printf 'Unable to fetch cluster version for context `%s`.\n' "$context" >&2
    return 1
  fi

  local k8s_version platform
  k8s_version="$(printf '%s' "$version_json" | jq -r '.serverVersion.gitVersion // empty')"
  platform="$(printf '%s' "$version_json" | jq -r '.serverVersion.platform // empty')"

  if [ -z "$k8s_version" ]; then
    printf 'Server version missing from `kubectl version` output.\n' >&2
    return 1
  fi

  printf 'Context: %s\n' "$context"
  printf 'API server: %s\n' "$server"
  printf 'Kubernetes version: %s\n' "$k8s_version"
  printf 'Platform: %s\n' "${platform:-unknown}"
}
