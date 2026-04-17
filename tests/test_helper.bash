# Shared helpers for the kstack bats suite.
#
# Expected layout:
#   $REPO_ROOT        top of the kstack checkout (computed from this file)
#   $FIXTURES_DIR     tests/fixtures
#   $MOCKS_DIR        tests/mocks
#
# Each test's setup() should call one of:
#   common_setup                general-purpose isolated HOME + tmpdir
#   global_install_setup        isolate HOME and stage a fake global install

TEST_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_HELPER_DIR/.." && pwd)"
FIXTURES_DIR="$TEST_HELPER_DIR/fixtures"
MOCKS_DIR="$TEST_HELPER_DIR/mocks"

common_setup() {
  TMPDIR_TEST="${BATS_TEST_TMPDIR:-$(mktemp -d)}"
  export HOME="$TMPDIR_TEST/home"
  mkdir -p "$HOME"
  export ORIGINAL_PATH="$PATH"
}

# Prepend a dedicated mock dir to PATH. Stubs placed here shadow system commands.
use_mocks() {
  MOCK_BIN="$TMPDIR_TEST/mock-bin"
  mkdir -p "$MOCK_BIN"
  export PATH="$MOCK_BIN:$PATH"
}

# Install a named mock from tests/mocks into the current MOCK_BIN.
install_mock() {
  local name="$1"
  cp "$MOCKS_DIR/$name" "$MOCK_BIN/$name"
  chmod +x "$MOCK_BIN/$name"
}

# Write a one-off stub to MOCK_BIN. The body is the command's #!/usr/bin/env bash contents.
write_stub() {
  local name="$1" body="$2"
  cat > "$MOCK_BIN/$name" <<EOF
#!/usr/bin/env bash
$body
EOF
  chmod +x "$MOCK_BIN/$name"
}

# Create a bare git repo at $1 with a single commit and tag $2.
# Echoes the repo path on success.
make_bare_repo_with_tag() {
  local bare="$1" tag="$2"
  local work="$TMPDIR_TEST/work-$(basename "$bare")"
  mkdir -p "$bare" "$work"
  git init --quiet --bare "$bare"
  git -c init.defaultBranch=main init --quiet "$work"
  (
    cd "$work"
    git config user.email "test@example.com"
    git config user.name "Test"
    # Seed with an empty skills dir and a stub install so clones are functional.
    mkdir -p skills
    echo "stub" > README.md
    git add README.md
    git commit --quiet -m "init"
    git branch -M main
    git tag "$tag"
    git remote add origin "$bare"
    git push --quiet origin main
    git push --quiet origin "$tag"
  )
}

# Assert that a file exists. Usage: assert_file_exists "$path"
assert_file_exists() {
  if [ ! -e "$1" ]; then
    echo "expected file to exist: $1" >&2
    return 1
  fi
}

assert_file_not_exists() {
  if [ -e "$1" ]; then
    echo "expected file to NOT exist: $1" >&2
    return 1
  fi
}
