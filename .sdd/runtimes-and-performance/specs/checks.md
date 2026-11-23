# Spec · Real checks, rules and delivery

Requirements RC1..RC7. **(USER)** marks what only the user, or the collaborator, can do: anything with a window, and anything on a Linux host. The agent runs Wine only headless.

## RC1 · Each new item for real, on the Mac (agent, headless)
In a scratch bottle (`build/bodega create runtimes-check`), the agent shall run `deps install` for each new item and arch. After each one, the agent checks:
- the marker is the vendor's file (no Wine mark, or a regular `.ttf`);
- `user.reg` holds the overrides;
- `deps list` prints `installed`;
- for `xact`, `regsvr32` exited 0.

Afterwards the agent checks the fonts, with design §4's GDI check. It records the time each install took, and .NET's steps and marker (design §10). Then it stops and deletes the bottle.
- **Check:** the commands and their output, in `verify.md`.

## RC2 · The same on Linux (USER: the collaborator)
On an x86_64 Linux host, with a build of this branch (`tool/package_linux.sh` or `flutter run -d linux`, and `dart compile exe` for the CLI), the same as RC1:
- `deps install` of `vcrun2022 x64`, `d3dx9 x86`, `xact x64`, `d3dcompiler_47 x64`, `corefonts all`, `physx all` and `dotnet48 all` in a scratch bottle;
- `deps list` afterwards;
- the bottle removed.

The output goes into `verify.md`.

## RC3 · Linux performance (USER: the collaborator)
On the same host, the collaborator runs a game or a program with a window and records:
- **GameMode:** `gamemoded -s` while it runs with GameMode on, and again with it off.
- **MangoHud:** whether the overlay shows with the HUD on.
- **NTSync:** `uname -r`, `ls -l /dev/ntsync`, and `ls -l /proc/$(pgrep -n wineserver)/fd | grep ntsync` while it runs.

Each result goes into `verify.md`. An option whose check shows no change is removed from the Linux UI in this change.

## RC4 · DXVK's options on the Mac (USER)
In a bottle with DXVK, the user plays a DXVK game twice, with `DXVK_LOG_LEVEL=info` in the bottle's variables and "Async shader compilation" on. The agent then reads `<exe>_d3d11.log` and `bottles/<b>/dxvk-cache/`, and checks:
- the first log holds `async compiler threads`;
- a `<exe>.dxvk-cache` file is in the folder;
- the second log holds `valid state cache entries`.

The user plays once more with the switch off, and the log must not hold `async compiler threads`. If a check fails, its option is removed in this change.

## RC5 · The panel in the app (USER)
In the debug app, the user checks these in a bottle:
- install D3DX9 (32-bit) and Core fonts from "All runtimes", with progress;
- see the status change and the "Checked at" time move;
- see "Check again" work.

The agent reads the bottle afterwards to confirm the markers.

## RC6 · Rules
**Rules**
- `.claude/CLAUDE.md`'s line on runtime installers shall say: vendors' own servers, except the core fonts and `d3dcompiler_47`, which come from the copies named in `dependencies.dart`, pinned by SHA-256; never stored in the repo or the packages.
- `architecture.md`'s download path shall read `downloads/<file>`.

**Checks**
- `git ls-files | grep -iE '\.(exe|msi|cab|ttf)$'` prints nothing.
- **Check:** `git diff <base> -- .claude`; that command.

## RC7 · Delivery
- `../runtimes-commit.sh` shall commit M1, M2 and the docs on `feat/runtimes-and-performance`, in English, with no AI attribution, and push nothing.
- `tool/version.sh check` passes.
- Issue #15 is closed only after `verify.md` shows RE1–RE10, RA1–RA8 and RC1–RC6 met, and the user agrees.
- **Check:** `bash -n ../runtimes-commit.sh`; `tool/version.sh check`; the user runs the script.
