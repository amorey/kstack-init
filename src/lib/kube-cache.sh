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
# shellcheck disable=SC2034  # KUBE_CACHE_* vars are read by the caller and by later kube_cache calls.

# kube-cache.sh — shared kubectl snapshot cache.
#
# Sourced (not executed) by skills that want to read cluster-wide state from
# a TTL-bounded on-disk snapshot. /cluster-status and /audit-* share the same
# per-context cache directory, so running them back-to-back inside the TTL
# window costs zero extra kubectl calls. Targeted skills like /investigate
# bypass this lib and talk to kubectl directly.
#
# Layout (under $KSTACK_ROOT):
#   cache/kube/<context-sha>/cluster.json   # kubectl version -o json
#   cache/kube/<context-sha>/nodes.json     # kubectl get nodes -o json
#   cache/kube/<context-sha>/pods.json      # kubectl get pods -o json --all-namespaces
#   cache/kube/<context-sha>/...            # one file per resource kind
#
# Usage:
#   . "$KSTACK_ROOT/lib/kube-cache.sh"
#   if ! kube_cache::init --context="$ctx" --ttl=15m; then
#     response::"${KUBE_CACHE_ERROR_KIND}_error" "$KUBE_CACHE_ERROR"; exit 0
#   fi
#   kube_cache::ensure_version            || response::infra_error "…"
#   kube_cache::ensure_list nodes         || response::infra_error "…"
#   kube_cache::ensure_list pods --all-namespaces
#
# Requires $KSTACK_ROOT. init sets KUBE_CACHE_ERROR + KUBE_CACHE_ERROR_KIND
# (user|infra) on failure; ensure_* return non-zero on kubectl failure
# without touching those globals.

# _kube_cache::context_sha <value>
#   12-char sha256 prefix of <value>. Falls back to a sanitized 40-char
#   truncation when neither sha256sum nor shasum is on PATH — keeps the tool
#   usable in minimal environments at the cost of longer cache-dir names.
_kube_cache::context_sha() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print substr($1,1,12)}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | awk '{print substr($1,1,12)}'
  else
    printf '%s' "$1" | tr -c 'A-Za-z0-9' _ | cut -c1-40
  fi
}

# _kube_cache::parse_ttl_seconds <duration>
#   Parse "30s" / "15m" / "2h" / "1d" into integer seconds on stdout.
#   Returns 1 on malformed input. The `[ "$n" -eq "$n" ]` check errors on
#   any non-integer, guarding against inputs like "1.5h" or "abcm".
_kube_cache::parse_ttl_seconds() {
  local v="$1" n=""
  case "$v" in
    *s) n="${v%s}"; [ -n "$n" ] && [ "$n" -eq "$n" ] 2>/dev/null && printf '%d\n' "$n" && return 0 ;;
    *m) n="${v%m}"; [ -n "$n" ] && [ "$n" -eq "$n" ] 2>/dev/null && printf '%d\n' "$(( n * 60 ))" && return 0 ;;
    *h) n="${v%h}"; [ -n "$n" ] && [ "$n" -eq "$n" ] 2>/dev/null && printf '%d\n' "$(( n * 3600 ))" && return 0 ;;
    *d) n="${v%d}"; [ -n "$n" ] && [ "$n" -eq "$n" ] 2>/dev/null && printf '%d\n' "$(( n * 86400 ))" && return 0 ;;
  esac
  return 1
}

# _kube_cache::mtime <file>
#   Portable mtime (GNU `stat -c` / BSD `stat -f` fallback).
_kube_cache::mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

# _kube_cache::is_fresh <file> <ttl_secs>
#   True iff <file> exists and its mtime is within <ttl_secs> of now.
#   ttl_secs=0 is always stale — the way callers force a refetch.
_kube_cache::is_fresh() {
  local file="$1" ttl="$2" mt now
  [ -f "$file" ] || return 1
  mt="$(_kube_cache::mtime "$file")" || return 1
  [ -n "$mt" ] || return 1
  now="$(date +%s)"
  [ "$(( now - mt ))" -lt "$ttl" ]
}

# _kube_cache::ensure_file <file> <fetch_cmd…>
#   Atomic-replace <file> with fetch_cmd stdout when stale. Uses .tmp + mv
#   so a concurrent reader never sees a partial write. Returns non-zero if
#   fetch_cmd or mv fails; in either case no .tmp is left behind.
_kube_cache::ensure_file() {
  local file="$1"
  shift
  if _kube_cache::is_fresh "$file" "$KUBE_CACHE_TTL_SECS"; then
    return 0
  fi
  if ! "$@" > "$file.tmp" 2>/dev/null; then
    rm -f "$file.tmp"
    return 1
  fi
  mv "$file.tmp" "$file" || { rm -f "$file.tmp"; return 1; }
}

