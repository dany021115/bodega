# Automatic versioning and installer workflows

Current version: 1.0.0 (`apps/bodega/pubspec.yaml`, line `version: 1.0.0+1`). This work doesn't change it.

Delivery rule: nothing on macOS is tested (there is no Mac). The macOS parts are written from reading the code.

## Flow

```
push to main ──► tag-version ──► creates vX.Y.Z (only if it doesn't exist)
                                          │
  release-linux (by hand, tag=vX.Y.Z)       release-macos (by hand, tag=vX.Y.Z)
   build   -> .deb, .tar.gz, AppImage         resolve -> engine-* and hostlibs-* from this repo
   release -> uploads to the vX.Y.Z release    (optional: build them first)
                                               package -> Bodega-X.Y.Z-macos-arm64.dmg
                                               release -> uploads to the vX.Y.Z release
```

## Requirements (EARS)

| ID | Requirement |
|---|---|
| R1 | When a push reaches `main` and the version in `apps/bodega/pubspec.yaml` has no `vX.Y.Z` tag, `tag-version` shall create that annotated tag on that commit. If it already exists, it shall do nothing. It is only triggered by a push to `main`. |
| R2 | `release-linux` and `release-macos` shall only be started by hand, with a `tag` input. They shall check out that tag and reject one that is not `vX.Y.Z` or that is not in the history of `main`. |
| R3 | `release-macos` shall produce `Bodega-X.Y.Z-macos-arm64.dmg` with `Bodega.app` (arm64, ad hoc signature), which carries Wine, hostlibs, DXMT, DXVK, SDL2 and the CLI inside. |
| R4 | On first launch on macOS, the app shall register the bundled runtime and layers by copying them to `~/Library/Application Support/Bodega` and removing the quarantine, so that the Setup screen doesn't appear (Rosetta is still checked). |
| R5 | `release-macos` shall take the engine and hostlibs from releases of this repo (`engine-*` and `hostlibs-*`, by explicit tag or the most recent one) and may build them first with `build_engine` and `build_hostlibs` (off by default). |
| R6 | `release-linux` shall produce `Bodega-X.Y.Z-linux-amd64.deb`, `Bodega-X.Y.Z-linux-x86_64.tar.gz` and `Bodega-X.Y.Z-linux-x86_64.AppImage`. |
| R7 | The `release` job of each workflow shall create the `vX.Y.Z` release if it is missing (with generated notes) and upload its files, replacing those with the same name. |
| R8 | `tool/package_macos.sh` shall build the DMG locally with the same pieces (local files, or files downloaded from the releases). The workflow calls it. |
| R9 | `tool/version.sh` shall have `get`, `bump patch\|minor\|major` and `check`. |
| R10 | The `bump-version` skill and `AGENTS.md` shall require bumping the version with each fix (patch), update or feature (minor) and incompatible change (major), and running `tool/version.sh check` before each commit. Creating tags by hand is forbidden. |
| R11 | The version stays at 1.0.0 with this work. |
| R12 | The engine error that points to `dany021115/bodega-engine` shall point to this repo's releases. |

## Acceptance criteria

Static (checked without Flutter or a Mac):

- S1: `bash -n` of all the scripts, and `apps/bodega/tool/check_layers.sh`.
- S2: the workflows are valid YAML. `tag-version` only has `push` with `branches: [main]`. The `release-*` ones only have `workflow_dispatch`. `build.yml` and `build-hostlibs.yml` keep `workflow_dispatch` and add `workflow_call`.
- S3: `tool/version.sh get` prints `1.0.0`; `check` exits with 0 when there are no tags; `bump` on a temporary copy resets the lower numbers.
- S4: `git tag` only appears in `tag-version.yml`, `AGENTS.md` and the skill.
- S5: the installer names carry the version and the system.

Manual (the user runs them): run the workflows; open the `.dmg` on a Mac and check that Setup doesn't show up.

## tool/version.sh

Version file: `apps/bodega/pubspec.yaml`, line `version: X.Y.Z+N`.

- `get`: prints `X.Y.Z`.
- `bump patch|minor|major`: base = the version of the latest `vX.Y.Z` tag (`git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*'`). Target = the base bumped at that level (patch: `x.y.z+1`; minor: `x.y+1.0`; major: `x+1.0.0`). If the current version is already greater than or equal to the target, it changes nothing and says so. If not, it writes the target and increments `N` by one. Without tags, the current version hasn't been published yet: it changes nothing and says so. That way the version is bumped only once per delivery, at the highest level needed.
- `check`: without tags, it exits with 0. With a tag: if the version is lower than the tag's, it fails; if it is equal and there are product changes since the tag (files modified relative to the tag, or untracked, other than `.sdd/`, `.claude/`, `AGENTS.md` and `*.md`), it fails with a message saying what to do (`tool/version.sh bump <level>`); if it is greater, it exits with 0.

Levels: patch = a bug fix; minor = a new feature or an improvement; major = an incompatible change (data or bottle format, a removed feature).

