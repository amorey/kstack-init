#!/usr/bin/env bats

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

    mkdir -p bin lib skills/demo skills/_partials
    cp "$REPO_ROOT/install" install
    cp "$REPO_ROOT/lib/agents.sh" lib/agents.sh
    cp "$REPO_ROOT/lib/cache.sh" lib/cache.sh
    cp "$FIXTURES_DIR/skills/demo/SKILL.md.tmpl" skills/demo/SKILL.md.tmpl
    cp "$FIXTURES_DIR/skills/_partials/global-flags.md" skills/_partials/global-flags.md
    cp "$FIXTURES_DIR/skills/_partials/update-check.md" skills/_partials/update-check.md
    cp "$FIXTURES_DIR/README.md" README.md
    cat > bin/hello <<'EOF'
#!/usr/bin/env bash
echo hello
EOF
    chmod +x bin/hello install
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
