#!/usr/bin/env bash
# scripts/clean.sh — wipe repo-local install artifacts.
#
# For development. Removes the rendered skills directories, caches, and the
# legacy build dir from the kstack repo so you can re-run ./install against
# a clean tree.
#
# Safe to run any time. Only touches paths that are gitignored.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Paths the repo-local install (and older versions of it) can write into.
# Keep this list in sync with .gitignore.
PATHS="
  .claude
  .codex
  .config/opencode
  .cursor
  .factory
  .slate
  .kiro
  .hermes
  .cache
  .build
"

removed=0
for p in $PATHS; do
  full="$REPO_ROOT/$p"
  if [ -e "$full" ]; then
    rm -rf "$full"
    echo "removed $p"
    removed=$((removed + 1))
  fi
done

if [ "$removed" -eq 0 ]; then
  echo "Nothing to clean."
fi
