# Spec · app

Extends `.sdd/archive/2026-11-23-mach9-parity/specs/app.md` (PA2, PA6).

## FA1 · Domain

- `NativeOption` (`apps/bodega/lib/domain/entities/native_option.dart`) shall gain `strictCodeTracking` and `fullX87Precision`, after `vulkanWined3d`, with the engine's names, since the mapper maps by name.
- **Given** an app of a Mach9 bottle with both on in the engine, **then** `LibraryApp.nativeOptions` holds both. (mapper test)

## FA2 · Dialog

- "Native engine options…" shall list seven switches: the five of PA2, then the two new ones.
- Turning one sends `LibraryEvent.setNativeOption`, as PA2 says.
- **Given** an app of a Mach9 bottle with `strictCodeTracking` on, **then**:
  - the dialog shows seven switches;
  - "Strict code tracking" is on;
  - turning "Full x87 precision" on sends the event with `fullX87Precision`. (widget test)

## FA3 · Text

Each option has its name and its hint in `app_en.arb` and `app_es.arb`, with an ARB description, and a case in `native_text.dart`:

| Key | English | Spanish |
|---|---|---|
| `nativeStrictCodeTracking` | Strict code tracking | Seguimiento estricto del código |
| `nativeStrictCodeTrackingHint` | Turn it on when a game hangs or closes at start on the Native engine and runs on the Rosetta engine: for games that change their own code while they run. Slower. | Actívala si un juego se cuelga o se cierra al empezar en el motor nativo y funciona en el motor Rosetta: es para juegos que cambian su propio código mientras corren. Va más lento. |
| `nativeFullX87Precision` | Full x87 precision | Precisión x87 completa |
| `nativeFullX87PrecisionHint` | Turn it on when an old game's physics, timing or picture go wrong. Slower. | Actívala si en un juego antiguo la física, los tiempos o la imagen salen mal. Va más lento. |

- No text says a switch gets around a protection.
- **Given** every `NativeOption`, **then** its names and hints are distinct and non-empty in both languages. (`text_test.dart`'s existing loop)
