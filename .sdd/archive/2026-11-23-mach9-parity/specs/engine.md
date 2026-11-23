# Engine · mach9-parity

Requirements PE1..PE10. `ENG` is `packages/engine/`. Every check is `cd ENG && dart analyze && dart test`; existing tests change only where a requirement says so.

## PE1 · msync in new catalog bottles on Mach9 (P1)
`installEntry` shall save the entry's `sync` only into a new bottle of runtime `bodega`. A new `mach9` bottle shall keep `hostPlatform.defaultSync`. An existing bottle shall keep its own sync, as today.
- **Given** the `steam` entry and `runtime: mach9`, **when** it installs into a new bottle, **then** its `sync` is `msync` and the installer's launch environment has no `WINEMSYNC=0`. (test)
- **Given** the same entry with `runtime: bodega`, **then** its `sync` is `none`, as today. (test)

## PE2 · The retina setting (P2)
`BottleSettings` shall gain `retina` (`auto`, `on`, `off`; default `auto`). It is read for any bottle and written to `settings.json` only for a `mach9` bottle whose value is not `auto`. An unknown value is `BadChoice(ChoiceKind.retina, …)`.

`setRetina(home, bottle, mode)` shall save the mode of a `mach9` bottle. On a `bodega` bottle, `on` and `off` are `setHighRes(true|false)`, and `auto` is `BadChoice(ChoiceKind.retina, 'auto', ['on', 'off'])`. On a `mach9` bottle, `setHighRes(v)` shall be `setRetina(v ? 'on' : 'off')`. The two engines' settings thus stay apart, and no new failure is needed.
- **Given** a Rosetta bottle, **when** its settings are saved again, **then** the file is the same byte for byte. (test)
- **Given** a Mach9 bottle, **when** `setRetina(off)` runs, **then** `settings.json` holds `"retina":"off"`; after `setRetina(auto)`, the key is gone. (test)

## PE3 · The main display's density (P3)
`HostPlatform` shall gain `bool mainDisplayHiDpi()` (synchronous: the FFI calls are):
- **Mac:** CoreGraphics through `dart:ffi`. True when the main display's current mode has a pixel width greater than its width in points. Any failure (no display, a library that can't be loaded) gives false.
- **Linux:** false.
- **Test hosts:** a field.
- **Given** the test Mac with `hiDpi: true`, **then** `auto` resolves to retina on with `LogPixels` 192; with false, to off with 96. (test)
- **Check:** on this Mac, `dart run` of a one-line probe prints the same as the design's FFI test (2048 points, 2048 pixels today, so false).

## PE4 · Retina values before the session boots (P4)
Before `_launchIn` starts a program in a `mach9` bottle, other than Bodega's own `reg`, `wineboot` and `msiexec` runs, it shall:
1. **Want:** `RetinaMode` `y` or `n`, and `LogPixels` 192 or 96. The mode decides; `auto` uses PE3.
2. **Read** both values from `prefix/user.reg`:
   - `[Software\\Wine\\Mac Driver]` `"RetinaMode"`;
   - `[Control Panel\\Desktop]` `"LogPixels"=dword:…`;
   - a missing value counts as `n` or 96.
3. **When the values differ and no wineserver runs for the bottle:** write both with `reg add`, then `wineserver -k` and `-w` on the bottle's runtime, then launch.
4. **When the values differ and a session runs:** launch as is, with the log header line `# retina waits for the next session`.

The log header shall carry `# retina <on|off> (<mode>)`.
- **Given** a Mach9 bottle with `retina: on` and an empty `user.reg`, **when** a program launches, **then**:
  - the fake `reg` gets both `add` calls;
  - the fake wineserver gets `-k`, then `-w`, before the program;
  - the header says `# retina on (on)`. (test)
- **Given** `user.reg` already matching, **then** no `reg` call and no `-k` happen. (test)
- **Given** a running session (the fake `wineserver -w` blocks), **then** the program launches with no `reg` call, and the header has the "waits" line. (test)
- **Given** a Rosetta bottle, **then** nothing of this runs. (test)

## PE5 · Creation ends its session (P3 of the proposal's What)
`createBottle` shall wait for the bottle's wineserver (`-w`) after the registry values and Mono, so the first launch boots a new session.
- **Given** a Mach9 bottle being created, **then** the fake wineserver's last call is `-w`, and it comes after the `reg` and `msiexec` calls. (test)

## PE6 · Rosetta-only steps left out on Mach9 (P5)
In a `mach9` bottle, a fix's `env` steps whose name starts with `ROSETTA_`, `D3DM_`, `DXVK_`, `MVK_` or `MTL_HUD_` shall not reach the environment. The log header shall carry `# skipped <NAME>, <NAME>` (sorted) when any was left out. `gamePlan` shall omit them from the plan's `env`. Registry steps, DLL overrides and every other variable apply as today.
- **Given** a fix with `D3DM_ENABLE_METALFX=1`, `DXVK_ASYNC=1` and `VKD3D_CONFIG=dxr`, **when** it launches in a Mach9 bottle, **then**:
  - only `VKD3D_CONFIG` is in the environment;
  - the header says `# skipped D3DM_ENABLE_METALFX, DXVK_ASYNC`;
  - `gamePlan` lists only `VKD3D_CONFIG`. (test)
- **Given** the same fix in a Rosetta bottle, **then** all three apply, as today. (test)

## PE7 · Native options per app (P6, P7, P8)
- **`settings.json`** shall gain `native`: app key → sorted list of the options that are on. It is saved only when not empty.
- **The options** are the enum `NativeOption`:

  | Option | Field | Value |
  |---|---|---|
  | `noForceNx` | `force_nx` | `false` |
  | `largeAddressAware` | `large_address_aware` | `true` |
  | `notDpiAware` | `dpi_aware` | `false` |
  | `cglOpenGl` | `opengl` | `cgl` |
  | `vulkanWined3d` | `wined3d` | `vulkan` |

