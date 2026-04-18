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
  MAN="$TMPDIR_TEST/out/SKILL.man"
  mkdir -p "$TMPDIR_TEST/out"
}

render() {
  local man_path="${5:-/install/path/SKILL.man}"
  render_skill "$1" "$2" "$3" "$4" "$man_path" "$OUT" "$SKILLS_SRC" "$GF" "$UC"
}

render_m() {
  render_man "$1" "$README" "$MAN"
}

@test "render_skill substitutes SKILL_NAME and AGENT" {
  render demo claude /root /bin
  grep -F "name: kstack-demo" "$OUT"
  grep -F "agent: claude" "$OUT"
}

@test "render_skill substitutes INSTALL_ROOT and BIN_DIR" {
  render demo claude /my/root /my/bin
  grep -F "install_root: /my/root" "$OUT"
  grep -F "bin_dir: /my/bin" "$OUT"
}

@test "render_skill substitutes MAN_PATH" {
  render demo claude /root /bin /skills/demo/SKILL.man
  grep -F "man_path: /skills/demo/SKILL.man" "$OUT"
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

@test "render_man extracts the skill section body from README" {
  render_m demo
  grep -F "A fixture skill used by tests." "$MAN"
  grep -F "nothing real" "$MAN"
  grep -F "flag-one" "$MAN"
}

@test "render_man prepends a title line for the skill" {
  render_m demo
  head -n 1 "$MAN" | grep -F "/demo"
}

@test "render_man strips <dd> and </dd> HTML tags" {
  render_m demo
  ! grep -F "<dd>" "$MAN"
  ! grep -F "</dd>" "$MAN"
}

@test "render_man stops at the closing </dd> of the target skill" {
  render_m demo
  # Should not leak into the /demo-with-args section below it.
  ! grep -F "demo-with-args" "$MAN"
  ! grep -F "Variant whose heading" "$MAN"
}

@test "render_man matches a skill whose heading carries an argument" {
  render_man demo-with-args "$README" "$MAN"
  grep -F "Variant whose heading" "$MAN"
  ! grep -F "A fixture skill used by tests." "$MAN"
}

@test "render_man appends the global flags table from README" {
  render_m demo
  grep -F "Global flags" "$MAN"
  grep -F -e "--context <ctx>" "$MAN"
  grep -F -e "--dry-run" "$MAN"
}

@test "render_man ends with the END HELP sentinel" {
  render_m demo
  tail -n 1 "$MAN" | grep -F "=== END HELP ==="
}

@test "render_man exits non-zero when README has no matching section" {
  run render_man nosuch-skill "$README" "$MAN"
  [ "$status" -ne 0 ]
}

@test "render_man creates output parent dir" {
  MAN="$TMPDIR_TEST/out/nested/sub/SKILL.man"
  render_m demo
  [ -f "$MAN" ]
}
