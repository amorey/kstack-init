# render_prose — Markdown pipe-table output.
#
# Input is the normalized intermediate produced by aggregate.jq. Output is a
# single string — stdout is emitted verbatim by the skill body. Structure:
#   1. Headline with counts + scope
#   2. Nodes table (always)
#   3. Workloads table (skipped when empty)
#   4. PDBs table (skipped when empty)
#   5. Pod phase summary line
#   6. Next-step hint (for highest-severity finding)
#   7. Errors block (only when errors[] non-empty)

def _glyph($status):
  if   $status == "True"  then "✓"
  elif $status == "False" then "✗"
  else "—" end;

# Healthy = pressures False AND Ready True. Pressures "Unknown" treated as
# non-healthy so we display "—" and the node row falls out as worth reading.
def _node_mem($r):    if $r.mem    == "False" then "✓" elif $r.mem    == "True"  then "✗" else "—" end;
def _node_disk($r):   if $r.disk   == "False" then "✓" elif $r.disk   == "True"  then "✗" else "—" end;
def _node_pid($r):    if $r.pid    == "False" then "✓" elif $r.pid    == "True"  then "✗" else "—" end;
def _node_ready($r):  if $r.ready  == "True"  then "✓" elif $r.ready  == "False" then "✗" else "—" end;
def _node_sched($r):  if $r.schedulable       then "✓" else "✗" end;

def _sev_rank: {critical: 0, warning: 1, info: 2};

def _sort_findings:
  sort_by([(_sev_rank[.severity] // 3), (.namespace // ""), .name]);

def _headline:
  . as $r
  | ($r.summary.critical + $r.summary.warning + $r.summary.info) as $n
  | "\($n) findings — \($r.summary.critical) critical, \($r.summary.warning) warning, \($r.summary.info) info"
  + " · context=\(if $r.context == "" then "(current)" else $r.context end)"
  + " · namespace=\(if $r.namespace == "" then "all" else $r.namespace end)";

def _node_table:
  . as $r
  | "## Nodes (\($r.node_rows | length))\n"
    + "| Node | Role | MemPressure | DiskPressure | PIDPressure | Ready | Schedulable | Notes |\n"
    + "|------|------|-------------|--------------|-------------|-------|-------------|-------|\n"
    + ( $r.node_rows
        | map(
            . as $row
            | ( $r.findings
                | map(select(.category == "node" and .name == $row.name))
                | _sort_findings | .[0] ) as $top
            | ($top | if . == null then "" else "\(.severity): \(.reason)" end) as $notes
            | "| \($row.name) | \($row.role) | \(_node_mem($row)) | \(_node_disk($row)) | \(_node_pid($row)) | \(_node_ready($row)) | \(_node_sched($row)) | \($notes) |"
          )
        | join("\n") )
    + "\n";

def _workload_table:
  . as $r
  | ( $r.findings
      | map(select(.category == "pod" or .category == "workload"))
      | _sort_findings ) as $rows
  | if ($rows | length) == 0 then ""
    else
      "\n## Workloads (\($rows | length))\n"
      + "| Severity | Kind | Namespace | Name | Reason | Detail |\n"
      + "|----------|------|-----------|------|--------|--------|\n"
      + ( $rows
          | map("| \(.severity) | \(.kind) | \(.namespace // "—") | \(.name) | \(.reason) | \(.detail) |")
          | join("\n") )
      + "\n"
    end;

def _pdb_table:
  . as $r
  | ( $r.findings
      | map(select(.category == "pdb"))
      | _sort_findings ) as $rows
  | if ($rows | length) == 0 then ""
    else
      "\n## PDBs (\($rows | length))\n"
      + "| Namespace | Name | Reason | Detail |\n"
      + "|-----------|------|--------|--------|\n"
      + ( $rows
          | map("| \(.namespace) | \(.name) | \(.reason) | \(.detail) |")
          | join("\n") )
      + "\n"
    end;

def _phase_line:
  . as $r
  | ( ["Running","Pending","Succeeded","Failed","Unknown"]
      | map(. as $k | ($r.pod_phases[$k] // 0) | . as $v
                     | if $v > 0 then "\($v) \($k)" else empty end) ) as $parts
  | if ($parts | length) == 0 then ""
    else "\nPods: " + ($parts | join(" · ")) + "\n" end;

def _next_hint:
  . as $r
  | ( $r.findings | _sort_findings | .[0] ) as $top
  | if $top == null then ""
    elif $top.category == "node" then
      "→ /investigate node/\($top.name)\n"
    elif $top.namespace == null or $top.namespace == "" then
      "→ /investigate \($top.kind | ascii_downcase)/\($top.name)\n"
    else
      "→ /investigate \($top.kind | ascii_downcase)/\($top.namespace)/\($top.name)\n"
    end;

def _errors:
  . as $r
  | if ($r.errors | length) == 0 then ""
    else
      "\nErrors:\n"
      + ( $r.errors
          | map("- \(.call): rc=\(.rc) \(.stderr // "" | gsub("\n"; " "))")
          | join("\n") )
      + "\n"
    end;

def render_prose:
  (_headline)
  + "\n\n" + _node_table
  + _workload_table
  + _pdb_table
  + _phase_line
  + _next_hint
  + _errors;
