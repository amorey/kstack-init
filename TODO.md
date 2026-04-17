# kstack TODO

Overall plan from README-finished to v0.1.0 launch. Grouped by phase; within each phase items are roughly ordered.

## MISC

- [ ] Add a clean-up skill that removes all "kstack-managed" cluster resources

## Foundation

- [x] Scaffold repo layout — `.claude/skills/`, `bin/`, `skills/*/SKILL.md.tmpl`, document placeholder resolution convention
- [x] Build `install` script with multi-agent support — auto-detect + `--agent <name>` flag per README agent table (codex, opencode, cursor, factory, slate, kiro, hermes); supports repo-local and `--global` modes
- [x] Build `uninstall` script
- [x] Shared global flag handling — `--context`, `--namespace`, `--json`, `--dry-run` across every skill
- [x] Upgrade path — `git pull && ./install` (repo-local); `~/.config/kstack/bin/upgrade` wrapper and `curl | bash` bootstrap at `kubestack.xyz/install.sh` for global installs (tracks latest tag)
- [x] Update notifications — `bin/check-update` runs from skill preamble on each invocation (24h cache, both modes), `bin/dismiss-update` silences per-version, `bin/upgrade` mode-aware; all three agent-invoked, not user-facing

## Pilot skill + testing

- [ ] Scaffold `/cluster-status` as the pattern-setter for all other skills
- [ ] Build kind fixture harness — clusters with planted failures (crashloop pod, overbroad RBAC, missing NetworkPolicy, outdated image); runner invokes skills headlessly and asserts output mentions planted symptoms
- [ ] Write first eval scenario for `/cluster-status`
- [ ] CI — run evals and script tests on PRs

## Remaining skills

Priority: highest-value + simplest first.

- [ ] `/events` — Events API query with dedup and noisy-reason collapse; detect event exporter backends
- [ ] Enable remote grep in Kubetail CLI — `/logs` depends on this CLI surface
- [ ] `/logs` — shell out to kubetail for node-side regex filter
- [ ] `/investigate` — root-cause analysis with state-specific paths for Pending/CrashLoopBackOff/OOMKilled/ImagePullBackOff/Error
- [ ] `/watch` — detached watcher with state-hash filter; management via `--list`/`--stop`
- [ ] `/exec` — interactive exec + ephemeral debug container fallback for scratch/distroless
- [ ] `/audit-security` — RBAC, pod security, secrets; Kyverno/OPA/Falco integration; SARIF output
- [ ] `/audit-network` — NetworkPolicy, Service, Ingress, Gateway API, DNS, encryption; Cilium/Istio/Linkerd integration
- [ ] `/audit-cost` — requests vs usage; metrics-server + Prometheus/OpenCost integration
- [ ] `/audit-outdated` — version skew, image/chart freshness, CVE scan via Trivy, deprecated API detection

## Launch prep

- [ ] Add `CODE_OF_CONDUCT.md` — Contributor Covenant 2.1 (referenced in README badge)
- [ ] Add issue/PR templates and `CONTRIBUTING.md`
- [ ] Verify assets — confirm `assets/kstack.svg`; add social preview card
- [ ] Translate README into 7 languages — zh-CN, ja, ko, de, es, pt-BR, fr under `.github/`
- [ ] Verify external links — Discord, Slack, kubetail-org GitHub
- [ ] Tag `v0.1.0` and announce — release notes, Discord/Slack post

## Decisions locked in

- Pilot skill: `/cluster-status`
- Translations: done pre-launch (README already links them as if they exist)
- Kubetail remote grep: the Rust filter exists; work is enabling it in the Kubetail CLI
- Testing: kind fixtures + eval rubric, deferred until `/cluster-status` is scaffolded
