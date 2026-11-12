# Bodega

Bodega is a launcher for Windows games on Apple Silicon Macs and on x86_64 Linux. It runs them with
Wine (x86_64 Wine under Rosetta 2 on the Mac) and picks a graphics backend for each game: Wine's own
wined3d, DXMT, DXVK, or Apple's D3DMetal on the Mac once you import it.

It is young and moves fast: it runs the games we play, and you should expect rough edges.

## What it does

- **Bottles.** Each bottle is its own Windows prefix with its own settings: graphics backend, sync
  mode, the Windows user name games see, and options per program.
- **Graphics backends.** Bodega reads each `.exe` to tell 32 from 64 bits and which DirectX it uses,
  picks a backend that fits, and warns you when the one you chose doesn't.
- **Catalog and fixes.** Known games and launchers come with tested settings, and per-game fixes come
  from [highball-db](https://github.com/gauthierpiarrette/highball-db) (CC0).
- **Anti-cheat status.** Each catalog entry shows its anti-cheat status from
  [AreWeAntiCheatYet](https://areweanticheatyet.com) before you install. Bodega never tries to get
  around anti-cheat.
- **Nintendo Switch games on the Mac.** Bodega works with Ryubing, an emulator you install yourself;
  if it is missing, Bodega links to Ryubing's official download page. You bring your own keys,
  firmware and games: Bodega only checks that they are there, and launches the games with Ryubing.
  It also opens Switch games you made into Mac apps with nxnative.
- **Gamepads** through SDL2.
- **Updates.** On macOS, and with the Linux AppImage, the app finds new releases and installs them
  after checking their SHA-256. Your bottles and settings stay.
- **A command-line tool**, `bodega`, built on the same engine as the app.

## Requirements

On a Mac:

- Apple Silicon (M1 or later) with Rosetta 2.
- macOS 14 Sonoma or later.

On Linux:

- x86_64, with Ubuntu 24.04 or later. Other distributions can use the `.tar.gz` or the
  AppImage, and Arch has its own package.
- Vulkan on a real GPU, and PulseAudio or PipeWire.

## Install

Download the latest release from the
[Releases page](https://github.com/dany021115/bodega/releases/latest).

**macOS.** Open `Bodega-<version>-macos-arm64.dmg` and drag Bodega to Applications. The app is not
notarized, so macOS blocks it the first time: open System Settings → Privacy & Security and click
**Open Anyway**.

**Linux.**

- `.deb`: `sudo apt install ./Bodega-<version>-linux-amd64.deb`
- AppImage: `chmod +x Bodega-<version>-linux-x86_64.AppImage`, then run it.
- `.tar.gz`: extract it and run `./bodega`.
- Arch: `sudo pacman -U Bodega-<version>-arch-x86_64.pkg.tar.zst`

The Linux section of [apps/bodega/README.md](apps/bodega/README.md#linux) has the details: data
folders, gamepads, ntsync, HUD.

### D3DMetal

D3DMetal is part of Apple's Game Porting Toolkit and has its own license, so Bodega never bundles or
downloads it. To use it, download the Game Porting Toolkit from Apple yourself and import it from
Bodega's backends screen. Its license is between you and Apple.

## Build from source

You need Flutter 3.47 (Dart 3.13), and Xcode on a Mac.

```
git clone https://github.com/dany021115/bodega.git
cd bodega/apps/bodega
dart run build_runner build --delete-conflicting-outputs
flutter run -d macos    # or: flutter run -d linux
```

The engine and the CLI:

```
cd packages/engine
dart test
dart compile exe bin/bodega.dart -o ../../build/bodega
```

The Wine engine is built by the `build-engine` workflow from the recipe in [wine/](wine/) (see
[wine/README.md](wine/README.md)). `tool/package_macos.sh` and `tool/package_linux.sh` package the
releases.

## Repository layout

| Path | What it holds |
|---|---|
| [apps/bodega](apps/bodega) | The Flutter app, for macOS and Linux |
| [packages/engine](packages/engine) | The engine (pure Dart) and the `bodega` CLI |
| [wine](wine) | The recipe and patches that build Wine and its host libraries |
| [packaging](packaging) | Packaging files for Linux (Debian, Arch, AppImage) and macOS |
| [tool](tool) | Versioning and packaging scripts |
| [.sdd](.sdd) | Specs, written before the code; finished ones are in `.sdd/archive/` |

## Contributing

- Everything in git is in English: code, comments, docs, specs, commit messages, branch names and
  pull requests.
- Versions follow SemVer, and only the `tag-version` workflow creates tags: see
  [AGENTS.md](AGENTS.md).
- Bodega doesn't help bypass anti-cheat, and doesn't use code or data from CrossOver's closed parts.
  CrossOver's LGPL Wine source is fine.

## License

Bodega is free software under the GNU General Public License, version 3 or later: see
[LICENSE](LICENSE).

The Wine build recipe and its patches in [wine/](wine/) are under the GNU Lesser General Public
License, version 2.1 or later, like Wine itself: see [wine/LICENSE](wine/LICENSE).

Releases bundle third-party components under their own licenses, among them Wine, DXVK, DXMT,
MoltenVK, vkd3d and SDL2: see [wine/NOTICE.md](wine/NOTICE.md) and
[packaging/linux/LICENSES](packaging/linux/LICENSES).

## Credits

- [Wine](https://www.winehq.org), and CodeWeavers for the LGPL Wine source of CrossOver that the
  macOS engine is built from.
- [Highball](https://github.com/gauthierpiarrette/highball), whose engine recipe and game data
  Bodega builds on.
- DXVK, DXMT, MoltenVK, vkd3d-proton, SDL and AreWeAntiCheatYet.

Bodega is not affiliated with Apple, CodeWeavers or Nintendo. CrossOver is a trademark of
CodeWeavers, D3DMetal and Game Porting Toolkit belong to Apple, and Nintendo Switch is a
trademark of Nintendo.
