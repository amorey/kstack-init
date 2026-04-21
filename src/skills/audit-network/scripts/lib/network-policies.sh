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

# network-policies.sh — NetworkPolicy audit for /audit-network.
#
# Checks:
#   1. Namespaces without a default-deny NetworkPolicy.
#   2. Pods not selected by any NetworkPolicy in their namespace.
#
# Known limitations (initial version):
#   - Default-deny detection checks for an empty podSelector only; it does not
#     verify that policyTypes includes Ingress+Egress or that no allow rules
#     exist. A policy with podSelector:{} plus an allow-all ingress rule will
#     count as "default-deny" even though it doesn't actually deny anything.
#   - matchExpressions-based selectors are ignored; only matchLabels is
#     evaluated for pod coverage.
#
# Sourced, not executed. Requires jq on PATH.

_NETPOL_EXCLUDED_NS='["kube-system","kube-public","kube-node-lease"]'

# _netpol::truncate_list <array-var-name> <max>
#   Format array as "a, b, c" truncated at <max> items.
_netpol::truncate_list() {
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

# network_policies::render <cache_dir>
#   Reads namespaces.json, networkpolicies.json, and pods.json from
#   <cache_dir>. Prints a pre-formatted findings block to stdout.
#   Returns 0 on success, non-zero if a required file is missing or jq fails.
network_policies::render() {
  local cache_dir="$1"
  local ns_file="$cache_dir/namespaces.json"
  local netpol_file="$cache_dir/networkpolicies.json"
  local pods_file="$cache_dir/pods.json"

  for f in "$ns_file" "$netpol_file" "$pods_file"; do
    if [ ! -r "$f" ]; then
      echo "Required file not found: $f" >&2
      return 1
    fi
  done

  local findings=()

  # --- Check 1: namespaces without default-deny ---
  # A "default-deny" policy has spec.podSelector == {} (empty matchLabels),
  # meaning it selects all pods in the namespace. Single jq pass over both
  # namespaces.json and networkpolicies.json — no bash loop needed.
  local no_deny_output
  no_deny_output="$(jq -r --argjson excluded "$_NETPOL_EXCLUDED_NS" \
    --slurpfile netpols "$netpol_file" '
    # Namespaces that have at least one policy with empty podSelector.
    ([$netpols[0].items[]
      | select(
          (.spec.podSelector == {})
          or (.spec.podSelector.matchLabels == null
              and ((.spec.podSelector.matchExpressions // []) | length) == 0)
        )
      | .metadata.namespace
    ] | unique) as $denied |

    # User namespaces not in the denied set.
    [.items[]
      | .metadata.name as $n
      | select($excluded | index($n) | not)
      | select($denied | index($n) | not)
      | $n
    ] | .[]
  ' "$ns_file")" || return 1

  local no_deny_ns=()
  local ns
  while IFS= read -r ns; do
    [ -z "$ns" ] && continue
    no_deny_ns+=("$ns")
  done <<< "$no_deny_output"

  if [ "${#no_deny_ns[@]}" -gt 0 ]; then
    local ns_list
    ns_list="$(_netpol::truncate_list no_deny_ns 10)"
    findings+=("$(printf '  %d namespace(s) without default-deny: %s' "${#no_deny_ns[@]}" "$ns_list")")
  fi

  # --- Check 2: pods not selected by any NetworkPolicy ---
  # For each pod, check whether any NetworkPolicy in the same namespace
  # selects it (either via empty podSelector = all pods, or via matchLabels
  # that are a subset of the pod's labels).
  local unprotected_pods
  unprotected_pods="$(jq -r --slurpfile netpols "$netpol_file" '
    # Build a lookup: for each namespace, list of policy selectors.
    ($netpols[0].items | group_by(.metadata.namespace) |
      map({key: .[0].metadata.namespace, value: [.[] | .spec.podSelector]}) |
      from_entries
    ) as $pol_map |

    # For each pod, check if any policy in its namespace selects it.
    [.items[] | . as $pod |
      ($pod.metadata.namespace) as $ns |
      ($pol_map[$ns] // []) as $selectors |

      # A pod is "matched" if any selector applies:
      #   - empty selector ({} or {matchLabels:null}) = selects all pods
      #   - matchLabels: every key/value must appear in pod labels
      if ($selectors | length) == 0 then
        # No policies at all in this namespace — pod is unprotected.
        "\($ns)/\($pod.metadata.name)"
      elif any($selectors[];
        ((.matchLabels // {}) | to_entries) as $required |
        if ($required | length) == 0 then
          true  # empty selector = default-deny, matches all
        else
          ($pod.metadata.labels // {}) as $labels |
          all($required[]; $labels[.key] == .value)
        end
      ) then
        empty  # matched by at least one policy
      else
        "\($ns)/\($pod.metadata.name)"
      end
    ] | .[]
  ' "$pods_file")" || return 1

  local unprotected_list=()
  local pod
  while IFS= read -r pod; do
    [ -z "$pod" ] && continue
    unprotected_list+=("$pod")
  done <<< "$unprotected_pods"

  if [ "${#unprotected_list[@]}" -gt 0 ]; then
    local pod_list
    pod_list="$(_netpol::truncate_list unprotected_list 10)"
    findings+=("$(printf '  %d pod(s) not selected by any NetworkPolicy: %s' "${#unprotected_list[@]}" "$pod_list")")
  fi

  # --- Output ---
  if [ "${#findings[@]}" -eq 0 ]; then
    printf '  No issues found.\n'
  else
    printf '%s\n' "${findings[@]}"
  fi
}
