# Spec · Checks on the real thing

These are checks that mocks can't make. Verify pastes each one's output.

## C1 · The importer, against the real source

The agent runs `tool/import_fixes.py` with no `--src`. It downloads highball-db at `bc72f85`.

**Then:**
- the printed counts are pasted;
- `git diff --stat packages/engine/lib/fixes_data.dart` shows the new data;
- a second run leaves no diff.

## C2 · The plan on a real bottle (agent, headless)

In a scratch bottle, the agent adds a program by hand whose exe name, or whose title, matches an entry with a Mac backend.

**Then:**
- `bodega game show` prints that match, and `backend: <name> (config)` when that backend is installed;
- `bodega game use … off` and `on` succeed;
- after `off`, `wine reg query` on the entry's registry key (if it has one) no longer finds the value.

The bottle is stopped and then deleted.

## C3 · In the app (USER)

1. **Open the Games page.**
   - Search for a game.
   - Filter by Broken and by DXMT.
   - Open a game's page and check that its sections match the data.
2. **Check a Steam game you have.** In its bottle, its row in Games shows the match and what it changes.
   - Launch it, with Steam closed first. The run log's first lines say `backend: <name> (config)`.
   - Turn the switch off and launch again: the backend line no longer says `config`.
3. **Send a report.** "Report how it ran" opens GitHub's form, filled in. Sending it is up to you.

## C4 · Linux (collaborator)

On a Linux host with this build:
- `bodega game show <bottle> <key>` for a matched game prints no Mac backend and no Mac steps;
- `game use … off` and `on` work;
- the Games page opens.

The commands go in `tasks.md`.
