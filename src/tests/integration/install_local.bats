#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  common_setup

  # Build a minimal fake kstack checkout mirroring the real layout: a
  # top-level install script plus src/{lib,bin,skills,...}.
  FAKE_ROOT="$TMPDIR_TEST/kstack"
  mkdir -p "$FAKE_ROOT/src/bin" "$FAKE_ROOT/src/lib" \
           "$FAKE_ROOT/src/skills/demo" "$FAKE_ROOT/src/skills/_partials"

  cp "$CHECKOUT_ROOT/install" "$FAKE_ROOT/install"
  cp "$REPO_ROOT/lib/agents.sh" "$FAKE_ROOT/src/lib/agents.sh"
  cp "$REPO_ROOT/lib/cache.sh" "$FAKE_ROOT/src/lib/cache.sh"
  cp "$FIXTURES_DIR/skills/demo/SKILL.md.tmpl" "$FAKE_ROOT/src/skills/demo/SKILL.md.tmpl"
  cp "$FIXTURES_DIR/skills/_partials/global-flags.md" "$FAKE_ROOT/src/skills/_partials/global-flags.md"
  cp "$FIXTURES_DIR/skills/_partials/update-check.md" "$FAKE_ROOT/src/skills/_partials/update-check.md"
  cp "$FIXTURES_DIR/README.md" "$FAKE_ROOT/README.md"
  cat > "$FAKE_ROOT/src/bin/hello" <<'EOF'
#!/usr/bin/env bash
echo hello
EOF
  chmod +x "$FAKE_ROOT/src/bin/hello" "$FAKE_ROOT/install"
}

@test "install --agent claude renders SKILL.md into .claude/skills/demo" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/demo/SKILL.md"
}

@test "install --agent claude uses local paths in template output" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F "install_root: $FAKE_ROOT/.kstack" "$FAKE_ROOT/.claude/skills/demo/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -F "bin_dir: $FAKE_ROOT/.kstack/bin" "$FAKE_ROOT/.claude/skills/demo/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "install materializes bin/ under .kstack" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$FAKE_ROOT/.kstack/bin/hello" ]
}

@test "install materializes lib/ under .kstack" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -f "$FAKE_ROOT/.kstack/lib/cache.sh" ]
}

@test "install writes install.conf under .kstack" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -f "$FAKE_ROOT/.kstack/install.conf" ]
}

@test "install --agent codex writes to .codex/skills/demo" {
  run "$FAKE_ROOT/install" --agent codex --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.codex/skills/demo/SKILL.md"
}

@test "install --agent=opencode writes to .config/opencode/skills" {
  run "$FAKE_ROOT/install" --agent=opencode --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.config/opencode/skills/demo/SKILL.md"
}

@test "install --agent nosuch exits 1 with 'Unknown agent'" {
  run "$FAKE_ROOT/install" --agent nosuch
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown agent: nosuch"* ]]
}

@test "install --agent without value exits 1" {
  run "$FAKE_ROOT/install" --agent
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing value for --agent"* ]]
}

@test "install rejects unknown option" {
  run "$FAKE_ROOT/install" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option: --bogus"* ]]
}

@test "install creates .kstack/cache in repo-local mode" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -d "$FAKE_ROOT/.kstack/cache" ]
}

@test "install with no skills/ directory exits 1" {
  rm -rf "$FAKE_ROOT/src/skills"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 1 ]
  [[ "$output" == *"No skills/ directory"* ]]
}

@test "install with missing global-flags partial exits 1" {
  rm "$FAKE_ROOT/src/skills/_partials/global-flags.md"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing partial"* ]]
}

@test "install with no agents auto-detected falls back to claude" {
  # Empty PATH: no agent CLIs visible.
  run env PATH="/usr/bin:/bin" "$FAKE_ROOT/install" --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/demo/SKILL.md"
}

@test "install --help prints usage and exits 0" {
  run "$FAKE_ROOT/install" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"kstack install"* ]]
  [[ "$output" == *"Usage:"* ]]
}

@test "install replaces stale symlink in skill slot" {
  mkdir -p "$FAKE_ROOT/.claude/skills"
  ln -s /nonexistent "$FAKE_ROOT/.claude/skills/demo" 2>/dev/null || skip "symlinks not supported"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ ! -L "$FAKE_ROOT/.claude/skills/demo" ]
  [ -f "$FAKE_ROOT/.claude/skills/demo/SKILL.md" ]
}

