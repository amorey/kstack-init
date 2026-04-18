#!/usr/bin/env bash
# cluster-status fetch — runs four kubectl calls in parallel and stashes
# stdout/stderr/rc under $tmp/<key>.{json,err,rc}. The caller decides how to
# surface failures; any non-zero rc or empty stdout is not re-run.

# fetch_all <tmp> <context> <namespace>
#   <tmp>       — existing directory, owned by caller; cleanup is external.
#   <context>   — empty string or a kube-context name.
#   <namespace> — empty string or a namespace scoping pods/workloads/pdbs.
fetch_all() {
  local tmp="$1" context="$2" namespace="$3"

  local cluster_args namespaced_args
  cluster_args="$(build_kubectl_args "$context" "" cluster)"
  namespaced_args="$(build_kubectl_args "$context" "$namespace" namespaced)"

  _fetch_one "$tmp/nodes"     kubectl get nodes $cluster_args -o json &
  _fetch_one "$tmp/pods"      kubectl get pods $namespaced_args -o json &
  _fetch_one "$tmp/workloads" kubectl get deployments,statefulsets,daemonsets $namespaced_args -o json &
  _fetch_one "$tmp/pdbs"      kubectl get poddisruptionbudgets $namespaced_args -o json &

  wait
}

# _fetch_one <prefix> <cmd...>
#   Runs <cmd...>, capturing stdout to $prefix.json, stderr to $prefix.err,
#   and rc to $prefix.rc. Never exits the caller on failure.
_fetch_one() {
  local prefix="$1"; shift
  local rc=0
  "$@" >"$prefix.json" 2>"$prefix.err" || rc=$?
  printf '%s\n' "$rc" > "$prefix.rc"
  # A malformed JSON body (e.g. truncated kubectl output) yields a zero rc
  # but breaks the downstream jq pipeline — normalize to an empty object so
  # jq receives valid input and aggregate.jq is free to decide what to do.
  if ! jq -e . "$prefix.json" >/dev/null 2>&1; then
    printf '{}\n' > "$prefix.json"
  fi
}

# record_errors <tmp> <out_json_file>
#   Writes a JSON array of {call, rc, stderr} entries for any fetch that
#   failed. Empty array when every fetch returned rc=0.
record_errors() {
  local tmp="$1" out="$2" key rc entries=""
  for key in nodes pods workloads pdbs; do
    [ -f "$tmp/$key.rc" ] || continue
    rc="$(cat "$tmp/$key.rc")"
    [ "$rc" = "0" ] && continue
    local err=""
    [ -f "$tmp/$key.err" ] && err="$(cat "$tmp/$key.err")"
    local entry
    entry="$(jq -cn --arg call "$key" --argjson rc "$rc" --arg err "$err" \
      '{call: $call, rc: $rc, stderr: $err}')"
    entries="$entries$entry"$'\n'
  done
  if [ -z "$entries" ]; then
    printf '[]\n' > "$out"
  else
    printf '%s' "$entries" | jq -s '.' > "$out"
  fi
}
