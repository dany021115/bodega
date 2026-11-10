# Design: bottles-ui

Only what is not obvious.

## 1. What we take from CrossOver

The organization and the list of features, read from its installed app. None of its icons, nibs, data or its own wording are used; ordinary words such as `Abrir` ("Open") or `Gráficos` ("Graphics") cannot be avoided. `.claude/CLAUDE.md` will put it this way: we still don't copy its UI, and resembling it in how it is organized is not copying it.

## 2. Registered and detected

A **registered** application is in `apps.json`: it comes from the catalog or from `Agregar` ("Add"). A **detected** one is computed when listing, from `.lnk` files or Steam manifests, and is not saved: that way, uninstalling something makes it disappear without having to clean anything up.

`Ocultar` ("Hide") is the only thing saved about them, in `hidden`.

**Why not enable `winemenubuilder`** (`engine.dart:58`): it would create launchers on the Mac, and all we need is to read what the installer already leaves in the prefix.

```
bottleApps = registered + (.lnk ∪ Steam) − hidden, no repeated key
```

`steam` today has one `app.json` and 3 `.lnk` files pointing to `steam.exe`: that gives a single application, the registered one, plus Muck.

## 3. Icons

A single-icon `.ico` is rebuilt: 6 bytes of header, the 16 of the entry, and the data of the largest `RT_ICON`. It works the same for PNG and DIB, and Flutter decodes it without conversion.

It is read with `RandomAccessFile`, and only the `.rsrc` section, with a cap of 64 MB; a larger `.rsrc` gives `null`. Some games have a huge exe, so the repository runs it in `Isolate.run`, with the cache in front.

## 4. Steam games

They inherit Steam's environment, so their backend is the one `steam.exe` uses. Choosing another one is not offered here: it needs per-process rules, and it belongs in the engine SDD. Libraries in other folders (`libraryfolders.vdf`) aren't handled either, because only the one in the prefix exists.

`-applaunch` with Steam open should pass the command to the running instance, but it has a window and has not been tested. The launched process exits right away; since what is open is tracked per bottle, that doesn't matter.

## 5. State

- **`BottlesBloc`,** global: it now feeds the sidebar. `ShellBody` reloads it when an install finishes, and the screens do so when adding or deleting.
- **`LibraryBloc`:** `open` is still a set of bottles. The guard changes from "this bottle is open" to "this key was launched less than 2 s ago". `_follow` allows several at once: the first one that sees the bottle empty closes it and the others do nothing, as already happens.
- **`BottleDetailBloc`:** per page. Each bottle has its own route and page, so there is no state to clear when switching.
- **Collapsed sections:** in `shared_preferences`, per section and not per bottle.

## 6. Composition

`MainShell`, with the sidebar, stays the same and `SideBar` is rebuilt. The bottle screen decides with `LayoutBuilder`, not by breakpoint: what matters is the width of the content, which depends on the sidebar.

| Window | Sidebar | Content | Column |
|---|---|---|---|
| 720 | 68 | 652 | Below |
| 801 | 220 | 581 | Below |
| 1150 | 220 | 930 | Beside, 270 |

The 760 threshold leaves at least 490 px for the applications.

## 7. Environment of a launch

`wineEnv` does `...extra` at the end, and cannot remove a key. `avx: false` needs to remove `ROSETTA_ADVERTISE_AVX`, so `_start` receives `remove`, a set of keys that are deleted from the final map. `wineEnv`, which has its own tests, is not changed.

## 8. Copy, export, import

`cp -cR` clones on APFS and, according to its man page, falls back to a normal copy if it can't. `-R` copies links as links. `tar` also stores them as links. On Linux the copy is `cp -a --reflink=auto`, which clones on btrfs and XFS and copies elsewhere; both live in `HostPlatform.copyTree`.

`importBottle` validates with `tar -tzf` before extracting. macOS's `tar` already rejects `..` and absolute paths, but checking it gives a clear error and lets us require a single root folder. It is extracted into `.tmp-import`, which `listBottles` ignores, and only renamed at the end. Both `tar`s refuse by default to extract through a link the archive itself created, so a link such as `z:` cannot carry files out of the bottle: bsdtar on the Mac by its documented default, GNU tar on Linux checked (an archive with `r/l -> /outside` and `r/l/evil` stops with "Not a directory" and writes nothing outside), and the failed import leaves nothing.

Exporting leaves out `logs` and `icons`: they are not needed and get regenerated. A new log creates its `logs` folder, since an imported bottle has none (found in the real check: the first run of an imported bottle failed).

## 9. Checked before writing this

With a temporary test, since deleted, and a temporary bottle, also deleted. Nothing with a window.

