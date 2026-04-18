#!/usr/bin/env bash
# cluster-status helpers — pure functions sourced by scripts/snapshot and
# exercised directly by tests/unit/cluster_status_funcs.bats.

# parse_duration_to_secs <dur>
#   Accepts a suffixed duration — "90s", "5m", "1h", "24h", "2d".
#   Prints the integer number of seconds on stdout; exits 2 on bad input.
parse_duration_to_secs() {
  local dur="${1:-}" n unit
  if [[ ! "$dur" =~ ^([0-9]+)([smhd])$ ]]; then
    echo "Invalid --since duration: '$dur' (expected 90s, 5m, 1h, 24h, 2d)" >&2
    return 2
  fi
  n="${BASH_REMATCH[1]}"; unit="${BASH_REMATCH[2]}"
  case "$unit" in
    s) printf '%s\n' "$n" ;;
    m) printf '%s\n' "$((n * 60))" ;;
    h) printf '%s\n' "$((n * 3600))" ;;
    d) printf '%s\n' "$((n * 86400))" ;;
  esac
}

# validate_severity <sev>
#   Exits 0 when $sev is one of critical|warning|info; exits 2 otherwise.
validate_severity() {
  case "${1:-}" in
    critical|warning|info) return 0 ;;
    *) echo "Invalid --severity: '${1:-}' (expected critical|warning|info)" >&2
       return 2 ;;
  esac
}

# build_kubectl_args <context> <namespace> <scope>
#   Emits space-separated kubectl flags for the given request:
#     <context>   — empty or cluster name
#     <namespace> — empty, or an ns for pod/workload/pdb calls
#     <scope>     — "cluster" (always cluster-scoped, ignores namespace)
#                 | "namespaced" (uses namespace or --all-namespaces)
build_kubectl_args() {
  local context="$1" namespace="$2" scope="$3" args=""
  [ -n "$context" ] && args="--context=$context"
  if [ "$scope" = "namespaced" ]; then
    if [ -n "$namespace" ]; then
      args="$args -n $namespace"
    else
      args="$args --all-namespaces"
    fi
  fi
  printf '%s\n' "${args# }"
}
