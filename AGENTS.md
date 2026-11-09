# Agent notes

Bodega is a personal launcher for Windows games on Apple Silicon and Linux. For the full project guide (layers, commands, lines not to cross), read `.claude/CLAUDE.md`.

## Versioning

- The version lives in `apps/bodega/pubspec.yaml` as `version: X.Y.Z+N` (SemVer).
- Each fix raises the patch number (`Z`), each update or new feature raises the minor number (`Y`), and each breaking change raises the major number (`X`).
- Raise the version once per delivery, to the highest level it needs, with `tool/version.sh bump <patch|minor|major>`.
- Before every commit, and when you finish any fix, update or feature, use the `bump-version` skill and run `tool/version.sh check`. Do not commit if the check fails.
- Docs-only changes (`*.md`, `.sdd/`, `.claude/`) do not raise the version.
- The current version (1.0.0) is still unreleased until the first tag exists.

## Tags and releases

- Only the `tag-version` workflow creates `vX.Y.Z` tags. It runs on push to `main`.
- Never create, move or delete tags by hand (`git tag`, `git push --tags`), and never create them from other workflows.
- `release-linux` and `release-macos` upload the release files. Run them by hand, from the tag: pick it in "Use workflow from" (Tags tab). They build that tag, and fail if you run them from a branch.
- Commit and push still need the user's approval.

## GitHub Actions budget

The account is GitHub Free and the repository is private: about 12 USD a month of compute (roughly 2,000 Linux minutes, or 190 macOS minutes) and 500 MB of artifact storage. When you add or change a workflow:

- Put whatever can be optional behind a boolean `workflow_dispatch` input, off by default (see `smoke` in `release-linux` and `build_engine` in `release-macos`).
- Never chain a macOS job to another workflow: it costs ten times a Linux one.
- Give `upload-artifact` `retention-days: 1`, and keep big files out of artifacts where you can.
- Give PR workflows `concurrency` with `cancel-in-progress` and a short `timeout-minutes`.

## Installers

- `Bodega-X.Y.Z-macos-arm64.dmg` (built by `tool/package_macos.sh`)
- `Bodega-X.Y.Z-linux-amd64.deb`
- `Bodega-X.Y.Z-linux-x86_64.tar.gz`
- `Bodega-X.Y.Z-linux-x86_64.AppImage` (the Linux ones are built by `tool/package_linux.sh`)
- `Bodega-X.Y.Z-arch-x86_64.pkg.tar.zst` (Arch; `packaging/arch/build_arch.sh` wraps the `.tar.gz`, and `package_linux.sh` calls it where `makepkg` exists)
