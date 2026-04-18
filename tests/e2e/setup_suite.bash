#!/usr/bin/env bash
# tests/e2e/setup_suite.bash — bats suite-level hook for the e2e tier.
#
# Brings up a kind cluster once before any test in tests/e2e/ runs and
# deletes it once all tests have finished. Individual tests inherit
# KUBECONFIG and talk to the cluster directly.
#
# Env:
#   KSTACK_KIND_CLUSTER   name of the kind cluster (default: kstack-test)
#   KSTACK_REUSE_CLUSTER  if =1, adopt an existing cluster and skip teardown

KSTACK_KIND_CLUSTER="${KSTACK_KIND_CLUSTER:-kstack-test}"

_kstack_require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

setup_suite() {
  local missing=()
  for cmd in kind kubectl docker; do
    if ! _kstack_require_cmd "$cmd"; then
      missing+=("$cmd")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    if declare -F skip_suite >/dev/null 2>&1; then
      skip_suite "missing required commands: ${missing[*]}"
    else
      echo "# e2e suite requires ${missing[*]} on PATH — skipping" >&3
      export KSTACK_E2E_SKIP=1
      return 0
    fi
  fi

  if kind get clusters 2>/dev/null | grep -qx "$KSTACK_KIND_CLUSTER"; then
    echo "# adopting existing kind cluster: $KSTACK_KIND_CLUSTER" >&3
  else
    echo "# creating kind cluster: $KSTACK_KIND_CLUSTER" >&3
    kind create cluster --name "$KSTACK_KIND_CLUSTER" --wait 90s >&3 2>&1
  fi

  export KUBECONFIG="$BATS_SUITE_TMPDIR/kubeconfig"
  kind get kubeconfig --name "$KSTACK_KIND_CLUSTER" > "$KUBECONFIG"
  export KSTACK_KIND_CLUSTER
}

teardown_suite() {
  if [ "${KSTACK_E2E_SKIP:-0}" = "1" ]; then
    return 0
  fi
  if [ "${KSTACK_REUSE_CLUSTER:-0}" = "1" ]; then
    echo "# KSTACK_REUSE_CLUSTER=1 — leaving $KSTACK_KIND_CLUSTER running" >&3
    return 0
  fi
  if _kstack_require_cmd kind; then
    echo "# deleting kind cluster: $KSTACK_KIND_CLUSTER" >&3
    kind delete cluster --name "$KSTACK_KIND_CLUSTER" >&3 2>&1 || true
  fi
}
