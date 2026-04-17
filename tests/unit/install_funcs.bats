#!/usr/bin/env bats

# Source install to call render_skill directly against the test fixtures.

setup() {
  load '../test_helper.bash'
  common_setup
  . "$REPO_ROOT/install"

  # render_skill reads these globals; tests point them at fixtures.
  SKILLS_SRC="$FIXTURES_DIR/skills"
  GLOBAL_FLAGS_PARTIAL="$SKILLS_SRC/_partials/global-flags.md"
  UPDATE_CHECK_PARTIAL="$SKILLS_SRC/_partials/update-check.md"
  OUT_DIR="$TMPDIR_TEST/out"
  mkdir -p "$OUT_DIR"
}

@test "render_skill substitutes SKILL_NAME and AGENT" {
  render_skill demo claude /root /bin "$OUT_DIR/SKILL.md"
  run grep -F "name: kstack-demo" "$OUT_DIR/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -F "agent: claude" "$OUT_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "render_skill substitutes INSTALL_ROOT and BIN_DIR" {
  render_skill demo claude /my/root /my/bin "$OUT_DIR/SKILL.md"
  run grep -F "install_root: /my/root" "$OUT_DIR/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -F "bin_dir: /my/bin" "$OUT_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "render_skill inlines both partials" {
  render_skill demo claude /root /bin "$OUT_DIR/SKILL.md"
  run grep -F "does one thing" "$OUT_DIR/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -F "check-update at session start" "$OUT_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "render_skill expands BIN_DIR inside update-check partial" {
  render_skill demo claude /root /opt/kstack/bin "$OUT_DIR/SKILL.md"
  run grep -F "Run /opt/kstack/bin/check-update" "$OUT_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "render_skill leaves no raw template markers" {
  render_skill demo claude /root /bin "$OUT_DIR/SKILL.md"
  run grep -F '{{' "$OUT_DIR/SKILL.md"
  [ "$status" -ne 0 ]
}

@test "render_skill creates output parent dir" {
  render_skill demo claude /root /bin "$OUT_DIR/nested/sub/SKILL.md"
  [ -f "$OUT_DIR/nested/sub/SKILL.md" ]
}
