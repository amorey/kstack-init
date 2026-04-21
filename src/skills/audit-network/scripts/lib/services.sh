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

# shellcheck shell=bash

# services.sh — Service health audit for /audit-network.
#
# Checks:
#   1. Services with no ready endpoints.
#   2. Services whose selector matches zero pods.
#
# Sourced, not executed. Requires jq on PATH.

# Excluded namespaces — kept in sync with network-policies.sh.
_SVC_EXCLUDED_NS='["kube-system","kube-public","kube-node-lease"]'

# _svc::truncate_list <array-var-name> <max>
#   Format array as "a, b, c" truncated at <max> items.
_svc::truncate_list() {
  local -n _arr=$1
  local max=$2 count=${#_arr[@]}
  local out
  if [ "$count" -le "$max" ]; then
    out="$(printf '%s, ' "${_arr[@]}")"
    printf '%s' "${out%, }"
  else
    out="$(printf '%s, ' "${_arr[@]:0:$max}")"
    printf '%s …and %d more' "${out%, }" "$(( count - max ))"
  fi
}

# services::render <cache_dir>
#   Reads services.json, endpoints.json, and pods.json from <cache_dir>.
#   Prints a pre-formatted findings block to stdout. Returns 0 on success.
services::render() {
  local cache_dir="$1"
  local svc_file="$cache_dir/services.json"
  local ep_file="$cache_dir/endpoints.json"
  local pods_file="$cache_dir/pods.json"

  for f in "$svc_file" "$ep_file" "$pods_file"; do
    if [ ! -r "$f" ]; then
      echo "Required file not found: $f" >&2
      return 1
    fi
  done

  local findings=()

  # Run both checks in a single jq invocation for efficiency. Output is
  # newline-delimited "type|ns/name" lines.
  local issues
  issues="$(jq -r --argjson excluded "$_SVC_EXCLUDED_NS" \
    --slurpfile eps "$ep_file" --slurpfile pods "$pods_file" '
    # Build endpoints lookup: "ns/name" -> true if has ready addresses.
    ($eps[0].items // [] |
      map({
        key: "\(.metadata.namespace)/\(.metadata.name)",
        value: ((.subsets // []) | any((.addresses // []) | length > 0))
      }) | from_entries
    ) as $ep_map |

    # Build per-namespace pod label sets for selector matching.
    ($pods[0].items // [] |
      group_by(.metadata.namespace) |
      map({
        key: .[0].metadata.namespace,
        value: [.[] | .metadata.labels // {}]
      }) | from_entries
    ) as $pod_labels |

    # Check each service (skip ExternalName, excluded namespaces, default/kubernetes).
    [.items[] |
      select(.spec.type != "ExternalName") |
      .metadata.namespace as $ns |
      select($excluded | index($ns) | not) |
      select(.metadata.name != "kubernetes" or $ns != "default") |
      . as $svc |
      "\(.metadata.namespace)/\(.metadata.name)" as $key |

      # Check 1: no ready endpoints.
      (if ($ep_map[$key] // false) == false then
        "no-endpoints|\($key)"
      else empty end),

      # Check 2: selector matches zero pods.
      (if (.spec.selector // {} | length) > 0 then
        (.spec.selector | to_entries) as $sel |
        ($pod_labels[$svc.metadata.namespace] // []) as $ns_pods |
        ([$ns_pods[] | . as $pl |
          if all($sel[]; $pl[.key] == .value) then . else empty end
        ] | length) as $matched |
        if $matched == 0 then
          "zero-pods|\($key)"
        else empty end
      else empty end)
    ] | .[]
  ' "$svc_file")" || return 1

  # Parse results.
  local no_ep=() zero_pods=()
  local line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local type="${line%%|*}" svc="${line#*|}"
    case "$type" in
      no-endpoints) no_ep+=("$svc") ;;
      zero-pods) zero_pods+=("$svc") ;;
    esac
  done <<< "$issues"

  if [ "${#no_ep[@]}" -gt 0 ]; then
    local svc_list
    svc_list="$(_svc::truncate_list no_ep 10)"
    findings+=("$(printf '  %d service(s) with no ready endpoints: %s' "${#no_ep[@]}" "$svc_list")")
  fi

  if [ "${#zero_pods[@]}" -gt 0 ]; then
    local svc_list
    svc_list="$(_svc::truncate_list zero_pods 10)"
    findings+=("$(printf '  %d service(s) with selector matching zero pods: %s' "${#zero_pods[@]}" "$svc_list")")
  fi

  if [ "${#findings[@]}" -eq 0 ]; then
    printf '  No issues found.\n'
  else
    printf '%s\n' "${findings[@]}"
  fi
}
