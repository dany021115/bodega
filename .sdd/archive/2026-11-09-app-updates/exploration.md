# Exploration · app-updates

## Problem
When a new version of Bodega comes out, the app does not find out. The user wants a modal to
appear when a new release is detected, and the app to update itself.

Today it cannot: `dany021115/bodega` is **private**, and without an account the GitHub API answers
`404` to `releases/latest` (checked with `curl`). The user's decision: a **public repo
for releases only** (e.g. `dany021115/bodega-releases`), with the code kept private.
A GitHub Page is not needed: the app asks the releases API. Also, Pages does not accept
files over 100 MB, and the `.dmg` is 447 MB.

## Releases today
- `tag-version.yml:24-35`: creates `vX.Y.Z` on a push to `main` if the pubspec version
  has no tag.
- `release-macos.yml` and `release-linux.yml` (run by hand, from the tag):
  - `release-macos.yml:155-157` and `release-linux.yml:167-169`: `SHA256SUMS-macos` /
    `SHA256SUMS-linux` with `sha256sum`.
  - `release-macos.yml:167-168` and `release-linux.yml:179-180`: `gh release create "$TAG"
    --generate-notes` and `gh release upload "$TAG" dist/* --clobber`, with `github.token`
    (only valid for this repo).
- Sizes for v1.1.0: `.dmg` 447 MB, AppImage 210 MB, `.deb` 130 MB, Arch 187 MB,
  `.tar.gz` 235 MB. The `.dmg` carries the engine inside (`Resources/bundle`).
- macOS signing: ad hoc (`tool/package_macos.sh:153-156`), no Developer ID.
- The teammates' earlier plan: `.sdd/release-improvements` M8 (`design.md:79-86`): a version
  notice with `dio` + `package_info_plus` once per session; phase 2, Sparkle on macOS.
  This SDD replaces it (T11 and T16 there).

## App (`apps/bodega/lib`)
- Installed version: `app/shared/widgets/app_version.dart:7` (`PackageInfo.fromPlatform`).
- Downloads: `data/service/downloader.dart:12` `Downloader.fetch(url, dest, cancel,
  onProgress)` with `dio`, to a `.part`, cancellable. It can download the installer.
- Global notices: `app/shared/widgets/shell_body.dart:11` (`MultiBlocListener` with
  toasts): the place to listen to an updates bloc and open the modal.
- Routes: `app/router.dart:71` `ShellRoute` → `MainShell` → `ShellBody`.
- Dependencies already in place: `dio`, `package_info_plus`, `url_launcher`, `toastification`.

## How the app gets replaced
- **macOS:** the app is not sandboxed and does not mark downloads as "quarantined": a
  `.dmg` downloaded by the app itself does not trigger Gatekeeper. It is mounted (`hdiutil`, as
  the engine already does in `engine.dart:483`), the new `.app` is copied, and a separate script waits
  for Bodega to quit, swaps `Bodega.app` and opens it again. Where it is installed:
  `Platform.resolvedExecutable` (`platform_mac.dart:47` already uses it).
- **Linux AppImage:** the `APPIMAGE` variable gives its path. The file is replaced and
  relaunched.
- **Linux `.deb`, Arch and `.tar.gz`:** they live in `/opt/bodega` (`packaging/linux/build_deb.sh:3`)
  and belong to the package manager: only a notice with the command (or the link).

## Constraints
- License: the engine is Wine (LGPL). If the binaries are public, the Wine code we
  use must be too: CrossOver's LGPL tree (public at codeweavers.com) + the repo's `wine/`
  (recipe and patches, 1.6 MB). `wine/` can be attached to every public release.
- D3DMetal is never published (it is not in the `.dmg`: the user imports it).
- Creating the public repo and its token is visible from outside: the user confirms it.
  It needs a token with write permission on that repo, stored as a secret in
  `dany021115/bodega`.
- The API without login allows 60 requests per hour per IP: one per session is enough.
- Over a slow connection the 447 MB download takes a long time: it must show progress and
  be cancellable.
- Layers: network and processes go in `data/`; the UI in `app/`; `tool/check_layers.sh`.

## Open questions
1. **Name of the public repo:** `dany021115/bodega-releases`.
2. **What gets uploaded there:** the installers, `SHA256SUMS-*`, the release notes and
   `wine-src.tar.gz` (the `wine/` folder). Do they also stay in the private repo? I propose
   they do (it costs nothing).
3. **When to check:** when the app opens, and at most once every 24 h. "Ahora no" ("Not now")
   hides that version until the next one.
4. **File check:** against `SHA256SUMS-macos`/`-linux` from the same release.
   If it does not match, it is not installed.
5. **Notes in the modal:** the release body (Markdown) as plain text.
6. **Testing it for real** needs two public releases (an old one installed and a new one).
   I propose a test with a fake local release (test server) in the tests, and the real one
   when the next version comes out.
