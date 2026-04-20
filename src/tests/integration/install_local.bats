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

# install --local mode: clones a kstack-owned upstream into $PWD/.kstack/
# and renders skills into $PWD/.<agent>/skills/kstack-<name>/.

setup() {
  load '../test_helper.bash'
  common_setup

  # Build a fake upstream: bare+working repo pair with tag v1.2.3.
  BARE="$TMPDIR_TEST/kstack.git"
  WORK="$TMPDIR_TEST/kstack-work"
  mkdir -p "$BARE" "$WORK"
  git init --quiet --bare "$BARE"
  git -c init.defaultBranch=main init --quiet "$WORK"
  (
    cd "$WORK"
    git config user.email "test@example.com"
    git config user.name "Test"

    mkdir -p src/bin src/lib src/skills/demo/scripts src/skills/_partials
    cp "$REPO_ROOT/install" install
    cp "$SRC_ROOT/lib/agents.sh" src/lib/agents.sh
    cp "$SRC_ROOT/lib/cache.sh" src/lib/cache.sh
    cp "$FIXTURES_DIR/skills/demo/SKILL.md.tmpl" src/skills/demo/SKILL.md.tmpl
    cp "$FIXTURES_DIR/skills/_partials/global-flags.md" src/skills/_partials/global-flags.md
    cp "$FIXTURES_DIR/skills/_partials/entrypoint.md" src/skills/_partials/entrypoint.md
    cp "$FIXTURES_DIR/README.md" README.md
    cat > src/bin/hello <<'EOF'
#!/usr/bin/env bash
echo hello
EOF
    cat > src/skills/demo/scripts/snapshot <<'EOF'
#!/usr/bin/env bash
echo snap
EOF
    chmod +x install src/bin/hello src/skills/demo/scripts/snapshot
    git add -A
    git commit --quiet -m "init"
    git branch -M main
    git tag v1.2.3
    git remote add origin "$BARE"
    git push --quiet origin main
    git push --quiet origin v1.2.3
  )

  # PROJECT is the user's project dir — where --local drops .kstack/.
  PROJECT="$TMPDIR_TEST/proj"
  mkdir -p "$PROJECT"

  RUN_INSTALL="$REPO_ROOT/install"
  export KSTACK_REMOTE_URL="$BARE"
}

@test "install --local clones bare repo into \$PWD/.kstack/upstream at latest tag" {
  cd "$PROJECT"
  run "$RUN_INSTALL" --local --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -d "$PROJECT/.kstack/upstream/.git" ]
  [ -f "$PROJECT/.kstack/install.conf" ]
  run cat "$PROJECT/.kstack/install.conf"
  [ "$output" = "v1.2.3" ]
}

@test "install --local renders skills into \$PWD/.claude/skills/kstack-<name>" {
  cd "$PROJECT"
  run "$RUN_INSTALL" --local --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT/.claude/skills/kstack-demo/SKILL.md"
  # Bare-name slots are never rendered — every mode uses the kstack- prefix.
  [ ! -e "$PROJECT/.claude/skills/demo" ]
}

@test "install --local substitutes local install root and bin dir into template" {
  cd "$PROJECT"
  run "$RUN_INSTALL" --local --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F "install_root: $PROJECT/.kstack" "$PROJECT/.claude/skills/kstack-demo/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -F "bin_dir: $PROJECT/.kstack/bin" "$PROJECT/.claude/skills/kstack-demo/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "install --local substitutes SKILL_DIR to the local rendered slot path" {
  cd "$PROJECT"
  run "$RUN_INSTALL" --local --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F "skill_dir: $PROJECT/.claude/skills/kstack-demo" "$PROJECT/.claude/skills/kstack-demo/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "install --local substitutes SKILL_NAME with the kstack- prefix" {
  cd "$PROJECT"
  run "$RUN_INSTALL" --local --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F "name: kstack-demo" "$PROJECT/.claude/skills/kstack-demo/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "install --local copies skills/<name>/scripts/ into rendered slot" {
  cd "$PROJECT"
  run "$RUN_INSTALL" --local --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$PROJECT/.claude/skills/kstack-demo/scripts/snapshot" ]
}

@test "install --local copies bin/ helpers under \$PWD/.kstack/bin" {
  cd "$PROJECT"
  run "$RUN_INSTALL" --local --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$PROJECT/.kstack/bin/hello" ]
}

@test "install --local copies lib/ under \$PWD/.kstack/lib" {
  cd "$PROJECT"
  run "$RUN_INSTALL" --local --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -f "$PROJECT/.kstack/lib/agents.sh" ]
  [ -f "$PROJECT/.kstack/lib/cache.sh" ]
}

@test "install --local re-run updates the existing upstream checkout" {
  cd "$PROJECT"
  run "$RUN_INSTALL" --local --agent claude --quiet
  [ "$status" -eq 0 ]
  run "$RUN_INSTALL" --local --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT/.claude/skills/kstack-demo/SKILL.md"
}

@test "install --local preserves non-kstack skill slot in the shared skills dir" {
  cd "$PROJECT"
  run "$RUN_INSTALL" --local --agent claude --quiet
  [ "$status" -eq 0 ]
  mkdir -p "$PROJECT/.claude/skills/user-own"
  echo "mine" > "$PROJECT/.claude/skills/user-own/SKILL.md"
  run "$RUN_INSTALL" --local --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$PROJECT/.claude/skills/user-own/SKILL.md"
}

@test "install --local and --global are mutually exclusive" {
  cd "$PROJECT"
  run "$RUN_INSTALL" --local --global --agent claude --quiet
  [ "$status" -eq 1 ]
  [[ "$output" == *"mutually exclusive"* ]]
}
