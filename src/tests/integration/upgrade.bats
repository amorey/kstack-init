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

setup() {
  load '../test_helper.bash'
  common_setup
}

@test "upgrade in global location execs upstream/install --global" {
  # Stage a fake global install.
  mkdir -p "$HOME/.config/kstack/bin" "$HOME/.config/kstack/upstream"
  cp "$SRC_ROOT/bin/upgrade" "$HOME/.config/kstack/bin/upgrade"
  chmod +x "$HOME/.config/kstack/bin/upgrade"
  cat > "$HOME/.config/kstack/upstream/install" <<'EOF'
#!/usr/bin/env bash
echo "GLOBAL-INSTALL:$*"
EOF
  chmod +x "$HOME/.config/kstack/upstream/install"

  run "$HOME/.config/kstack/bin/upgrade" --extra
  [ "$status" -eq 0 ]
  [[ "$output" == *"GLOBAL-INSTALL:--global --extra"* ]]
}

@test "upgrade in repo-local location git-pulls then execs ./install" {
  # Stage a fake repo with the installed layout under .kstack/.
  FAKE_REPO="$TMPDIR_TEST/fake-repo"
  BARE="$TMPDIR_TEST/fake-repo.git"
  mkdir -p "$FAKE_REPO/.kstack/bin" "$BARE"

  git init --quiet --bare "$BARE"
  git -c init.defaultBranch=main init --quiet "$FAKE_REPO"
  (
    cd "$FAKE_REPO"
    git config user.email "test@example.com"
    git config user.name "Test"
    cat > install <<'EOF'
#!/usr/bin/env bash
echo "LOCAL-INSTALL:$*"
EOF
    chmod +x install
    cp "$SRC_ROOT/bin/upgrade" .kstack/bin/upgrade
    chmod +x .kstack/bin/upgrade
    git add -A
    git commit --quiet -m "init"
    git branch -M main
    git remote add origin "$BARE"
    git push --quiet -u origin main
  )

  run "$FAKE_REPO/.kstack/bin/upgrade" --foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"LOCAL-INSTALL:--foo"* ]]
}
