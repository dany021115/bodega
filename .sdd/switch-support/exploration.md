# Exploration: switch-support

Phase: explore. Sources: a research report on the emulators, the frontends and the law (in Spanish, kept out of the repo because its source list links emulator downloads), and three read-only code maps (engine; app; platforms, packaging and rules), re-checked against the code on 2026-11-10. No code was changed.

Paths: `engine/` is `packages/engine/`; `lib/`, `test/` and `macos/` are under `apps/bodega/`; other paths (`LICENSE`, `README.md`) start at the repo root. Dart file names are unique, so tables use bare names once the folder is clear. i18n is being applied on this branch (`feat/i18n`): M1 (T1–T12) is committed (60e545a), M2 and M3 are open (`.sdd/i18n/tasks.md:37-85`), so lines under `lib/` may move. Outside sources are named by project, file and commit, never linked: the repo is public, and Nintendo's notices target whoever "offer, link to, or otherwise provide access to" Switch emulators. Only legal documents carry links.

## 1. Problem

- Bodega runs Windows games only, each in a Wine bottle, and every layer assumes it: an app has a bottle (`engine/lib/apps.dart:6-15`, `lib/domain/entities/library_app.dart:8`), every launch runs `wine` (`apps.dart:398-409`, `engine.dart:448`), "running" means the bottle's `wineserver` is busy (`engine.dart:635-649`, `library_state.dart:10`), and the app gets past `/setup` only with the Wine runtime and no host issue (`setup_state.dart:18`, `router.dart:39-49`).
- The user wants Nintendo Switch games. On macOS they run through an emulator the user installs, natively: no Wine, no bottle, no Rosetta. Ryubing (the Ryujinx continuation) first, Eden later. Linux comes later, so the structure must leave room for it.
- Bodega is public on GitHub under the GPL-3.0-or-later (`.claude/CLAUDE.md:3`), and so are its releases and the update check (`AGENTS.md:15-18`, `update_repository_impl.dart:20`). Nintendo's 2026 DMCA notices target repos that "offer, link to, or otherwise provide access to" Switch emulators, and GitHub applies them to whole fork networks (§3). The law shapes this change as much as the code.

What switch-support means for Bodega:

1. Find the emulator the user installed, read its version, and say what is missing (the emulator, `prod.keys`, firmware, a first launch macOS has not approved) by checking that files exist, never reading them. It is the D3DMetal rule, "the user imports their own copy" (`.claude/CLAUDE.md:64`), without D3DMetal's download link.
2. Keep the user's game files as a list of paths, titled from the file name. Never copy, open or decrypt them.
3. Launch a game through the emulator, follow it with the `.log`/`.exit` contract Wine launches use (`engine.dart:429-434`), stop it, and find it again after Bodega restarts.
4. Show Switch games and their status in the app, in English and Spanish, and in the CLI.
5. Ryubing on the Mac first. Eden and Linux arrive as new data and one host implementation, not new logic.

## 2. What exists outside

### Emulators (10 Nov 2026)

| Emulator | Origin, license | State | macOS (Apple Silicon) | Linux x86_64 |
|---|---|---|---|---|
| **Ryubing** (still called "Ryujinx") | Ryujinx's continuation, MIT | active; stable 1.3.3 (11 Oct 2025), a canary per commit | a universal `Ryujinx.app`; "Only Apple Silicon Macs are properly supported" (its download page) | tar.gz, AppImage; a Flathub package its own log calls unofficial (`src/Ryujinx/Program.cs`), frozen since its packaging repo fell (§3) |
| **Eden** | yuzu's line, GPL-3.0 (`GPL-3.0-or-later` headers) | active; v0.2.1 (1 Jun 2026) and nightlies | a DMG, "experimental, and you should expect major graphical glitches and crashes" (its release notes) | AppImages in several variants; Flathub `dev.eden_emu.eden` |
| Hydra | new, Mac only (Metal), GPL-3.0 | v0.4.2, "very early stages" | its release cannot open a given game from outside; its README asks for converted NSPs and decrypted firmware | no |
| Kenji-NX | a Ryujinx fork, MIT | 2.0.5 (Oct 2025) | yes; CLI unchecked; named in the Feb 2026 notice | yes |
| Citron, Sudachi, suyu, torzu | yuzu forks | no official channel that answers | | |

ES-DE reached the same answer: its `switch` system carries only Eden (default) and Ryujinx (`USERGUIDE.md`).

### Ryubing and Eden, as Bodega needs them

Read at Ryubing commit `a61a426` (2 Nov 2026) and Eden commit `89d1a1c` (10 Nov 2026).

| | Ryubing | Eden |
|---|---|---|
| macOS app | `Ryujinx.app/Contents/MacOS/Ryujinx` (`distribution/macos/create_app_bundle.sh`); `org.ryujinx.Ryujinx`, macOS 12.0+, opens `.nca .nro .nso .nsp .xci` (`distribution/macos/Info.plist`) | `eden.app/Contents/MacOS/eden`, deduced from `OUTPUT_NAME "eden"` (`src/yuzu/CMakeLists.txt`) and ES-DE's rule; id `com.yuzu-emu.yuzu`, old yuzu's, so the id alone does not tell them apart (`src/yuzu/Info.plist`) |
| Open a game | `Ryujinx <game>`; `-f/--fullscreen`, `-r/--root-data-dir`, `-p/--profile`, `-g/--graphics-backend`, `-i/--application-id`, `--docked-mode`/`--handheld-mode`; never `--install-firmware` (`src/Ryujinx/Utilities/CommandLineState.cs`) | `eden <game>` or `-g/--game <game>`; `-f/--fullscreen`, `-u/--user` (`src/core/launch_params.cpp`, `docs/user/CommandLine.md`); `-i` is declared without its argument: avoid it |
| Headless | `--no-gui` with `--root-data-dir`, `--profile`, `--fullscreen`, `--use-main-config` (the UI's settings), `--input-profile-1…8`; the game is required, and the process ends when its window closes (`src/Ryujinx/Headless/Options.cs`, `HeadlessRyujinx.cs`) | `eden-cli`, the SDL front end, takes the same arguments |
| Data folder | macOS `~/Library/Application Support/Ryujinx`, Linux `~/.config/Ryujinx`; `portable/` beside the executable or the `.app`; `-r`, which falls back to normal when missing (`src/Ryujinx.Common/Configuration/AppDataManager.cs`) | `$XDG_DATA_HOME/eden` or `~/.local/share/eden`, on macOS too; portable `user/` in the working folder, which on macOS is the folder holding `eden.app` (`src/common/fs/path_util.cpp`, `src/yuzu/main.cpp`); no flag |
| Keys | `prod.keys`, `title.keys` in `~/.switch/` (normal mode), then `<data>/system/` (`src/Ryujinx.HLE/FileSystem/VirtualFileSystem.cs`) | `<data>/keys/` (`src/core/crypto/key_manager.cpp`) |
| Firmware | `<data>/bis/system/Contents/registered/` (`ContentManager.cs`, `ContentPath.cs`) | `<data>/nand/system/Contents/registered/` |
| Game files | `.xci .nsp .pfs0 .nca .nro .nso`, not `.nsz`/`.xcz` (`src/Ryujinx/Systems/AppLibrary/ApplicationLibrary.cs`) | `nro nso nca xci xcz nsp nsz kip` (`src/qt_common/qt_common.cpp`) |
| Traps | won't start from `~/Downloads` or iCloud, nor as root (`src/Ryujinx/Program.cs`): launch with `cwd = $HOME`; no single-instance lock seen; pads through SDL3, set up in the emulator | the Flathub package has no `home` permission: a game needs `flatpak run --file-forwarding <id> @@ <game> @@` (Flatpak's command reference) or a grant |
| Flatpak data (deduced, untested) | `~/.var/app/io.github.ryubing.Ryujinx/config/Ryujinx` | `~/.var/app/dev.eden_emu.eden/data/eden` |

