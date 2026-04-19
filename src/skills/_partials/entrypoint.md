## Entrypoint

Before doing anything else this turn, run:

    {{ROOT_DIR}}/bin/entrypoint --skill-dir={{SKILL_DIR}} -- <user args verbatim>

Then inspect the exit code:

- **0** — If stdout ends with `=== END HELP ===`, the user asked for `--help`: print stdout verbatim (stopping at the sentinel) and end the turn. Do not restate or reformat. Otherwise continue: if stdout is non-empty, prepend it verbatim to your first reply (it is an update notice), then run the rest of this SKILL.md.
- **10** — Response complete. Print stdout verbatim and end the turn. Do not add commentary.
- **11** — User-facing error. Print stderr verbatim and end the turn.
- Any other non-zero — Print stderr, stop. Do not run the skill body.

If the user later says "upgrade kstack" / "install the update", run `{{ROOT_DIR}}/bin/upgrade` and report the result (idempotent). If the user says "dismiss" / "hide the notice", run `{{ROOT_DIR}}/bin/dismiss-update` and confirm.
