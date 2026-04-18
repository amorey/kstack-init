#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  common_setup
  LIB="$REPO_ROOT/lib/cluster-status"
  FIX="$FIXTURES_DIR/kubectl"
  NOW="2026-04-18T12:00:00Z"
}

# node_rubric <file>  →  jq array of findings
node_rubric() {
  jq -L "$LIB" -c 'include "rubric_nodes"; rubric_nodes' "$1"
}
pod_rubric() {
  jq -L "$LIB" -c --arg now "$NOW" 'include "rubric_pods"; rubric_pods($now)' "$1"
}
workload_rubric() {
  jq -L "$LIB" -c 'include "rubric_workloads"; rubric_workloads' "$1"
}
pdb_rubric() {
  jq -L "$LIB" -c 'include "rubric_pdbs"; rubric_pdbs' "$1"
}

# count <jq-out> <filter>
count() {
  echo "$1" | jq "[.[] | $2] | length"
}

@test "nodes: NotReady worker produces one critical finding" {
  out="$(node_rubric "$FIX/nodes.json")"
  [ "$(count "$out" "select(.reason == \"NotReady\" and .severity == \"critical\")")" -eq 1 ]
}

@test "nodes: MemoryPressure produces warning" {
  out="$(node_rubric "$FIX/nodes.json")"
  [ "$(count "$out" "select(.reason == \"MemoryPressure\" and .severity == \"warning\")")" -eq 1 ]
}

@test "nodes: cordoned worker produces Cordoned warning" {
  out="$(node_rubric "$FIX/nodes.json")"
  [ "$(count "$out" "select(.reason == \"Cordoned\" and .severity == \"warning\")")" -eq 1 ]
}

@test "nodes: healthy control-plane contributes no findings" {
  out="$(node_rubric "$FIX/nodes.json")"
  [ "$(count "$out" "select(.name == \"cp-1\")")" -eq 0 ]
}

@test "nodes: empty list returns []" {
  out="$(node_rubric "$FIX/nodes_empty.json")"
  [ "$out" = "[]" ]
}

@test "node_rows: three rows match the three items" {
  out="$(jq -L "$LIB" -c 'include "rubric_nodes"; node_rows' "$FIX/nodes.json")"
  [ "$(echo "$out" | jq 'length')" -eq 3 ]
}

@test "pods: CrashLoopBackOff restarts=3 is warning" {
  out="$(pod_rubric "$FIX/pods.json")"
  [ "$(count "$out" "select(.name == \"crash-warn\" and .severity == \"warning\" and .reason == \"CrashLoopBackOff\")")" -eq 1 ]
}

@test "pods: CrashLoopBackOff restarts=12 is critical" {
  out="$(pod_rubric "$FIX/pods.json")"
  [ "$(count "$out" "select(.name == \"crash-crit\" and .severity == \"critical\" and .reason == \"CrashLoopBackOff\")")" -eq 1 ]
}

@test "pods: OOMKilled via lastState.terminated is critical" {
  out="$(pod_rubric "$FIX/pods.json")"
  [ "$(count "$out" "select(.name == \"oom-app\" and .severity == \"critical\" and .reason == \"OOMKilled\")")" -eq 1 ]
}

@test "pods: ImagePullBackOff is warning" {
  out="$(pod_rubric "$FIX/pods.json")"
  [ "$(count "$out" "select(.name == \"image-pull\" and .severity == \"warning\" and .reason == \"ImagePullBackOff\")")" -eq 1 ]
}

@test "pods: Pending unschedulable > 10m is critical" {
  out="$(pod_rubric "$FIX/pods.json")"
  [ "$(count "$out" "select(.name == \"pending-old\" and .severity == \"critical\" and .reason == \"Unschedulable\")")" -eq 1 ]
}

@test "pods: healthy Running pod contributes no findings" {
  out="$(pod_rubric "$FIX/pods.json")"
  [ "$(count "$out" "select(.name == \"web-abc\")")" -eq 0 ]
}

@test "pod_phase_counts: matches expected buckets" {
  out="$(jq -L "$LIB" -c 'include "rubric_pods"; pod_phase_counts' "$FIX/pods.json")"
  [ "$(echo "$out" | jq '.Running')" -eq 4 ]
  [ "$(echo "$out" | jq '.Pending')" -eq 2 ]
}

@test "workloads: Deployment drift emits ReplicaDrift" {
  out="$(workload_rubric "$FIX/workloads.json")"
  [ "$(count "$out" "select(.kind == \"Deployment\" and .name == \"web\" and .reason == \"ReplicaDrift\")")" -eq 1 ]
}

@test "workloads: DaemonSet drift emits ReplicaDrift" {
  out="$(workload_rubric "$FIX/workloads.json")"
  [ "$(count "$out" "select(.kind == \"DaemonSet\" and .name == \"node-exporter\" and .reason == \"ReplicaDrift\")")" -eq 1 ]
}

@test "workloads: healthy items contribute no findings" {
  out="$(workload_rubric "$FIX/workloads.json")"
  [ "$(count "$out" "select(.name == \"healthy-dep\" or .name == \"db\" or .name == \"fluent-bit\")")" -eq 0 ]
}

@test "pdbs: violating PDB is critical" {
  out="$(pdb_rubric "$FIX/pdbs.json")"
  [ "$(count "$out" "select(.name == \"web\" and .severity == \"critical\" and .reason == \"PDBViolation\")")" -eq 1 ]
}

@test "pdbs: healthy PDB contributes no findings" {
  out="$(pdb_rubric "$FIX/pdbs.json")"
  [ "$(count "$out" "select(.name == \"db\")")" -eq 0 ]
}