Unverified: whether Ryubing's normal UI quits or returns to its game list when a game ends; the `.app` name inside Eden's DMG; what Eden does when a game ends; the Flatpak data folders; `--file-forwarding` with Eden's `eden-launcher` command.

### How frontends integrate them

| Frontend (license) | Finds the emulator | Command | Title and art |
|---|---|---|---|
| ES-DE (MIT, on GitLab) | `resources/systems/{macos,linux}/es_find_rules.xml`. Mac: only `/Applications/eden.app/Contents/MacOS/eden` and `/Applications/Ryujinx.app/Contents/MacOS/Ryujinx`. Linux: PATH names (`eden`, `Ryujinx`, `ryujinx`), AppImage globs (`~/Applications/Eden*.AppImage`, `~/Applications/*yujinx*.AppImage`, also in `~/.local/bin`, `~/AppImages`, `~/bin`), Flatpak exports (`/var/lib/flatpak/exports/bin/<id>`, `~/.local/share/flatpak/exports/bin/<id>`), `~/Applications/publish/Ryujinx` | `es_systems.xml`: Eden `-f -g %ROM%`, Ryujinx `%ROM%` | scrapers (ScreenScraper, TheGamesDB) |
| Playnite (MIT, Windows) | the user picks a folder; an executable regex per `emulator.yaml` | `Emulators/Ryujinx/emulator.yaml`: `--fullscreen "{ImagePath}"` for `xci, nsp`; `Emulators/Eden/emulator.yaml`: `-f -g "{ImagePath}"` | a checksum against its database, else the file name |
| LaunchBox (closed) | the user sets the executable | the game path appended, or at `%romfile%` | its own database; "Dependency Files" check that firmware and keys exist; no Switch emulator among its auto-install plugins |
| Pegasus (GPL-3.0) | none: a user-written `metadata.pegasus.txt` | `launch: <emulator> "{file.path}"` | asset files |
| EmuDeck (GPL-3.0, Linux) | `Ryujinx.sh` under `publish/`, `eden*.AppImage`, or a Flatpak id | ES-DE's | ES-DE's; it still downloads Ryujinx from fixed URLs (`functions/EmuScripts/emuDeckRyujinx.sh`); Eden's installer is commented out |
| RetroDECK | dropped Switch "forever" on 19 Feb 2026 (its blog), over "legal exposure and implied responsibility"; it had shipped Ryubing inside its package | | |

Detection is a list of known places per OS; a launch is a command template plus the game path. No frontend appears in Nintendo's GitHub notices (§3).

### Title, icon and cover

An NCA is encrypted except its logo section, and a game's name and icon live in its control NCA; an `.nsp` (PFS0) shows only file names; an `.xci` adds an encrypted title-key area; only homebrew `.nro` holds a plain icon and name (Switchbrew wiki: NCA, XCI, NRO).

| Option | Gives | Verdict |
|---|---|---|
| A. The file name without `[…]` and `(…)`; a bracketed 16-hex block as the title id (a heuristic; Eden prints ids as `{:016X}`) | a clean title, maybe the id | MVP; the card shows the initial, as it does today without an icon (`apps.dart:459-461`, `app_icon.dart:69-76`) |
| B. A `.nro`'s plain ASET section | homebrew's real icon and name | later |
| C. Emulator caches: Eden's `~/.cache/eden/game_list/<id>.jpeg` and `.appname.txt` (on by default, `src/qt_common/game_list/worker.cpp`); Ryubing's `games/<id>/gui/metadata.json` (`Title` only, no icons on disk) | a name, Eden's icon | later, opt-in: internals that change, filled only after the emulator scans the folder |
| D. IGDB, ScreenScraper | good covers | not now: IGDB is non-commercial and needs a client secret a free app can't ship; ScreenScraper wants developer credentials, has quotas, licenses its data CC BY-NC-SA |
| E. `blawar/titledb` | names, icons | never: each title carries `key` and `rightsId`, and its images hotlink the eShop CDN |
| F. Decrypting the control NCA with the user's keys | everything | never: decrypting is circumvention (17 U.S.C. §1201) |
| G. A cover the user picks | anything | later |

## 3. The legal frame

Not legal advice: a summary of primary sources.

