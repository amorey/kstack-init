#!/usr/bin/env bash

# Copyright 2026 The Kubetail Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# kstack bootstrap — hosted at https://www.kubestack.xyz/install.sh
#
# Intended for use via:
#
#     curl -sS https://www.kubestack.xyz/install.sh | bash
#
# Resolves the latest tagged release of kstack, clones (or updates) a
# kstack-owned checkout at ~/.config/kstack/upstream/, then hands off to
# the in-repo `install` wrapper in that checkout. All substantive logic
# lives in the in-repo install scripts — this bootstrap is just a getter.
#
# This script is duplicated verbatim in the kubetail-website repo's
# static assets. When editing this file, update both copies.
set -eu

REPO="kubetail-org/kstack"
UPSTREAM_DIR="$HOME/.config/kstack/upstream"
LEGACY_DIR="$HOME/.config/kstack/src"

main() {
  TAG=$(curl -sS "https://api.github.com/repos/$REPO/releases/latest" \
          | grep -o '"tag_name":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
  [ -n "$TAG" ] || { echo "Could not resolve latest kstack release." >&2; exit 1; }

  # One-time migration: legacy layout used ~/.config/kstack/src/ as the
  # clone target; the repo now carries its own src/ subdir, so the clone
  # moved to upstream/ to avoid the src/src/ collision.
  if [ -d "$LEGACY_DIR/.git" ] && [ ! -d "$UPSTREAM_DIR/.git" ]; then
    rm -rf "$LEGACY_DIR"
  fi

  if [ -d "$UPSTREAM_DIR/.git" ]; then
    git -C "$UPSTREAM_DIR" fetch --tags --quiet
    git -C "$UPSTREAM_DIR" checkout --quiet "$TAG"
  else
    mkdir -p "$(dirname "$UPSTREAM_DIR")"
    git clone --depth 1 --branch "$TAG" --quiet "https://github.com/$REPO.git" "$UPSTREAM_DIR"
  fi

  exec "$UPSTREAM_DIR/install" --global "$@"
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  main "$@"
fi
