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

# pod-info.sh — fetch per-pod health/status for /cluster-status.
#
# Sourced, not executed. Exposes pod_info::fetch, which takes a context
# name and prints an aligned table with one row per pod across all
# namespaces. On failure it writes a diagnostic to stderr and returns
# non-zero.

pod_info::fetch() {
  local context="$1"

  local pods_json
  if ! pods_json="$(kubectl --context="$context" get pods --all-namespaces -o json 2>/dev/null)"; then
    # shellcheck disable=SC2016  # backticks are literal markdown, not command substitution
    printf 'Unable to list pods for context `%s`.\n' "$context" >&2
    return 1
  fi

  local rows
  rows="$(printf '%s' "$pods_json" | jq -r '
    def age($start):
      ((now - ($start | fromdateiso8601)) / 86400 | floor) as $d
      | if $d >= 1 then "\($d)d"
        else ((now - ($start | fromdateiso8601)) / 3600 | floor) as $h
             | if $h >= 1 then "\($h)h"
               else ((now - ($start | fromdateiso8601)) / 60 | floor | tostring) + "m"
               end
        end;

    def state_reason($statuses):
      [ ($statuses // [])[]
        | (.state // {})
        | (.waiting.reason // .terminated.reason // null)
        | select(. != null and . != "")
      ] | .[0] // "";

    def phase_or_reason:
      state_reason(.status.containerStatuses) as $cr
      | if ($cr != "") then $cr
        else (.status.reason // .status.phase // "Unknown")
        end;

    def ready_count($statuses):
      ($statuses // []) | map(select(.ready == true)) | length;

    def restarts($statuses):
      ($statuses // []) | map(.restartCount // 0) | add // 0;

    def owner:
      ((.metadata.ownerReferences // []) | .[0].kind // "Pod");

    .items
    | sort_by(.metadata.namespace, .metadata.name)
    | .[]
    | (.status.containerStatuses // []) as $cs
    | (.spec.containers // []) as $spec
    | ($spec | length) as $total
    | [
        .metadata.namespace,
        .metadata.name,
        phase_or_reason,
        "\(ready_count($cs))/\($total)",
        (restarts($cs) | tostring),
        age(.status.startTime // .metadata.creationTimestamp),
        (.status.qosClass // "-"),
        owner,
        (.spec.nodeName // "-")
      ]
    | @tsv
  ')"

  if [ -z "$rows" ]; then
    printf 'No pods found.\n' >&2
    return 1
  fi

  {
    printf 'NAMESPACE\tNAME\tSTATUS\tREADY\tRESTARTS\tAGE\tQOS\tOWNER\tNODE\n'
    printf '%s\n' "$rows"
  } | column -t -s "$(printf '\t')"
}
