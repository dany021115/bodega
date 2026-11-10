# Catalog

## C1 · Data
`lib/catalog_data.dart` holds a JSON with the 7 entries, in this order: `steam`, `rockstar`, `ea-app`, `ubisoft-connect`, `battle-net`, `epic-games`, `gog-galaxy`. That is the order the list shows.

Fields of each entry:

| Field | Content |
|---|---|
| `id`, `title` | Identifier (a valid bottle name, R8) and title |
| `status`, `statusNote` | C2 |
| `flaky` | Optional: why it is unstable |
| `installer` | `url`, `sha256` (or `null`), `args`, `msi` |
| `exe`, `args` | Executable relative to `drive_c`, with `/`, and its arguments |
| `backend`, `sync` | A backend from the list, not `auto`; `msync` or `none` |
| `env` | The program's variables |
| `registry` | List of `{key, name, type, data}` |
| `notes`, `knownIssues` | In Spanish; `knownIssues`: `{symptom, fix}` |
| `source` | `{repo, commit, path, license, verified}` |

**Scenario (test `catalog data`):**
- **Given** the embedded JSON, **then** there are 7 entries with a valid, unique `id`, a `url` that starts with `https://`, a known `backend` and `sync`, a relative `exe` without `..`, license `CC0-1.0`, and no `env` with `WINEPREFIX`, `WINEMSYNC`, `PATH`, `HOME` or `DYLD_*`.

## C2 · Statuses
- `tested`: tested by the user in Bodega; `statusNote` says when and with what.
- `reported`: Highball verified it, or third parties report it, on a comparable engine.
- `untested`: no verification that applies to this engine.
- `blocked`: it cannot be installed; `statusNote` explains why and what the alternative is.

Initial values:

| Entry | Status |
|---|---|
| `steam` | `tested`, after U3 (`reported` at first) |
| `rockstar`, `ubisoft-connect` | `reported` |
| `ea-app` | `reported`, with `flaky` |
| `battle-net` | `untested`, with `flaky` |
| `epic-games`, `gog-galaxy` | `blocked` |

Only U3 or a later test by the user can set `tested`. There are no stars or numeric ratings.

**Scenario (test `catalog data`):**
- **Given** a `blocked` entry, **then** its `statusNote` is not empty.

## C3 · List and search
`bodega catalog list [texto]` prints `id  título  estado` (id, title, status), one line per entry. The filter is case-insensitive and searches `id` and `title`.

**Scenarios (test `catalogEntries`):**
- **Given** `STEAM`, **then** a single entry, `steam`.
- **Given** `zzz`, **then** none, exit 0.
- **Given** no text, **then** all 7, in order.

## C4 · Detail
`bodega catalog show <id>` prints the title, status and note, backend, sync, notes, known issues and provenance. An unknown `id` gives an error and exit 1.

**Scenario (CLI, T8):** `show steam` shows `reported` and `highball-db`; `show nope` exits with 1.
