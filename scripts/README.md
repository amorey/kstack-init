# scripts/

## `clean.sh`

Wipes repo-local install artifacts (rendered skill directories, `.cache/`, legacy `.build/`) so you can re-run `./install` against a clean tree. Development-only; only touches gitignored paths.

## `install.sh`

Curl-pipe bootstrap hosted at `https://www.kubestack.xyz/install.sh`. Resolves the latest tagged release, clones a kstack-owned checkout at `~/.config/kstack/src/`, and hands off to the in-repo `install` script.

`scripts/install.sh` is the source of truth. A verbatim copy lives in the `kubetail-website` repo's static assets (served at the public URL). **When you edit `scripts/install.sh`, copy the updated file into `kubetail-website` and ship it.** There is no automated sync.

Treat edits here like edits to a release artifact: they affect every new global install the moment the website redeploys, so land them deliberately.
