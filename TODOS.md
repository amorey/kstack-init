# TODOS

## /aggregate-log-errors skill
**What:** Build the second Kstack skill that uses Kubetail cluster-agent for cross-pod log aggregation.
**Why:** This is the moat skill. Raw kubectl can't aggregate logs across pods. Kubetail can. Differentiates Kstack from anyone else wrapping kubectl.
**Context:** Design doc has the full spec at `~/.gstack/projects/kstack/andres-unknown-design-20260416-125235.md` (time window, division of labor, dependency matrix). The SKILL.md should follow the same scripted-with-escape-hatches pattern as /top.
**Blocked on:** Documenting the exact Kubetail CLI commands for log aggregation (what command aggregates logs across pods? Does it require port-forwarding to the cluster-agent API?).
**Depends on:** Kubetail CLI interface documentation.

## Kind-based acceptance test suite
**What:** Shell script that creates a kind cluster with known problems (CrashLoopBackOff, OOMKilled, pending pods), runs /top, and verifies output contains expected diagnostic keywords.
**Why:** As more skills are added, manual testing on production won't scale. Need regression tests that can run in CI.
**Context:** Phase 1 uses manual testing on real clusters. This becomes important at 3+ skills. Test plan at `~/.gstack/projects/kstack/andres-unknown-eng-review-test-plan-20260416-135343.md`.
**Depends on:** /top skill being built and working.

## Multi-cluster support
**What:** Accept an optional cluster context argument so users can check different clusters without switching kubectl context (e.g., `/top --context=prod-eks`).
**Why:** Teams with staging + production clusters will want to check both without context-switching.
**Context:** Phase 1 uses current kubectl context. Add `--context` flag to kubectl commands in the SKILL.md when this is implemented.
**Depends on:** /top skill being built.
