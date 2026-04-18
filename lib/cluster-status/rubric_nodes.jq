# rubric_nodes — one finding per distinct node problem.
#
# Input: parsed `kubectl get nodes -o json` (or {} on fetch failure).
# Output: [ {severity, category, kind, namespace, name, reason, detail, ts} ].
#   ts is an RFC3339 string (lastTransitionTime) or "" when unknown — the
#   top-level aggregator converts it to epoch seconds for --since filtering.

def _cond(conds; t): (conds // []) | map(select(.type == t)) | .[0];

def _role(labels):
  if   (labels["node-role.kubernetes.io/control-plane"] // null) != null
  then "control-plane"
  elif (labels["node-role.kubernetes.io/master"]        // null) != null
  then "control-plane"
  else "worker"
  end;

def _emit_node(sev; reason; detail; ts):
  { severity: sev, category: "node", kind: "Node",
    namespace: null, name: .metadata.name,
    reason: reason, detail: detail, ts: (ts // "") };

def rubric_nodes:
  (.items // [])
  | map(
      . as $node
      | ($node.status.conditions // []) as $conds
      | (_cond($conds; "Ready"))          as $ready
      | (_cond($conds; "MemoryPressure")) as $mem
      | (_cond($conds; "DiskPressure"))   as $disk
      | (_cond($conds; "PIDPressure"))    as $pid
      | [
          ( if ($ready.status // "Unknown") != "True"
            then $node | _emit_node("critical"; "NotReady";
              "Ready=\(($ready.status // "Unknown")) reason=\(($ready.reason // "-"))";
              $ready.lastTransitionTime)
            else empty end ),
          ( if ($mem.status // "False") == "True"
            then $node | _emit_node("warning"; "MemoryPressure"; "MemoryPressure=True"; $mem.lastTransitionTime)
            else empty end ),
          ( if ($disk.status // "False") == "True"
            then $node | _emit_node("warning"; "DiskPressure"; "DiskPressure=True"; $disk.lastTransitionTime)
            else empty end ),
          ( if ($pid.status // "False") == "True"
            then $node | _emit_node("warning"; "PIDPressure"; "PIDPressure=True"; $pid.lastTransitionTime)
            else empty end ),
          ( if ($node.spec.unschedulable // false) == true
            then $node | _emit_node("warning"; "Cordoned"; "spec.unschedulable=true"; "")
            else empty end )
        ]
    )
  | add // [];

# node_rows — always-emit table rows for the Nodes table (not filtered by
# severity). Returns one object per node with the shape used by render_prose.
def node_rows:
  (.items // [])
  | map(
      . as $n
      | ($n.status.conditions // []) as $c
      | { name: $n.metadata.name,
          role: (_role($n.metadata.labels // {})),
          mem:   (_cond($c; "MemoryPressure").status // "Unknown"),
          disk:  (_cond($c; "DiskPressure").status   // "Unknown"),
          pid:   (_cond($c; "PIDPressure").status    // "Unknown"),
          ready: (_cond($c; "Ready").status          // "Unknown"),
          schedulable: (($n.spec.unschedulable // false) | not) }
    );
