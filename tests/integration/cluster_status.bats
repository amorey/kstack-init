#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  common_setup
  use_mocks

  SNAP="$REPO_ROOT/skills/cluster-status/scripts/snapshot"
  FIX="$FIXTURES_DIR/kubectl"
  export KSTACK_ROOT="$REPO_ROOT"
  # Pin clock to a fixed time near the fixture timestamps so tests are
  # deterministic regardless of wall-clock drift.
  export KSTACK_NOW="2026-04-18T12:00:00Z"
}

# write_kubectl_stub — respond to each kubectl subcommand with the matching
# fixture file. Captures each invocation to $TMPDIR_TEST/kubectl.log for
# assertions on flags.
write_kubectl_stub() {
  local fixture_prefix="${1:-}"
  write_stub kubectl "$(cat <<EOF
: "\${KUBECTL_LOG:=$TMPDIR_TEST/kubectl.log}"
printf '%s\n' "\$*" >> "\$KUBECTL_LOG"
resource=""
for a in "\$@"; do
  case "\$a" in
    nodes) resource=nodes; break ;;
    pods)  resource=pods; break ;;
    deployments,statefulsets,daemonsets) resource=workloads; break ;;
    poddisruptionbudgets) resource=pdbs; break ;;
  esac
done
case "\$resource" in
  nodes)     cat "$FIX/${fixture_prefix}nodes.json" ;;
  pods)      cat "$FIX/${fixture_prefix}pods.json" ;;
  workloads) cat "$FIX/${fixture_prefix}workloads.json" ;;
  pdbs)      cat "$FIX/${fixture_prefix}pdbs.json" ;;
  *)         echo "unknown resource: \$*" >&2; exit 1 ;;
esac
EOF
)"
}

@test "snapshot prose: exits 0, prints headline and nodes table" {
  write_kubectl_stub
  run "$SNAP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"findings —"* ]]
  [[ "$output" == *"## Nodes (3)"* ]]
  [[ "$output" == *"worker-down"* ]]
  [[ "$output" == *"→ /investigate"* ]]
}

@test "snapshot --json emits valid JSON with expected schema" {
  write_kubectl_stub
  run "$SNAP" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  [ "$(echo "$output" | jq -r '.summary | keys | sort | join(",")')" = "critical,info,warning" ]
  [ "$(echo "$output" | jq -r '.pod_phases | keys | length > 0')" = "true" ]
  [ "$(echo "$output" | jq -r '.findings | length > 0')" = "true" ]
}

@test "snapshot --namespace foo passes -n foo to pod/workload/pdb calls" {
  write_kubectl_stub
  run "$SNAP" --namespace foo
  [ "$status" -eq 0 ]
  # nodes call must remain cluster-scoped
  run grep -F "get nodes " "$TMPDIR_TEST/kubectl.log"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "-n foo" ]]
  # pods/workloads/pdbs must carry -n foo
  run grep -F "get pods -n foo" "$TMPDIR_TEST/kubectl.log"
  [ "$status" -eq 0 ]
  run grep -F "get deployments,statefulsets,daemonsets -n foo" "$TMPDIR_TEST/kubectl.log"
  [ "$status" -eq 0 ]
}

@test "snapshot --context prod appends --context=prod to every call" {
  write_kubectl_stub
  run "$SNAP" --context prod
  [ "$status" -eq 0 ]
  [ "$(grep -c -F -- '--context=prod' "$TMPDIR_TEST/kubectl.log")" -eq 4 ]
}

@test "snapshot --dry-run prints four would-run lines and sentinel" {
  write_kubectl_stub
  run "$SNAP" --dry-run
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | grep -c -F '# would run:')" -eq 4 ]
  [[ "$output" == *"Dry run — no commands executed."* ]]
  [ ! -f "$TMPDIR_TEST/kubectl.log" ]
}

@test "snapshot --since 5m filters out findings older than the cutoff" {
  write_kubectl_stub
  run "$SNAP"
  [ "$status" -eq 0 ]
  full_count="$(echo "$output" | head -1 | sed -E 's/^([0-9]+) findings.*/\1/')"
  run "$SNAP" --since 5m
  [ "$status" -eq 0 ]
  filtered_count="$(echo "$output" | head -1 | sed -E 's/^([0-9]+) findings.*/\1/')"
  [ "$filtered_count" -lt "$full_count" ]
}

@test "snapshot --severity critical drops warnings and info" {
  write_kubectl_stub
  run "$SNAP" --severity critical
  [ "$status" -eq 0 ]
  [[ "$output" != *"| warning |"* ]]
}

@test "snapshot unknown flag exits 2 with Unknown flag message" {
  write_kubectl_stub
  run "$SNAP" --wat
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown flag '--wat'"* ]]
}

@test "snapshot invalid --since exits 2" {
  write_kubectl_stub
  run "$SNAP" --since bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"Invalid"* ]]
}

@test "snapshot invalid --severity exits 2" {
  write_kubectl_stub
  run "$SNAP" --severity bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"Invalid"* ]]
}

@test "snapshot without KSTACK_ROOT fails with clear error" {
  write_kubectl_stub
  run env -u KSTACK_ROOT "$SNAP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"KSTACK_ROOT"* ]]
}

@test "snapshot surfaces kubectl failure in errors[]" {
  write_stub kubectl "$(cat <<EOF
: "\${KUBECTL_LOG:=$TMPDIR_TEST/kubectl.log}"
printf '%s\n' "\$*" >> "\$KUBECTL_LOG"
for a in "\$@"; do
  if [ "\$a" = "pods" ]; then
    echo "boom: rbac denied" >&2
    exit 1
  fi
done
case "\$*" in
  *nodes*)                cat "$FIX/nodes.json" ;;
  *deployments,statefulsets,daemonsets*) cat "$FIX/workloads.json" ;;
  *poddisruptionbudgets*) cat "$FIX/pdbs.json" ;;
esac
EOF
)"
  run "$SNAP" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.errors | length >= 1' >/dev/null
  echo "$output" | jq -e '.errors[] | select(.call == "pods")' >/dev/null
}
