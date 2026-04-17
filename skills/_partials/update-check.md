## Update notifications

Before your first response in this session, run `{{BIN_DIR}}/check-update --quiet`. If the command prints a line, prepend that line verbatim to your response, then continue with the user's request.

If the user accepts the update or says something like "upgrade kstack" / "install the update", run `{{BIN_DIR}}/upgrade` and report the result. The upgrade script is idempotent — safe to re-run at any time.

If the user says something like "dismiss", "hide the notice", or otherwise asks to stop being notified about the current available version, run `{{BIN_DIR}}/dismiss-update` and confirm. The notice will return automatically when a newer release is published.
