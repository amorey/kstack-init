# render_json — pass-through serializer for --json mode.
#
# Input is the normalized intermediate object produced by aggregate.jq.
# Output is the exact schema documented in skills/cluster-status/SKILL.md.tmpl:
#   context, namespace, checked_at, summary, pod_phases, findings[], errors[].

def render_json:
  { context:     .context,
    namespace:   (if .namespace == "" then null else .namespace end),
    checked_at:  .checked_at,
    summary:     .summary,
    pod_phases:  .pod_phases,
    findings: (.findings
                | map({
                    severity: .severity,
                    category: .category,
                    kind:     .kind,
                    namespace: (if .namespace == "" or .namespace == null
                                then null else .namespace end),
                    name:     .name,
                    reason:   .reason,
                    detail:   .detail
                  })),
    errors:      .errors };
