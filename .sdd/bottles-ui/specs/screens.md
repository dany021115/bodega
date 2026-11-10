# Screens

As before: blocs with `bloc_test` and fake repositories; every screen in `pages_test.dart` at 720, 801, 1100 and 1921 px; you accept the visuals. You test the operations that have a window.

## Milestone 1

### V1 · Sidebar
From top to bottom: `Biblioteca` ("Library"), `Instalar` ("Install") (`/catalog`), the `Botellas` ("Bottles") title with its list, and at the bottom `Backends` and the theme.

- Each bottle: name, a dot if it is open, and a warning if it is incomplete.
- The bottle of the current route is highlighted.
- With many bottles, only their list scrolls.
- Below `DESKTOP`: icons only, with each bottle's initial and a tooltip.

**Scenarios (widget test `SideBar`):** at 1000 px the names show; at 600 px, initials; it highlights the current bottle, and the dot if it is open; 50 bottles don't overflow.

### V2 · Routes
`/bottles/:name` is the bottle screen. `/bottles` goes to `/library`, and so does deleting a bottle. A bottle that doesn't exist shows a notice with a way back to Library.

**Scenario (test `router`):** those redirects, and the `/setup` ones stay the same.

### V3 · Bottle screen
A header with the name and the status (`Abierta` ("Open"), `Cerrada` ("Closed") or `Incompleta` ("Incomplete")); a center with its applications; a 270 px right column with collapsible sections that remember whether they were expanded.

- If the content is narrower than 760 px, the column moves below the applications.
- In this milestone, the column holds what already exists: Run a program, Stop and Delete; Graphics, msync and exceptions; and Logs.
- Logs open in a dialog, with their last 2,000 lines.

**Scenarios (`BottleDetailBloc` and `pages_test`):** loads applications and settings; an empty bottle invites you to install; switches to a single column below 760 px.

### V4 · Applications of a bottle
A grid of icons with titles. Double click or Enter opens. Right click or the `⋯` button: `Abrir` ("Open") and `Ocultar` ("Hide").

The icon is the program's real one; if there is none, the catalog logo; if not, the initial. A broken image falls back to the next one.

**Scenarios (widget `AppTile` and `AppIcon`):** double click opens; a single click doesn't; Enter opens; `⋯` offers both; the icon's three fallbacks.

### V5 · Library
The applications of all bottles, with icon, title, bottle name, bottle status, `Abrir` and, if the bottle is open, `Parar botella` ("Stop bottle"). When empty, it invites you to `Instalar`.

**Scenarios (test `LibraryBloc`):** lists those of several bottles, including the detected ones; a bottle without applications doesn't show up.

### V6 · Opening several
`LibraryEvent.open` carries the bottle and the key.

- With the bottle open, another of its applications can be opened.
- The same application is not launched twice within 2 s: launching takes milliseconds, and a double click on `Abrir` would get through if we only checked while it is launching.
- `Abierta` is still per bottle, with everything from P7 and P8 of `flutter-app`.

**Scenarios (test `LibraryBloc`):** two applications in one bottle; a double click launches once; it stays open until it empties; closed when everything ends.

### V7 · What already exists, adapted
- **Catalog detail:** `Abrir` uses the bottle and the application.
- **Add another application:** chooses a new bottle or any ready one.
- **Bottles:** the sidebar list reloads on install, add and delete.
- **Window:** 1150×800 by default; the minimum stays at 720×480.

**Scenarios (tests `CatalogRepository`, `AddAppBloc`):** with two applications in `steam`, the catalog still marks Steam as installed; adding to a bottle that already has an application works.

## Milestone 2

### V8 · Actions
`Ejecutar con opciones…` ("Run with options…"), `Instalar en esta botella` ("Install in this bottle"), `Abrir unidad C:` ("Open drive C:") (in Finder), `Abrir terminal` ("Open terminal"), `Parar` ("Stop") and `Borrar botella` ("Delete bottle").

**Scenario (widget):** `Parar` only with the bottle open. Delete asks for confirmation, naming the bottle.

### V9 · Advanced settings
Graphics, Windows version, msync, high resolution, DLSS and AVX.

- msync and high resolution warn that they close the bottle.
- DLSS says that it needs a compatible game and that it hasn't been tested.

**Scenarios (test `BottleDetailBloc`):** each setting calls the repository and reloads; cancelling the warning changes nothing; an error is shown.

### V10 · Control panels
Wine configuration, Registry editor, Task manager, Control panel, Game controllers (`control joy.cpl`) and Uninstall programs.

**Scenario (widget):** each one launches its program with `LibraryEvent.run`.

### V11 · Run with options
A dialog with program, arguments, environment variables, the backend for that launch, Metal HUD, no AVX, and `Guardar como lanzador` ("Save as launcher") with its title. Also available from each application's `⋯`, already filled in.

Variables are written one per line as `NOMBRE=valor` ("NAME=value"). An invalid line is flagged and nothing is launched. `WINEDEBUG` is set here: there is no separate screen for log channels.

**Scenarios (test `RunOptionsBloc`):** launches with what was typed; saving creates the application; an invalid variable doesn't launch; a path that Wine doesn't accept gets a warning.

### V12 · Install with options
On the catalog detail: `Botella nueva` ("New bottle") by default, or a list; and `Instalador` ("Installer"): download by default, or choose a local file.

With an existing bottle, it warns if the entry asks for a different sync. Coming from `Instalar en esta botella`, the bottle arrives already selected.

**Scenarios (test `InstallBloc`):** into an existing bottle, it doesn't download if there is a local file; it rejects an existing bottle that isn't ready; the rest of P4 still holds.

## Milestone 3

### V13 · New bottle and import
At the foot of the bottle list: `+` with `Nueva botella…` ("New bottle…") (name and Windows version, with the name validated while typing) and `Importar…` ("Import…").

**Scenarios (test `NewBottleBloc`):** creates it and navigates to it; an invalid or repeated name, nothing is created.

### V14 · Duplicate, rename and export
In Actions. All three warn that they close the bottle, and show that they are working without blocking the interface. Export asks where to save. On rename, the app goes to the new route.

**Scenarios (test `BottleDetailBloc`):** each one calls the repository and navigates; an error is shown and the bottle stays as it was.

### V15 · Preferences
An entry at the bottom of the sidebar. Data folder with `Abrir en Finder` ("Open in Finder"); installer cache with its size and `Vaciar` ("Empty"), which asks for confirmation; and the theme, which moves out of the sidebar.

**Scenarios (test `PreferencesBloc`):** size; emptying leaves it at zero.
