# kstack

*Skill pack for Claude Code that helps you monitor your K8s clusters superintelligently*

<a href="https://discord.gg/CmsmWAVkvX"><img src="https://img.shields.io/discord/1212031524216770650?logo=Discord&style=flat-square&logoColor=FFFFFF&labelColor=5B65F0&label=Discord&color=64B73A"></a>
[![Slack](https://img.shields.io/badge/Slack-kubetail-364954?logo=slack&labelColor=4D1C51)](https://kubernetes.slack.com/archives/C08SHG1GR37)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)
[![Contributor Resources](https://img.shields.io/badge/Contributor%20Resources-purple?style=flat-square)](https://github.com/kubetail-org)

English | [简体中文](.github/README.zh-CN.md) | [日本語](.github/README.ja.md) | [한국어](.github/README.ko.md) | [Deutsch](.github/README.de.md) | [Español](.github/README.es.md) | [Português](.github/README.pt-BR.md) | [Français](.github/README.fr.md)

## Introduction

**Kstack** is a skill pack for Claude Code that helps you perform monitoring, troubleshooting and auditing tasks on your K8s clusters in a smart, fast, and cost-effective way. Alongside standard tools like `kubectl`, kstack uses [`kubetail`](https://github.com/kubetail-org/kubetail) to process and filter node-level data at the source before sending it back to Claude for analysis. This makes monitoring with Claude faster and more token efficient. Kstack also detects the services running in your cluster and uses their specialized tooling when necessary (e.g. Argo, Cilium).

Once you install kstack you'll have access to a set of K8s commands inside Claude Code:

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

Our goal is to help bring the power of AI to K8s monitoring in a user-friendly and cost-effective way that keeps you in control. If you notice a bug or have a suggestion please create a GitHub Issue or send us an email (hello@kubetail.com)!

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

Kstack uses your local `kubeconfig` file for authentication so it will be able to perform any actions that you can with `kubectl`. If it runs into permissions problems, it will let you know.

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

## Uninstall

To uninstall kstack, run the `uninstall` script then delete the repo:

```console
git clone https://github.com/kubetail-org/kstack.git
./kstack/bin/uninstall
rm -rf kstack
```

## Reference

## Get Involved

At Kubetail, we're building the most **user-friendly**, **cost-effective**, and **secure** logging platform for Kubernetes and we'd love your contributions! Here's how you can help:

* UI/UX design
* React frontend development
* Reporting issues and suggesting features

Reach us at hello@kubetail.com, or join our [Discord server](https://discord.gg/CmsmWAVkvX) or [Slack channel](https://join.slack.com/t/kubetail/shared_invite/zt-2cq01cbm8-e1kbLT3EmcLPpHSeoFYm1w).
