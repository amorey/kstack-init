# rubric_pods — CrashLoopBackOff, OOMKilled, Pending-unschedulable, pull errors.
#
# Input: parsed `kubectl get pods -A -o json` (or {} on fetch failure),
#        plus a top-level `$now_rfc3339` string for age math on Pending pods.
# Output: [ {severity, category:"pod", kind:"Pod", namespace, name, reason,
#            detail, ts} ].

def _emit_pod(sev; reason; detail; ts):
  { severity: sev, category: "pod", kind: "Pod",
    namespace: .metadata.namespace, name: .metadata.name,
    reason: reason, detail: detail, ts: (ts // "") };

# Seconds between two RFC3339 strings. Returns 0 when either is missing.
def _age_secs($now; $then):
  if ($now == null or $now == "" or $then == null or $then == "") then 0
  else (($now | fromdateiso8601) - ($then | fromdateiso8601)) end;

def rubric_pods($now):
  (.items // [])
  | map(
      . as $pod
      | ($pod.status.containerStatuses // []) as $cs
      | ($pod.status.phase // "Unknown") as $phase
      | [
          # CrashLoopBackOff
          ( $cs[]?
            | select((.state.waiting.reason // "") == "CrashLoopBackOff")
            | . as $c
            | $pod | _emit_pod(
                (if ($c.restartCount // 0) > 5 then "critical" else "warning" end);
                "CrashLoopBackOff";
                "container=\($c.name) restarts=\($c.restartCount // 0)";
                ""
              )
          ),
          # OOMKilled — inspect lastState (terminated) even if current state is running
          ( $cs[]?
            | select((.lastState.terminated.reason // "") == "OOMKilled")
            | . as $c
            | $pod | _emit_pod("critical"; "OOMKilled";
                "container=\($c.name) exitCode=\($c.lastState.terminated.exitCode // 0)";
                ($c.lastState.terminated.finishedAt // ""))
          ),
          # ImagePull / config errors
          ( $cs[]?
            | select((.state.waiting.reason // "") | IN("ImagePullBackOff","ErrImagePull","CreateContainerConfigError"))
            | . as $c
            | $pod | _emit_pod("warning";
                ($c.state.waiting.reason);
                "container=\($c.name) message=\($c.state.waiting.message // "")";
                "")
          ),
          # Pending + unschedulable > 2m. No transition timestamp on the
          # schedule-gate; use the pod's startTime (creationTimestamp fallback).
          ( if $phase == "Pending" and ($pod.spec.nodeName // "") == ""
            then
              ( ($pod.status.startTime // $pod.metadata.creationTimestamp // "") as $t
                | (_age_secs($now; $t)) as $age
                | if $age > 600
                  then $pod | _emit_pod("critical"; "Unschedulable";
                         "pending for \($age)s with no nodeName"; $t)
                  elif $age > 120
                  then $pod | _emit_pod("warning"; "Unschedulable";
                         "pending for \($age)s with no nodeName"; $t)
                  else empty end
              )
            else empty end )
        ]
    )
  | add // [];

# pod_phase_counts — always-emit summary, regardless of severity filter.
def pod_phase_counts:
  (.items // [])
  | map(.status.phase // "Unknown")
  | reduce .[] as $p ({}; .[$p] = ((.[$p] // 0) + 1));
