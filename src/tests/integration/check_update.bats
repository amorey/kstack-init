#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  common_setup

  # Global-mode install layout: check-update lives at $HOME/.config/kstack/bin,
  # libs alongside at $HOME/.config/kstack/lib.
  mkdir -p "$HOME/.config/kstack/bin" "$HOME/.config/kstack/cache" "$HOME/.config/kstack/lib"
  cp "$REPO_ROOT/bin/check-update" "$HOME/.config/kstack/bin/check-update"
  cp "$REPO_ROOT/lib/cache.sh" "$HOME/.config/kstack/lib/cache.sh"
  chmod +x "$HOME/.config/kstack/bin/check-update"
  CACHE_FILE="$HOME/.config/kstack/cache/update.json"
  CHECK="$HOME/.config/kstack/bin/check-update"

  # Set installed version.
  echo "v1.0.0" > "$HOME/.config/kstack/install.conf"
}

# ─── git stub ─────────────────────────────────────────────────
# Intercepts `git ls-remote --tags ... v*` to emit MOCK_TAGS; everything else
# falls through to real git. Used to control the "remote latest" for refresh.
stub_git() {
  use_mocks
  REAL_GIT="$(command -v git)"
  write_stub git "
REAL_GIT=$REAL_GIT
if [ \"\$1\" = 'ls-remote' ]; then
  # Emit tags from \$MOCK_TAGS (space-separated).
  for t in \$MOCK_TAGS; do
    printf 'abcdef\trefs/tags/%s\n' \"\$t\"
  done
  exit 0
fi
exec \"\$REAL_GIT\" \"\$@\"
"
}

@test "check-update with stale cache refreshes from remote and prints notice" {
  stub_git
  export MOCK_TAGS="v1.0.0 v1.1.0 v2.0.0"
  cat > "$CACHE_FILE" <<EOF
{
  "last_check": "2000-01-01T00:00:00Z",
  "latest_known": "v1.0.0"
}
EOF
  run "$CHECK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"kstack v2.0.0 is available"* ]]
  [[ "$output" == *"you're on v1.0.0"* ]]
}

@test "check-update with fresh cache does NOT hit remote (same output from cache)" {
  stub_git
  export MOCK_TAGS=""  # if git runs, no notice possible
  now_iso="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  cat > "$CACHE_FILE" <<EOF
{
  "last_check": "$now_iso",
  "latest_known": "v2.0.0"
}
EOF
  run "$CHECK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"kstack v2.0.0 is available"* ]]
}

@test "check-update prints up-to-date when latest == installed" {
  stub_git
  export MOCK_TAGS="v1.0.0"
  run "$CHECK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"kstack v1.0.0 is up to date"* ]]
}

@test "check-update with dismissed_version >= latest is silent/up-to-date" {
  stub_git
  export MOCK_TAGS=""
  now_iso="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  cat > "$CACHE_FILE" <<EOF
{
  "last_check": "$now_iso",
  "latest_known": "v2.0.0",
  "dismissed_version": "v2.0.0"
}
EOF
  run "$CHECK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"update to v2.0.0 dismissed"* ]]
}

@test "check-update --quiet suppresses up-to-date message" {
  stub_git
  export MOCK_TAGS="v1.0.0"
  run "$CHECK" --quiet
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "check-update --quiet still prints notice when one is due" {
  stub_git
  export MOCK_TAGS="v5.0.0"
  run "$CHECK" --quiet
  [ "$status" -eq 0 ]
  [[ "$output" == *"kstack v5.0.0 is available"* ]]
}

@test "check-update with no install.conf exits silently (bail)" {
  rm -f "$HOME/.config/kstack/install.conf"
  stub_git
  export MOCK_TAGS="v9.0.0"
  run "$CHECK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "check-update with installed=main exits silently (pre-release)" {
  echo "main" > "$HOME/.config/kstack/install.conf"
  stub_git
  export MOCK_TAGS="v9.0.0"
  run "$CHECK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "check-update writes/updates cache after refresh" {
  stub_git
  export MOCK_TAGS="v1.0.0 v1.1.0 v3.0.0"
  rm -f "$CACHE_FILE"
  run "$CHECK"
  [ "$status" -eq 0 ]
  [ -f "$CACHE_FILE" ]
  run grep -F '"latest_known": "v3.0.0"' "$CACHE_FILE"
  [ "$status" -eq 0 ]
}

@test "check-update preserves dismissed_version through refresh" {
  stub_git
  export MOCK_TAGS="v1.0.0 v2.5.0"
  cat > "$CACHE_FILE" <<EOF
{
  "last_check": "2000-01-01T00:00:00Z",
  "latest_known": "v2.0.0",
  "dismissed_version": "v2.0.0"
}
EOF
  run "$CHECK"
  [ "$status" -eq 0 ]
  # Now v2.5.0 > dismissed v2.0.0, so notice should fire again.
  [[ "$output" == *"kstack v2.5.0 is available"* ]]
  grep -F '"dismissed_version": "v2.0.0"' "$CACHE_FILE"
}
