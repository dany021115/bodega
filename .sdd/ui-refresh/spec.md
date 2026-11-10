# Spec: UI refresh

A visual and flow change to the macOS and Linux app. What already exists
(bottles, backends, catalog, installs, launching) stays the same; what changes
are the screens you enter through and navigate.

## Requirements

R1. Library as the first screen. Opening the app (with the runtime ready)
lands on `/library`. It shows, as a grid or a list (switchable with `ViewToggle`,
preference `libraryViewGrid`), only the apps marked "en biblioteca" ("in library"). An
app outside the library stays inside its bottle.

R2. Create a bottle without an .exe. "Nueva botella" ("New bottle") asks only for the name. The .exe is
added later, from the bottle.

R3. Bottle with a details panel. `/bottles/:name` shows the bottle's apps
in the center, and on the right a panel with status, backend, sync,
actions, settings and logs. Below `DESKTOP` (801 px) the panel moves
below the apps.

R4. Add an app with two options: "Populares" ("Popular", the catalog) and
"Desde un .exe" ("From an .exe"). Both end up in the chosen bottle.

R5. Adding to or removing from the library does not take the app out of the bottle. Removing
marks the app as "off library"; marking it again shows it again.

R6. Nothing that exists is lost. macOS and Linux behave the same. The
catalog (`/catalog`) still exists as a route, with no link in the
sidebar; it is reached from the "Agregar app" ("Add app") dialog.

## Data model

- `apps.json` gains `offLibrary`: a list of app keys that are not shown in
  the library. If it is missing, it is treated as empty. The engine reads and writes it
  (`packages/engine/lib/apps.dart`).
- `renameBottle(home, from, to)`: renames a bottle and its apps.
- `setInLibrary(home, bottle, key, value)`: marks or unmarks an app as in the
  library by writing `offLibrary`.

## Palette and tokens

Dark theme by default, with its light version (`ThemeBloc`, no button for now). Colors in `device/theme/color.dart` (`AppColor`) and
the gradient in `device/theme/gradient.dart` (`AppGradient`).

- Backgrounds: `background` (070B1A), `sidebar` (0B1126), `bottlePanel` (0A1030),
  `surface` (10183A), `surface2` (172250). In `ColorScheme`: `surfaceContainer`
  is the sidebar, `surfaceContainerHigh` the cards and toasts.
- Borders: `border` (222F66).
- Text: `text` (EAF0FF), `textSecondary` (8C9BC8).
- Accents: `cyan` (22D3EE) primary, `blue` (3B82F6), `violet` (8B5CF6),
  `error` (F87171).
- Catalog states: `statusTested`, `statusReported`, `statusUntested`,
  `statusBlocked`, `statusFlaky`.
- Brand gradient: cyan, blue, violet (`AppGradient.brand`).

Spacing in `AppSpacing`, radii in `AppRadius`, text in `AppTextStyle`.

## Toasts

`AppToast` uses a `surfaceContainerHigh` background, `onSurface` text, and a border and
accent per type: success `statusTested`, error `colorScheme.error`, warning
`statusFlaky`, info `colorScheme.primary`.

## Out of scope

- A button to switch themes. The light theme and the `ThemeBloc` stay, as in the rest of the project, with dark as the default (user's decision, 2026-11-09).
- Engine changes beyond `offLibrary`, `renameBottle` and `setInLibrary`.
