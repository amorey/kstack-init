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

# shellcheck shell=bash
# kstack installed-skills manifest — paired read/write helpers shared by
# scripts/install (write at install time, read for diff-based prune) and
# src/bin/uninstall (read to know which slots to delete).
#
# Format: one slot name per line, no header. Consumers treat blank lines
# as absent. Writers sort the output so diffs stay stable across installs.
#
# Source this file; do not execute it.

# manifest::path $root — absolute path of the manifest inside an install root.
manifest::path() { printf '%s\n' "$1/installed-skills"; }

# manifest::read $root — print each slot (one per line) to stdout. Silent
# when the manifest is missing so callers can treat it as an empty set.
manifest::read() {
  local f
  f="$(manifest::path "$1")"
  [ -f "$f" ] || return 0
  cat -- "$f"
}

# manifest::write $root $slot_names... — write one slot per line, sorted.
# Each argument is a single slot name (already-prefixed).
manifest::write() {
  local root="$1"; shift
  local slot
  for slot in "$@"; do
    [ -n "$slot" ] && printf '%s\n' "$slot"
  done | LC_ALL=C sort > "$(manifest::path "$root")"
}
