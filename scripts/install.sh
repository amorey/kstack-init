#!/usr/bin/env bash
# kstack bootstrap — hosted at https://www.kubestack.xyz/install.sh
#
# Intended for use via:
#
#     curl -sS https://www.kubestack.xyz/install.sh | bash
#
# Resolves the latest tagged release of kstack, clones (or updates) a
# kstack-owned checkout at ~/.config/kstack/src/, then hands off to the
# real installer in that checkout. All substantive logic lives in the
# in-repo `install` script — this bootstrap is just a getter.
#
# This script is duplicated verbatim in the kubetail-website repo's
# static assets. When editing this file, update both copies.
set -eu

REPO="kubetail-org/kstack"
SRC_DIR="$HOME/.config/kstack/src"

main() {
  TAG=$(curl -sS "https://api.github.com/repos/$REPO/releases/latest" \
          | grep -o '"tag_name":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
  [ -n "$TAG" ] || { echo "Could not resolve latest kstack release." >&2; exit 1; }

  if [ -d "$SRC_DIR/.git" ]; then
    git -C "$SRC_DIR" fetch --tags --quiet
    git -C "$SRC_DIR" checkout --quiet "$TAG"
  else
    mkdir -p "$(dirname "$SRC_DIR")"
    git clone --depth 1 --branch "$TAG" --quiet "https://github.com/$REPO.git" "$SRC_DIR"
  fi

  exec "$SRC_DIR/install" --global "$@"
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  main "$@"
fi
