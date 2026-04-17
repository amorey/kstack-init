#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  common_setup
}

@test "upgrade in global location execs src/install --global" {
  # Stage a fake global install.
  mkdir -p "$HOME/.config/kstack/bin" "$HOME/.config/kstack/src"
  cp "$REPO_ROOT/bin/upgrade" "$HOME/.config/kstack/bin/upgrade"
  chmod +x "$HOME/.config/kstack/bin/upgrade"
  cat > "$HOME/.config/kstack/src/install" <<'EOF'
#!/usr/bin/env bash
echo "GLOBAL-INSTALL:$*"
EOF
  chmod +x "$HOME/.config/kstack/src/install"

  run "$HOME/.config/kstack/bin/upgrade" --extra
  [ "$status" -eq 0 ]
  [[ "$output" == *"GLOBAL-INSTALL:--global --extra"* ]]
}

@test "upgrade in repo-local location git-pulls then execs ./install" {
  # Stage a fake repo.
  FAKE_REPO="$TMPDIR_TEST/fake-repo"
  BARE="$TMPDIR_TEST/fake-repo.git"
  mkdir -p "$FAKE_REPO/bin" "$BARE"

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
    cp "$REPO_ROOT/bin/upgrade" bin/upgrade
    chmod +x bin/upgrade
    git add -A
    git commit --quiet -m "init"
    git branch -M main
    git remote add origin "$BARE"
    git push --quiet -u origin main
  )

  run "$FAKE_REPO/bin/upgrade" --foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"LOCAL-INSTALL:--foo"* ]]
}
