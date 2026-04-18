# rubric_workloads — replica-drift findings for Deployment / StatefulSet / DaemonSet.
#
# Input: parsed `kubectl get deployments,statefulsets,daemonsets -A -o json`.
# Output: [ {severity:"warning", category:"workload", kind, namespace, name,
#            reason:"ReplicaDrift", detail, ts:""} ].

def _emit_workload(kind; detail):
  { severity: "warning", category: "workload",
    kind: kind, namespace: .metadata.namespace, name: .metadata.name,
    reason: "ReplicaDrift", detail: detail, ts: "" };

def rubric_workloads:
  (.items // [])
  | map(
      . as $w
      | (.kind // "") as $k
      | if ($k == "Deployment" or $k == "StatefulSet")
          and (($w.status.readyReplicas // 0) < ($w.spec.replicas // 0))
        then $w | _emit_workload($k; "ready=\($w.status.readyReplicas // 0)/\($w.spec.replicas // 0)")
        elif $k == "DaemonSet"
          and (($w.status.numberReady // 0) < ($w.status.desiredNumberScheduled // 0))
        then $w | _emit_workload("DaemonSet"; "ready=\($w.status.numberReady // 0)/\($w.status.desiredNumberScheduled // 0)")
        else empty end
    );
