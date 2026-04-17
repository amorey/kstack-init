# kstack

**Kstack is a skill pack for Claude that helps you monitor K8s superintelligently**

<a href="https://discord.gg/CmsmWAVkvX"><img src="https://img.shields.io/discord/1212031524216770650?logo=Discord&style=flat-square&logoColor=FFFFFF&labelColor=5B65F0&label=Discord&color=64B73A"></a>
[![Slack](https://img.shields.io/badge/Slack-kubetail-364954?logo=slack&labelColor=4D1C51)](https://kubernetes.slack.com/archives/C08SHG1GR37)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)
[![Contributor Resources](https://img.shields.io/badge/Contributor%20Resources-purple?style=flat-square)](https://github.com/kubetail-org)

English | [简体中文](.github/README.zh-CN.md) | [日本語](.github/README.ja.md) | [한국어](.github/README.ko.md) | [Deutsch](.github/README.de.md) | [Español](.github/README.es.md) | [Português](.github/README.pt-BR.md) | [Français](.github/README.fr.md)

## Introduction

**Kstack** is a skill pack for Claude that helps you to perform monitoring and troubleshooting tasks on your K8s cluster in a smart, fast and cost effective way. In addition to using tools like `kubectl` and `aws`, kstack also uses [`kubetail`](https://github.com/kubetail-org/kubetail) to process and filter node-level data at the source before sending it back to Claude for analysis. Once you install kstack you'll have access to several K8s-related commands you can use inside Claude Code. Here are some common commands:

* `/health` - Perform a global health check (e.g. restarts, cpu, memory, disk)
* `/security-check` - Look at RBAC permissions and make privilege tightening suggestions
* `/network-check` - Look at `NetworkPolicy` and `Service` resources and make suggestions
* `/logs` - Fetch container logs with remote-grep capability

Our goal is to help bring the power of AI to K8s monitoring in a fun, cost-effective way that keeps you in control. If you notice a bug or have a suggestion please create a GitHub Issue or send us an email (hello@kubetail.com)!

## Quickstart

To install kstack, just clone the repo into your skills directory and run the `setup` script:

```console
cd ~/.claude/skills
git clone https://github.com/kubetail-org/kstack.git
cd kstack && ./setup
```

Alternatively you can open a Claude Code session and paste in this prompt:

```console
Install kstack: run `git clone --single-branch --depth https://github.com/kubetail-org/kstack.git` ~/.claude/skills/kstack && cd ~/.claude/skills/kstack && ./setup`
```

## Other AI Agents

Kstack works with all AI coding agents that support skills, not just Claude. The `setup` script auto-detects which
agents you have installed:

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

## Privacy and Telemetry

Kstack doesn't collect any telemetry information. To help us improve the project your feedback is very welcome.

## Reference

## Get Involved

At Kubetail, we're building the most **user-friendly**, **cost-effective**, and **secure** logging platform for Kubernetes and we'd love your contributions! Here's how you can help:

* UI/UX design
* React frontend development
* Reporting issues and suggesting features

Reach us at hello@kubetail.com, or join our [Discord server](https://discord.gg/CmsmWAVkvX) or [Slack channel](https://join.slack.com/t/kubetail/shared_invite/zt-2cq01cbm8-e1kbLT3EmcLPpHSeoFYm1w).
