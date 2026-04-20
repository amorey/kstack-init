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

  # Build a minimal fake kstack checkout mirroring the real layout:
  # scripts/install plus src/{lib,bin,skills,...}.
  FAKE_ROOT="$TMPDIR_TEST/kstack"
  mkdir -p "$FAKE_ROOT/scripts" \
           "$FAKE_ROOT/src/bin" "$FAKE_ROOT/src/lib" "$FAKE_ROOT/src/schemas" \
           "$FAKE_ROOT/src/skills/demo" "$FAKE_ROOT/src/skills/_partials"

  cp "$REPO_ROOT/scripts/install" "$FAKE_ROOT/scripts/install"
  cp "$SRC_ROOT/lib/agents.sh" "$FAKE_ROOT/src/lib/agents.sh"
  cp "$SRC_ROOT/lib/cache.sh" "$FAKE_ROOT/src/lib/cache.sh"
  cp "$SRC_ROOT/schemas/response.schema.json" "$FAKE_ROOT/src/schemas/response.schema.json"
  cp "$FIXTURES_DIR/skills/demo/SKILL.md.tmpl" "$FAKE_ROOT/src/skills/demo/SKILL.md.tmpl"
  cp "$FIXTURES_DIR/skills/_partials/global-flags.md" "$FAKE_ROOT/src/skills/_partials/global-flags.md"
  cp "$FIXTURES_DIR/skills/_partials/entrypoint.md" "$FAKE_ROOT/src/skills/_partials/entrypoint.md"
  cp "$FIXTURES_DIR/README.md" "$FAKE_ROOT/README.md"
  cat > "$FAKE_ROOT/src/bin/hello" <<'EOF'
#!/usr/bin/env bash
echo hello
EOF
  chmod +x "$FAKE_ROOT/src/bin/hello" "$FAKE_ROOT/scripts/install"
  INSTALL="$FAKE_ROOT/scripts/install"
}

@test "install --agent claude renders SKILL.md into .claude/skills/kstack-demo" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/kstack-demo/SKILL.md"
}

@test "install --agent claude uses local paths in template output" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F "install_root: $FAKE_ROOT/.kstack" "$FAKE_ROOT/.claude/skills/kstack-demo/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -F "bin_dir: $FAKE_ROOT/.kstack/bin" "$FAKE_ROOT/.claude/skills/kstack-demo/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "install materializes bin/ under .kstack" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$FAKE_ROOT/.kstack/bin/hello" ]
}

@test "install materializes entrypoint into .kstack/bin with exec bit" {
  cp "$SRC_ROOT/bin/entrypoint" "$FAKE_ROOT/src/bin/entrypoint"
  chmod +x "$FAKE_ROOT/src/bin/entrypoint"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$FAKE_ROOT/.kstack/bin/entrypoint" ]
}

@test "rendered SKILL.md contains the entrypoint invocation" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F "$FAKE_ROOT/.kstack/bin/entrypoint" "$FAKE_ROOT/.claude/skills/kstack-demo/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -F -- "--skill-dir=$FAKE_ROOT/.claude/skills/kstack-demo" "$FAKE_ROOT/.claude/skills/kstack-demo/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "install materializes lib/ under .kstack" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -f "$FAKE_ROOT/.kstack/lib/cache.sh" ]
}

@test "install writes install.conf under .kstack" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -f "$FAKE_ROOT/.kstack/install.conf" ]
}

@test "install --agent codex writes to .codex/skills/kstack-demo" {
  run "$INSTALL" --agent codex --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.codex/skills/kstack-demo/SKILL.md"
}

@test "install --agent=opencode writes to .config/opencode/skills" {
  run "$INSTALL" --agent=opencode --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.config/opencode/skills/kstack-demo/SKILL.md"
}

@test "install --agent nosuch exits 1 with 'Unknown agent'" {
  run "$INSTALL" --agent nosuch
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown agent: nosuch"* ]]
}

@test "install --agent without value exits 1" {
  run "$INSTALL" --agent
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing value for --agent"* ]]
}

@test "install rejects unknown option" {
  run "$INSTALL" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option: --bogus"* ]]
}

