# Proposal · i18n

## Why
Bodega is public now, and everything in git is in English except the app's UI
text, which is written in Spanish inside the widgets. `CLAUDE.md` says this
change moves it to a Spanish translation file. The engine and the `bodega` CLI
still print and throw Spanish, which breaks the same rule.

## What
- The app speaks **English and Spanish**. It follows the system's language:
  a Mac or a desktop in Spanish sees Spanish, any other language sees English.
  No manual switch yet: it comes with the Preferences screen (`bottles-ui` V15).
- Every UI string lives in `apps/bodega/lib/l10n/app_en.arb` (the template)
  and `app_es.arb`. The Spanish text is today's text, unchanged.
- The **engine and the CLI** speak English only: errors, output, hints, the
  host checks.
- What the engine reports with a known meaning (the host checks, the gamepad
  checks, the log hints, Easy Anti-Cheat, the install steps, a bad Windows
  user name) carries a stable `id` and its arguments, so the app shows it in
  the user's language. An engine **error** reaches the app as English text
  and is shown as is.
- The app's own errors (data layer) become typed `AppError`s that the app
  translates.
- macOS permission prompts (microphone, camera, local network, Downloads) in
  both languages.

## Not in this change
- A language switch (Preferences, `bottles-ui` T12).
- Translating catalog data. The catalog's notes (`catalog_data.dart`) were
  hand-written in Spanish; they turn English like the rest of the engine, and
  the app shows them as they are. The macOS app menu (`MainMenu.xib`) stays
  as Flutter's template has it, in English.
- Other languages: adding one is a new `app_xx.arb` and a line in the macOS
  `Info.plist`.

## Impact
- Engine: every user-facing string; `HostIssue` gains `id` and `args`;
  `hintsIn` and `antiCheatHints` return `Hint`s instead of `String`s; install
  steps carry an id; `badUser` returns a reason instead of a sentence. Tests
  that match Spanish messages.
- App: `flutter_localizations` and `intl`, `l10n.yaml`, the ARB files, every
  widget with text, the blocs and domain entities that build text today, the
  data layer's errors, `AppError`, the tests (they run in English).
- macOS: `Info.plist` in English and `es.lproj/InfoPlist.strings`.
- Linux: nothing beyond the app; the `.desktop` file is already in English.
- Existing data on disk does not change: no persisted key or file format
  changes. The one log marker the engine reads back (`fixNotApplied`) turns
  English; hints are read from the log of the run that just ended, so old logs
  don't matter.
