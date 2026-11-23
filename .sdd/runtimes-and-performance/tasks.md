# Tasks · runtimes-and-performance

**Conventions**
- `engine/` is `packages/engine/`, where `dart` runs. `lib/` and `test/` are `apps/bodega/`'s, where `flutter` runs.
- `<base>` is the commit T1 starts from.
- **Every task ends green:**
  - in `engine/`: `dart analyze && dart test`;
  - in `apps/bodega`, from T12 on: `flutter analyze && flutter test && tool/check_layers.sh`.
- Run `flutter gen-l10n` after an ARB edit, and build_runner after a Freezed or Injectable one.
- **(USER)** means only the user or the collaborator can do it. The agent never commits or pushes.

## M1 · Engine and CLI

- [x] **T1** Starting point (design §11).
  - **Needs:** the user has run `../dependencies-commit.sh`, and `git status --short` is empty.
  - **Does:** `git switch --no-track -c feat/runtimes-and-performance` from `feat/dependencies`.
  - **Check:** `git branch --show-current`; `git rev-parse --abbrev-ref '@{u}'` fails; `<base>` written here.
  - **2026-11-18:** the agent ran `../dependencies-commit.sh` at the user's word, after `dart test` (321 passed) and `flutter test` (810 passed). It pushed `feat/dependencies` and opened pull request #21 against `feat/switch-keys-firmware` (#20). `<base>` is f7f49e4. `@{u}` fails with `no upstream configured`.
