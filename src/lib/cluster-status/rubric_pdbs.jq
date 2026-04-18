# rubric_pdbs — PodDisruptionBudget violations.
#
# Input: parsed `kubectl get poddisruptionbudgets -A -o json`.
# Output: [ {severity:"critical", category:"pdb", kind:"PodDisruptionBudget",
#            namespace, name, reason:"PDBViolation", detail, ts:""} ].

def rubric_pdbs:
  (.items // [])
  | map(
      . as $p
      | if (($p.status.currentHealthy // 0) < ($p.status.desiredHealthy // 0))
        then { severity: "critical", category: "pdb",
               kind: "PodDisruptionBudget",
               namespace: $p.metadata.namespace, name: $p.metadata.name,
               reason: "PDBViolation",
               detail: "healthy=\($p.status.currentHealthy // 0)/\($p.status.desiredHealthy // 0)",
               ts: "" }
        else empty end
    );
