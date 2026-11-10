# Tasks · d3dmetal-and-backends

## Milestone A · Exe graphics
- [x] T1 Engine: `exeGraphics(path)` in `backends.dart` (isolate), and the Mac
  `autoBackend` reuses it. Tests: synthetic PEs DX9/32 (with `d3d10`), DX12/64, non-PE; Blur stays on wine.
- [x] T2 Engine: `Platform.backendFits` (the G3 table on Mac, always yes on Linux) and
  `backendUse(name)` ("Sirve para…" ("Works for…")). Tests for Mac and a simulated Linux.
- [x] T3 App data/domain: `ExeGraphics` entity (bits, directx, label, misfits),
  `BackendRepository.graphics(exes)`, `BackendInfo.use`. `tool/check_layers.sh` clean.
- [x] T4 App: `GraphicsBloc` (load, cache) + bloc_test.
- [x] T5 App: label in `AppCard`/`AppRow` (not on `steam.exe`); notice in `bottle_column`
  and in `run_options_dialog`; "Sirve para…" line in `backend_card`. Widget tests.

## Milestone B · Installing D3DMetal
- [x] T6 **U (user)**: download `Game_Porting_Toolkit_3.0.dmg` from Apple. I look at the real dmg
  (names, inner dmg, license, `redist/lib`, `Info.plist`) before writing T8.
  If something does not match the spec, I stop and fix the spec. T8 was done earlier with the
  documented structure. With the real dmg (`Game_Porting_Toolkit_4.0_beta_3.dmg`): the outer
  one has no license and contains `Evaluation environment for Windows games 4.0 beta 3.dmg`
  (with a license) along with samples and a `.pkg`. The inner contents (`redist/lib`) are confirmed by U2 on
  accepting the license. Right after the download, `hdiutil` gives "Resource busy" for a few seconds: it retries.
- [x] T7 Engine: `gptkReleases`, `findGptkDmg(version, dir)`, `d3dmetalVersion(home)`. Tests.
- [x] T8 Engine: `installD3DMetalDmg(home, dmg)` (mount, `open` the inner one, wait for the
  volume, import, always unmount). Mac test with a dmg made with `hdiutil create`.
- [x] T9 App: D3DMetal card with the installed version + list + Install / Waiting /
  choose dmg / Cancel; the check when done. Delete `d3dmetal_instructions.dart`.
  `NSDownloadsFolderUsageDescription`. bloc_test + widget test.

## Extra (requested during apply)
- [-] E1 Detect the engine and dxmt/dxvk tarballs with Spotlight. **Dropped**: the
  release app already carries the engine inside (`Resources/bundle`), and when it is opened from Finder,
  macOS does not let it see Documents. The engine screen only shows in debug builds.
- [x] E2 App icon: `assets/images/logo.png` in the 7 sizes of `AppIcon.appiconset`
  (Mac). The Linux packages (deb, AppImage, Arch) already take `app_icon_512.png` from there.

## Wrap-up
- [x] T10 `dart analyze && dart test` (engine), `flutter analyze && flutter test &&
  tool/check_layers.sh` (app), macOS build.
- [ ] U1 Blur: label `DX9 · 32 bits`; bottle on d3dmetal → notice; Automatic → no notice.
- [x] U2 Install from the card with the real dmg → license → imported. Done with 4.0 beta 3
  (4.0b3 stays installed). The check with a bottle is still pending (Blur was open during verify).
