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

# scripts/install.sh bootstrap: resolves latest tag via GitHub API (curl),
# then clones (or fetches) the maintained checkout and execs $SRC_DIR/install.

setup() {
  load '../test_helper.bash'
  common_setup
  use_mocks

  # Build a local bare repo that our git stub will redirect the clone to.
  REAL_GIT="$(command -v git)"
  BARE_REPO="$TMPDIR_TEST/fake.git"
  local work="$TMPDIR_TEST/fake-work"
  mkdir -p "$BARE_REPO" "$work"
  "$REAL_GIT" init --quiet --bare "$BARE_REPO"
  "$REAL_GIT" -c init.defaultBranch=main init --quiet "$work"
  (
    cd "$work"
    "$REAL_GIT" config user.email "test@example.com"
    "$REAL_GIT" config user.name "Test"
    cat > install <<'EOF'
#!/usr/bin/env bash
echo "INSTALL-RAN:$*"
EOF
    chmod +x install
    "$REAL_GIT" add -A
    "$REAL_GIT" commit --quiet -m "init"
    "$REAL_GIT" branch -M main
    "$REAL_GIT" tag v9.9.9
    "$REAL_GIT" remote add origin "$BARE_REPO"
    "$REAL_GIT" push --quiet origin main
    "$REAL_GIT" push --quiet origin v9.9.9
  )

  # curl stub: emit tag_name; real curl isn't wanted.
  write_stub curl '
if [[ "$*" == *"api.github.com"* ]]; then
  printf "%s\n" "{\"tag_name\": \"v9.9.9\"}"
  exit 0
fi
exit 1
'

  # git stub: rewrite the upstream URL to our local bare repo; delegate everything
  # else to real git.
  write_stub git "
REAL_GIT=$REAL_GIT
args=()
for a in \"\$@\"; do
  case \"\$a\" in
    https://github.com/kubetail-org/kstack.git) args+=(\"$BARE_REPO\") ;;
    *) args+=(\"\$a\") ;;
  esac
done
exec \"\$REAL_GIT\" \"\${args[@]}\"
"
}

@test "scripts/install.sh clones bare repo at resolved tag and execs install" {
  run "$REPO_ROOT/scripts/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"INSTALL-RAN:--global"* ]]
  [ -d "$HOME/.config/kstack/upstream/.git" ]
}

@test "scripts/install.sh exits 1 when GitHub API yields no tag" {
  write_stub curl 'echo "{}"; exit 0'
  run "$REPO_ROOT/scripts/install.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not resolve latest kstack release"* ]]
}

@test "scripts/install.sh updates existing checkout on rerun" {
  run "$REPO_ROOT/scripts/install.sh"
  [ "$status" -eq 0 ]
  run "$REPO_ROOT/scripts/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"INSTALL-RAN:--global"* ]]
}
