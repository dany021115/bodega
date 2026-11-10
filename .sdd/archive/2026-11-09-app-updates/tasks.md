# Tasks · app-updates

## Publish
- [x] T1 Step "Publish to bodega-releases" in `release-macos.yml` and `release-linux.yml`
  (create the release with the copied notes, upload the files and `wine-src.tar.gz`; without
  `RELEASES_TOKEN`, a warning). Check: `actionlint` if available, and reading the YAML.
- [ ] T2 **U (user)**: ~~create a public `dany021115/bodega-releases`~~ (done with `gh`, approved);
  still to do: create the fine-grained token and store it as `RELEASES_TOKEN`.

## App
- [x] T3 Engine: public `sha256Of(path)` (what used to be `_sha256`). Test. A5 test: starting
  with a new bundle keeps bottles, `backends/d3dmetal` and `runtimes/current`.
- [x] T4 Domain + data: `AppUpdate`, `UpdateRepository`, `UpdateRepositoryImpl.check`
  (API, SemVer, 24 h, skipped version, platform). Tests with a fake `dio`: greater, equal,
  lower, 404, no network, skipped, 24 h, Linux without AppImage.
- [x] T5 Data: `download` (Downloader + SHA256SUMS + check) and `install` (macOS: dmg
  → `.Bodega-update.app` + script; AppImage: rename). Tests: a SHA that does not match; a test
  dmg made with `hdiutil create` (Mac) leaves the new app and the script, nothing mounted, and the
  data folder untouched (A5).
- [x] T6 `UpdateBloc` (check on startup, skip, download with progress, cancel, install) +
  bloc_test.
- [x] T7 `UpdateDialog` + listener in `ShellBody`; check on startup in `main.dart` only with
  `kReleaseMode`. Widget test of the modal (installable, notice only, progress, error).
- [x] T8 `dart analyze && dart test`, `flutter analyze && flutter test &&
  tool/check_layers.sh`, macOS build. Mark T11/T16 of `.sdd/release-improvements` as
  replaced.
- [ ] U1 (user) With the first public release: an older installed app shows the notice, updates
  and opens the new one.
