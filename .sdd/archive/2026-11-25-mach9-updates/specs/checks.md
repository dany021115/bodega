# Spec · checks

## MC1 · Automated

- **Engine:** `dart analyze` and `dart test`.
- **App:** build_runner, `flutter gen-l10n`, `flutter analyze`, `flutter test` and `tool/check_layers.sh`.

## MC2 · AGENT, real

1. **The latest release:** `bodega runtime check mach9` against the real API prints `latest 0.4.0`, and the cache holds the digest `3b5dd83e…e6d9`.
2. **Wine Mono:** `monoVersionOf` on the installed 0.4.0 gives `11.3.0`; `monoRelease('11.3.0')` gives the digest `df2dfc16…18d3`.
3. **An install with no fixed version**, in a temporary `BODEGA_HOME`:
   - `bodega runtime install mach9 ~/Downloads/Mach9-0.4.0.dmg --mono ~/Downloads/wine-mono-11.3.0-x86.msi` (local files, checked against GitHub's digests) ends with the probe passing and `checked: true`;
   - a second install of the same version changes nothing.

The home is removed.

## MC3 · USER

- **The card:** the engine card says "Checked by Bodega" for 0.4.0, with no update offered.
- **When Mach9 ships its next version:** the notice and "Update" appear, and the update ends checked.
