# kubectl JSON fixtures

Hand-authored JSON bodies that stand in for `kubectl get … -o json` output in
`tests/unit/cluster_status_rubrics.bats` and `tests/integration/cluster_status.bats`.
Each file is the minimum shape the cluster-status jq rubrics consume — not a
full kubectl response.

- `nodes.json` — one control-plane, one worker w/ MemoryPressure, one worker
  NotReady+cordoned.
- `pods.json` — healthy Running + Pending-unschedulable (old) + CrashLoopBackOff
  (3 restarts, warning) + CrashLoopBackOff (12 restarts, critical) + OOMKilled
  + ImagePullBackOff.
- `workloads.json` — Deployment drift + StatefulSet healthy + DaemonSet drift.
- `pdbs.json` — one healthy, one violating.
- `*_empty.json` — `{"items":[]}` for edge-case tests.

Timestamps use a fixed `NOW=2026-04-18T12:00:00Z` — tests pass the same value
via `--arg now`, so `--since` filtering is deterministic.
