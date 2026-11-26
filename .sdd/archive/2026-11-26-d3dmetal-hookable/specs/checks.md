# Spec · checks

## HC1 · Automated

- **Engine:** `dart analyze` and `dart test` pass.
- **App:** `flutter analyze` and `flutter test` pass; the app does not change.
- **The patch's rewrite function, cut from the patch and built standalone with the Mac's clang, AddressSanitizer and UndefinedBehaviorSanitizer:** its synthetic cases (HW2) pass.

## HC2 · Real, headless (an agent, in a temporary bottle on the new engine with D3DMetal)

The temporary bottle lives in a temporary `BODEGA_HOME`, never in the user's home, so no bottle of the user's moves to an untested engine. The engine with 0029 is also the first to ship 0028 (462002c), so a bottle created on it must boot (`wineboot` exit 0) as a general check.

- **The zig test program:**
  - with the variable set: 0 thunks left, `Present` starts `48 B8` and returns `S_OK`;
  - unset: 1024 thunks.
- **PolyHook 2 at b0aac632f427cd730c88b9b5198c6669aa05d02f (2023-07-19)**, built with zig for the test only, with a detour on D3DMetal's `Present`. The commit before it, 0d4d90e, refuses to hook the original thunk instead of faulting.
  - **without the variable:** the call faults at a junk address;
  - **with it:** the detour runs and `Present` returns `S_OK`.
- **Output:** pasted in `tasks.md` and `verify.md`.

## HC3 · The user

FIFA 23 on the Rosetta engine with D3DMetal: the mod creates its detours, and the game gets past the start screen without the crash at `0x3825FF`. This is not the acceptance test, and it can only show the rewrite while Bodega does not recognise the game: highball-db names EA anticheat for FIFA 23, so a recognised FIFA 23 launches without it (HE2).
