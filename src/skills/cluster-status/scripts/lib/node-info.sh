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

# node-info.sh — fetch per-node health/status for /cluster-status.
#
# Sourced, not executed. Exposes node_info::fetch, which takes a context
# name and prints an aligned table with one row per node. On failure it
# writes a diagnostic to stderr and returns non-zero.

node_info::fetch() {
  local context="$1"

  local nodes_json
  if ! nodes_json="$(kubectl --context="$context" get nodes -o json 2>/dev/null)"; then
    # shellcheck disable=SC2016  # backticks are literal markdown, not command substitution
    printf 'Unable to list nodes for context `%s`.\n' "$context" >&2
    return 1
  fi

  local rows
  rows="$(printf '%s' "$nodes_json" | jq -r '
    def role:
      (.metadata.labels // {})
      | to_entries
      | map(select(.key | startswith("node-role.kubernetes.io/")))
      | (map(.key | sub("node-role.kubernetes.io/"; "")) | join(",")) as $r
      | if ($r == "") then "worker" else $r end;

    def age:
      ((now - (.metadata.creationTimestamp | fromdateiso8601)) / 86400 | floor) as $d
      | if $d >= 1 then "\($d)d"
        else ((now - (.metadata.creationTimestamp | fromdateiso8601)) / 3600 | floor) as $h
             | if $h >= 1 then "\($h)h"
               else ((now - (.metadata.creationTimestamp | fromdateiso8601)) / 60 | floor | tostring) + "m"
               end
        end;

    def cond_status($conds; $t):
      (($conds | map(select(.type == $t)) | .[0]) // {}).status // "Unknown";

    def ready($conds):
      if cond_status($conds; "Ready") == "True" then "Ready" else "NotReady" end;

    def schedulable:
      if (.spec.unschedulable // false) then "No" else "Yes" end;

    def pressure($conds):
      [ ["MemoryPressure","mem"], ["DiskPressure","disk"], ["PIDPressure","pid"] ]
      | map(select(cond_status($conds; .[0]) == "True") | .[1])
      | if length == 0 then "-" else join(",") end;

    def taints:
      ((.spec.taints // []) | length) as $n
      | if $n == 0 then "-" else ($n | tostring) end;

    .items
    | sort_by(.metadata.name)
    | .[]
    | (.status.conditions // []) as $conds
    | [
        .metadata.name,
        role,
        ready($conds),
        age,
        .status.nodeInfo.kubeletVersion,
        (.status.nodeInfo.operatingSystem + "/" + .status.nodeInfo.architecture),
        ((.metadata.labels // {})["topology.kubernetes.io/zone"] // "-"),
        schedulable,
        pressure($conds),
        taints
      ]
    | @tsv
  ')"

  if [ -z "$rows" ]; then
    printf 'No nodes found.\n' >&2
    return 1
  fi

  {
    printf 'NAME\tROLE\tSTATUS\tAGE\tKUBELET\tPLATFORM\tZONE\tSCHEDULABLE\tPRESSURE\tTAINTS\n'
    printf '%s\n' "$rows"
  } | column -t -s "$(printf '\t')"
}