@test "install creates .kstack/cache in dev mode" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -d "$FAKE_ROOT/.kstack/cache" ]
}

@test "install with no skills/ directory exits 1" {
  rm -rf "$FAKE_ROOT/src/skills"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 1 ]
  [[ "$output" == *"No skills/ directory"* ]]
}

@test "install with missing global-flags partial exits 1" {
  rm "$FAKE_ROOT/src/skills/_partials/global-flags.md"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing partial"* ]]
}

@test "install with no agents auto-detected falls back to claude" {
  # Empty PATH: no agent CLIs visible.
  run env PATH="/usr/bin:/bin" "$INSTALL" --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/kstack-demo/SKILL.md"
}

@test "install --help prints usage and exits 0" {
  run "$INSTALL" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"kstack install"* ]]
  [[ "$output" == *"Usage:"* ]]
}

@test "install replaces stale symlink in skill slot" {
  mkdir -p "$FAKE_ROOT/.claude/skills"
  ln -s /nonexistent "$FAKE_ROOT/.claude/skills/kstack-demo" 2>/dev/null || skip "symlinks not supported"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ ! -L "$FAKE_ROOT/.claude/skills/kstack-demo" ]
  [ -f "$FAKE_ROOT/.claude/skills/kstack-demo/SKILL.md" ]
}

@test "install replaces stale file blocking skill slot" {
  mkdir -p "$FAKE_ROOT/.claude/skills"
  echo "stale" > "$FAKE_ROOT/.claude/skills/kstack-demo"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -f "$FAKE_ROOT/.claude/skills/kstack-demo/SKILL.md" ]
}

@test "install renders help.md under references/ alongside SKILL.md" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/kstack-demo/references/help.md"
}

@test "install creates references/ directory next to SKILL.md" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -d "$FAKE_ROOT/.claude/skills/kstack-demo/references" ]
}

@test "help.md contains the README skill body" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F "A fixture skill used by tests." "$FAKE_ROOT/.claude/skills/kstack-demo/references/help.md"
  [ "$status" -eq 0 ]
}

@test "help.md contains the global flags table" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F -e "--context <ctx>" "$FAKE_ROOT/.claude/skills/kstack-demo/references/help.md"
  [ "$status" -eq 0 ]
}

@test "help.md does not carry the legacy END HELP sentinel" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F "=== END HELP ===" "$FAKE_ROOT/.claude/skills/kstack-demo/references/help.md"
  [ "$status" -ne 0 ]
}

@test "install copies response schema into ROOT_DIR/schemas" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -f "$FAKE_ROOT/.kstack/schemas/response.schema.json" ]
  run grep -F 'kstack script response envelope' "$FAKE_ROOT/.kstack/schemas/response.schema.json"
  [ "$status" -eq 0 ]
}

@test "SKILL.md skill_dir placeholder resolves to rendered slot path" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  run grep -F "skill_dir: $FAKE_ROOT/.claude/skills/kstack-demo" "$FAKE_ROOT/.claude/skills/kstack-demo/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "install aborts when README has no section for a skill" {
  rm "$FAKE_ROOT/README.md"
  : > "$FAKE_ROOT/README.md"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -ne 0 ]
  [[ "$output" == *"no README section for /demo"* ]]
}

@test "install prunes orphan kstack-* skill slot not backed by a source template" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  mkdir -p "$FAKE_ROOT/.claude/skills/kstack-ghost"
  echo "stale" > "$FAKE_ROOT/.claude/skills/kstack-ghost/SKILL.md"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_ROOT/.claude/skills/kstack-ghost" ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/kstack-demo/SKILL.md"
}

@test "install preserves non-kstack skill slot in the shared skills dir" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  mkdir -p "$FAKE_ROOT/.claude/skills/user-own"
  echo "mine" > "$FAKE_ROOT/.claude/skills/user-own/SKILL.md"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/user-own/SKILL.md"
}

@test "install logs each pruned skill slot" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  mkdir -p "$FAKE_ROOT/.claude/skills/kstack-ghost"
  echo "stale" > "$FAKE_ROOT/.claude/skills/kstack-ghost/SKILL.md"
  run "$INSTALL" --agent claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"pruned: kstack-ghost"* ]]
}

