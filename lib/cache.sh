# kstack update cache — shared by check-update and dismiss-update.
#
# Source this file; do not execute it. Requires $HOME.

# resolve_cache_paths $script_dir
#   Sets INSTALL_ROOT, CACHE_DIR, CACHE_FILE based on whether $script_dir
#   lives inside the global install (~/.config/kstack/bin) or a repo-local
#   checkout (<repo>/bin).
resolve_cache_paths() {
  if [ "$1" = "$HOME/.config/kstack/bin" ]; then
    INSTALL_ROOT="$HOME/.config/kstack"
    CACHE_DIR="$INSTALL_ROOT/cache"
  else
    INSTALL_ROOT="$(dirname "$1")"
    CACHE_DIR="$INSTALL_ROOT/.kstack/cache"
  fi
  CACHE_FILE="$CACHE_DIR/update.json"
}

# read_cache_fields $cache_file
#   Sets cache_ts / cache_latest / cache_dismissed in one awk pass. Sets empty
#   strings when the file is missing or a field isn't present.
read_cache_fields() {
  cache_ts=""
  cache_latest=""
  cache_dismissed=""
  [ -f "$1" ] || return 0
  local _awk_out
  _awk_out="$(awk -F'"' '
    /"last_check"[[:space:]]*:/        { ts = $4 }
    /"latest_known"[[:space:]]*:/      { latest = $4 }
    /"dismissed_version"[[:space:]]*:/ { dismissed = $4 }
    END { print ts; print latest; print dismissed }
  ' "$1")"
  {
    IFS= read -r cache_ts
    IFS= read -r cache_latest
    IFS= read -r cache_dismissed
  } <<< "$_awk_out"
}

# write_cache_json $cache_file $last_check $latest_known [$dismissed_version]
#   Atomic-replaces $cache_file. Omits the dismissed_version line when empty.
write_cache_json() {
  local file="$1" ts="$2" latest="$3" dismissed="${4:-}"
  {
    printf '{\n'
    printf '  "last_check": "%s",\n' "$ts"
    if [ -n "$dismissed" ]; then
      printf '  "latest_known": "%s",\n' "$latest"
      printf '  "dismissed_version": "%s"\n' "$dismissed"
    else
      printf '  "latest_known": "%s"\n' "$latest"
    fi
    printf '}\n'
  } > "$file.tmp" 2>/dev/null \
    && mv "$file.tmp" "$file" 2>/dev/null \
    || rm -f "$file.tmp" 2>/dev/null
}