| Test | Result |
|---|---|
| Icon of `steam.exe` from Dart, decoded by Flutter | PNG, 256×256, 18,652 bytes, 4 ms |
| Icon of `Blur.exe` | DIB, 32×32, 3,262 bytes, under 1 ms |
| Icon of the runtime's `notepad.exe` | PNG, 256×256 |
| `.lnk` files of `steam`, with a script | 3 files, all 3 pointing to `C:\Program Files (x86)\Steam\steam.exe` |
| `appmanifest` | Muck 1625450 with `StateFlags` 4; 228980 is the redistributables |
| `librarycache/1625450/` | `<hash>.jpg`, `header.jpg`, `library_600x900.jpg`, `logo.png` and others |
| `winecfg -v win7` and then `winecfg -v` | `exit=0`, answers `win7`, no window |
| `reg add … RetinaMode` | `exit=0`, and `reg query` returns it |
| `LogPixels` in `HKCU\Control Panel\Desktop` | Does not exist at first: it has to be created |
| `cp -cR` of a 537 MB bottle | 336 ms, `z:` is still `/` and `c:` is still `../drive_c` |
| Program in the copy | `exit=7` as requested, and keeps `RetinaMode` |
| `tar -czf` and `tar -xzf` | 13.3 s and 146 MB; 1.7 s; `z:` is still `/` |
| Rename and launch | Works |

**Not checked:** `-applaunch`, the visual effect of high resolution, DLSS, and the HUD with DXMT. All of it has a window, and you test it.

## 10. Controllers, a fix outside the milestones (2026-11-05)

Your Xbox controller didn't work in Blur, but it did in CrossOver. **Cause, measured in the Wine logs:** without `libSDL2` (CrossOver ships it, we don't), `winebus` sees the controller through IOHID as `is_hidraw`, and `is_hidraw_enabled` discards it: `ignoring hidraw device 045e:02fd`.

**Fix:** `HKLM\System\CurrentControlSet\Services\WineBus` with `Enable SDL=0` and `DisableInput=1` makes Wine prefer IOHID for every controller. The log changes to `Adding device … WINEXINPUT\VID_045E&PID_02FD&XI_00`.

The engine sets it once per bottle: when creating it, or on the first launch of one that already existed. It is saved as `gamepads: 1` in `settings.json`.

**No rumble:** `bus_iohid` doesn't support it. Shipping SDL2, as CrossOver does, is the improvement, and it is left for the engine SDD as version 2.

**Follow-up (2026-11-05):** the controller didn't work the first time because the `reg add` calls started Wine's controller service before the values existed, and that service keeps them for the whole session. Now `_ensureGamepads` waits up to 5 s for that session to end. Checked: a program launched right after creating the bottle already sees the controller. You confirmed that the controller works in Blur.

**SDL2, checked and not applied:** the official 2.32.10 (`SDL2-2.32.10.dmg`, SHA-256 `4a7ac31640d70214e848f994be8a12849c0f97918a7e6c2e27a40036166d1a7f`, zlib) is extracted to x86_64. In a temporary copy of the runtime, Wine loads it (`SDL main loop started`) and adds the controller through SDL (`sdl_add_device … 045e 02fd`). It is left for the engine SDD, because of rumble.

## 11. Local network (2026-11-05)

- **Blur on PC** (PCGamingWiki): LAN for 20 players, split screen for 4, TCP 3074 and UDP 3074 and 50001. Its online service shut down; Amax Emu brings it back.
- **macOS** (TN3179): blocks an app's local network access until it is given the "Local Network" permission, and whatever the app launches counts as its own. Programs launched from Terminal have it by default.
- **Fix:** `NSLocalNetworkUsageDescription` in Bodega's `Info.plist`. The permission is tied to the code signature, and ours is ad hoc, so it may be requested again after rebuilding.
- **This Mac's firewall** is off.

**SDL2 applied (2026-11-05):** with macOS's direct path (IOHID) the controller showed up, but with the controls wrong in Blur, because it arrives without being translated to the Xbox layout. `installSdl` downloads the official SDL2 with its pinned SHA, keeps only its x86_64 part next to `winebus.so`, and signs it locally. `_ensureGamepads` now uses version 2 (SDL, Wine's default values) if the runtime has SDL2, and version 1 (IOHID) if not. Checked on a copy of the runtime: the bottle moves to version 2 on its own, and Wine adds the controller through SDL (`sdl_add_device … 045e 02fd`). Also installed in the user's runtime with `bodega sdl install`.

**Pending:** a screen in the app to install it, because a new runtime doesn't include it. Until it has it, that runtime falls back to version 1 on its own.
