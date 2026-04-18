#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  common_setup
  . "$REPO_ROOT/install"

  SKILLS_SRC="$FIXTURES_DIR/skills"
  GF="$SKILLS_SRC/_partials/global-flags.md"
  UC="$SKILLS_SRC/_partials/update-check.md"
  README="$FIXTURES_DIR/README.md"
  OUT="$TMPDIR_TEST/out/SKILL.md"
  HELP="$TMPDIR_TEST/out/references/help.md"
  mkdir -p "$TMPDIR_TEST/out"
}

render() {
  local help_path="${5:-/install/path/references/help.md}"
  render_skill "$1" "$2" "$3" "$4" "$help_path" "$OUT" "$SKILLS_SRC" "$GF" "$UC"
}

render_h() {
  render_help "$1" "$README" "$HELP"
}

@test "render_skill substitutes SKILL_NAME and AGENT" {
  render demo claude /root /bin
  grep -F "name: kstack-demo" "$OUT"
  grep -F "agent: claude" "$OUT"
}

@test "render_skill substitutes ROOT_DIR and BIN_DIR" {
  render demo claude /my/root /my/bin
  grep -F "install_root: /my/root" "$OUT"
  grep -F "bin_dir: /my/bin" "$OUT"
}

@test "render_skill substitutes HELP_PATH" {
  render demo claude /root /bin /skills/demo/references/help.md
  grep -F "help_path: /skills/demo/references/help.md" "$OUT"
}

@test "render_skill inlines both partials" {
  render demo claude /root /bin
  grep -F "does one thing" "$OUT"
  grep -F "check-update at session start" "$OUT"
}

@test "render_skill expands BIN_DIR inside update-check partial" {
  render demo claude /root /opt/kstack/bin
  grep -F "Run /opt/kstack/bin/check-update" "$OUT"
}

@test "render_skill leaves no raw template markers" {
  render demo claude /root /bin
  ! grep -F '{{' "$OUT"
}

@test "render_skill creates output parent dir" {
  OUT="$TMPDIR_TEST/out/nested/sub/SKILL.md"
  render demo claude /root /bin
  [ -f "$OUT" ]
}

@test "render_help extracts the skill section body from README" {
  render_h demo
  grep -F "A fixture skill used by tests." "$HELP"
  grep -F "nothing real" "$HELP"
  grep -F "flag-one" "$HELP"
}

@test "render_help prepends a title line for the skill" {
  render_h demo
  head -n 1 "$HELP" | grep -F "/demo"
}

@test "render_help strips <dd> and </dd> HTML tags" {
  render_h demo
  ! grep -F "<dd>" "$HELP"
  ! grep -F "</dd>" "$HELP"
}

@test "render_help stops at the closing </dd> of the target skill" {
  render_h demo
  # Should not leak into the /demo-with-args section below it.
  ! grep -F "demo-with-args" "$HELP"
  ! grep -F "Variant whose heading" "$HELP"
}

@test "render_help matches a skill whose heading carries an argument" {
  render_help demo-with-args "$README" "$HELP"
  grep -F "Variant whose heading" "$HELP"
  ! grep -F "A fixture skill used by tests." "$HELP"
}

@test "render_help appends the global flags table from README" {
  render_h demo
  grep -F "Global flags" "$HELP"
  grep -F -e "--context <ctx>" "$HELP"
  grep -F -e "--dry-run" "$HELP"
}

@test "render_help ends with the END HELP sentinel" {
  render_h demo
  tail -n 1 "$HELP" | grep -F "=== END HELP ==="
}

@test "render_help exits non-zero when README has no matching section" {
  run render_help nosuch-skill "$README" "$HELP"
  [ "$status" -ne 0 ]
}

@test "render_help creates output parent dir" {
  HELP="$TMPDIR_TEST/out/nested/sub/help.md"
  render_h demo
  [ -f "$HELP" ]
}
