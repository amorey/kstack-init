#!/usr/bin/env bats

# Source check-update so is_newer/bail are callable without running main.

setup() {
  load '../test_helper.bash'
  common_setup
  . "$SRC_ROOT/bin/check-update"
}

@test "is_newer: equal versions returns 1" {
  run is_newer v1.0.0 v1.0.0
  [ "$status" -eq 1 ]
}

@test "is_newer: newer returns 0" {
  run is_newer v2.0.0 v1.0.0
  [ "$status" -eq 0 ]
}

@test "is_newer: older returns 1" {
  run is_newer v1.0.0 v2.0.0
  [ "$status" -eq 1 ]
}

@test "is_newer: minor bump" {
  run is_newer v1.2.0 v1.1.9
  [ "$status" -eq 0 ]
}

@test "is_newer: patch bump" {
  run is_newer v1.0.10 v1.0.2
  [ "$status" -eq 0 ]
}

@test "is_newer: two-digit version segments" {
  run is_newer v1.10.0 v1.9.0
  [ "$status" -eq 0 ]
}

@test "bail exits 0" {
  run bail
  [ "$status" -eq 0 ]
}
