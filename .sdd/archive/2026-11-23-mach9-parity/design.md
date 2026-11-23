# Design · mach9-parity

Only what is not obvious. `M/` is Mach9 at `cc71942` (v0.4.0), `ENG/` is `packages/engine/`, `APP/` is `apps/bodega/`.

## 1. Display density through FFI (PE3)
These are Mach9.app's `retina.rs` rule and CoreGraphics' C API, loaded once on the first call:

```dart
final cg = DynamicLibrary.open(
    '/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics');
// CGMainDisplayID() -> uint32
// CGDisplayCopyDisplayMode(uint32) -> CGDisplayModeRef (null without a display)
// CGDisplayModeGetWidth / CGDisplayModeGetPixelWidth(CGDisplayModeRef) -> size_t
// CGDisplayModeRelease(CGDisplayModeRef)
hiDpi = pixelWidth > width;
```

- **Checked on 2026-11-23** on this Mac (`dart run`, 0.35 s with the VM start): `points 2048 pixels 2048`. The built-in panel is in a non-HiDPI mode, so `auto` gives off here, as Mach9.app would.
- **Where it lives:** in `platform_mac.dart`, behind `HostPlatform`. Tests use a field on the test host.
- **When it runs:** only when a Mach9 launch needs to decide (PE4).

## 2. `user.reg` read (PE4)
Wine writes `user.reg` as sections `[Key\\Path] <time>` followed by `"Name"=value` lines. The read is line-based:

1. find the section `[Software\\Wine\\Mac Driver]`, then its `"RetinaMode"="y|n"`;
2. find the section `[Control Panel\\Desktop]`, then its `"LogPixels"=dword:XXXXXXXX` (hex).

- **A missing file, section or value** counts as Wine's default: `n`, 96.
- **Writes** go only through `reg add` (Wine owns the file), followed by `wineserver -k` and `-w` on the bottle's runtime (`_wineserver(rt, prefix, …)`).
- **Whether a session runs** is `_serverRunning(rt, dir)`. It is asked only when the values differ, so a matching launch pays for one file read.

## 3. The rule lines (PE7, PE8)
- **The order of fields** in a line follows compatdb's `Key::ALL` (`M/compatdb/core/src/key.rs:227-248`): `exe`, `company`, `product`, `original_filename`, `dxgi`, `d3d9`, `wined3d`, `opengl`, `dpi_aware`, `large_address_aware`, `gcmouse`, `force_nx`, `metal_hud`, `vulkan_capture`, `metal_capture`, `dll_overrides`, `arguments_override`, `arguments`, `debug_channels`, `env`.
- **`_compatdbLine`** gets a sort by that order, so callers may list fields in any order. Today's callers already follow it, so their golden lines don't change.
- **`_mach9Rules`** gains:
  - `target`: `steam:<id>` or the program key;
  - `options`: the `NativeOption`s of the launched app.
- **Which line holds what:**

| Line | Holds |
|---|---|
| `exe=*` | the effective graphics fields, `metal_hud` (except for a Steam app), the menu override and the fix's overrides, as today |
| `exe=<target>` | the option or exception's graphics fields (D17), `metal_hud` for a Steam app, and the app's options; omitted when empty |
| `exe=<other>` | other programs' exceptions and HUD, as today (D18) |

## 4. Where data lives
- **`settings.json`:**
  - `"retina": "on"|"off"` for a Mach9 bottle, absent for `auto`;
  - `"native": {"<app key>": ["largeAddressAware", "noForceNx"]}`, sorted, absent when empty.

  Both are read with defaults, so older files read the same.
- **`BottleInfo`/`bottleSettings`** expose `retina`. A `nativeOptions(home, bottle, key)` function gives one app's options.
- **The app** gets the options for `LibraryApp` from the library repository, which already reads each bottle's settings for the HUD.

## 5. The catalog's engine (PA3)
- `InstallEvent.start` gains `runtime` (default `bodega`), and `install_repository_impl` passes it to `engine.installEntry(runtime:)`.
- The detail page reads `RuntimeInfo` for Mach9 from `BackendRepository.runtimes()` (#22's A6), which the catalog bloc loads with the bottles.

## 6. The engine card's Check (PA4)
- `BackendsBloc` gains `checkEngine(bottle)`. It runs `BackendRepository.test(bottle, name)` for `mtld3d`, `dxmt` and `wine` in turn, and keeps each result in the state's `probes`, keyed `mach9:<name>`.
- The engine card reuses `ProbeDialog` with `bottles` set to the ready Mach9 bottles (`readyBottles` gains a `runtime` parameter; today it keeps Rosetta's only).

## 7. Steps left out (PE6)
`FixStep` gains `bool forRosettaOnly`: an `env` step whose name starts with one of the five prefixes. `_launchIn` and `gamePlan` filter on `mach9`, and the header's `# skipped` line names what was filtered out.