- **yuzu.** *Nintendo of America v. Tropic Haze LLC*, D.R.I. No. 1:24-cv-00082. The [complaint](https://storage.courtlistener.com/recap/gov.uscourts.rid.56980/gov.uscourts.rid.56980.1.0.pdf) (ECF 1, 26 Feb 2024) claims trafficking under 17 U.S.C. §1201(a)(2) and (b)(1), circumvention under (a)(1), and contributory and induced infringement. It says users get `prod.keys` "through unlawful websites or by unlawfully hacking a Nintendo Switch console" and faults yuzu's site for instructions: for Nintendo, keys from one's own console are unlawful too. The [Final Judgment and Permanent Injunction](https://storage.courtlistener.com/recap/gov.uscourts.rid.56980/gov.uscourts.rid.56980.11.0.pdf) (ECF 11, 6 Mar 2024): USD 2.4 million, an injunction, the domain handed over; "Yuzu executes code that decrypts Nintendo Switch video games… using unauthorized copies of Nintendo Switch cryptographic keys".
- **Ryujinx** stopped on 1 Oct 2024 (Ryubing's `README.md`; no primary statement found).
- ***Nintendo v. Keighin***, D. Colo. No. 1:24-cv-03101, by default: the [recommendation](https://storage.courtlistener.com/recap/gov.uscourts.cod.238647/gov.uscourts.cod.238647.36.0.pdf) (ECF 36, 3 Oct 2025) notes he "shared links to Ryujinx, Yuzu, other emulators"; the [order](https://storage.courtlistener.com/recap/gov.uscourts.cod.238647/gov.uscourts.cod.238647.37.0.pdf) (ECF 37, 29 Oct 2025) awards USD 17,500 and bars "trafficking in Switch emulators, Nintendo's proprietary cryptographic keys, or other software". Nintendo cites both cases in its 2026 notices.
- **GitHub notices.** 69 Nintendo files in GitHub's `github/dmca` repo, Feb 2024 to 6 Nov 2026, among them `2025/03/2025-03-13-nintendo.md` (a Ryujinx network of 897 repos, Ryubing's included), `2025/06/2025-06-03-nintendo.md` (Ryubing's releases; where "offer, link, or otherwise provide access to" appears), `2026/02/2026-02-12-nintendo.md` (13 emulators named, Eden, Ryubing and Kenji-NX among them; networks over 100 forks processed whole), `2026/06/2026-06-30-nintendo.md` (Ryubing's Flathub packaging), `2026/07/2026-07-10-nintendo.md` (copies of Eden's website) and `2026/11/2026-11-06-nintendo-4.md` (Citron). No frontend is named (ES-DE, Playnite, LaunchBox, Pegasus, EmuDeck, RetroDECK, Lutris, Heroic and Bottles were searched). GitHub contacts owners first, "to give them an opportunity to make changes".
- **Licenses.** Running a program the user installed mixes no licenses, MIT or GPL. GPLv3's aggregate clause (`LICENSE:239-243`) is moot: nothing ships. ES-DE's rules and Playnite's YAML (MIT) may be adapted with their notice; Eden's code (GPL-3.0-or-later) is compatible; titledb is out (option E).
- **Trademarks.** "Nintendo Switch" as descriptive text only; no Nintendo logo or icon. No official guide for third parties was found.

Rules for this repo, from [17 U.S.C. §1201](https://www.law.cornell.edu/uscode/text/17/1201), the yuzu case and the 2026 notices:

- **Never ship, download or link** an emulator, keys, firmware or games: no asset in `packaging/linux/assets.json` or the macOS bundle (`tool/package_macos.sh:132-148`), no pinned URL like `_pinned` (`platform_mac.dart:6-21`), no `Downloader` path, no `launchUrl` like the Game Porting Toolkit's (`gptk_section.dart:52`, fed by `backends.dart:62-78`), no install command in a `HostIssue.command` (`requirement_card.dart:31-53`), no package dependency.
- **Never read, copy, validate or decrypt** keys, firmware or game files, headers included; never run `--install-firmware`; never strip quarantine from the emulator (Bodega strips it only from its own copies: `platform_mac.dart:42-52`, `:275-282`); no titledb, eShop images or Nintendo logos.
- **Never explain how to get** keys, firmware or dumps in public text: UI, ARB descriptions, READMEs, `.sdd/`, comments, commits, PR titles. Release notes come from PR titles (`--generate-notes`: `release-linux.yml:179`, `release-macos.yml:167`) and show in the app's update dialog.
- **May:** stat known paths; list a folder only to tell empty from not; read the emulator's `Info.plist` and its quarantine attribute; check Flatpak exports; launch the user's emulator with the user's game, follow it, stop it; say what is missing, not how to get it, and point to the emulator's own menus; keep paths, never copies, in `$BODEGA_HOME`; use bundle ids and Flatpak ids, which identify and do not link.
- **Public text stays link-free:** `README.md`'s Credits link projects (`:118-127`), so a Switch line names the emulators without links; the research's source list must not be committed as is.
- **A takedown would hit** the whole repo, Wine recipe included (`.claude/CLAUDE.md:18`); the releases, with the engine and hostlibs tarballs `tool/package_macos.sh:64-103` fetches; the update check (`update_repository_impl.dart:20`); and the release mirror, also on GitHub (`AGENTS.md:18`).

## 4. Code map

### 4.1 Engine (unchanged in the working tree)

| Concern | Where | For Switch |
|---|---|---|
| A bottle is a folder | `bottles/<name>` with rule R8 (`engine.dart:54-63`); built with a runtime and `wineboot` (`:174-208`); ready = `syswow64/kernel32.dll` + `system.reg` (`:425-427`); `listBottles` takes every folder (`apps.dart:355-364`) | a fake bottle would reach `wineserver`: the app waits on every bottle (`library_bloc.dart:36`; `engine.dart:337-339`) |
| An app | `InstalledApp(bottle, key, id, title, exe, args, inLibrary, hud)` (`apps.dart:6-15`), built at `:84-93`, `:97-106`, `:296-311`, `:341-350` and `engine/test/apps_test.dart:787`; `apps.json` = `{apps, hidden, offLibrary}`, written atomically (`apps.dart:36-75`, `backends.dart:512-517`); detected `.lnk` and Steam apps merged by title (`apps.dart:228-248`) | `apps.json`'s shape fits a game list |
| Keys and ids | `appKey` (`apps.dart:26-34`); `steam:<appid>` (`:340`) branches `appIcon` (`:465`) and `fixForApp` (`fixes.dart:104-108`); `id` is the origin: `custom` (`apps.dart:151`), `detected` (`:300`), `steam-game` (`:345`), a catalog id (`catalog.dart:199`) the app's catalog matches (`catalog_repository_impl.dart:19`) | a precedent for namespaced keys |
| Calls take a bottle | through `_existing` (`engine.dart:394-398`; `apps.dart:141`, `:176`, `:201`, `:214`, `:226`, `:382`); `openApp` always ends in `_launchIn` (`apps.dart:398-409`) | a `.nsp` stored as an app would go to `wine` |
| Launch | `runInBottle` (`engine.dart:210-234`) → `_launchIn` (`:236-333`): runtime and ready prefix (`:250-257`), exe and cwd (`:258-269`), `winPathProblem` (`:262`), a label of `[A-Za-z0-9._-]` up to 40 chars (`:277-290`), env layers (`:297-312`), a detached `_start` whose `Process` is dropped (`:321-332`) | the emulator needs its own cwd (`$HOME`), no Windows path rule, its own env |
| The wrapper | `_launch` (`:429-434`) appends the output and `# exit=N`, writes `.exit` atomically and does not `exec`, so the program is the shell's child; `_start` runs `/bin/sh -c _launch bodega <log> [wrapper] $rt/engine/bin/wine …` with `wineEnv` and `includeParentEnvironment: false` (`:436-455`) | `_launch` knows nothing of Wine; `_start` hard-codes it (`:448`) |
| Logs, exit | `_newLog`: `logs/<UTC>-<label>.log`, header `# runtime`, `# backend`, `# cwd`, `# argv`, `# aviso`, never the env (`:554-582`); `exitOf` polls every 250 ms, no timeout (`:351-361`); `bottleLogs` (`:658-679`); `hintsIn` reads any log (`:377-392`) | reusable as they are |
| Running, stopping | `waitBottle` = `wineserver -w` (`:335-340`); `stopBottle` = `-k`, no reaper (`:342-349`); "running" = `-w` still waiting after 1 s (`:635-649`); no pid stored, no `killPid`, no `.pid` in `engine/lib/` (grep) | an emulator lives per process, Wine per bottle |
| Dart SDK 3.13 | a detached start gives a pid, never an exit code (SDK `lib/io/process.dart:357-362`); `Process.killPid` returns false for a gone process (`:468-485`); `ProcessSignal` has no signal 0 (`:589-617`) | liveness by `ps -p` or a harmless signal, plus a name check: pids are reused |
| Host | `HostPlatform`: 31 members, nearly all Wine (`platform.dart:18-78`); `detect()` (`:22-27`); a global tests replace (`:80-81`); facades `checkHost`, `checkGamepads`, `hostCapabilities` (`engine.dart:90-98`) | system code goes there (`.claude/rules/architecture.md:51`) |
| Issues | `HostIssue(title, detail, command)`, "before bottles can run" (`platform.dart:3-4`): Rosetta (`platform_mac.dart:122-130`); CPU, Vulkan, audio (`platform_linux.dart:108-142`). `GamepadReport` carries issues that block nothing (`gamepads.dart:14-21`), null on the Mac (`platform_mac.dart:119-120`) | a `checkHost` issue blocks the app and every CLI verb |
| Capabilities | 8 fields, all bottle options (`platform.dart:6-16`; `platform_mac.dart:132-142`; `platform_linux.dart:168-178`) | a flag could hide Switch per host |
| Env | `wineEnv` (`engine.dart:67-85`); Mac `baseEnv`: 5 session keys, a fixed `PATH`, then `WINEMSYNC`, `ROSETTA_ADVERTISE_AVX`, `DOTNET_EnableWriteXorExecute=0`, `MVK_CONFIG_LOG_LEVEL` (`platform_mac.dart:77-92`); Linux keeps a whitelist without `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME` or `QT_*` (`platform_linux.dart:53-87`) | Ryubing is .NET, so Wine's `DOTNET_…` must not reach it; Eden reads `XDG_*` |
| Tools | Mac `/usr/bin/<name>` (`platform_mac.dart:108-109`); `plutil` reads a bundle version (`backends.dart:95-107`); Linux takes names on `PATH` (`platform_linux.dart:99-100`), and `_onPath` stats the exec bit along `Platform.environment`'s PATH (`:290-299`); nothing looks in `/Applications` or by bundle id (grep) | |
| D3DMetal, the precedent | never pinned (`platform_mac.dart:3`); `installBackend` refuses it (`backends.dart:32-37`); `findGptkDmg` is async because the first read of Downloads makes macOS ask (`:80-93`); the license is accepted in macOS's own window (`:109-113`, `:174-175`); a copy from CrossOver is refused (`:232-236`); `_intoSlot` strips quarantine from Bodega's copy (`:307`; `platform_mac.dart:114-117`) | the emulator stays where it is: no copy, no quarantine change, no URL |
| Gamepads | Linux reads `/proc/bus/input/devices` and opens each node (`platform_linux.dart:144-166`), in text that names Wine (`gamepads.dart:68-84`); the Mac sets WineBus per bottle (`platform_mac.dart:284-342`) | emulators set up pads themselves |
| Wrappers | GameMode (`platform_linux.dart:281-283`), PRIME (`:271-279`), the Metal HUD (`platform_mac.dart:188`), read from a bottle's `settings.json` (`backends.dart:389-410`) | reusable for an emulator |
| CLI | one `switch` over list patterns (`bin/bodega.dart:34-239`); usage and exit 64 (`:240-244`); the `checkHost` gate before every verb (`:245-251`); `bodegaHome` (`:252`); `bodega: …` and exit 1 (`:253-256`). Families are blocks: `catalog` (`:143-154`, `:167-177`), `fix` (`:155-166`), `backend` (`:197-237`); parsers live in the library, tested (`backends.dart:849-877`; `engine/test/apps_test.dart:988`); `_follow` is per bottle (`:259-285`); `apps` prints `bottle title key` (`:121-126`) | a `switch` block with its own follow |

### 4.2 App (`lib/`)

| Assumption: every app lives in a Wine bottle | Where |
|---|---|
| An app has a bottle and a Windows exe | `library_app.dart:8`, `:15-16`; the mapper rewrites `C:\` and reads PE icons in an isolate (`app_mapper.dart:6-21`; `library_repository_impl.dart:19-25`) |
| The repository is keyed by bottle; only `firstExit` and `hintsIn` take a log | `library_repository.dart:5-54` |
| Running = bottle open; a run ends when the bottle empties; stop stops the bottle | `library_state.dart:10`; `library_bloc.dart:85-88`, `:165-173`, `:175-193`; `stop_bottle.dart:7-18`; `library_repository_impl.dart:88-102` |
| Hints and the 5 s anti-cheat poll belong to a bottle | `library_bloc.dart:120-143`, `:157-163`, `:195-215`; `library_page.dart:93-97` |
| Tag, filter, column and count name bottles | `library_page.dart:97`, `:130-150`, `:157`, `:173-177`, `:196-235`; `app_en.arb:196`, `:226` |
| The menu holds Wine launch options | `app_menu.dart:4`, `:32-55`; `library_page.dart:57-70` |
| Adding needs a bottle and an `.exe` | `add_app_dialog.dart:25-28`, `:180`; its only caller `bottle_detail_page.dart:173`; `add_app_repository_impl.dart:17-35` |
| An empty library means "create a bottle" | `library_page.dart:258-267`; `app_en.arb:234-238` |
| Ready = Wine runtime and no host issue | `setup_state.dart:18`; `setupRedirect` allows only `/setup` otherwise (`router.dart:39-49`, `:47`), tested in `test/app/router_test.dart:14-36` |
| The side bar counts apps and marks open bottles | `side_bar.dart:61-64`, `:171` |

What Switch can reuse:

- `AppCard` and `AppRow` take a `LibraryApp` (`app_card.dart:37`) but read only `id`, `title` and `iconPath` (`:69`, `:112`, `:132`), with a `footerChip` slot (`:45`); the running chip and play/stop know no bottle (`:151-159`, `:192-212`). `AppIcon` falls back to the title's initial (`app_icon.dart:69-76`).
- `repositoryCall` maps throws to `AppError` (`repository_call.dart:9-27`); `firstExit` and `waitBottle` silence failures on purpose (`library_repository_impl.dart:95-102`).
- Sections: `_section` builds side bar items (`side_bar.dart:38-48`: Library `:98-103`, BOTTLES and New bottle `:105-159`, the scrolling list `:161-183`, Backends `:185-190`, version `:192`); routes are `AppRoute` values (`router.dart:28-37`) with paths in `RouterManager`, where a missing one throws (`device/router/manager.dart:6-19`).
- The bottle page already lays out "games plus a status panel": a 380 px panel at the right from 760 px, stacked below that (`bottle_detail_page.dart:57-61`, `:345-375`); `StatusChip` rows (`bottle_column.dart:143-210`); opening a folder (`:313`).
- `RequirementCard`: title, detail and a copyable command (`requirement_card.dart:10-59`), reused by Gamepads (`gamepads_section.dart:34-36`), which hides itself on a null report (`:22-23`); Backends hides D3DMetal by capability (`backends_page.dart:28`, `:48-49`).
- File pickers: only `openFile`; no `openFiles` or `getDirectoryPath` in `lib/`; type groups are built in the handler (`add_app_dialog.dart:25-26`).
- DI is Injectable only (`di.dart:7-8`); app-wide blocs are provided in `main.dart:49-62`; `PreferenceKey` (`preference.dart:4-10`). The app reads the OS only at `update_repository_impl.dart:48`; all else comes through `RuntimeStatus` (`runtime_repository_impl.dart:19-44`).

### 4.3 Platforms and packaging

- **macOS.** No App Sandbox (`macos/Runner/Release.entitlements:4-5` is empty; `DebugProfile.entitlements:5-8` holds JIT and a network server), no hardened runtime, ad hoc signing (`project.pbxproj:460`, `:536`, `:592`; `tool/package_macos.sh:153-156`), not notarized (`packaging/macos/README.md:43`): starting another app's binary needs no entitlement, and a future sandbox would pass to children. Deployment target 12.0 (`project.pbxproj:474`), Ryubing's minimum, while `README.md:30` says 14. Closing the window quits Bodega (`AppDelegate.swift:6-8`); detached children survive (`engine.dart:210-212`, `:454`). TCC already asks Bodega for what its children use (`MainFlutterWindow.swift:22-27`), and Bodega declares one folder string, Downloads (`Info.plist:27-28`).
- **Linux.** Data in `$XDG_DATA_HOME/bodega` (`platform_linux.dart:30-36`). From an AppImage the first start copies the bundle (`:38-51`), about 814 MiB of Wine (`packaging/linux/README.md:71`), even for a Switch-only user. `_installCommand` writes distro install commands (`platform_linux.dart:346-365`; `gamepads.dart:75`, `:83`): an emulator gets none. `AppRun` sets no variables (`packaging/linux/build_appimage.sh:23-27`).
- **Package text** says Windows and Wine: `packaging/linux/bodega.desktop:4` (no `MimeType=`), `build_deb.sh:38`, `packaging/arch/PKGBUILD:8`. Nothing ships for Switch: no asset, dependency or NOTICE entry (`packaging/linux/LICENSES/NOTICE.md:3`).

### 4.4 Tests and CI

- CI is one `ubuntu-24.04` job of 15 minutes (`.github/workflows/test.yml:22-48`): engine `dart analyze` and `dart test`; app build_runner, analyze, test and `check_layers.sh`. There is no macOS job, and macOS runners are "few and slow" (`AGENTS.md:26`), so Mac code must run on Linux, as `TestMac` allows (`engine/test/_mac.dart:6-31`; Mac-tool skips at `backends_test.dart:423`, `:476`).
- Engine seams: a temp home (`engine/test/apps_test.dart:161-172`); `LinuxPlatform(mangoHud:, bundle:)` and `MacPlatform(bundle:)` (`platform_linux.dart:8`, `platform_mac.dart:28`; `engine/test/bundle_test.dart:36`, `:52`); a fake `wine` that saves its env and exits 7, and a fake `wineserver -w` that waits while a `hang` file exists (`engine/test/engine_test.dart:10-34`; `engine/test/fixes_test.dart:221-223`); assertions on the log header and `exitOf` (`engine/test/engine_test.dart:262-273`).
- App: blocs with `bloc_test` and `mocktail` (`code-style.md:24`); `pages_test.dart` at 720, 801, 1150 and 1921 px, in `en` and `es`, 480 px high (`test/app/pages_test.dart:376`, `:419-426`), failing on English-only text in Spanish (`:400`); the side bar with 50 bottles at 801×480 (`test/app/main_shell_test.dart:179-186`); ARB parity (`test/l10n_parity_test.dart`).
- A Switch test needs: a fake `<tmp>/Applications/Ryujinx.app/Contents/MacOS/Ryujinx` script that records argv, cwd and env and exits with a given code; search roots injected like `bundle`; `HOME` from an env map, as `defaultHome(env)` takes it (`platform.dart:39`), not from `Platform.environment` (`platform_linux.dart:27` does); an empty `prod.keys`; empty and non-empty `registered/` folders; empty game files with made-up names. Never real keys, firmware, games or emulator builds, in git or downloaded by CI.

## 5. Where Switch could plug in

| Seam | Option | For | Against |
|---|---|---|---|
| Game list (engine) | A. Its own store, `switch/games.json`, shaped like `apps.json` | Wine's model and `engine/test/apps_test.dart` (995 lines) untouched; removal is one `part` line (`engine.dart:14-21`); a folder made on demand, like `backends/` (`backends.dart:290`) | the app merges two lists |
| | B. A kind field on `InstalledApp` | one list feeds the library (`library_repository_impl.dart:23`) | 4 constructors change; `bottle` means nothing; every bottle call (§4.1), `appIcon`, the catalog's id match and `bodega apps` meet Switch games |
| | C. A fake bottle | | ruled out: `listBottles` takes any folder, and the app waits on each with `wineserver` (§4.1) |
| Launch (engine) | A. A neutral `spawn(log, cwd, argv, env)` out of `_start`, and a generic `_newLog` | one `.log`/`.exit` contract | touches Wine's launch path, which i18n T19 also edits (`# aviso`, `.sdd/i18n/tasks.md:51`) |
| | B. A small launcher in a new part, reusing `_launch` and `exitOf` | Wine untouched; a part sees the library's private names | header and label code twice |
| | C. A `GameRunner` over Wine and emulators (the research's sketch) | one interface | Wine stops per bottle (`engine.dart:342-349`): `stop(gameKey)` would stop a whole bottle |
| Mac process | A. Exec `<app>/Contents/MacOS/<CFBundleExecutable>` through `_launch`, with `cwd = $HOME` | log, exit code and pid, as today | TCC asks in Bodega's name; the app's `LSEnvironment`, if any, is skipped (check with `plutil -p`) |
| | B. `/usr/bin/open -W -n -a <app> --stdout <log> --stderr <log> --args …` | TCC and Gatekeeper treat the emulator as its own app | `.exit` holds `open`'s code; the pid must be found (`pgrep` by path) |
| UI mode (Ryubing) | A. `--no-gui --use-main-config --fullscreen <game>` | the process ends with the game window, so `.exit` means the game ended | no emulator menus while playing; frontends don't use it |
| | B. The normal UI, `--fullscreen <game>` | the command ES-DE and Playnite use | may return to its game list instead of quitting (unverified), so "running" outlives the game |
| Track, stop | A. Keep the `Process` `_launchIn` drops (`engine.dart:321`) and signal the shell's child | no script change | gone when Bodega restarts |
| | B. A `_launch` variant: the program in the background, `$!` into a `.pid` beside the log, then `wait` | the pid outlives Bodega; the shell still writes `.exit` | a new script to test |
| | Either way: SIGTERM, then SIGKILL, to the emulator, never the shell, because a dead shell writes no `.exit` (`engine.dart:355-356`); after a restart, a `.log` with no `.exit` plus a live pid with the right name; `flatpak ps` and `flatpak kill` for Flatpak runs | | |
| Find it (Mac) | fixed `/Applications` and `~/Applications` (ES-DE checks the first); `mdfind "kMDItemCFBundleIdentifier == 'org.ryujinx.Ryujinx'"`; the `.app` the user picks (`file_selector`, `apps/bodega/pubspec.yaml:55`) | paths are cheap and testable on Linux with a fake `HOME`; Spotlight finds any place; a pick covers the rest | Spotlight can be off and lists mounted DMGs and other volumes; picking a `.app` with `file_selector` is untested |
| | Whichever: read `CFBundleIdentifier`, `CFBundleExecutable` and `CFBundleShortVersionString` with `plutil -extract … raw`, as `backends.dart:95-107` does | | |
| Find it (Linux, later) | AppImage globs (exec bit; FUSE, `apps/bodega/README.md:34`); Flatpak exports or `flatpak info`; a tar.gz the user picks (`Ryujinx.sh`, as its `.desktop` runs); `PATH`, which may lack `~/.local/bin` when Bodega starts from a menu | | a Flatpak sees only its folders and grants: `--file-forwarding` (one file), `--filesystem=<dir>:ro` for one run, or a lasting override, which changes another app's permissions |
| Host hooks | A. Abstract members on `HostPlatform` (the research's candidates, command, env) | the compiler makes Linux answer; `TestMac` inherits them | grows a class that is all Wine |
| | B. One getter that returns an emulator host: real on the Mac, a stub on Linux | follows `architecture.md:51`; Switch code in one file | |
| | C. Emulator definitions as data, like `_pinned` (`platform_mac.dart:6-21`) | a fork is a table edit | fields differ per OS: per-OS sub-records |
| Status | A. Its own report, like `GamepadReport`, behind a facade (`engine.dart:93-95`); "not yet" on Linux, as the Mac's gamepads give null (`platform_mac.dart:119-120`) | blocks nothing | |
| | B. A capability, so the app hides Switch | the app knows at start (`setup_state.dart:11`) | every `HostCapabilities` builder changes (§4.1; `runtime_repository_impl.dart:33-42`) |
| | Never inside `checkHost`: it would block Wine users and every CLI verb | | |
| CLI | a `['switch', …]` block (status, add, list, open, stop) with its parsers in the library | testable like `parseOpen` | the `checkHost` gate stops it on a Mac without Rosetta (`bin/bodega.dart:245-251`): leave the family out, or gate per verb; `_follow` is per bottle |
| App data | A1. `SwitchGame` and `SwitchRepository`, `LibraryApp` untouched | LibraryBloc, mapper and tests untouched; removable | cards take a `LibraryApp` (`app_card.dart:37`) |
| | A2. Widen `LibraryApp` with a platform and a nullable `bottle` | one list, same cards | every row of §4.2's table branches |
| | A3. A fake bottle | least wiring | stop runs `wineserver -k`; graphics read a drive C (`backend_repository_impl.dart:123`); options fetch a bottle (`library_page.dart:59`) |
| Running state | B1. A `@lazySingleton` `SwitchBloc` keyed by game, provided in `main.dart:49-62` | LibraryBloc and `test/app/library_bloc_test.dart` untouched | the library and side bar read two blocs; `ShellBody` needs its listeners (`shell_body.dart:32-43`) |
| | B2. LibraryBloc with `win:<bottle>` and `switch:<key>` | one `open` set | changes `_runs`, `_opening`, hints, `_watch` and `closed` (`library_bloc.dart:21-23`, `:114-193`) and every `open.contains(bottle)` |
| Where it shows | C1. Mixed into the Library, with a platform chip in `footerChip` and a platform filter | one place to play | count, column, stop and empty texts change (`app_en.arb:81`, `:196`, `:226`, `:238`); i18n T19 edits the same bloc and tag |
| | C2. A section of its own: an `AppRoute`, its path, a `SideBarItem`, a page shaped like `BottleDetailView` | Wine screens untouched; removable | the Library stops being "all my games"; the side bar's fixed part grows at 480 px, beside i18n's Settings (T26) |
| | C3. Both | | C1's cost plus C2's |
| Adding games | D1. "Add games" on the Switch page: `openFiles`, `getDirectoryPath` (new to the app), a folder scan off the UI isolate | no bottle, no installer | |
| | D2. A third tab in the add-app dialog | its "add to library" switch fits | dialog and bloc are built around one bottle (`add_app_dialog.dart:28`; `add_app_state.dart:9-20`) |
| Status UI | E1. A panel on the Switch page: `StatusChip` rows, "Check again", "Choose emulator…" | | |
| | E2. `HostIssue`s in a `RequirementCard`, without a command | an existing widget | inside `RuntimeStatus.issues` they block the app (`setup_state.dart:18`) |
| | E3. A card on `/setup` | | reachable only while not ready (`router.dart:47-48`) |
| | E4. The emulator's path and fullscreen in i18n's Settings dialog (T26) | one place for settings | waits for M3 |
| Setup gate | F1. Keep it | no change | a Switch-only user needs the runtime, plus Rosetta on a Mac |
| | F2. A saved "Switch only" way past `/setup` | | the Windows screens then run with no runtime: `waitBottle` and `stopBottle` fail (`engine.dart:335-349`), silenced (`library_repository_impl.dart:95-102`) |
| | F3. A gate per section | precise | a redirect per route and a disabled bottle block (`side_bar.dart:105-183`) |
| Settings | G1. A file under the data root, through `EngineHome` (`engine_home.dart:6-10`) | the CLI and the app share it | |
| | G2. A `PreferenceKey` | | the CLI cannot see it |
| Order with i18n | Switch before M2 | starts now | its text errors and Spanish-shaped issues get rewritten by T13–T23 |
| | Switch after M2 | `EngineFailure`, codes and `lib/app/shared/text/` from the start (`.sdd/i18n/design.md:52-69`, `:108`, `:152-155`) | waits |
| Isolation | this repo, in a few files | one tree, one CI | a takedown still takes the repo |
| | a separate repo or package | the main repo stays clean | `_launch` and friends are private to `engine.dart`'s parts; two release trains |
| | a build-time flag | | the code stays in the repo, so the exposure does too |

## 6. Project constraints

- **Layers** (`.claude/rules/architecture.md:9-12`, enforced by `apps/bodega/tool/check_layers.sh:22-30`): `domain/` is pure Dart; only `data/` imports the engine, through `repositoryCall` (`architecture.md:24`); the data root only through `EngineHome` (`:25`).
- **The platform owns the system** (`architecture.md:49-52`): paths, env, tools and checks go in `HostPlatform`; the app learns the host through `RuntimeStatus`.
- **BLoCs, DI, routes** (`architecture.md:29-46`): a running game outlives its page, so its bloc is a `@lazySingleton` provided in `main.dart`; page blocs are `@injectable`; Injectable only, then build_runner; `AppRoute` plus `RouterManager`; `setupRedirect` stays pure and tested.
- **Style** (`code-style.md:10`, `:13-16`, `:23-26`): absolute imports; Freezed 4 (`sealed` events, `abstract` states and entities); blocs with `bloc_test` and `mocktail`; engine-backed repositories on a temp home; new screens in `pages_test.dart`. `:21` ("everything the user reads in Spanish") is stale until i18n T29.
- **Widgets** (`widget-standards.md:10-12`, `:19`, `:29`): one widget per file; `XPage`/`XView` when a page provides its bloc; `confirm()` before stopping a game, saying unsaved progress is lost; down to 720×480.
- **Text** (`apps/bodega/l10n.yaml:5`, `:9`): every string in `app_en.arb` (the template, with an `@` description) and `app_es.arb`, checked by `test/l10n_parity_test.dart` and by `pages_test.dart` in both locales. Brand names stay as they are (`.sdd/i18n/proposal.md:19`): Ryubing, Eden, Nintendo Switch. After M2 the engine returns codes (`.sdd/i18n/design.md:52-69`, `:108`) worded in `lib/app/shared/text/` (`:152-155`); today's Spanish `HostIssue` (`platform_mac.dart:126-127`) is the pattern being removed.
- **English in git** (`.claude/CLAUDE.md:7`; `AGENTS.md:3`): code, `.sdd/`, commits, PR titles.
- **Lines not to cross** (`.claude/CLAUDE.md:62-68`): the D3DMetal model (`:64`) and anti-cheat (`:66`) apply; data adapted from elsewhere names its source, commit and license, as `catalog_data.dart:1-3` does.
- **Working rules** (`.claude/CLAUDE.md:72-76`): no commit or push without the user's approval, no AI attribution; the user does anything with a window, so running the real emulator with a game is a USER task, like i18n's T32 and T33 (`.sdd/i18n/tasks.md:80-83`); check against the real thing.
- **Versioning** (`AGENTS.md:7-16`): a feature raises the minor number; `bump-version` and `tool/version.sh check` before a commit; `.sdd/` alone does not bump; only `tag-version` tags. The tree is at `1.5.0+12` (`apps/bodega/pubspec.yaml:20`) over `v1.4.2`, and i18n reaches `main` whole as 1.5.0 (`.sdd/i18n/design.md:190`).
- **CI** (`.github/workflows/test.yml:22-48`; `AGENTS.md:21-28`): Linux only, 15 minutes, no new macOS job.

## 7. Risks

| Risk | Where | Mitigation |
|---|---|---|
| A DMCA notice against Bodega | GitHub applies notices to networks; a takedown hits source, Wine recipe, releases and update check (§3) | no emulator URL anywhere; neutral text; Switch in a few files; GitHub warns first |
| A link slips into public text | README credits (`README.md:118-127`), ARB descriptions, `.sdd/`, PR titles that become release notes (`release-linux.yml:179`) | a test that fails on emulator host names or download URLs in tracked files |
| Status text turns into a guide | the missing-keys message and its ARB description | name the file and the emulator's menu, never a source |
| Fork churn | yuzu's forks mostly gone; Ryujinx became Ryubing | definitions as data; the user can pick the `.app` |
| Emulator internals change | data folders, flags, caches | use only the game path and `--fullscreen`/`-f`; pin the verified paths in tests; caches opt-in |
| Exit is not game over | Ryubing's normal UI may stay open after a game (unverified) | the headless mode, which ends with its window; a USER test |
| A stop that hangs tracking | killing the shell leaves no `.exit`, `exitOf` has no timeout (`engine.dart:355-359`), and the app stays "open" (`library_bloc.dart:167-168`) | signal the emulator's pid, never the shell |
| A reused pid after a restart | no pid is stored today | a pid file plus a process-name check |
| Wine's env leaks into the emulator | `DOTNET_EnableWriteXorExecute=0` and Wine keys on the Mac (`platform_mac.dart:87-91`); `XDG_*` dropped on Linux (`platform_linux.dart:62-77`) | a per-host emulator env, tested like `wineEnv` (`engine/test/engine_test.dart:94`) |
| TCC prompts in Bodega's name | under exec, games in Documents, Desktop, iCloud or external disks prompt as Bodega, which declares only Downloads (`Info.plist:27-28`) | a USER test; usage strings in `en` and `es` (after i18n T27), or `open` |
| Gatekeeper | a quarantined emulator never opened won't exec, and Bodega must not strip it | say "open it once from the Finder"; the attribute alone does not mean blocked (verify) |
| Collisions with i18n | M2 rewrites errors, hints and issues (T16, T19, T21), M3 adds Settings to the side bar (T26) (`.sdd/i18n/tasks.md:45-68`) | apply after M2; strings in both ARBs |
| Side bar height | 480 px floor (`widget-standards.md:29`; `test/app/main_shell_test.dart:179-186`) | one item at most; test it beside Settings |
| Eden on macOS | "experimental" | Ryubing first on the Mac |
| Flatpak sandbox | Eden's package has no home; Ryubing's is unofficial and frozen | `--file-forwarding`; prefer AppImage |

To check on the real thing (USER, `.claude/CLAUDE.md:73`): which pid `Process.pid` gives for a detached start, and whether the shell leads its own session; exec against `open -W`, with focus and fullscreen; the exit code when the window closes and after SIGTERM; whether Ryubing's normal UI quits after a game; which TCC prompts appear and in whose name; the first launch of a quarantined emulator; that the emulator runs as arm64 (Activity Monitor, Kind = Apple); macOS's prompt when Bodega lists a game folder in Downloads (precedent `backends.dart:80-82`). On Linux, later: FUSE, `--file-forwarding` against `--filesystem`, `flatpak ps` and `flatpak kill`, the sandboxes' XDG folders.

## 8. Open questions for propose

1. **Does Bodega only detect the emulator, with no link and no help installing it?** **Default: yes.** It looks in `/Applications` and `~/Applications` or takes the `.app` the user picks; it never links, downloads or offers an install command for an emulator, keys, firmware or games (§3), because of the notices' "link to".
2. **Is the MVP Ryubing on the Mac?** **Default: yes**, with data and hooks shaped for Eden and Linux. Ryubing is the only emulator whose own project calls Mac support proper; Eden's macOS builds are experimental. Eden and Linux follow in a second phase.
3. **Do Switch games work without the Wine runtime, given that `setupRedirect` forces `/setup`?** **Default: not in the MVP (F1).** The DMG puts the runtime in place at first start (`packaging/macos/README.md:39`; `platform_mac.dart:42-52`), so a Mac user meets only the Rosetta check (`platform_mac.dart:122-130`). The CLI's `switch` verbs skip the `checkHost` gate (`bin/bodega.dart:245-251`), since Rosetta is a Wine need. Revisit with Linux, where an AppImage's first start copies 814 MiB of Wine (`platform_linux.dart:38-51`).
4. **Do Switch games mix into the Library, or get a section of their own?** **Default: a section of their own in the MVP (C2)**, a "Switch" side bar item whose page holds the status panel and the games, run by its own `SwitchBloc` (B1). The Library, LibraryBloc and i18n's T19 edits stay untouched, and the feature stays removable. Mixing in (C3) comes once cards take a shared item type.
5. **Are `--no-gui` and fullscreen the defaults?** **Default: both on**, as `--no-gui --use-main-config --fullscreen <game>`, and fullscreen a saved setting. Headless ends with its window (Ryubing's `HeadlessRyujinx.cs`), so `.exit` means the game ended, and `--use-main-config` keeps the user's settings. If the USER test finds it lacking, fall back to the normal UI with `--fullscreen`, the command ES-DE and Playnite use.
6. **Is the title the file name, or online metadata?** **Default: the file name (option A)**, with a bracketed title id kept when present and the initial on the card. No IGDB or ScreenScraper now; titledb and decrypting never. A cover the user picks, `.nro` icons and emulator caches come later, opt-in.
7. **Does Switch support live in this repo, or in a module easy to split off?** **Default: this repo, isolated:** one engine part behind one `part` line (`engine.dart:14-21`), one CLI block, one folder per app layer, one route and one side bar item, no emulator URL anywhere. Removing it is deleting files and a few lines. A separate package would need `_launch` (`engine.dart:429-434`) made public.
8. **Which Linux format comes first?** **Default: AppImage**, which both emulators ship and which sees the user's files; then a tar.gz or `PATH` binary the user picks; Flatpak last, through `--file-forwarding` (Eden's package has no home access; Ryubing's is unofficial and frozen).
9. **Where does the engine keep Switch games?** **Default: their own store (A)**, `$BODEGA_HOME/switch/games.json` (key, title, absolute path, title id if known, `inLibrary`, date added), written atomically like `apps.json` (`backends.dart:512-517`), with logs in `switch/logs/`.
10. **How does a launch reuse Wine's machinery?** **Default: B**, a new part that runs the emulator through a pid-writing variant of `_launch` and reads `exitOf`, leaving `_start` and `_newLog` to Wine. A `GameRunner` waits for a third runner.
11. **On the Mac, exec the binary or go through `open`?** **Default: exec `Contents/MacOS/<CFBundleExecutable>`**, with `cwd = $HOME` and its own env: it keeps the exit code and the pid. If the USER test shows TCC prompts that break games, add usage strings or fall back to `open -W`.
12. **Where do the host hooks go?** **Default: B plus C**, one abstract getter on `HostPlatform` returning an emulator host (real on the Mac, a "not yet" stub on Linux), fed by a table of emulator definitions with per-OS sub-records: bundle id, app and executable; AppImage globs, Flatpak id and `PATH` names; argument template; data, key and firmware paths. Rules adapted from ES-DE or Playnite keep their MIT notice and commit.
13. **How does the app learn the emulator's status, and hide Switch where it doesn't run yet?** **Default: its own report (A)** through a facade beside `checkGamepads` (`engine.dart:93-95`): the install found and its version, missing keys, missing firmware, quarantine; never in `checkHost`. Plus one capability (B), false on Linux in the MVP, so the side bar hides the section as soon as it draws (the check ends before the shell shows, `router.dart:46`), as Backends hides D3DMetal (`backends_page.dart:48-49`).
14. **How is the emulator found on the Mac?** **Default: `/Applications/Ryujinx.app`, then `~/Applications/Ryujinx.app`, then the user's pick**, saved; each confirmed by its `Info.plist` (`org.ryujinx.Ryujinx`, the executable, the version). No Spotlight in the MVP: it can be off and lists copies on DMGs and other volumes.
15. **Where do Switch settings live?** **Default: a file under the data root (G1)**, `switch/settings.json` (emulator, its picked path, fullscreen, headless), so the CLI and the app agree; view state stays in `Preferences`.
16. **How do games get in?** **Default: D1**, "Add games" on the Switch page: files (`openFiles`) or a folder (`getDirectoryPath`), scanned once off the UI isolate (as `apps()` reads, `library_repository_impl.dart:19-25`) by the emulator's own extensions, kept by absolute path and never copied. No re-scan, so no `hidden` list.
17. **Order with i18n, and version?** **Default:** propose and design now; apply after i18n M2 is committed, on its own branch, so Switch starts with failure codes and `lib/app/shared/text/` and stays clear of T19; its side bar item lands after T26's Settings. i18n ships as 1.5.0 (`.sdd/i18n/design.md:190`); switch-support is the next minor, 1.6.0 (`AGENTS.md:8`).
18. **The emulator's environment?** **Default: a per-host whitelist** beside `baseEnv`: the session's keys, plus `XDG_*`, `QT_*` and `XDG_CURRENT_DESKTOP` on Linux; none of Wine's (`platform_mac.dart:88-91`) and none of the AppImage runtime's (`APPIMAGE`, `platform_linux.dart:49`).
19. **New lines not to cross?** **Default: add them to `.claude/CLAUDE.md:62-68` in this change:** never bundle, download or link Switch emulators, keys, firmware or games; never read, copy, validate or decrypt keys, firmware or game files, only check they exist; no guides to obtaining them, no `blawar/titledb`, no eShop images; no emulator URL in the repo; don't strip quarantine from apps Bodega didn't ship.
20. **Package text and file types?** **Default: unchanged in the MVP**: no Switch in `bodega.desktop:4`, `build_deb.sh:38` or `PKGBUILD:8`, no `MimeType=` for `.nsp` and `.xci`; the README names the emulators without links.

## Outside this change

- Hydra, Kenji-NX, Citron and the other forks.
- Online metadata, `.nro` icons, emulator caches, covers the user picks, play time.
- Input profiles (`--input-profile-1…8`), choosing the emulator per game.
- Installing keys or firmware: that stays in the emulator's own menus.
- Windows hosts, and Switch on arm64 Linux.
