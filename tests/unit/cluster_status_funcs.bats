#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  common_setup
  # shellcheck source=../../lib/cluster-status/helpers.sh
  . "$REPO_ROOT/lib/cluster-status/helpers.sh"
}

@test "parse_duration_to_secs 90s" {
  run parse_duration_to_secs 90s
  [ "$status" -eq 0 ]
  [ "$output" = "90" ]
}

@test "parse_duration_to_secs 5m" {
  run parse_duration_to_secs 5m
  [ "$status" -eq 0 ]
  [ "$output" = "300" ]
}

@test "parse_duration_to_secs 1h" {
  run parse_duration_to_secs 1h
  [ "$status" -eq 0 ]
  [ "$output" = "3600" ]
}

@test "parse_duration_to_secs 24h" {
  run parse_duration_to_secs 24h
  [ "$status" -eq 0 ]
  [ "$output" = "86400" ]
}

@test "parse_duration_to_secs 2d" {
  run parse_duration_to_secs 2d
  [ "$status" -eq 0 ]
  [ "$output" = "172800" ]
}

@test "parse_duration_to_secs rejects unsuffixed integer" {
  run parse_duration_to_secs 5
  [ "$status" -eq 2 ]
  [[ "$output" == *"Invalid"* ]]
}

@test "parse_duration_to_secs rejects gibberish" {
  run parse_duration_to_secs abc
  [ "$status" -eq 2 ]
  [[ "$output" == *"Invalid"* ]]
}

@test "validate_severity accepts critical" {
  run validate_severity critical
  [ "$status" -eq 0 ]
}

@test "validate_severity accepts warning" {
  run validate_severity warning
  [ "$status" -eq 0 ]
}

@test "validate_severity accepts info" {
  run validate_severity info
  [ "$status" -eq 0 ]
}

@test "validate_severity rejects garbage" {
  run validate_severity nope
  [ "$status" -eq 2 ]
  [[ "$output" == *"Invalid"* ]]
}

@test "build_kubectl_args cluster scope ignores namespace" {
  run build_kubectl_args "" "foo" cluster
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "build_kubectl_args cluster scope picks up context" {
  run build_kubectl_args "prod" "" cluster
  [ "$status" -eq 0 ]
  [ "$output" = "--context=prod" ]
}

@test "build_kubectl_args namespaced scope falls back to --all-namespaces" {
  run build_kubectl_args "" "" namespaced
  [ "$status" -eq 0 ]
  [ "$output" = "--all-namespaces" ]
}

@test "build_kubectl_args namespaced scope honors --namespace" {
  run build_kubectl_args "" "kube-system" namespaced
  [ "$status" -eq 0 ]
  [ "$output" = "-n kube-system" ]
}

@test "build_kubectl_args combines context and namespace" {
  run build_kubectl_args "prod" "kube-system" namespaced
  [ "$status" -eq 0 ]
  [ "$output" = "--context=prod -n kube-system" ]
}

@test "build_kubectl_args cluster scope with context and namespace drops namespace" {
  run build_kubectl_args "prod" "kube-system" cluster
  [ "$status" -eq 0 ]
  [ "$output" = "--context=prod" ]
}
