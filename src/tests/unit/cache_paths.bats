#!/usr/bin/env bats

# Source lib/cache.sh so resolve_cache_paths is callable directly.

setup() {
  load '../test_helper.bash'
  common_setup
  . "$SRC_ROOT/lib/cache.sh"
}

@test "resolve_cache_paths: global mode points at ~/.config/kstack/cache" {
  resolve_cache_paths "$HOME/.config/kstack/bin"
  [ "$ROOT_DIR" = "$HOME/.config/kstack" ]
  [ "$CACHE_DIR" = "$HOME/.config/kstack/cache" ]
  [ "$CACHE_FILE" = "$HOME/.config/kstack/cache/update.json" ]
}

@test "resolve_cache_paths: repo-local mode points at <repo>/.kstack/cache" {
  resolve_cache_paths "/fake/repo/.kstack/bin"
  [ "$ROOT_DIR" = "/fake/repo/.kstack" ]
  [ "$CACHE_DIR" = "/fake/repo/.kstack/cache" ]
  [ "$CACHE_FILE" = "/fake/repo/.kstack/cache/update.json" ]
}
