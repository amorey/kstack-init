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

  # Build a fake "upstream" kstack checkout in a bare+working repo pair.
  # install --global clones from $KSTACK_REMOTE_URL at the latest v* tag.
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
    # Install script at repo root — mirrors the real repo layout.
    cp "$REPO_ROOT/install" install
    cp "$SRC_ROOT/lib/agents.sh" src/lib/agents.sh
    cp "$SRC_ROOT/lib/cache.sh" src/lib/cache.sh
    cp "$FIXTURES_DIR/skills/demo/SKILL.md.tmpl" src/skills/demo/SKILL.md.tmpl
    cp "$FIXTURES_DIR/skills/_partials/global-flags.md" src/skills/_partials/global-flags.md
    cp "$FIXTURES_DIR/skills/_partials/update-check.md" src/skills/_partials/update-check.md
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

  # install script under test: the one in the bare-repo-cloned source.
  # Run the in-repo one — it will ensure_src_checkout from our local bare repo.
  RUN_INSTALL="$REPO_ROOT/install"
  export KSTACK_REMOTE_URL="$BARE"
}

@test "install --global clones bare repo at latest tag and writes install.conf" {
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/kstack/install.conf" ]
  run cat "$HOME/.config/kstack/install.conf"
  [ "$output" = "v1.2.3" ]
}

@test "install --global renders skills into \$HOME/.claude/skills/kstack-<name>" {
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$HOME/.claude/skills/kstack-demo/SKILL.md"
  # Template must reference the global install root and bin dir.
  run grep -F "install_root: $HOME/.config/kstack" "$HOME/.claude/skills/kstack-demo/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -F "bin_dir: $HOME/.config/kstack/bin" "$HOME/.claude/skills/kstack-demo/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "install --global substitutes SKILL_DIR to the rendered slot path" {
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F "skill_dir: $HOME/.claude/skills/kstack-demo" "$HOME/.claude/skills/kstack-demo/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "install --global copies skills/<name>/scripts/ into rendered slot" {
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$HOME/.claude/skills/kstack-demo/scripts/snapshot" ]
}

@test "install --global copies bin/ helpers to \$HOME/.config/kstack/bin" {
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$HOME/.config/kstack/bin/hello" ]
}

@test "install --global copies lib/ to \$HOME/.config/kstack/lib" {
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/kstack/lib/agents.sh" ]
  [ -f "$HOME/.config/kstack/lib/cache.sh" ]
}

@test "install --global re-run uses fetch+checkout path" {
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  # Second run — should take the "Updating" branch, still succeeds.
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$HOME/.claude/skills/kstack-demo/SKILL.md"
}

@test "install --global prunes orphan kstack-* skill slot" {
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  mkdir -p "$HOME/.claude/skills/kstack-ghost"
  echo "stale" > "$HOME/.claude/skills/kstack-ghost/SKILL.md"
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/skills/kstack-ghost" ]
  assert_file_exists "$HOME/.claude/skills/kstack-demo/SKILL.md"
}

@test "install --global preserves non-kstack skill slot in shared skills dir" {
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  mkdir -p "$HOME/.claude/skills/user-own"
  echo "mine" > "$HOME/.claude/skills/user-own/SKILL.md"
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$HOME/.claude/skills/user-own/SKILL.md"
}

@test "install --global prunes orphan helper from \$HOME/.config/kstack/bin" {
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  echo "#!/bin/sh" > "$HOME/.config/kstack/bin/ghost-helper"
  chmod +x "$HOME/.config/kstack/bin/ghost-helper"
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/kstack/bin/ghost-helper" ]
  [ -x "$HOME/.config/kstack/bin/hello" ]
}

@test "install --global prunes orphan .sh file from \$HOME/.config/kstack/lib" {
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  echo "# stale" > "$HOME/.config/kstack/lib/ghost.sh"
  run "$RUN_INSTALL" --global --agent claude --quiet
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/kstack/lib/ghost.sh" ]
  [ -f "$HOME/.config/kstack/lib/agents.sh" ]
  [ -f "$HOME/.config/kstack/lib/cache.sh" ]
}
