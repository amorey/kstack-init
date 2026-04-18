# shellcheck shell=bash
# kstack agent table — shared between install, uninstall, and test suite.
#
# Source this file; do not execute it.
# Requires $HOME to be set before agent_skills_dir_global is called.

KNOWN_AGENTS="claude codex opencode cursor factory slate kiro hermes"

# agent_cli: CLI binary to probe for auto-detect
agent_cli() {
  case "$1" in
    claude)   echo claude ;;
    codex)    echo codex ;;
    opencode) echo opencode ;;
    cursor)   echo cursor ;;
    factory)  echo droid ;;
    slate)    echo slate ;;
    kiro)     echo kiro-cli ;;
    hermes)   echo hermes ;;
    *)        return 1 ;;
  esac
}

# agent_skills_dir_global: where the agent reads skills from (user-level)
agent_skills_dir_global() {
  case "$1" in
    claude)   echo "$HOME/.claude/skills" ;;
    codex)    echo "$HOME/.codex/skills" ;;
    opencode) echo "$HOME/.config/opencode/skills" ;;
    cursor)   echo "$HOME/.cursor/skills" ;;
    factory)  echo "$HOME/.factory/skills" ;;
    slate)    echo "$HOME/.slate/skills" ;;
    kiro)     echo "$HOME/.kiro/skills" ;;
    hermes)   echo "$HOME/.hermes/skills" ;;
    *)        return 1 ;;
  esac
}

# agent_skills_dir_local: where the agent reads skills from (repo-level)
# Args: $1 = repo root, $2 = agent name
agent_skills_dir_local() {
  local root="$1"
  case "$2" in
    claude)   echo "$root/.claude/skills" ;;
    codex)    echo "$root/.codex/skills" ;;
    opencode) echo "$root/.config/opencode/skills" ;;
    cursor)   echo "$root/.cursor/skills" ;;
    factory)  echo "$root/.factory/skills" ;;
    slate)    echo "$root/.slate/skills" ;;
    kiro)     echo "$root/.kiro/skills" ;;
    hermes)   echo "$root/.hermes/skills" ;;
    *)        return 1 ;;
  esac
}

is_known_agent() {
  case " $KNOWN_AGENTS " in *" $1 "*) return 0 ;; esac
  return 1
}