- **`setNativeOption(home, bottle, key, option, on)`** shall throw `AppNotFound` for an app the bottle doesn't have. It saves in a bottle of either runtime; only a `mach9` launch sends the options, since Rosetta's Wine has no compatdb.
- **`nativeOptions(home, bottle, key)`** shall give the set that is on.
- **`openApp` in a `mach9` bottle** shall add one line when the app has any option on: `exe=<target>`, then the fields in compatdb's `Key::ALL` order:
  - `dxgi`, `d3d9`, `wined3d`, `opengl`, `dpi_aware`, `large_address_aware`, `gcmouse`, `force_nx`, `metal_hud`, `dll_overrides`;
  - `<target>` is PE8's for a Steam app, otherwise the program's exe key.

The line merges with the launch's own line for the same target (PE8, D17) into one line.
- **Given** an app with `largeAddressAware` and `noForceNx`, **then** `compatdbRules` holds `exe=game.exe;large_address_aware=true;force_nx=false`. (golden test)
- **Given** an option or exception of `dxmt` for the same app, **then** the line is `exe=game.exe;dxgi=dxmt;large_address_aware=true;force_nx=false`. (golden test)
- **Given** a Rosetta bottle with an option on, **then** a launch carries no `WINE_COMPATDB`. (test)

## PE8 · A Steam game's own rule (P9)
When `openApp` launches an app whose key is `steam:<id>` in a `mach9` bottle:
- the line D17 writes for the launched program becomes `exe=steam:<id>`; today it is `exe=steam.exe` (the program's key);
- `metal_hud=true` goes on that line, not on `exe=*`.

The `exe=*` line keeps its graphics fields and `dll_overrides`.
- **Given** `steam:220` launched with `--backend wine --hud`, **then** the rules are:
  - `exe=*;dxgi=wined3d;d3d9=wined3d;dll_overrides=winemenubuilder.exe=`;
  - `exe=steam:220;dxgi=wined3d;d3d9=wined3d;metal_hud=true`. (golden test)
- **Given** a program that is not a Steam app, **then** the lines are as today. (test)

## PE9 · Mono with .NET (P10)
`monoMissing` shall be false when the prefix holds `drive_c/windows/Microsoft.NET/Framework/v4.0.30319/clr.dll`.
- **Given** a Mach9 bottle without `mono-2.0` and with that file, **then** `monoMissing` is false; without the file, true. (test)

## PE10 · What Wine lacks, from the bottle's own Wine (P11)
`appNeeds` shall read the bottle's runtime (`runtimeDir(home, bottleRuntime(home, bottle))`), from `engine/lib/wine/<dir>`:

| Runtime | 64-bit program | 32-bit program |
|---|---|---|
| bodega | `x86_64-windows` | `i386-windows` |
| mach9 | `aarch64-windows` | `i386-windows` |

When the runtime is not installed, nothing counts as missing, as today.
- **Given** a Mach9 bottle whose fake runtime has `aarch64-windows/mfc140.dll`, and a 64-bit exe importing it, **then** MFC is optional, not recommended. (test)

## PE11 · CLI
- `bodega option <bottle> retina auto|on|off` calls `setRetina`.
- `bodega native <bottle> <key>` lists the options, each `on` or `off`.
- `bodega native <bottle> <key> <option> on|off` calls `setNativeOption`.
- The options' CLI names are `no-force-nx`, `large-address-aware`, `not-dpi-aware`, `cgl-opengl` and `vulkan-wined3d`.
- `bodegaUsage` lists the verbs.
- **Given** the arguments, **then** `cli.dart`'s parsers give the calls above, and bad values give the usage. (test)

## PE12 · Moving a bottle to Native (P17, P18, P19; added in apply)
`moveToNative(home, bottle, {onStep})` shall turn the Rosetta bottle [bottle] into a Mach9 one under the same name, and return the dependencies (`<id> <arch>`) the old bottle had installed.
- **Refusals, each leaving the bottle as it is:**
  - a Mach9 bottle is `BadChoice(ChoiceKind.runtime, 'mach9', ['bodega'])`;
  - a blocked host is `RuntimeUnavailable`;
  - no Mach9 runtime is `RuntimeNotInstalled`;
  - a running bottle is `BottleOpen`.
- **Steps (`NativeMoveStep`):**
  - `creating`: `createBottle(temp, runtime: mach9)` with Mono, then the Windows user and version;
  - `copying`: the merge of P17, `apps.json` and `icons/`, and the settings;
  - `finishing`: `removeBottle(old)`, then `renameBottle(temp, old)`.
- A failure before `finishing` removes the temporary bottle and rethrows.
- **Given** a Rosetta bottle with Steam in `Program Files (x86)`, a save in `users/<user>/AppData/Roaming`, a game folder `C:\Games`, an `apps.json`, and settings with a `dxvk` exception, a `dxmt` one, sync `none` and `highRes` on, **when** it moves, **then**:
  - the bottle of that name is Mach9 and holds those files and `apps.json`;
  - its settings have `msync`, the `dxmt` exception, no `dxvk` one, and `retina: on`;
  - the old folder is gone. (test)
- **Given** the new prefix's own `users/<user>/Documents` is a link to a folder outside, and the old prefix has a real `Documents` with a file, **then** nothing is written into the folder outside. (test)
- **Given** the copy fails, **then** the old bottle is as it was and no temporary bottle is left. (test)
- **Given** a Mach9 bottle, or no Mach9 runtime, **then** the refusals above. (test)
- **CLI:** `bodega native-move <bottle>` prints each step, then what to install again.

