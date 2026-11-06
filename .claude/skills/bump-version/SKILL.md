---
name: bump-version
description: Use on any fix, update or new feature and before any commit, to raise the project's SemVer version in apps/bodega/pubspec.yaml.
---

# bump-version

Keeps the Bodega version in step with the work. The rules are in `AGENTS.md`.

1. Classify the work: fix -> patch; update or feature -> minor; breaking change -> major; docs-only -> none.
2. Run `tool/version.sh check`.
3. If it fails, or the work is a fix, update or feature, run `tool/version.sh bump <level>`. It compares against the last `vX.Y.Z` tag and never bumps twice, so repeating it is safe.
4. Run `tool/version.sh check` again and mention the new version in the final reply.
5. Never create, move or delete tags. Only the `tag-version` workflow creates them, on push to `main`.
6. If there is no tag yet, the current version (1.0.0) is still unreleased: nothing is bumped.
