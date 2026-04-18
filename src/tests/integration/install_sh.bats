#!/usr/bin/env bats

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
  run "$SRC_ROOT/scripts/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"INSTALL-RAN:--global"* ]]
  [ -d "$HOME/.config/kstack/upstream/.git" ]
}

@test "scripts/install.sh exits 1 when GitHub API yields no tag" {
  write_stub curl 'echo "{}"; exit 0'
  run "$SRC_ROOT/scripts/install.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not resolve latest kstack release"* ]]
}

@test "scripts/install.sh updates existing checkout on rerun" {
  run "$SRC_ROOT/scripts/install.sh"
  [ "$status" -eq 0 ]
  run "$SRC_ROOT/scripts/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"INSTALL-RAN:--global"* ]]
}