# kube_cache::init [--context=<name>] [--ttl=<duration>] [--refresh]
#   Resolve context (empty/missing → `kubectl config current-context`),
#   parse ttl, create $KSTACK_ROOT/cache/kube/<sha>/, and populate the
#   following vars in caller scope:
#     KUBE_CACHE_CONTEXT     - resolved kubectl context
#     KUBE_CACHE_DIR         - absolute path to the cache dir
#     KUBE_CACHE_TTL_SECS    - integer seconds (0 = always refetch)
#   On failure: returns 1 and populates
#     KUBE_CACHE_ERROR       - human-readable message
#     KUBE_CACHE_ERROR_KIND  - "user" (bad flags / no context) or "infra"
#                              (missing KSTACK_ROOT, mkdir failed).
#   Callers dispatch with: response::"${KUBE_CACHE_ERROR_KIND}_error" "$KUBE_CACHE_ERROR"
#   --refresh is a user-visible synonym for --ttl=0s.
kube_cache::init() {
  KUBE_CACHE_CONTEXT=""
  KUBE_CACHE_DIR=""
  KUBE_CACHE_TTL_SECS=""
  KUBE_CACHE_ERROR=""
  KUBE_CACHE_ERROR_KIND=""

  local ttl="15m" refresh=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --context=*) KUBE_CACHE_CONTEXT="${1#--context=}" ;;
      --ttl=*)     ttl="${1#--ttl=}" ;;
      --refresh)   refresh=1 ;;
      *) KUBE_CACHE_ERROR="kube_cache::init: unknown arg \`$1\`"
         KUBE_CACHE_ERROR_KIND=user
         return 1 ;;
    esac
    shift
  done
  [ "$refresh" = 1 ] && ttl=0s

  if [ -z "$KUBE_CACHE_CONTEXT" ]; then
    if ! KUBE_CACHE_CONTEXT="$(kubectl config current-context 2>/dev/null)" \
        || [ -z "$KUBE_CACHE_CONTEXT" ]; then
      KUBE_CACHE_ERROR="Unable to determine current context. Set one with kubectl or pass --context."
      KUBE_CACHE_ERROR_KIND=user
      return 1
    fi
  fi

  if ! KUBE_CACHE_TTL_SECS="$(_kube_cache::parse_ttl_seconds "$ttl")"; then
    KUBE_CACHE_ERROR="Invalid --ttl value \`$ttl\`. Use durations like 30s, 15m, 2h, 1d."
    KUBE_CACHE_ERROR_KIND=user
    return 1
  fi

  if [ -z "${KSTACK_ROOT:-}" ]; then
    KUBE_CACHE_ERROR="KSTACK_ROOT not set; source kube-cache.sh from a skill that runs via bin/entrypoint."
    KUBE_CACHE_ERROR_KIND=infra
    return 1
  fi

  local sha
  sha="$(_kube_cache::context_sha "$KUBE_CACHE_CONTEXT")"
  KUBE_CACHE_DIR="$KSTACK_ROOT/cache/kube/$sha"
  if ! mkdir -p "$KUBE_CACHE_DIR" 2>/dev/null; then
    KUBE_CACHE_ERROR="Unable to create cache dir: $KUBE_CACHE_DIR"
    KUBE_CACHE_ERROR_KIND=infra
    return 1
  fi
}

# kube_cache::ensure_list <resource> [extra kubectl args…]
#   Write $KUBE_CACHE_DIR/<resource>.json from
#   `kubectl --context=<ctx> get <resource> -o json [args]` when stale.
#   Returns non-zero on kubectl failure (caller handles reporting).
kube_cache::ensure_list() {
  local resource="$1"
  shift
  _kube_cache::ensure_file "$KUBE_CACHE_DIR/$resource.json" \
    kubectl --context="$KUBE_CACHE_CONTEXT" get "$resource" -o json "$@"
}

# kube_cache::ensure_version
#   Write $KUBE_CACHE_DIR/cluster.json from `kubectl version -o json`.
kube_cache::ensure_version() {
  _kube_cache::ensure_file "$KUBE_CACHE_DIR/cluster.json" \
    kubectl --context="$KUBE_CACHE_CONTEXT" version -o json
}

# kube_cache::path <name>
#   Print the cache path for a snapshot by filename stem (e.g. "pods",
#   "nodes", "cluster"). Does not fetch; readers pair this with ensure_*.
kube_cache::path() {
  printf '%s/%s.json\n' "$KUBE_CACHE_DIR" "$1"
}