@test "install replaces stale file blocking skill slot" {
  mkdir -p "$FAKE_ROOT/.claude/skills"
  echo "stale" > "$FAKE_ROOT/.claude/skills/demo"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -f "$FAKE_ROOT/.claude/skills/demo/SKILL.md" ]
}

@test "install renders help.md under references/ alongside SKILL.md" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/demo/references/help.md"
}

@test "install creates references/ directory next to SKILL.md" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -d "$FAKE_ROOT/.claude/skills/demo/references" ]
}

@test "help.md contains the README skill body" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F "A fixture skill used by tests." "$FAKE_ROOT/.claude/skills/demo/references/help.md"
  [ "$status" -eq 0 ]
}

@test "help.md contains the global flags table" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F -e "--context <ctx>" "$FAKE_ROOT/.claude/skills/demo/references/help.md"
  [ "$status" -eq 0 ]
}

@test "help.md ends with END HELP sentinel" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  run tail -n 1 "$FAKE_ROOT/.claude/skills/demo/references/help.md"
  [[ "$output" == *"=== END HELP ==="* ]]
}

@test "SKILL.md skill_dir placeholder resolves to rendered slot path" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F "skill_dir: $FAKE_ROOT/.claude/skills/demo" "$FAKE_ROOT/.claude/skills/demo/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "install aborts when README has no section for a skill" {
  rm "$FAKE_ROOT/README.md"
  : > "$FAKE_ROOT/README.md"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -ne 0 ]
  [[ "$output" == *"no README section for /demo"* ]]
}

@test "install prunes orphan skill slot not backed by a source template" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  mkdir -p "$FAKE_ROOT/.claude/skills/ghost"
  echo "stale" > "$FAKE_ROOT/.claude/skills/ghost/SKILL.md"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_ROOT/.claude/skills/ghost" ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/demo/SKILL.md"
}

@test "install logs each pruned skill slot" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  mkdir -p "$FAKE_ROOT/.claude/skills/ghost"
  echo "stale" > "$FAKE_ROOT/.claude/skills/ghost/SKILL.md"
  run "$FAKE_ROOT/install" --agent claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"pruned: ghost"* ]]
}

@test "install leaves current skill slot intact on idempotent rerun" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/demo/SKILL.md"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/demo/SKILL.md"
}

@test "install copies skills/<name>/scripts/ into rendered slot as executable" {
  mkdir -p "$FAKE_ROOT/src/skills/demo/scripts"
  cat > "$FAKE_ROOT/src/skills/demo/scripts/snapshot" <<'EOF'
#!/usr/bin/env bash
echo snap
EOF
  chmod +x "$FAKE_ROOT/src/skills/demo/scripts/snapshot"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$FAKE_ROOT/.claude/skills/demo/scripts/snapshot" ]
}

@test "install omits scripts/ slot when source skill has no scripts dir" {
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_ROOT/.claude/skills/demo/scripts" ]
}

@test "install prunes stale scripts/ slot when source dir is removed" {
  mkdir -p "$FAKE_ROOT/src/skills/demo/scripts"
  echo "#!/usr/bin/env bash" > "$FAKE_ROOT/src/skills/demo/scripts/snapshot"
  chmod +x "$FAKE_ROOT/src/skills/demo/scripts/snapshot"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$FAKE_ROOT/.claude/skills/demo/scripts/snapshot" ]
  rm -rf "$FAKE_ROOT/src/skills/demo/scripts"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_ROOT/.claude/skills/demo/scripts" ]
}

@test "install prunes orphan scripts when source dir shrinks" {
  mkdir -p "$FAKE_ROOT/src/skills/demo/scripts"
  echo "#!/usr/bin/env bash" > "$FAKE_ROOT/src/skills/demo/scripts/snapshot"
  echo "#!/usr/bin/env bash" > "$FAKE_ROOT/src/skills/demo/scripts/extra"
  chmod +x "$FAKE_ROOT/src/skills/demo/scripts/snapshot" "$FAKE_ROOT/src/skills/demo/scripts/extra"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$FAKE_ROOT/.claude/skills/demo/scripts/extra" ]
  rm "$FAKE_ROOT/src/skills/demo/scripts/extra"
  run "$FAKE_ROOT/install" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$FAKE_ROOT/.claude/skills/demo/scripts/snapshot" ]
  [ ! -e "$FAKE_ROOT/.claude/skills/demo/scripts/extra" ]
}
