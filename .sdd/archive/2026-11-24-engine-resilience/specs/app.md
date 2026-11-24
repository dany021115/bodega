# Spec · app

## Part A

### EA1 · Retina for both engines (ER7)

- On the Mac, a bottle's settings show the retina dropdown (Follow the display, On, Off) for both engines, and Rosetta's high-resolution switch goes.
- On Linux, without the `retina` capability, the switch stays, and changing it no longer asks to close the bottle.

Scenarios:
- **Given** a Rosetta bottle, **then** its settings show the dropdown, and choosing one sends the bottle's retina event. (widget test)

### EA2 · Apps that stay open (ER4)

- An app whose first process exited stays "open" (running) while `appStillRunning` is true. The app asks every 5 s, then marks it closed.

Scenarios:
- **Given** `firstExit`, then `appStillRunning` true twice, then false, **then** the app is running until the third answer, then closed. (bloc test)

### EA3 · Orphans ended (ER3)

- When the app starts, it runs `reapOrphans`. When something was ended, a toast says how many leftover processes of old bottles Bodega closed.

Scenarios:
- **Given** `reapOrphans` returning two, **then** one toast with 2. (bloc or widget test)

## Part B

### EA4 · The hang hint (ER5)

- During a run, the 5-second timer also asks `runHung`. A hung app shows the `stuckLock` hint on its bottle and as a toast, "This game seems stuck".
- Its text names the actions, which live where they already are: the card's ■ closes it, and the app's menu has "Open with the Rosetta engine" for a Native app outside its bottle. Changed in apply: the hint chip holds text only.

Scenarios:
- **Given** `runHung` true for an app of a Mach9 bottle, **then** the hint shows with both actions, and "Close" sends the stop event. (bloc and widget tests)

### EA5 · Open with the Rosetta engine (ER6)

- The app menu of an app of a Mach9 bottle whose exe is a host path has "Open with the Rosetta engine".
- It shows the steps while the bottle is made, then opens the game, and a toast names the bottle.
- The library then shows the Rosetta entry only.

Scenarios:
- **Given** such an app, **then** the item is in its menu, and choosing it calls the repository. Given an app inside `drive_c`, **then** the item is absent. (widget tests)

### EA6 · Metal 4 (ER8)

- A Rosetta bottle's settings, with D3DMetal installed, show a "Metal 4 (D3DMetal)" switch with a line on when to try it.

Scenarios:
- **Given** a Rosetta bottle with D3DMetal, **then** the switch shows and sends its event; for a Native bottle, absent. (widget test)

## Both parts

### EA7 · Text

- Every new text is in `app_en.arb` and `app_es.arb`, with a description, and is worded in `app/shared/text/`.
- `pages_test.dart` renders the new dropdown, hint, menu item and switch at the window sizes, in English and Spanish.
