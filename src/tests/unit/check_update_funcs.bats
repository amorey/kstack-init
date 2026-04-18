#!/usr/bin/env bats

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
