# Verify · engine-resilience

Date: 2026-11-24.
- Branch `feat/fex-options`, cut from `origin/main` after v1.7.0.
- Version 1.8.0+16.
- The user chose to ship before trying it ("todo a un pr, mergealo y pon a correr los release"). EC3 and EC4, the user's runs, are still open.

## Requirements

| Requirement | Verdict | Evidence |
|---|---|---|
| ER1 · pads on the Native engine | Met | `mach9_test`, "ER1 SDL3 pads before the session boots" (3 tests); MG6's exact environment has `SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1`. Real, Mach9 0.4.0: the first probe wrote the three values, `gamepads: 3` and `# pads sdl3`; the second wrote nothing (tasks T8). |
| ER2 · a bottle's processes | Met | `processes_test`, "ER2" (3 tests). Real: a live Mach9 session listed its six processes by name, once D1 moved to `ps` + `lsof -p` (T8). |
| ER3 · the reaper and orphans | Met | `processes_test`, "ER3" (4 tests, a SIGTERM-proof process and the Whisky case among them). Real: `stopBottle` left nothing. On the user's Mac the new app's first start ended pid 26464, the 5-day-old `winedevice.exe` that held the pad. |
| ER4 · a relaunch stays open | Met | `processes_test`, "ER4" (2 tests); `library_bloc_test`, "EA2". |
| ER7 · retina for both runtimes | Met | `mach9_test`, "ER7 a Rosetta bottle follows its retina too"; `runtimes_test`, "ER7 a Rosetta bottle takes auto too"; `options_test`, setHighRes (4 tests); MB1's legacy file round-trips. |
| ER5 · the hang | Met | `processes_test`, "ER5" (2 tests); `library_bloc_test`, "EA4"; `english_test` counts 9 markers. |
| ER6 · open with Rosetta | Met | `options_test`, "ER6" (3 tests: a new bottle and its reuse, an app inside its bottle refused, names). |
| ER8 · measuring and Metal 4 | Met | `processes_test`, "ER8" (3 tests); `options_test`, "ER8 metal4". Real and read-only: `bodega measure Games 3` gave `average  cpu 235.2%  top blur.exe 207.9%  gpu 74%`. |
| EA1–EA7 · the app | Met | The bloc, widget and text tests named in tasks T6 and T13. `pages_test` renders the dropdown, the Metal 4 switch and the menu item. |
| EC1 · automated | Met | Engine: `dart analyze` no issues, `dart test` +506 ~5. App: `flutter analyze` no issues, `flutter test` +1027, `tool/check_layers.sh` Layers OK. |
| EC2 · real, part A | Met | tasks T8. |
| EC3, EC4 · the user's runs | Open | Pending, by the user's choice to ship first: the pad in Blur set by Bodega alone, FIFA filling the screen on Rosetta and staying "open", the hang hint, "Open with the Rosetta engine", and the three measurements on the Rosetta engine. |

## Known

- **A flaky test, once:** under load, ER1's first test failed once, because the fake `wineserver -w` outlasted `_serverRunning`'s 1 s. PE4's tests share that heuristic.
- **The Native entry is forgotten:** "Open with the Rosetta engine" removes the Native entry through `hideApp`. For an app added by hand, that forgets it.
