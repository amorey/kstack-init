#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  common_setup
  . "$REPO_ROOT/install"

  SKILLS_SRC="$FIXTURES_DIR/skills"
  GF="$SKILLS_SRC/_partials/global-flags.md"
  UC="$SKILLS_SRC/_partials/update-check.md"
  OUT="$TMPDIR_TEST/out/SKILL.md"
  mkdir -p "$TMPDIR_TEST/out"
}

render() {
  render_skill "$1" "$2" "$3" "$4" "$OUT" "$SKILLS_SRC" "$GF" "$UC"
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
