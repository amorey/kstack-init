# kstack

*Skill pack for Claude Code that helps you monitor your K8s clusters superintelligently*

<img width="350" alt="kstack" src="assets/kstack.svg" />

<a href="https://discord.gg/CmsmWAVkvX"><img src="https://img.shields.io/discord/1212031524216770650?logo=Discord&style=flat-square&logoColor=FFFFFF&labelColor=5B65F0&label=Discord&color=64B73A"></a>
[![Slack](https://img.shields.io/badge/Slack-kubetail-364954?logo=slack&labelColor=4D1C51)](https://kubernetes.slack.com/archives/C08SHG1GR37)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)
[![Contributor Resources](https://img.shields.io/badge/Contributor%20Resources-purple?style=flat-square)](https://github.com/kubetail-org)

English | [简体中文](.github/README.zh-CN.md) | [日本語](.github/README.ja.md) | [한국어](.github/README.ko.md) | [Deutsch](.github/README.de.md) | [Español](.github/README.es.md) | [Português](.github/README.pt-BR.md) | [Français](.github/README.fr.md)

## Introduction

**Kstack** is a skill pack for Claude Code that helps you perform monitoring, troubleshooting and auditing tasks on your K8s clusters in a smart, fast, and cost-effective way. Alongside standard tools like `kubectl`, kstack uses [`kubetail`](https://github.com/kubetail-org/kubetail) to process node-level data at the source before sending it back to Claude for analysis. This makes monitoring with Claude faster and more token efficient. Kstack also detects the services running in your cluster and uses their specialized tooling when necessary (e.g. Argo, Cilium).

Once you install kstack you'll have access to these K8s commands inside Claude Code:

**Monitoring**
* `/cluster-status` — Health snapshot (pod restarts, node conditions, resource pressure)
* `/events` — Recent events, ranked by severity
* `/watch <resource>` — Background watcher (pings Claude only on state changes)

**Troubleshooting**
* `/investigate <resource>` — Root-cause analysis across events, logs, and related resources
* `/exec <pod>` — Guided shell with diagnostics preloaded; ephemeral debug container for scratch/distroless
* `/logs` — Fetch container logs with remote grep via kubetail

**Audits**
* `/audit-security` — RBAC, pod security posture, privilege tightening
* `/audit-network` — NetworkPolicy, Service, Ingress, GatewayAPI, DNS and encryption checks
* `/audit-cost` — Requests vs. usage, over-provisioning, idle capacity
* `/audit-outdated` — Outdated services, known CVEs, available version bumps

Our goal is to bring the power of AI to K8s monitoring in a user-friendly and cost-effective way that keeps you in control. If you notice a bug or have a suggestion please create a GitHub Issue or send us an email (hello@kubetail.com)!

## Quickstart

To use kstack just clone this repo and open a Claude Code session inside the repo directory:

```console
git clone https://github.com/kubetail-org/kstack.git
cd kstack && claude
```

The repo already has the kstack skills installed (in `.claude/skills`) so you can start using them right away:

```console
──────────────────────────────────────────────────
> /cluster-status
──────────────────────────────────────────────────
```

Kstack uses your local `kubeconfig` file for authentication so it will be able to use your RBAC permissions to perform actions on your behalf. If it runs into permissions problems, it will let you know.

To install kstack globally, clone the repo into your user-level skills directory and run the `setup` script to symlink the skill set:

```console
cd ~/.claude/skills
git clone https://github.com/kubetail-org/kstack.git
cd kstack && ./setup
```

Alternatively, you can open a Claude Code session and paste in this prompt:

```console
Install kstack: run `git clone --single-branch --depth https://github.com/kubetail-org/kstack.git` ~/.claude/skills/kstack && cd ~/.claude/skills/kstack && ./setup`
```

After installing kstack globally you'll be able to use the skills from inside any project.

## Other AI Agents

Kstack can work with any AI agent that support skills, not just Claude. To install kstack in your other AI agents just run the `setup` script manually and it will auto-detect which agents you have installed:

```console
git clone https://github.com/kubetail-org/kstack.git
cd kstack && ./setup
```

Or target a specific agent with `./setup --host <name>`:

| Agent            | Flag              | Skills install to                     |
|------------------|-------------------|---------------------------------------|
| OpenAI Codex CLI | `--host codex`    | `~/.codex/skills/kstack-*/`           |
| OpenCode         | `--host opencode` | `~/.config/opencode/skills/kstack-*/` |
| Cursor           | `--host cursor`   | `~/.cursor/skills/kstack-*/`          |
| Factory Droid    | `--host factory`  | `~/.factory/skills/kstack-*/`         |
| Slate            | `--host slate`    | `~/.slate/skills/kstack-*/`           |
| Kiro             | `--host kiro`     | `~/.kiro/skills/kstack-*/`            |
| Hermes           | `--host hermes`   | `~/.hermes/skills/kstack-*/`          |

## Skill Reference

Each skill is invoked with `/<name>` inside a Claude Code session. All skills are read-only by default — any action that mutates cluster state requires explicit confirmation. Skills honor your local `kubeconfig` context and respect RBAC.

**Global flags** (supported by every skill):

| Flag              | Description                                                              |
|-------------------|--------------------------------------------------------------------------|
| `--context <ctx>` | Override the current kubeconfig context                                  |
| `--namespace <n>` | Scope the run to a single namespace (defaults to all accessible)         |
| `--json`          | Emit structured output for piping into other tools                       |
| `--dry-run`       | Print the commands kstack would run without executing them               |

---

### Monitoring

<dl>
<dt>

#### `/cluster-status`

</dt>
<dd>

Health snapshot across the entire cluster.

**What it checks:** pod phase distribution, restart counts, node `Ready`/`MemoryPressure`/`DiskPressure`/`PIDPressure` conditions, unschedulable pods, workload replica drift (desired vs. ready), and PDB violations.

**How it works:** a single fan-out of `kubectl get` calls with server-side field selectors, aggregated client-side. Summarization is delta-aware — on repeat runs, Claude highlights what changed rather than reprinting the full snapshot.

**Options:**
- `--since <duration>` — only flag issues that appeared in the last N minutes (e.g. `--since 15m`)
- `--severity <level>` — filter output to `critical`, `warning`, or `info`

</dd>
<dt>

#### `/events`

</dt>
<dd>

Recent cluster events, ranked by severity and deduplicated.

**What it checks:** `Warning` and `Normal` events from the Events API, grouped by `(reason, involvedObject.kind, namespace)` with occurrence counts. Noisy reasons (`Pulled`, `Created`, `Started`) are collapsed.

**How it works:** pulls from the `events.k8s.io/v1` API with server-side sorting by `lastTimestamp`. For clusters with an events exporter (e.g. kubernetes-event-exporter, Loki), `/events` detects and queries the backend instead of the short-lived in-cluster store.

**Options:**
- `--since <duration>` — window size (default `1h`)
- `--reason <regex>` — restrict to matching reasons
- `--object <kind/name>` — narrow to a single resource's event stream

</dd>
<dt>

#### `/watch <resource>`

</dt>
<dd>

Long-running background watcher that pings Claude only when state changes.

**What it does:** starts a detached watcher (shell loop + filter script) that streams `kubectl get --watch` for the target resource. The filter compares each update to the previous state hash and only notifies Claude on meaningful changes: phase transitions, restart count increments, replica drift, new `Warning` events, node condition flips.

**Why it's cheap:** while the resource stays healthy, the model isn't in the loop — idle token cost is effectively zero. Claude only enters the conversation when the filter fires.

**Arguments:**
- `<resource>` — any of `pod/<name>`, `deployment/<name>`, `node/<name>`, `namespace/<ns>`, or `cluster` for cluster-wide

**Options:**
- `--for <duration>` — auto-stop after N (default: until user cancels)
- `--threshold <level>` — minimum severity to ping on (default `warning`)
- `--quiet` — suppress heartbeat pings; only notify on anomalies
- `--list` / `--stop <id>` — manage active watchers

</dd>
</dl>

---

### Troubleshooting

<dl>
<dt>

#### `/investigate <resource>`

</dt>
<dd>

Root-cause analysis for a failing or suspicious resource.

**What it does:** gathers the resource spec, current + previous container statuses, recent events for the object and its owners, logs from failed/previous containers, related resources (ConfigMaps, Secrets, PVCs, Services, NetworkPolicies), and the last N changes from the revision history. Correlates signals into a ranked list of likely causes.

**Special cases:** for pods in `Pending`, `CrashLoopBackOff`, `OOMKilled`, `ImagePullBackOff`, or `Error` states, the skill jumps straight to the state-specific diagnostic path (node capacity + taints for Pending, prior-instance logs for CrashLoop, memory limits + workingset for OOM, image registry auth for ImagePull).

**Arguments:**
- `<resource>` — `<kind>/<name>` (e.g. `pod/api-7d9`, `deployment/web`, `ingress/public`)

**Options:**
- `--depth <n>` — how many hops of related resources to follow (default `2`)
- `--since <duration>` — log/event lookback window (default `1h`)
- `--compare <revision>` — diff current state against a prior revision

</dd>
<dt>

#### `/exec <pod>`

</dt>
<dd>

Guided shell into a pod's container with diagnostics pre-loaded.

**What it does:** opens an interactive `kubectl exec` session. Before handing you the prompt, Claude runs a lightweight probe (`ls /bin/sh`, env dump, DNS resolution of in-cluster services) and reports what's available. A history of common diagnostics (`nslookup`, `curl` to service endpoints, `env | grep`, `cat /proc/1/status`) is primed so you can recall with arrow-up.

**Scratch/distroless fallback:** if the target container has no shell, kstack transparently switches to `kubectl debug --target=<container> --image=<toolbox>` (default toolbox: `nicolaka/netshoot` for network issues, `busybox` otherwise). The debug container shares the target's PID namespace, so `/proc/1/root` gives you the scratch container's filesystem.

**Arguments:**
- `<pod>` — pod name, optionally `<pod>/<container>`

**Options:**
- `--toolbox <image>` — override the debug container image
- `--copy-to <name>` — clone the pod (useful when the original is crashlooping)
- `--node` — drop to a shell on the pod's *node* instead of the container

</dd>
<dt>

#### `/logs`

</dt>
<dd>

Fetch and filter container logs with kubetail's remote grep feature.

**Why it matters:** `kubectl logs` streams the entire log to the client before you can filter it — on chatty services this is both slow and an expensive number of tokens to hand to Claude. Kstack routes through [`kubetail`](https://github.com/kubetail-org/kubetail), which runs a Rust-powered regex filter on the node where the log lives and only sends matching lines back. This can reduce transferred data dramatically.

**Arguments (all optional, composable):**
- `--selector <label>` — label selector across pods (e.g. `app=api`)
- `--pod <name>` / `--container <name>` — narrow scope
- `--grep <regex>` — node-side filter (required for large log volumes)
- `--since <duration>` — lookback window (default `15m`)
- `--tail <n>` — last N lines
- `--follow` — stream new matches as they arrive
- `--level <level>` — shorthand for common log-level regexes (`error`, `warn`, `info`)

</dd>
</dl>

---

### Audits

All audit skills produce a ranked findings list (severity + evidence + suggested fix) and can emit SARIF via `--format sarif` for CI integration.

<dl>
<dt>

#### `/audit-security`

</dt>
<dd>

RBAC review, pod security posture, and privilege-tightening recommendations.

**What it checks:**
- **RBAC:** overly broad ClusterRoles, `*` verbs, wildcard resource access, service accounts with cluster-admin, unbound roles, stale bindings to deleted principals
- **Pod security:** containers running as root, missing `securityContext`, privileged containers, `hostNetwork`/`hostPID`/`hostIPC`, writable root FS, dangerous capabilities (`CAP_SYS_ADMIN`, `CAP_NET_ADMIN`), missing `seccompProfile`
- **Secrets:** secrets mounted but unused, secrets referenced in env vars (vs. mounted files), unencrypted etcd (when detectable)

**Detected integrations:** Kyverno, OPA/Gatekeeper, Falco — surfaces existing policy violations instead of re-scanning.

**Options:**
- `--standard <ps>` — Pod Security Standard level (`privileged`, `baseline`, `restricted`)
- `--fix` — emit patched manifests alongside findings

</dd>
<dt>

#### `/audit-network`

</dt>
<dd>

NetworkPolicy, Service, Ingress, Gateway API, DNS, and encryption sanity checks.

**What it checks:**
- **NetworkPolicies:** namespaces with no default-deny, pods matched by zero policies, policies referencing nonexistent labels, redundant/shadowed rules
- **Services:** Services with no matching endpoints, selectors that hit zero pods, ports mismatched with pod `containerPort`, headless services without StatefulSet
- **Ingress / Gateway API:** hostname collisions, missing TLS, unreferenced certs, backends pointing at missing services
- **DNS:** CoreDNS health, NXDOMAIN rates, stub domains, custom `resolv.conf` drift
- **Encryption:** mTLS coverage when a service mesh is detected (Istio, Linkerd, Cilium)

**Detected integrations:** Cilium (Hubble flow data), Istio, Linkerd.

**Options:**
- `--graph` — emit a Graphviz/Mermaid diagram of service connectivity
- `--probe` — actively test reachability between labeled pods (read-only traffic)

</dd>
<dt>

#### `/audit-cost`

</dt>
<dd>

Resource waste and right-sizing recommendations.

**What it checks:** requests vs. p95 actual usage (7-day window), workloads with no `resources.requests`, idle nodes, PVCs with zero read/write activity, over-provisioned HPAs (min=max), LoadBalancer services with no traffic, unused PVs.

**Data sources:** metrics-server for short-window data; if Prometheus/VictoriaMetrics is detected, pulls a longer history. If [OpenCost](https://www.opencost.io/) is installed, findings include dollar estimates.

**Options:**
- `--window <duration>` — lookback for usage stats (default `7d`)
- `--min-savings <usd>` — suppress findings below a dollar threshold (requires OpenCost)
- `--namespace <n>` — scope to one namespace for team-level reports

</dd>
<dt>

#### `/audit-outdated`

</dt>
<dd>

Outdated cluster components, known CVEs, and available version bumps.

**What it checks:**
- **Kubernetes itself:** control-plane and node versions vs. latest stable/LTS, version skew across components, end-of-support dates
- **Workloads:** container image tags vs. latest upstream, digest freshness, Helm releases with newer chart versions available, operators/CRDs behind their controller versions
- **Known vulnerabilities:** cross-references running images against CVE feeds (Trivy DB by default, Grype optional); correlates CVEs to actually-reachable code paths when an SBOM is available
- **Deprecated APIs:** manifests using API versions that are deprecated or removed in the next K8s minor

**Data sources:** GitHub/GHCR/quay.io for upstream versions, Trivy DB for CVEs, Helm repo indexes for chart versions, the cluster's own Discovery API for deprecated-API usage.

**Options:**
- `--severity <level>` — minimum CVE severity to report (`low`, `medium`, `high`, `critical`)
- `--target-version <ver>` — "if I upgraded to K8s X.Y, what would break?" mode
- `--include-prereleases` — surface alpha/beta upstream versions
- `--fix` — emit updated manifests/values files with new versions pinned

</dd>
</dl>

## Uninstall

To uninstall kstack, run the `uninstall` script then delete the repo:

```console
git clone https://github.com/kubetail-org/kstack.git
./kstack/bin/uninstall
rm -rf kstack
```

## Get Involved

At Kubetail, we're building the most **user-friendly**, **cost-effective**, and **secure** logging platform for Kubernetes and we'd love your contributions! Here's how you can help:

* UI/UX design
* React frontend development
* Reporting issues and suggesting features

Reach us at hello@kubetail.com, or join our [Discord server](https://discord.gg/CmsmWAVkvX) or [Slack channel](https://join.slack.com/t/kubetail/shared_invite/zt-2cq01cbm8-e1kbLT3EmcLPpHSeoFYm1w).

## Notes

* Thank you to Garry Tan's [gstack](https://github.com/garrytan/gstack) 
* Made with 🧿 in Istanbul
