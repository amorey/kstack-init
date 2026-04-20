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

# pod-info.sh — render a bounded pod summary + top-issues block for
# /cluster-status. Sourced, not executed. Outputs:
#
#   Pods   X/Y Ready · N pod(s) with restarts
#
#   Issues (K):
#     <ns>/<name>  <reason>  <detail>
#     ...               (top 5 by severity)
#     …and M more       (if > 5)
#
# Full per-pod details live in the cached pods.json for follow-up queries.

pod_info::render() {
  local file="$1"

  # One jq pass emits tagged tab-separated records; shell below parses them.
  local records
  records="$(jq -r '
    # Succeeded pods (completed jobs/cronjobs) are not unhealthy — their
    # containers report ready=false because they terminated normally. Treat
    # them as out-of-scope for the Ready/Total count and for Issues.
    def is_terminal_success: .status.phase == "Succeeded";

    def is_ready:
      (.status.containerStatuses // []) as $cs
      | (.spec.containers // []) as $spec
      | ($cs | length) > 0
        and ($cs | length) == ($spec | length)
        and all($cs[]; .ready == true);

    def waiting_reason:
      [ (.status.containerStatuses // [])[]
        | (.state // {}).waiting.reason
        | select(. != null and . != "")
      ] | .[0] // null;

    def waiting_message:
      [ (.status.containerStatuses // [])[]
        | (.state // {}).waiting.message
        | select(. != null and . != "")
      ] | .[0] // "";

    def reason_or_phase:
      waiting_reason // .status.reason // .status.phase // "Unknown";

    def total_restarts:
      (.status.containerStatuses // []) | map(.restartCount // 0) | add // 0;

    def sev_rank($r):
      ["CrashLoopBackOff","ImagePullBackOff","ErrImagePull",
       "CreateContainerError","CreateContainerConfigError",
       "InvalidImageName","RunContainerError"]
      | index($r) // 99;

    ([.items[] | select(is_terminal_success | not)]) as $active
    | ($active | length) as $total
    | ([$active[] | select(is_ready)] | length) as $ready
    | ([$active[] | select(total_restarts > 0)] | length) as $with_restarts
    | [$active[]
        | select(is_ready | not)
        | {
            pod: "\(.metadata.namespace)/\(.metadata.name)",
            reason: reason_or_phase,
            restarts: total_restarts,
            msg: waiting_message
          }
      ] as $issues
    | ($issues | sort_by(sev_rank(.reason), -(.restarts))) as $ranked
    | "SUMMARY\t\($ready)/\($total) Ready · \($with_restarts) pod(s) with restarts",
      "COUNT\t\($issues | length)",
      ($ranked | .[0:5][]
        | "ISSUE\t\(.pod)\t\(.reason)\t\(
            if .restarts > 0 and .msg != "" then "restarts=\(.restarts); \(.msg)"
            elif .restarts > 0 then "restarts=\(.restarts)"
            else .msg
            end
          )"),
      (if ($issues | length) > 5 then "MORE\t\(($issues | length) - 5)" else empty end)
  ' "$file" 2>/dev/null)"

  if [ -z "$records" ]; then
    printf 'No pods found.\n' >&2
    return 1
  fi

  local summary="" issue_count=0 issue_more=0 issue_rows=""
  while IFS=$'\t' read -r tag a b c; do
    case "$tag" in
      SUMMARY) summary="$a" ;;
      COUNT)   issue_count="$a" ;;
      ISSUE)   issue_rows+="  $a"$'\t'"$b"$'\t'"$c"$'\n' ;;
      MORE)    issue_more="$a" ;;
    esac
  done <<< "$records"

  printf 'Pods   %s\n' "$summary"

  if [ "$issue_count" -gt 0 ]; then
    printf '\nIssues (%s):\n' "$issue_count"
    printf '%s' "$issue_rows" | column -t -s "$(printf '\t')"
    if [ "$issue_more" -gt 0 ]; then
      printf '  …and %s more\n' "$issue_more"
    fi
  fi
}