@test "install leaves current skill slot intact on idempotent rerun" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/kstack-demo/SKILL.md"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  assert_file_exists "$FAKE_ROOT/.claude/skills/kstack-demo/SKILL.md"
}

@test "install copies skills/<name>/scripts/ into rendered slot as executable" {
  mkdir -p "$FAKE_ROOT/src/skills/demo/scripts"
  cat > "$FAKE_ROOT/src/skills/demo/scripts/snapshot" <<'EOF'
#!/usr/bin/env bash
echo snap
EOF
  chmod +x "$FAKE_ROOT/src/skills/demo/scripts/snapshot"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$FAKE_ROOT/.claude/skills/kstack-demo/scripts/snapshot" ]
}

@test "install mirrors skills/<name>/scripts/ subdirs (e.g. scripts/lib)" {
  mkdir -p "$FAKE_ROOT/src/skills/demo/scripts/lib"
  echo "#!/usr/bin/env bash" > "$FAKE_ROOT/src/skills/demo/scripts/snapshot"
  chmod +x "$FAKE_ROOT/src/skills/demo/scripts/snapshot"
  echo "helper() { echo hi; }" > "$FAKE_ROOT/src/skills/demo/scripts/lib/helper.sh"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$FAKE_ROOT/.claude/skills/kstack-demo/scripts/snapshot" ]
  [ -f "$FAKE_ROOT/.claude/skills/kstack-demo/scripts/lib/helper.sh" ]
}

@test "install rebuilds scripts/ slot when source files are removed" {
  mkdir -p "$FAKE_ROOT/src/skills/demo/scripts/lib"
  echo "#!/usr/bin/env bash" > "$FAKE_ROOT/src/skills/demo/scripts/snapshot"
  chmod +x "$FAKE_ROOT/src/skills/demo/scripts/snapshot"
  echo "x=1" > "$FAKE_ROOT/src/skills/demo/scripts/lib/helper.sh"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -d "$FAKE_ROOT/.claude/skills/kstack-demo/scripts/lib" ]
  rm -rf "$FAKE_ROOT/src/skills/demo/scripts/lib"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_ROOT/.claude/skills/kstack-demo/scripts/lib" ]
  [ -x "$FAKE_ROOT/.claude/skills/kstack-demo/scripts/snapshot" ]
}

@test "install omits scripts/ slot when source skill has no scripts dir" {
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_ROOT/.claude/skills/kstack-demo/scripts" ]
}

@test "install prunes stale scripts/ slot when source dir is removed" {
  mkdir -p "$FAKE_ROOT/src/skills/demo/scripts"
  echo "#!/usr/bin/env bash" > "$FAKE_ROOT/src/skills/demo/scripts/snapshot"
  chmod +x "$FAKE_ROOT/src/skills/demo/scripts/snapshot"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$FAKE_ROOT/.claude/skills/kstack-demo/scripts/snapshot" ]
  rm -rf "$FAKE_ROOT/src/skills/demo/scripts"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_ROOT/.claude/skills/kstack-demo/scripts" ]
}

@test "install prunes orphan scripts when source dir shrinks" {
  mkdir -p "$FAKE_ROOT/src/skills/demo/scripts"
  echo "#!/usr/bin/env bash" > "$FAKE_ROOT/src/skills/demo/scripts/snapshot"
  echo "#!/usr/bin/env bash" > "$FAKE_ROOT/src/skills/demo/scripts/extra"
  chmod +x "$FAKE_ROOT/src/skills/demo/scripts/snapshot" "$FAKE_ROOT/src/skills/demo/scripts/extra"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$FAKE_ROOT/.claude/skills/kstack-demo/scripts/extra" ]
  rm "$FAKE_ROOT/src/skills/demo/scripts/extra"
  run "$INSTALL" --agent claude --quiet
  [ "$status" -eq 0 ]
  [ -x "$FAKE_ROOT/.claude/skills/kstack-demo/scripts/snapshot" ]
  [ ! -e "$FAKE_ROOT/.claude/skills/kstack-demo/scripts/extra" ]
}