## Workflows

All the `release-*` workflows and `tag-version` go in `.github/workflows/`.

`tag-version.yml`: `on: push: branches: [main]`, `permissions: contents: write`, `concurrency: tag-version`. One job on `ubuntu-24.04`: checkout with `fetch-depth: 0`, `ver=$(tool/version.sh get)`, `tag=v$ver`; if `refs/tags/$tag` exists, it stops; if not, `git tag -a "$tag" -m "Bodega $ver" "$GITHUB_SHA"` and `git push origin "refs/tags/$tag"` with the `github-actions[bot]` identity. With `if: github.ref == 'refs/heads/main'`.

`release-linux.yml` (replaces `package-linux.yml`): `on: workflow_dispatch` with a `tag` input (required). Jobs: `build` (ubuntu-24.04) checks the tag, checks it out, installs dependencies, runs `tool/package_linux.sh` and uploads `dist/*` as an artifact; `release` (needs build) downloads the artifact and runs `gh release view "$TAG" || gh release create "$TAG" --title "Bodega ${TAG#v}" --generate-notes` and `gh release upload "$TAG" dist/* --clobber`.

`release-macos.yml`: `on: workflow_dispatch` with the inputs `tag` (required), `engine_tag` and `hostlibs_tag` (empty = the most recent release in this repo whose tag starts with `engine-` or `hostlibs-`), and `build_engine` and `build_hostlibs` (booleans, false by default). Jobs: `engine` (if `build_engine`) and `hostlibs` (if `build_hostlibs`) call `build.yml` and `build-hostlibs.yml` with `workflow_call` and `publish_release: true`; `package` (runner `macos-15`, arm64; it needs the previous ones, with `if: always() && !failure() && !cancelled()`) checks the tag, checks it out, installs Rosetta (`softwareupdate --install-rosetta --agree-to-license`) and Flutter 3.47.x, resolves the tags, and runs `tool/package_macos.sh`; `release` is the same as on Linux. If there is no `engine-*` or `hostlibs-*` release and the build inputs are off, `package` fails with a message that says what to run.

Tag validation in both (initial job): it matches `^v[0-9]+\.[0-9]+\.[0-9]+$`, it exists, and `git merge-base --is-ancestor "$tag" origin/main` passes.

`build.yml` and `build-hostlibs.yml`: they add `workflow_call` with the same inputs (`publish_release`, `ref_note`) and replace `github.event.inputs.X` with `inputs.X`.

## macOS: DMG contents and first launch

DMG (`hdiutil create -format UDZO`): `Bodega.app` and a link to `/Applications`. Name: `Bodega-X.Y.Z-macos-arm64.dmg`.

Inside the app: `Contents/MacOS/bodega-cli` (the CLI), and `Contents/Resources/bundle/` with the same layout as the Linux package: `runtime/<id>/{engine,renderers?,frameworks?,...}` (what `bodega install` produces) and `backends/<name>/wine` (dxmt and dxvk).

`tool/package_macos.sh`: builds the app (`flutter build macos --release`, after `pub get` and `build_runner`) and the CLI (`dart compile exe`); creates a temporary `BODEGA_HOME` and seeds it with the CLI itself: `bodega install <engine> <hostlibs>`, `bodega sdl install`, `bodega backend install dxmt`, `bodega backend install dxvk`; copies `runtimes/*` to `bundle/runtime/` and `backends/*` to `bundle/backends/`; signs ad hoc (`codesign --force --deep --sign -`); creates the DMG in `dist/`. The tarballs come from `--engine`/`--hostlibs` (local files with their `.sha256` next to them) or, if those aren't passed, from `gh release download` with `--engine-tag`/`--hostlibs-tag` (or the most recent `engine-*`/`hostlibs-*`).

First launch (`MacPlatform.prepareHome`): root = `$BODEGA_BUNDLE` or `Contents/Resources/bundle` (two levels above the executable: `File(Platform.resolvedExecutable).parent.parent.path + '/Resources/bundle'`). Linux's registration of the bundled pieces is reused, always with `copy: true`, and after copying each folder the quarantine is removed with `xattr -dr com.apple.quarantine` (if `xattr` doesn't exist, this is skipped). The copy is synchronous, happens only once, and takes a few seconds.

Test constructor: `LinuxPlatform({mangoHud, bundle})` and `MacPlatform({bundle})`; `bundle` replaces the detection through the environment and the executable.

## File names (Linux)

`tool/package_linux.sh` produces `Bodega-X.Y.Z-linux-amd64.deb`, `Bodega-X.Y.Z-linux-x86_64.tar.gz` and `Bodega-X.Y.Z-linux-x86_64.AppImage` (previously `bodega_X.Y.Z_amd64.deb`, `bodega-X.Y.Z-linux-x86_64.tar.gz`, `Bodega-X.Y.Z-x86_64.AppImage`). The Linux README is updated with the new names.
