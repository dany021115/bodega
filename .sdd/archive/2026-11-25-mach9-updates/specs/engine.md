# Spec · engine

## MU1 · No fixed versions (D1)

- `mach9.dart` holds no Mach9 or Wine Mono version, URL, size or hash.
- `mach9Identity` holds the bundle id, the team, `minimumVersion`, the `minimumMacos` floor and `diskBytes`.
- **Given** `grep` of `0.4.0`, `11.3.0` and the old hashes in `lib/`, **then** none is found outside comments that cite history. (check)

## MU2 · The latest release (D2)

- `mach9Latest()` gives the version, the dmg's URL, size and SHA-256, and `minimumMacos`, as D2 reads them, and caches them.

Scenarios:
- **Given** a fake `releases/latest` with `v0.5.0`, a `Mach9.dmg` with a digest and an `appcast.xml` asking for 26.5, **then** the version is `0.5.0`, the sha256 is the digest's, and `minimumMacos` is `26.5`. (test, `file://`)
- **Given** a release without `Mach9.dmg`, with a malformed digest, or older than `minimumVersion`, **then** `NoMach9Release`. (test)
- **Given** the real API, **then** `0.4.0` comes back with the known digest, until Mach9 ships again. (real, EC2)

## MU3 · Wine Mono from the copy (D3)

- `monoVersionOf(engine)` reads the version from `appwiz.cpl`.
- `monoRelease(v)` gives the MSI's URL, size and SHA-256 from its GitHub release.
- The install takes that MSI, checked against them.

Scenarios:
- **Given** an `appwiz.cpl` holding `wine-mono-11.3.0-x86.msi` in UTF-16LE, **then** `11.3.0`. (test)
- **Given** a fake release `wine-mono-11.3.0` with a digest, and an MSI whose hash differs, **then** `ChecksumMismatch`, with nothing switched. (test)
- **Given** Mach9 0.4.0's real `appwiz.cpl`, **then** `11.3.0`. (real)

## MU4 · Install, probe, rollback (D4)

Scenarios (tests with the fake dmg and fake Wine):
- **Given** the latest 0.5.0 and 0.4.0 installed, and a probe that passes, **then** `runtimes/mach9` points to `mach9-0.5.0`, its `runtime.json` has `checked: true`, and `mach9-0.4.0` is deleted afterwards (design D4.7).
- **Given** a probe that fails, **then** `runtimes/mach9` points to `mach9-0.4.0` again, `mach9-0.5.0` is gone, and `Mach9CheckFailed` is thrown.
- **Given** the user's `Mach9.app` 0.5.0 and the latest 0.5.0, **then** nothing is downloaded.
- **Given** a downloaded dmg whose hash is not GitHub's digest, **then** `ChecksumMismatch`, with nothing changed.
- **Given** a Mach9 bottle that runs, **then** the switch waits or refuses as MR8 says, and no cleanup runs.

## MU5 · Runtime info and the CLI (D5, D7)

Scenarios:
- **Given** a cache naming 0.5.0 and 0.4.0 installed, **then** `runtimeInfo(mach9)` has `latest: 0.5.0` and `updateAvailable: true`. (test)
- **Given** a `runtime.json` written by 1.8 (`checked: true`, no `checkedAt`), **then** it reads as checked. (test)
- **Given** `bodega runtime check mach9` with a fake API, **then** it prints the installed version, the latest, and `update available`. (test)
