# Design · i18n

## 1. Tooling
Flutter's `gen-l10n`, the boring choice: no new runtime package beyond
`flutter_localizations` and `intl`.

- `apps/bodega/l10n.yaml`: `arb-dir: lib/l10n`, template `app_en.arb`,
  output `app_localizations.dart`, class `AppLocalizations`,
  `nullable-getter: false`, `untranslated-messages-file:
  build/untranslated.json`.
- `pubspec.yaml`: `flutter: generate: true`, so `flutter pub get`, `run`,
  `test` and `build` write `lib/l10n/app_localizations*.dart`. Those files are
  generated, so gitignored like the rest.
- `lib/l10n/l10n.dart`: `extension L10n on BuildContext { AppLocalizations get
  l10n }`. Widgets write `context.l10n.someKey`.
- `MaterialApp.router` gets `AppLocalizations.localizationsDelegates` and
  `supportedLocales` (`en`, `es`). With no match Flutter takes the first
  supported locale, `en` (L1).

## 2. Where text is built
Only `app/` and `device/` turn things into words, because only they have a
`BuildContext`.

- `domain/` stays pure Dart: it returns values (numbers, enums, ids), never a
  sentence. `ExeGraphics.label` and `warning` go to `app/shared/`.
- `data/` returns values and typed `AppError`s, never a sentence.
- Blocs hold values (enums, ids, `AppError`), never a sentence; the page
  translates them. A toast in a state is a value the listener turns into words.
- `device/` may import `package:bodega/l10n/`; the layer rules don't change.

## 3. Errors
```dart
sealed class AppError {
  engine(String message)          // the engine's English text, shown as is
  network(String detail)          // "Network error: {detail}"
  unknown(String message)
  bottleExists(String bottle)     // install into a bottle that exists
  fileMissing(String path)
  backendNotPinned(String backend)
  updateUnsupported()             // this build can't update itself
  updateNoChecksum(String file)
  updateChecksumMismatch(String file)
  updateNotInBundle(String path)
  updateNotWritable(String dir)
  updateNoApp()                   // the dmg has no Bodega.app
  processFailed(String exe, int code, String stderr)
  downloadCut(int received, int total)
  downloadNotHttps(String url)
}
```
The data layer throws these where it threw Spanish strings; `repositoryCall`
already passes an `AppError` through. `app/shared/error_text.dart` has
`extension AppErrorText on AppError { String text(AppLocalizations l10n) }`,
and every page shows `error.text(context.l10n)` instead of `error.message`.

## 4. What the engine reports with a meaning
```dart
typedef HostIssue = ({String id, Map<String, String> args,
                      String title, String detail, String? command});
typedef Hint = ({String id, Map<String, String> args, String text});
typedef Progress = ({String id, Map<String, String> args, String text});
enum UserProblem { empty, tooLong, badCharacter, dotsOrSpaces } // badUser
```
`title`, `detail` and `text` are the engine's English, for the CLI and as the
app's fallback. The app translates the ids it knows, with `args`:

| id | where | args |
|---|---|---|
| `rosetta` | `MacPlatform.checkHost` | |
| `cpu` | `LinuxPlatform.checkHost` | |
| `vulkan` | `LinuxPlatform.checkHost` | |
| `audio` | `LinuxPlatform.checkHost` | |
| `padPermission` | `gamepadIssues` | `name`, `node` |
| `sdl` | `gamepadIssues` | |
| `freetype` | `hintsIn` | |
| `gnutls` | `hintsIn` | |
| `wineserver` | `hintsIn` | |
| `openFailed` | `hintsIn` | |
| `fixNotApplied` | `hintsIn` | |
| `easyAntiCheat` | `antiCheatHints` | `game` (empty when unknown), `platform` |
| `noChecksum` | `installEntry` step | `host` |
| `downloading` | `installEntry` step | |
| `syncKept` | `installEntry` step | `bottleSync`, `app`, `appSync` |
| `creatingBottle` | `installEntry` step | `bottle` |
| `registry` | `installEntry` step | `value` |
| `runningInstaller` | `installEntry` step | |
| `waitingInstall` | `installEntry` step | |
| `opening` | `installD3DMetalDmg` step | `file` |
| `acceptLicense` | `installD3DMetalDmg` step | |
| `importingD3DMetal` | `installD3DMetalDmg` step | |

An unknown id shows the engine's text. The domain mirrors them:
`HostIssue` gains `id` and `args`; new `Hint` and `ProgressStep` entities
(`id`, `args`, `text`) replace the `String`s of `LibraryRepository.hintsIn`,
`antiCheatHints`, `InstallState.step` and `BackendsState.gptkStep`; a domain
`UserProblem` mirrors the engine's. `app/shared/engine_text.dart` turns them
into words.

## 5. ARB conventions
- Keys in lowerCamelCase, prefixed by area: `common`, `shell`, `setup`,
  `backends`, `update`, `library`, `catalog`, `addApp`, `install`, `bottles`,
  `runOptions`, `gamepads`, `error`, `issue`, `hint`.
- The template (`app_en.arb`) carries a `@key` with a `description` when the
  meaning isn't obvious, and the `placeholders` with their types.
- Plurals and choices with ICU (`{count, plural, =1{…} other{…}}`).
- `app_es.arb` keeps today's Spanish word for word: the Spanish UI does not
  change with this change.

## 6. macOS
`Info.plist` gets `CFBundleLocalizations` (`en`, `es`) and its usage
descriptions in English. `macos/Runner/es.lproj/InfoPlist.strings` has today's
Spanish ones, as a variant group in the Runner target's resources, with `es` in
the project's `knownRegions`.

## 7. Tests
`flutter test` runs in `en_US`, so the tests find English text. Every test
`MaterialApp` gets the delegates and the supported locales. One test checks the
locale resolution (L1): `es_ES` gives Spanish, `fr_FR` gives English.
The layout tests of `pages_test.dart` (nothing overflows at each width) run
once per supported locale, since Spanish runs longer than English.
