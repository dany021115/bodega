# macOS package

`tool/package_macos.sh` builds `dist/Bodega-X.Y.Z-macos-arm64.dmg`, a disk image with `Bodega.app`, an `Applications` link and `README.txt` (this folder's file, for the end user).

## What the script does

1. Builds the app (`flutter build macos --release`) and the CLI (`dart compile exe`).
2. Seeds a temporary data directory with the CLI itself: `bodega install <engine> <hostlibs>`, `bodega sdl install`, `bodega backend install dxmt` and `bodega backend install dxvk`.
3. Copies the seeded runtimes and backends into the app, signs it ad hoc and writes the DMG.

## Requirements

- macOS on Apple Silicon (arm64), with Xcode.
- Flutter 3.47.
- Rosetta 2: `softwareupdate --install-rosetta --agree-to-license`.
- `gh` authenticated with access to this repo, unless you pass local tarballs.

## Usage

```
tool/package_macos.sh --engine ENGINE.tar.gz --hostlibs HOSTLIBS.tar.gz
tool/package_macos.sh [--engine-tag engine-TAG] [--hostlibs-tag hostlibs-TAG]
```

- Local mode: `--engine` and `--hostlibs` take files that have their `.sha256` next to them, as `bodega install` requires. The tags are ignored.
- Release mode (default): downloads the `.tar.gz` of the given tag, or of the newest `engine-*` and `hostlibs-*` release in this repo, into `packaging/macos/cache/`. That folder is gitignored.

## Layout inside the app

```
Bodega.app/Contents/
  MacOS/bodega-cli
  Resources/bundle/
    runtime/<id>/         Wine engine, from bodega install
    backends/dxmt/
    backends/dxvk/
```

On first launch, the app copies `Resources/bundle` into `~/Library/Application Support/Bodega` and removes the quarantine attribute.

## Signing

The app is signed ad hoc (`codesign --sign -`). It has no Developer ID and is not notarized, so macOS blocks the first launch. Users open it with right click, Open, or with `xattr -cr`, as `README.txt` explains.

## CI

The `release-macos` workflow (manual, `workflow_dispatch`) calls this script on a macOS arm64 runner, after optionally building the engine and host libraries with `build-engine` and `build-hostlibs`. It then uploads the DMG to the release.