- [x] **T2** The real files and their pins (RE2).
  - **Does:**
    - reads winetricks `20260125` again for each verb's facts;
    - downloads every new file once into `$BODEGA_HOME/downloads/` (Microsoft's DirectX file, .NET 4.8 and 4.0, PhysX, the eleven font packages, both `d3dcompiler_47`), with the GitHub copies at a commit;
    - writes down each size and SHA-256, and whether they equal winetricks' pins.
  - **Check:** the `shasum -a 256` lines, kept for `verify.md`.
  - **2026-11-18:** downloaded once into `downloads/`. Every file equals winetricks' pin (`load_*` at `20260125`) except the DirectX file, which is Microsoft's re-signed one.

    | `downloads/` | Bytes | SHA-256 | Source |
    |---|---|---|---|
    | `directx-jun2010.exe` | 100,275,120 | `053f76dcbb28802e23341b6a787e3b0791c0fa5c8d4d011b1044172dbf89c73b` | `download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe` (winetricks' mirror: 100,271,992, `8746ee1a…0c0d`) |
    | `dotnet48.exe` | 72,721,568 | `95889d6de3f2070c07790ad6cf2000d33d9a1bdfc6a381725ab82ab1c314fd53` | `download.visualstudio.microsoft.com/download/pr/7afca223-55d2-470a-8edc-6a1739ae3252/abd170b4b0ec15ad0222a809b761a036/ndp48-x86-x64-allos-enu.exe` |
    | `physx.exe` | 29,417,888 | `9b42b84e881769d681e09f62a1b51532616b2e6a2d5d99d0ccae6eb5fbbc208c` | `us.download.nvidia.com/Windows/9.23.1019/PhysX_9.23.1019_SystemSoftware.exe` |
    | `d3dcompiler_47-x86.dll` | 3,657,992 | `2ad0d4987fc4624566b190e747c9d95038443956ed816abfd1e2d389b5ec0851` | `raw.githubusercontent.com/mozilla/fxc2/9aba9b11079303d5577e0e3eb455f4d00f3b5946/dll/d3dcompiler_47_32.dll` (the files' last commit) |
    | `d3dcompiler_47-x64.dll` | 4,346,120 | `4432bbd1a390874f3f0a503d45cc48d346abc3a8c0213c289f4b615bf0ee84f3` | the same commit, `dll/d3dcompiler_47.dll` |
    | `corefonts-andale32.exe` | 198,384 | `0524fe42951adc3a7eb870e32f0920313c71f170c859b5f770d82b4ee111e970` | `raw.githubusercontent.com/pushcx/corefonts/8f8627b0004b5f1b952c09cf6390e4ae46475e59/<name>.exe` (its last commit) |
    | `corefonts-arial32.exe` | 554,208 | `85297a4d146e9c87ac6f74822734bdee5f4b2a722d7eaa584b7f2cbf76f478f6` | ″ |
    | `corefonts-arialb32.exe` | 168,176 | `a425f0ffb6a1a5ede5b979ed6177f4f4f4fdef6ae7c302a7b7720ef332fec0a8` | ″ |
    | `corefonts-comic32.exe` | 246,008 | `9c6df3feefde26d4e41d4a4fe5db2a89f9123a772594d7f59afd062625cd204e` | ″ |
    | `corefonts-courie32.exe` | 646,368 | `bb511d861655dde879ae552eb86b134d6fae67cb58502e6ff73ec5d9151f3384` | ″ |
    | `corefonts-georgi32.exe` | 392,440 | `2c2c7dcda6606ea5cf08918fb7cd3f3359e9e84338dc690013f20cd42e930301` | ″ |
    | `corefonts-impact32.exe` | 173,288 | `6061ef3b7401d9642f5dfdb5f2b376aa14663f6275e60a51207ad4facf2fccfb` | ″ |
    | `corefonts-times32.exe` | 661,728 | `db56595ec6ef5d3de5c24994f001f03b2a13e37cee27bc25c58f6f43e8f807ab` | ″ |
    | `corefonts-trebuc32.exe` | 357,200 | `5a690d9bb8510be1b8b4fe49f1f2319651fe51bbe54775ddddd8ef0bd07fdac9` | ″ |
    | `corefonts-verdan32.exe` | 351,992 | `c1cb61255e363166794e47664e2f21af8e3a26cb6346eb8d2ae2fa85dd5aad96` | ″ |
    | `corefonts-webdin32.exe` | 185,072 | `64595b5abc1080fba8610c5c34fab5863408e806aafe84653ca8575bed17d75a` | ″ |

    **Findings in the scratch bottle `runtimes-check`**
    - **DirectX.** The cabinet starts at byte 155,544 (`cbCabinet` 100,094,202), and `extrac32 /y /e /l` gives 157 files in about 2 s.
    - **D3DX9's inner cabinets.** The twenty `*d3dx9*x86*` cabinets give `d3dx9_24.dll`…`d3dx9_43.dll` in 8.5 s, extracted by one `cmd /c` batch file of `extrac32` lines, which starts Wine once instead of twenty times. The inner names mix case (`Jun2010_XACT_x86.cab`, `DEC2006_d3dx10_00_x86.cab`).
    - **The Arial package.** `arial32.exe`'s cabinet starts at byte 67,104 and holds `Arial.TTF`, `Arialbd.TTF`, `Arialbi.TTF` and `Ariali.TTF`.
    - **Fonts on the Mac.** A fresh bottle already has all eleven core families. Wine lists macOS's own copies (`/System/Library/Fonts/Supplemental/Arial.ttf` and the rest) in `user.reg`'s `[Software\\Wine\\Fonts\\External Fonts]`. This is spec change S1, below.
- [x] **T3** The table's new shape (RE1).
  - **Does:** `Download`, `DependencyKind`, `DependencyFile`, `Dependency.files`; the six rows moved; `dependencyArches` from `files.keys`; `_dependencyFile` accepts `all`.
  - **Check:** `dart test test/dependencies_test.dart` (RE1's cases, and every old case unchanged).
- [x] **T4** Status (RE3).
  - **Does:** `dependencyStatus` returning `bool?`; markers that are not PE files.
  - **Check:** `dart test test/dependencies_test.dart`.
- [x] **T5** Proposals (RE4).
  - **Does:** import patterns; "not in Wine" read from the runtime's two `lib/wine/*-windows/` folders; `all` rows.
  - **Check:** `dart test test/dependencies_test.dart` (the MFC cases still pass).
- [x] **T6** Installs (RE5, RE6, RE7).
  - **Does:**
    - several files;
    - `InstallTimedOut` and its English;
    - `cab` with the `MSCF` cut, `extrac32`, `take`, `into`, `register` and the clean-up;
    - `copy`;
    - the fake cabinet and the fake `extrac32` in the tests.
  - **Check:** `dart test test/dependencies_test.dart test/english_test.dart`.
  - **2026-11-18:** in `engine/`, `dart analyze` reports no issues and `dart test` gives 335 passed, 4 skipped. In T3–T6:
    - `DependencyFile` is a class with `run`, `cab` and `copy` constructors, so a row states only what its kind needs. `Download` and `Dependency` stay records, and `Dependency.files` is a map.
    - The tests' fake Wine gained `cmd` (it runs a batch's `extrac32` and `regsvr32` lines), `extrac32` (a fake cabinet is the 8-byte header and a tar), `regedit`, and `msiexec /x`.
- [x] **T7** `dotnet48` for real (design §10.1).
  - **Does:**
    - in a fresh scratch bottle, `deps install … dotnet48 all` with 4.8 alone;
    - adds winetricks' steps one at a time only if needed;
    - finds the 4.8-only marker file;
    - fills the row.
  - **Check:** the commands, outputs and times, for `verify.md`.
  - **2026-11-18:** the recipe is S3's, measured by hand first.
    - **Through the engine:** `build/bodega deps install runtimes-check dotnet48 all`, in the bottle where T8's items were already installed, took 434 s from its two downloads already in `downloads/`, and printed `dotnet48 all installed`.
    - **Afterwards:**
      - Wine Mono is gone;
      - `CurrentBuildNumber` is 19045 again (the bottle's own Windows 10);
      - `"mscoree"="native,builtin"` is in `user.reg`;
      - `Release`=528049.
    - **A real .NET program:** `csc.exe` (32-bit `Framework`) compiled a C# file, and the program printed `clr 4.0.30319.42000 64-bit`.
    - **Timing:** the earlier runs by hand took 1,950 s for 4.0 and 1,577 s for 4.8, so the time varies a lot under Rosetta. The 120-minute limit and "It can take up to an hour" stay.
- [x] **T8** The other rows for real (RE2, RC1).
  - **Does:**
    - fills `d3dx9`, `d3dx10`, `d3dx11_43`, `xact`, `d3dcompiler_47`, `physx` and `corefonts` with T2's pins;
    - finds PhysX's marker from a real install;
    - installs each item and arch headless in `runtimes-check`.
  - **Check:** `deps list` and the marker checks of RC1.
  - **2026-11-18:** `build/bodega deps install runtimes-check <id> <arch>` in a fresh bottle, headless, with T2's files already in `downloads/`.

    | Item | Time |
    |---|---|
    | `d3dx9` x86 / x64 | 36 s / 35 s |
    | `d3dx10` | 30 s / 29 s |
    | `d3dx11_43` | 18 s / 17 s |
    | `xact` | 65 s / 64 s |
    | `d3dcompiler_47` | 5 s / 6 s |
    | `physx all` | 13 s |
    | `corefonts all` | 14 s |

    - **`deps list`** then printed `installed` for every one of them. Before any install, it already printed `corefonts all installed`, through macOS's own fonts (S1).
    - **Clean-up:** no `windows/temp/bodega-*` folder is left.
    - **Fonts:** `windows/Fonts` holds the 30 core `.ttf` files in lowercase, and `"Arial (TrueType)"="arial.ttf"` is in both `Fonts` keys of `system.reg`.
    - **DLLs:** `user.reg` holds the overrides. `syswow64/d3dx9_43.dll` (1,998,168 B) and `system32/d3dx9_43.dll` (2,401,112 B) are Microsoft's.
    - **XACT:** the `xact x64` batch logs `regsvr32: Successfully registered DLL 'xaudio2_7.dll'`.
    - **The copy kind's log:** a copy runs nothing in Wine, so the CLI printed an empty `log:`. It now returns the log of its overrides' `reg` (RE7's test checks it).
- [x] **T9** Fonts (design §4).
  - **Does:** checks whether Wine finds Arial after the copy alone, and adds the registry pairs only if it doesn't.
  - **Check:** the check's output, for `verify.md`.
  - **2026-11-18:** replaced by S1. On the Mac, Wine already lists macOS's core fonts, so Core fonts counts as installed. The install still copies and registers the fonts, as winetricks does (T8).
- [x] **T10** DXVK on the Mac (RE8, RE9).
  - **Does:** `dxvkAsync` in `BottleSettings`, its JSON and `update`; the two variables in the Mac launch; the `dxvk-cache` folder; the AVX and msync env tests where missing.
  - **Check:** `dart test`.
  - **2026-11-18:** `HostCapabilities.dxvkAsync` (Mac true, Linux false) and `HostPlatform.dxvkEnv`. `_launchIn` adds them when the backend resolves to `dxvk`. AVX's launch test was already in `options_test.dart`, and msync's in `engine_test.dart`.
- [ ] **T11** CLI and M1 green (RE10).
  - **Does:** `all` and several files in `deps install`; `unknown` in `deps list`; the network test run once; `runtimes-check` stopped and removed.
  - **Check:**
    - `dart analyze && dart test`;
    - `BODEGA_NETWORK_TESTS=1 dart test test/dependencies_test.dart -n "server"`;
    - `dart compile exe bin/bodega.dart -o ../../build/bodega`.

  - **2026-11-18:**
    - **Done:** `deps install` takes `all` and several files; `deps list` prints `unknown`; `dart compile exe` builds. In `runtimes-check`, T7 and T8 used this CLI, and the bottle stays for RC5.
    - **Waits for the user's word:** the network test, which downloads about 340 MB again.

## M2 · App

- [x] **T12** Domain and errors (RA1, RA2).
  - **Does:** `Arch.all`, `DependencyStatus`, `checkedAt`, the list of paths, `HostCapabilities.dxvkAsync`, `installTimedOut`.
  - **Check:** build_runner; `flutter analyze`; `test/app/text_test.dart`.
- [x] **T13** Repository (RA3).
  - **Check:** `flutter test test/data/dependency_repository_test.dart`.
- [x] **T14** Bloc (RA4).
  - **Does:** `checkedAt` from an injected clock, `refresh`, `failedLog`.
  - **Check:** `flutter test test/app/dependencies_bloc_test.dart`.
- [x] **T15** Text (RA8).
  - **Does:** the ARB keys, and `dependency_text.dart`'s switches and table.
  - **Check:** `flutter gen-l10n`; `flutter test test/l10n_parity_test.dart test/app/text_test.dart`.
- [x] **T16** The section's list, "Checked at", "Check again", "Details", and the hand-picked mode removed (RA5, RA6).
  - **Check:** `flutter test test/app/dependencies_section_test.dart test/app/needs_dialog_test.dart`.
- [x] **T17** The async switch (RA7).
  - **Check:** the new widget cases.
- [x] **T18** M2 green (RA8).
  - **Does:** `pages_test.dart` with the list in `en` and `es`; runs the app in debug for the user.
  - **Check:** `flutter analyze && flutter test && tool/check_layers.sh`, with the output for `verify.md`.

**M2, 2026-11-18**
- **Checks:**
  - in `apps/bodega`: `flutter analyze` reports no issues, `flutter test` gives 816 passed, and `tool/check_layers.sh` says `Layers OK`;
  - in `engine/`: `dart test` gives 335 passed, 4 skipped.
- **New cases:**
  - `dependency_repository_test.dart`: several files with summed progress; unknown from an unreadable `syswow64`; `checkedAt`;
  - `dependencies_bloc_test.dart`: `failedLog` for the three failures; reading again;
  - `dependencies_section_test.dart`: the list per arch and for both, unknown without a button, "Checked at 3:04 PM" and "Check again", "Details" opening the log, and no "Choose the installer file…" for eleven files;
  - `text_test.dart`: statuses, `Arch.all`, each runtime's line, `installTimedOut`;
  - `bottle_detail_bloc_test.dart` and `pages_test.dart`: the async switch, on the Mac only.
- **The debug app runs again** for the user, with this change.

**Spec wording changed in M2** (same behaviour, less code):
- **RA4:** there is no `refresh` event. "Check again" sends `load`, which reads the bottle again. `checkedAt` is set by the repository when it reads the bottle (`DateTime.now()`), not by an injected clock in the bloc. The bloc test checks that a second `load` reads the bottle again.
- **RA7:** the switch is in the bottle's Settings only, not in the run options. It is a bottle setting, as DLSS is, and the run options carry only per-launch choices.
- **RE10's network test** still downloads every file again (about 340 MB). T2 already checked every pin against a real download, so it waits for the user's word (T11).
- **Proposals without a runtime:** with no runtime installed, nothing counts as missing from Wine, so imports are optional, as before. The app's repository tests have no runtime.

## M3 · Checks, rules and delivery

- [x] **T19** Rules (RC6).
  - **Does:** the lines in `.claude/CLAUDE.md` and `.claude/rules/architecture.md`.
  - **Check:** `git diff <base> -- .claude`; `git ls-files | grep -iE '\.(exe|msi|cab|ttf)$'`.
  - **2026-11-18:** one line in each file: vendors' servers, the two pinned copies, `extrac32`; and `downloads/<file>` with `files:`. `git ls-files | grep -iE '\.(exe|msi|cab|ttf)$'` prints nothing (exit 1).
- [ ] **T20** **(USER)** The panel in the app (RC5), and DXVK's options with a DXVK game (RC4).
  - **Check:** the agent reads the logs and the bottle; the results go in `verify.md`.
- [ ] **T21** **(USER: the collaborator)** Linux installs and performance (RC2, RC3).
  - **Does:** the collaborator runs these commands on x86_64 Linux (Ubuntu 24.04 or later), with Bodega's Linux package built from this branch (`tool/package_linux.sh`) installed, and passes on the output.
    ```
    git fetch && git switch feat/runtimes-and-performance
    (cd packages/engine && dart compile exe bin/bodega.dart -o ../../build/bodega)
    # RC2: installs, headless.
    build/bodega create rc2
    for item in "vcrun2022 x64" "d3dx9 x86" "xact x64" "d3dcompiler_47 x64" \
                "corefonts all" "physx all" "dotnet48 all"; do
      time build/bodega deps install rc2 $item
    done
    build/bodega deps list rc2
    build/bodega stop rc2   # then delete the bottle rc2 from Bodega
    # RC3: with a game running from Bodega.
    gamemoded -s            # GameMode on, then again with it off
    uname -r; ls -l /dev/ntsync
    ls -l /proc/$(pgrep -n wineserver)/fd | grep ntsync
    # MangoHud: with the HUD on, does the overlay show? (yes/no)
    ```
  - **Check:** the outputs pasted back.
- [ ] **T22** Delivery (RC7).
  - **Does:** `../runtimes-commit.sh`.
  - **Check:** `bash -n ../runtimes-commit.sh`; `tool/version.sh check`; the user runs it.
  - **2026-11-18:** `../runtimes-commit.sh` is written. It makes up to four commits (the version if it moves, M1, M2, the docs) with English messages and no attribution, and pushes nothing. `bash -n` passes, and `tool/version.sh check` says `OK: version 1.7.0 (tag v1.6.0)`. It waits for the user's word.
  - **2026-11-19:** the user asked to commit everything at the end. `../changes-commit.sh` replaces this script. It commits #15 from the patch taken before game-configurations (#16) began, then #16 (see `.sdd/game-configurations/tasks.md` T1 and T19).

## Spec changes found in apply (approved by the user on 2026-11-18)

- **S1 · Fonts** (design §3–§5, RE3, RC1). A `.ttf` marker also counts when Wine's `External Fonts` key in the prefix's `user.reg` names a file with the same base name, compared without case. On the Mac, Wine lists macOS's own core fonts there, so Core fonts reads "Installed" without any download. On Linux, it reads "Installed" when the host has them (for example `ttf-mscorefonts-installer`); otherwise its install copies the `.ttf` files in lowercase and registers each face as winetricks' `w_register_font` does, in both `Fonts` keys, through a single `regedit /S` of a `.reg` file. Wine can't be asked headless whether GDI sees a font, so design §4's GDI check gives way to this.
- **S2 · One Wine start per cabinet step** (design §4). The `cab` kind writes the `extrac32` lines (and `regsvr32` lines) to `bodega-<id>\run.bat`, each followed by `|| exit /b 1`, and runs `cmd /c` on it once. Measured on 2026-11-18 for XACT x86: the 33 `_xact_`, `_x3daudio_` and `_xaudio_` x86 cabinets give the 41 DLLs; they are copied in lowercase to `syswow64`, and one batch file of 27 `C:\windows\syswow64\regsvr32.exe /s` lines (the `xactengine*` DLLs and `xaudio2_0`…`xaudio2_7`) exits 0 in 14 s.
- **S3 · .NET 4.8's recipe** (design §3 and §10.1, RE2, RC1). This was measured on 2026-11-18 in fresh scratch bottles, headless, with T2's files.
  - **4.8 alone** exits 0 in 33 s and installs nothing. Its log says "`.NET Framework 4.8 or a later update is already installed`", for two reasons: Wine Mono writes `NDP\v4\Full` `Release`=533320, and on Windows 10 (build 19045) the installer treats 4.8 as part of the OS.
  - **Wine Mono out, then Windows 7.** Wine Mono comes out with `msiexec /x {0591009C-75D7-5F33-B5DF-4F47111155EC} /q` (7 s), its product code read from the `Uninstall` key whose `DisplayName` starts with `Wine Mono`. An `AppDefaults` version is not enough, because the installer reads `CurrentBuildNumber` from the registry, so the bottle's version has to be Windows 7 (`winecfg -v win7`). With both, 4.8 installs `clr.dll` in 59 s, but `mscoree.dll` stays Wine's, and `csc.exe` fails with "`Cannot determine common language runtime directory`". With Wine's `mscoree.dll` deleted, 4.8 brings none.
  - **What works, as winetricks does it:**
    1. Wine Mono out.
    2. Wine's `mscoree.dll` deleted from `system32` and `syswow64`.
    3. The bottle set to Windows 7.
    4. .NET 4.0 `/q /norestart`: exit 0, 1,950 s.
    5. .NET 4.8 `/q /norestart`: exit 0, 1,577 s.
    6. Wait while .NET compiles its native images (about 15 min more).
    7. The bottle set back to its own version.
    8. `mscoree` set to `native,builtin`.

    The result: Microsoft's `mscoree.dll` (444,752 and 297,808 bytes), `clr.dll` in `Framework` and `Framework64`, and `Release`=528049. `csc.exe` compiles a C# file in 68 s, and the program prints `clr 4.0.30319.42000 64-bit`.
  - **The change.**
    - `dotnet48`'s file `all` has two downloads, `dotnet40.exe` (Microsoft, 50,449,456 B, `65e064258f2e418816b304f646ff9e87af101e4c9552ab064bb74d281c38659f`, which is winetricks' pin) and then `dotnet48.exe`.
    - Before them, the steps above: Wine Mono out, Wine's `mscoree.dll` out, Windows 7, then back afterwards.
    - The limit is 120 min, and its one line in the panel says it can take up to an hour.
    - The marker is Microsoft's `clr.dll` plus `Release` ≥ 528040 under `[Software\\Microsoft\\NET Framework Setup\\NDP\\v4\\Full]` in `system.reg`. A 4.0 left alone by a failed 4.8 does not count, and Wine Mono has no `clr.dll`, so it does not count either.
    - The download grows to 123 MB.
- **S4 · PhysX's marker** (design §3 and §10.2). `physx.exe /s` exits 0 in 12 s. It puts NVIDIA's `PhysXLoader.dll` (75,304 B), `PhysXLoader64.dll`, `PhysXDevice*.dll` and the `PhysXCore.dll` of each engine version in `Program Files (x86)/NVIDIA Corporation/PhysX/`, and appends `C:\Program Files (x86)\NVIDIA Corporation\PhysX\Common` to the system `PATH`, which is how games find the loader. The marker is `Program Files (x86)/NVIDIA Corporation/PhysX/Common/PhysXLoader.dll`.
