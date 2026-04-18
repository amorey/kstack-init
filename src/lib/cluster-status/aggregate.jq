# aggregate — top-level orchestrator wiring rubrics + renderers.
#
# Invocation:
#   jq -L "$LIB_DIR" -n \
#      --slurpfile nodes     "$tmp/nodes.json" \
#      --slurpfile pods      "$tmp/pods.json" \
#      --slurpfile workloads "$tmp/workloads.json" \
#      --slurpfile pdbs      "$tmp/pdbs.json" \
#      --slurpfile errs      "$tmp/errors.json" \
#      --arg      context    "$CTX" \
#      --arg      namespace  "$NS" \
#      --arg      severity   "$SEV" \
#      --arg      now        "$NOW" \
#      --argjson  since_secs $SINCE \
#      --arg      mode       "prose|json" \
#      -f aggregate.jq
#
# Output: a string (prose) or a JSON object (--json), ready to print verbatim.

include "rubric_nodes";
include "rubric_pods";
include "rubric_workloads";
include "rubric_pdbs";
include "render_prose";
include "render_json";

def _sev_rank: {critical: 0, warning: 1, info: 2};

def _pass_severity($min):
  if $min == "" then true
  else (_sev_rank[.severity] // 3) <= (_sev_rank[$min] // 3) end;

# _ts_epoch — convert the rubric-emitted ts to seconds-since-epoch. Empty
# timestamp returns null so --since filters treat the finding as ageless.
def _ts_epoch:
  if . == null or . == "" then null
  else (try (. | fromdateiso8601) catch null) end;

def _pass_since($now_secs; $since_secs):
  if $since_secs == 0 then true
  else (.ts | _ts_epoch) as $t
       | if $t == null then true
         else ($now_secs - $t) <= $since_secs end
  end;

def _build:
  ($nodes[0]     // {}) as $n_raw
  | ($pods[0]    // {}) as $p_raw
  | ($workloads[0] // {}) as $w_raw
  | ($pdbs[0]    // {}) as $d_raw
  | ($errs[0]    // []) as $e
  | ($now | fromdateiso8601) as $now_secs
  | ( ($n_raw | rubric_nodes)
    + ($p_raw | rubric_pods($now))
    + ($w_raw | rubric_workloads)
    + ($d_raw | rubric_pdbs)
    ) as $all
  | ( $all
      | map(select(_pass_severity($severity)))
      | map(select(_pass_since($now_secs; $since_secs)))
    ) as $keep
  | { context:    $context,
      namespace:  $namespace,
      checked_at: $now,
      node_rows:  ($n_raw | node_rows),
      pod_phases: ($p_raw | pod_phase_counts),
      findings:   $keep,
      summary: {
        critical: ($keep | map(select(.severity == "critical")) | length),
        warning:  ($keep | map(select(.severity == "warning"))  | length),
        info:     ($keep | map(select(.severity == "info"))     | length)
      },
      errors: $e };

_build
| if $mode == "json" then render_json
  else render_prose end
