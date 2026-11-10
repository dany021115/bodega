# Proposal · app-updates

## Why
The app does not know when there is a new version, and even if it did, it could not download it: the
releases are in a private repo. The user wants an "update available" modal and the
app to update itself.

## What
**A. Public releases**
- A new public repo, `dany021115/bodega-releases`, with no code: releases only.
- `release-macos` and `release-linux` also publish there, with the same notes, the
  installers, the `SHA256SUMS-*` and `wine-src.tar.gz` (the `wine/` folder, because of the LGPL).
  They use a token in the `RELEASES_TOKEN` secret; without it, they warn and skip the step.

**B. Notice in the app**
- On opening, at most once every 24 h, the app asks GitHub for the latest release
  of the public repo. If it is newer than the installed one, a modal shows the version and its
  notes. "Ahora no" ("Not now") stops the notices for that version.
- No internet, or an error: nothing shows up.

**C. Updating**
- **macOS and AppImage:** "Actualizar" ("Update") downloads the installer with progress (it can be cancelled),
  checks it against its SHA256, replaces the app and opens it again.
- **`.deb`, Arch and `.tar.gz`:** the modal says how to update (a command) and links to the release.
- Only in the release app: a development build does not update (it would replace
  itself).

## Impact
- `.github/workflows/release-macos.yml`, `release-linux.yml`.
- Engine: `_sha256` becomes public (`sha256Of`) so it can be reused.
- App: update entity and repository (domain/data), `UpdateBloc`, a modal in
  `ShellBody`, two new keys in `Preferences`.
- User steps: create the public repo and the token (or approve that I create it with `gh`),
  and run a release to try it out.
- Replaces M8 (T11 and T16) of `.sdd/release-improvements`.
