part of 'engine.dart';

/// Who Mach9 is, and what Bodega's rules need of it: the only Mach9 facts in
/// the code (MU1). Its versions, and the Wine Mono each asks for, come from
/// GitHub; Apple's signature with [team] is what makes a copy trusted.
typedef Mach9Identity = ({
  String bundleId,
  String team,

  /// The oldest Mach9 accepted: older ones drop rules without `name=`.
  String minimumVersion,

  /// A floor; a release's own appcast may ask for more.
  String minimumMacos,

  /// What a copied runtime takes on disk, for the engine card.
  int diskBytes,
});

/// Mach9's identity (D1). Tests may replace it; the app only reads it.
Mach9Identity mach9Identity = (
  bundleId: 'app.mach9',
  team: 'WLKUUJD25W',
  minimumVersion: '0.4.0',
  minimumMacos: '26.4',
  diskBytes: 1061000000,
);

/// Mach9's latest release (MU2): its version, its dmg's URL, size and
/// SHA-256 from GitHub's digest, and the macOS its appcast asks for.
typedef Mach9Latest = ({
  String version,
  String url,
  int bytes,
  String sha256,
  String minimumMacos,
});

/// Where GitHub's API is: `BODEGA_GITHUB_API`, else GitHub's. A test may
/// set a `file://` folder laid out as the API's paths.
String githubApi =
    Platform.environment['BODEGA_GITHUB_API'] ?? 'https://api.github.com';

/// The text at [url], through curl as downloads are: HTTPS or a file.
Future<String> _fetchText(String url) => _run(hostPlatform.tool('curl'), [
  '-fLsS',
  '--proto',
  '=https,file',
  '--proto-redir',
  '=https',
  '-H',
  'Accept: application/vnd.github+json',
  '-A',
  'Bodega',
  url,
]);

/// An asset of a GitHub release JSON by [name]: URL, size and SHA-256 from
/// its `digest`, or [NoMach9Release] naming what is wrong.
({String url, int bytes, String sha256}) _asset(
  Map<String, dynamic> release,
  String name,
) {
  final asset = ((release['assets'] ?? const []) as List)
      .cast<Map<String, dynamic>>()
      .where((asset) => asset['name'] == name)
      .firstOrNull;
  if (asset == null) throw NoMach9Release('no $name in the release');
  final digest = RegExp(r'^sha256:([0-9a-f]{64})$')
      .firstMatch('${asset['digest']}');
  if (digest == null) throw NoMach9Release('no SHA-256 digest for $name');
  return (
    url: '${asset['browser_download_url']}',
    bytes: (asset['size'] ?? 0) as int,
    sha256: digest.group(1)!,
  );
}

/// The latest Mach9 release (MU2, D2), saved in `runtimes/.mach9-latest.json`.
/// With [maxAge], a saved answer younger than it is given without asking.
Future<Mach9Latest> mach9Latest(String home, {Duration? maxAge}) async {
  final cache = File('$home/runtimes/.mach9-latest.json');
  if (maxAge != null) {
    if (cachedMach9Latest(home) case final saved?) {
      final at = DateTime.tryParse(
        '${(jsonDecode(cache.readAsStringSync()) as Map)['checkedAt']}',
      );
      if (at != null && DateTime.now().difference(at) < maxAge) return saved;
    }
  }
  final release = jsonDecode(
    await _fetchText('$githubApi/repos/athei/mach9/releases/latest'),
  ) as Map<String, dynamic>;
  final version = '${release['tag_name']}'.replaceFirst(RegExp('^v'), '');
  if (!RegExp(r'^[0-9][0-9A-Za-z.+-]*$').hasMatch(version)) {
    throw NoMach9Release('version $version');
  }
  if (!_versionAtLeast(version, mach9Identity.minimumVersion)) {
    throw NoMach9Release(
      'version $version is older than ${mach9Identity.minimumVersion}',
    );
  }
  final dmg = _asset(release, 'Mach9.dmg');
  var macos = mach9Identity.minimumMacos;
  try {
    final appcast = await _fetchText(_asset(release, 'appcast.xml').url);
    for (final item in RegExp(
      r'<item>.*?</item>',
      dotAll: true,
    ).allMatches(appcast).map((m) => m.group(0)!)) {
      if (!item.contains('<sparkle:version>$version</sparkle:version>')) {
        continue;
      }
      final wanted = RegExp(r'<sparkle:minimumSystemVersion>([0-9.]+)<')
          .firstMatch(item)
          ?.group(1);
      if (wanted != null && !_versionAtLeast(macos, wanted)) macos = wanted;
    }
  } on NoMach9Release {
    // No appcast: the floor stands.
  } on ProcessFailed {
    // Unreachable: the floor stands.
  }
  final latest = (
    version: version,
    url: dmg.url,
    bytes: dmg.bytes,
    sha256: dmg.sha256,
    minimumMacos: macos,
  );
  Directory('$home/runtimes').createSync(recursive: true);
  _writeJson(cache.path, {
    'version': latest.version,
    'url': latest.url,
    'bytes': latest.bytes,
    'sha256': latest.sha256,
    'minimumMacos': latest.minimumMacos,
    'checkedAt': DateTime.now().toUtc().toIso8601String(),
  });
  return latest;
}

/// What [mach9Latest] last saved, or null.
Mach9Latest? cachedMach9Latest(String home) {
  try {
    final json = jsonDecode(
      File('$home/runtimes/.mach9-latest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    return (
      version: json['version'] as String,
      url: json['url'] as String,
      bytes: json['bytes'] as int,
      sha256: json['sha256'] as String,
      minimumMacos: json['minimumMacos'] as String,
    );
  } on Object {
    return null;
  }
}

/// The Wine Mono a Mach9 engine asks for (MU3, D3): the version its
/// `appwiz.cpl` names as `wine-mono-<v>-x86.msi`, in UTF-16, or null.
String? monoVersionOf(String engine) {
  final file = File('$engine/lib/wine/aarch64-windows/appwiz.cpl');
  if (!file.existsSync()) return null;
  final bytes = file.readAsBytesSync();
  final text = String.fromCharCodes([
    for (var i = 0; i + 1 < bytes.length; i += 2) bytes[i] | bytes[i + 1] << 8,
  ]);
  return RegExp(r'wine-mono-(\d+\.\d+\.\d+)-x86\.msi')
      .firstMatch(text)
      ?.group(1);
}

/// A Wine Mono MSI from its GitHub release (MU3): URL, size, SHA-256 and the
/// file name Mach9 looks for.
typedef MonoRelease = ({String url, int bytes, String sha256, String file});

Future<MonoRelease> monoRelease(String version) async {
  final file = 'wine-mono-$version-x86.msi';
  final release = jsonDecode(
    await _fetchText(
      '$githubApi/repos/madewokherd/wine-mono/releases/tags/'
      'wine-mono-$version',
    ),
  ) as Map<String, dynamic>;
  final asset = _asset(release, file);
  return (url: asset.url, bytes: asset.bytes, sha256: asset.sha256, file: file);
}

/// What [installMach9] is doing, for a UI to word in its own language.
enum Mach9Step {
  downloading('Downloading Mach9'),
  mounting('Opening the dmg'),
  copying('Copying Mach9'),
  checkingSignature("Checking Mach9's signature"),
  checking('Checking the copy'),

  /// After the copy, whose appwiz.cpl names the Wine Mono it needs (MU3).
  downloadingMono('Downloading Wine Mono'),
  switching('Switching to the new version'),

  /// A temporary bottle runs the graphics check on the new version (MU4).
  probing('Checking the new version');

  const Mach9Step(this.english);

  /// For the CLI and logs.
  final String english;
}

/// What [createBottle] is doing, for a UI to word in its own language.
enum BottleStep {
  prefix('Creating the Windows folder'),
  mono('Installing Wine Mono');

  const BottleStep(this.english);

  /// For the CLI and logs.
  final String english;
}

/// Installs Mach9 into `runtimes/mach9-<version>` and points `runtimes/mach9`
/// at it (MR4–MR9, MU4), from [source] (a `.dmg` or a `.app`), else the
/// user's `Mach9.app` when it is the latest release or newer, else the latest
/// release's dmg, checked against GitHub's digest. [sha256] is what a file
/// the caller downloaded must hash to. The Wine Mono is the one the copy's
/// `appwiz.cpl` names (MU3): [mono] when given, else [fetchMono]'s or the
/// engine's download of its GitHub release, checked against its digest.
/// The signature is checked on the copy, and installs run one at a time
/// (`runtimes/.mach9.lock`). Nothing under the copy's `engine/` is ever
/// written, signed or stripped (I3); a failure or [cancelled] leaves no
/// `.tmp-*`, no changed link and no mounted volume (I6). With [check], a
/// temporary bottle runs the probe on the new version: a failure points the
/// link back to the previous one and throws [Mach9CheckFailed]. Once it is
/// installed, its installers only take space, since the runtime keeps what it
/// uses: Bodega's own downloads go, older tries' included, and with
/// [deleteSource] the user's own `.dmg` [source] too. Returns the runtime's
/// folder.
Future<String> installMach9(
  String home, {
  String? source,
  String? sha256,
  String? mono,
  Future<String> Function(MonoRelease release)? fetchMono,
  bool check = true,
  bool deleteSource = false,
  void Function(Mach9Step step)? onStep,
  bool Function()? cancelled,
}) async {
  if (hostPlatform.mach9Block case final block?) {
    throw RuntimeUnavailable(RuntimeKind.mach9, block);
  }
  void stopIfCancelled() {
    if (cancelled?.call() ?? false) throw const Cancelled();
  }

  final runtimes = Directory('$home/runtimes')..createSync(recursive: true);
  // What this call downloaded itself, deleted once the install succeeds.
  final downloaded = <String>[];

  var from = source;
  var expected = sha256;
  String origin;
  if (from != null) {
    origin = expected != null ? 'download' : (_isDmg(from) ? 'dmg' : 'app');
  } else {
    // Offline, the last answer; with none, the user's own Mach9.app.
    Mach9Latest? latest;
    try {
      latest = await mach9Latest(home);
    } on ProcessFailed {
      latest = cachedMach9Latest(home);
      if (latest == null && findMach9App() == null) rethrow;
    }
    if (findMach9App() case final app?
        when latest == null || _versionAtLeast(app.version, latest.version)) {
      from = app.path;
      origin = 'app';
    } else {
      onStep?.call(Mach9Step.downloading);
      latest!;
      from = await _download(
        home,
        latest.url,
        latest.sha256,
        name: 'Mach9-${latest.version}.dmg',
      );
      downloaded.add(from);
      expected = latest.sha256;
      origin = 'download';
    }
  }
  if (expected != null && await sha256Of(from) != expected) {
    throw ChecksumMismatch(from);
  }
  stopIfCancelled();

  final image = from;
  // One install at a time, in this process and across processes (the app
  // and the CLI): they share the staging folder and the link.
  final (:dest, :previous) = await _oneMach9Install(runtimes.path, () async {
    // Mach9 staging left by an install that was killed: none runs now. A
    // Bodega runtime's `.tmp-*` is not ours.
    for (final old in runtimes.listSync(followLinks: false)) {
      if (old is Directory &&
          old.path.split('/').last.startsWith('.tmp-mach9-')) {
        old.deleteSync(recursive: true);
      }
    }
    String? mount;
    try {
      final String app;
      if (_isDmg(image)) {
        onStep?.call(Mach9Step.mounting);
        mount = await _attach(image, prefix: 'bodega-mach9');
        app = '$mount/Mach9.app';
        if (!Directory(app).existsSync()) {
          throw IncompleteArchive(image, 'Mach9.app');
        }
      } else {
        app = image;
      }
      stopIfCancelled();

      // The plist only: the signature is checked on the copy (MR5).
      final version = _mach9Version(app);
      final id = 'mach9-$version';
      final dest = '${runtimes.path}/$id';
      final previous = _mach9Linked(runtimes.path);
      if (previous == id) throw AlreadyInstalled(dest);
      await _noMach9BottleOpen(home);
      // A folder the link does not name is not installed: a killed install
      // left it, or an update kept it for a bottle that was open (MR8).
      await _removeUnusedMach9(home, runtimes.path, needed: dest);
      stopIfCancelled();

      onStep?.call(Mach9Step.copying);
      final tmp = Directory('${runtimes.path}/.tmp-$id')..createSync();
      try {
        // The whole app, so that its seal covers every file of the copy: a
        // source .app could change between a check of it and the copy.
        final copy = '${tmp.path}/Mach9.app';
        await hostPlatform.copyTree(app, copy);
        stopIfCancelled();

        onStep?.call(Mach9Step.checkingSignature);
        if (await _trustedMach9(copy) != version) {
          throw RuntimeNotTrusted(app, 'it changed while it was copied');
        }
        final wine = Directory('$copy/Contents/Resources/wine');
        if (!wine.existsSync()) {
          throw IncompleteArchive(image, 'Contents/Resources/wine');
        }
        wine.renameSync('${tmp.path}/engine');
        Directory(copy).deleteSync(recursive: true);
        stopIfCancelled();

        onStep?.call(Mach9Step.checking);
        await _checkMach9Copy(tmp.path, source: image);

        // MU3: the Wine Mono this Mach9 asks for, checked by its release.
        final monoVersion = monoVersionOf('${tmp.path}/engine');
        if (monoVersion == null) {
          throw IncompleteArchive(image, 'appwiz.cpl naming wine-mono');
        }
        final String msi;
        final String monoFile;
        if (mono != null) {
          msi = mono;
          monoFile = 'wine-mono-$monoVersion-x86.msi';
          // Offline, the user's own file is taken as it is.
          final release = await _monoReleaseOrNull(monoVersion);
          if (release != null && await sha256Of(msi) != release.sha256) {
            throw ChecksumMismatch(msi);
          }
        } else {
          onStep?.call(Mach9Step.downloadingMono);
          final release = await monoRelease(monoVersion);
          monoFile = release.file;
          msi = fetchMono != null
              ? await fetchMono(release)
              : await _download(
                  home,
                  release.url,
                  release.sha256,
                  name: release.file,
                );
          downloaded.add(msi);
          if (await sha256Of(msi) != release.sha256) {
            throw ChecksumMismatch(msi);
          }
        }
        File(msi).copySync('${tmp.path}/$monoFile');
        _writeJson('${tmp.path}/runtime.json', {
          'kind': RuntimeKind.mach9.name,
          'version': version,
          'source': origin,
          'checked': false,
          'mono': monoFile,
        });
        stopIfCancelled();

        onStep?.call(Mach9Step.switching);
        // Again: a bottle may have opened during the copy (MR8).
        await _noMach9BottleOpen(home);
        tmp.renameSync(dest);
      } catch (_) {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
        rethrow;
      }
      // Before the detach, which takes seconds: a folder no link names is
      // not installed (I6).
      _pointMach9(runtimes.path, id);
      return (dest: dest, previous: previous);
    } finally {
      if (mount != null) await _detach(mount);
    }
  });
  if (check) {
    await _checkNewMach9(home, runtimes.path, dest, previous, onStep);
  }
  // Older versions go: only the one the link names is ever used (MR8). One a
  // bottle still runs on stays, for the next install to remove.
  await _oneMach9Install(
    runtimes.path,
    () => _removeUnusedMach9(home, runtimes.path),
  );
  for (final file in downloaded) {
    if (File(file).existsSync()) File(file).deleteSync();
  }
  _deleteMach9Downloads(home);
  if (deleteSource &&
      source != null &&
      _isDmg(source) &&
      File(source).existsSync()) {
    File(source).deleteSync();
  }
  return dest;
}

/// Mach9's dmgs and Wine Mono's MSIs in `downloads/`, partial ones included:
/// after a good install none is needed, and a cancelled or failed try can
/// have left one (seen on 2026-11-24, 200 MB).
void _deleteMach9Downloads(String home) {
  final downloads = Directory('$home/downloads');
  if (!downloads.existsSync()) return;
  final installer = RegExp(
    r'^(Mach9(-[0-9][0-9A-Za-z.+-]*)?\.dmg|wine-mono-[0-9.]+-x86\.msi)(\.part)?$',
  );
  for (final file in downloads.listSync(followLinks: false).whereType<File>()) {
    if (installer.hasMatch(file.path.split('/').last)) file.deleteSync();
  }
}

/// Points `runtimes/mach9` at [id], atomically.
void _pointMach9(String runtimes, String id) {
  final link = Link('$runtimes/mach9.tmp');
  if (FileSystemEntity.typeSync(link.path, followLinks: false) !=
      FileSystemEntityType.notFound) {
    link.deleteSync();
  }
  (link..createSync(id)).renameSync('$runtimes/mach9');
}

/// [monoRelease], or null when GitHub cannot be reached.
Future<MonoRelease?> _monoReleaseOrNull(String version) async {
  try {
    return await monoRelease(version);
  } on ProcessFailed {
    return null;
  }
}

/// The name of the temporary bottle that checks a new Mach9 (MU4).
const mach9CheckBottle = 'mach9-check';

/// The check of a newly linked Mach9 (MU4): null when it passed, else what
/// failed. Tests may replace it.
Future<String?> Function(String home) mach9Probe = _probeMach9;

/// A temporary bottle on the linked Mach9 runs the probe's mtld3d cases; the
/// bottle is removed either way.
Future<String?> _probeMach9(String home) async {
  try {
    if (Directory(bottleDir(home, mach9CheckBottle)).existsSync()) {
      await removeBottle(home, mach9CheckBottle);
    }
    await createBottle(
      home,
      mach9CheckBottle,
      runtime: RuntimeKind.mach9,
      mono: false,
    );
    final cases = await backendTest(home, mach9CheckBottle, 'mtld3d');
    if (cases.isEmpty) return 'no case ran';
    final bad = [
      for (final result in cases)
        if (!result.ok) '${result.bits}-bit D3D${result.d3d}: ${result.log}',
    ];
    return bad.isEmpty ? null : bad.join('; ');
  } on EngineFailure catch (error) {
    return error.message;
  } finally {
    if (Directory(bottleDir(home, mach9CheckBottle)).existsSync()) {
      await removeBottle(home, mach9CheckBottle);
    }
  }
}

/// MU4, D4: a temporary bottle on the new runtime runs the probe's mtld3d
/// cases. Passing, the runtime is marked checked; failing, the link goes back
/// to [previous], the new copy goes, and [Mach9CheckFailed] is thrown. The
/// bottle is removed either way.
Future<void> _checkNewMach9(
  String home,
  String runtimes,
  String dest,
  String? previous,
  void Function(Mach9Step step)? onStep,
) async {
  onStep?.call(Mach9Step.probing);
  final json = '$dest/runtime.json';
  final info = jsonDecode(File(json).readAsStringSync()) as Map;
  final failure = await mach9Probe(home);
  if (failure == null) {
    _writeJson(json, {
      ...info,
      'checked': true,
      'checkedAt': DateTime.now().toUtc().toIso8601String(),
    });
    return;
  }
  final id = dest.split('/').last;
  if (previous != null &&
      previous != id &&
      Directory('$runtimes/$previous').existsSync()) {
    await _oneMach9Install(runtimes, () async {
      _pointMach9(runtimes, previous);
      Directory(dest).deleteSync(recursive: true);
    });
  }
  throw Mach9CheckFailed('${info['version']}', failure);
}

/// Runs [body] once no other Mach9 install runs: in this process, after the
/// ones before it; across processes, under a lock on `runtimes/.mach9.lock`
/// (which the system drops if the holder dies).
Future<T> _oneMach9Install<T>(String runtimes, Future<T> Function() body) {
  final run = _mach9Installs.then((_) async {
    final lock = File('$runtimes/.mach9.lock').openSync(mode: FileMode.append);
    try {
      await lock.lock(FileLock.blockingExclusive);
      return await body();
    } finally {
      lock.closeSync();
    }
  });
  _mach9Installs = run.then<void>((_) {}, onError: (Object _) {});
  return run;
}

Future<void> _mach9Installs = Future<void>.value();

/// The folder `runtimes/mach9` names, or null.
String? _mach9Linked(String runtimes) {
  final link = Link('$runtimes/mach9');
  return link.existsSync() ? link.targetSync().split('/').last : null;
}

/// Deletes every `mach9-*` folder the link does not name and no open Mach9
/// bottle runs on. [BottleOpen] when [needed] is one that a bottle runs on.
Future<void> _removeUnusedMach9(
  String home,
  String runtimes, {
  String? needed,
}) async {
  final linked = _mach9Linked(runtimes);
  for (final old in Directory(runtimes).listSync(followLinks: false)) {
    final name = old.path.split('/').last;
    if (old is! Directory || !name.startsWith('mach9-') || name == linked) {
      continue;
    }
    if (await _openMach9Bottle(home, old.path) case final bottle?) {
      if (old.path == needed) throw BottleOpen(bottle);
      continue;
    }
    old.deleteSync(recursive: true);
  }
}

bool _isDmg(String path) => path.toLowerCase().endsWith('.dmg');

/// D5, from the plist alone: [app] is Mach9 (bundle id), new enough and made
/// for this macOS. Returns its version.
String _mach9Version(String app) {
  final plist = '$app/Contents/Info.plist';
  if (!File(plist).existsSync()) {
    throw IncompleteArchive(app, 'Contents/Info.plist');
  }
  final id = _plistString(plist, 'CFBundleIdentifier');
  if (id != mach9Identity.bundleId) {
    throw RuntimeNotTrusted(app, 'bundle id ${id ?? 'missing'}');
  }
  final version = _plistString(plist, 'CFBundleShortVersionString') ?? '';
  if (!_versionAtLeast(version, mach9Identity.minimumVersion)) {
    throw RuntimeTooOld(version, mach9Identity.minimumVersion);
  }
  // A folder name: nothing else may come from the plist.
  if (!RegExp(r'^[0-9][0-9A-Za-z.+-]*$').hasMatch(version)) {
    throw RuntimeNotTrusted(app, 'version $version');
  }
  final minimum = _plistString(plist, 'LSMinimumSystemVersion');
  final host = _macosVersion();
  if (minimum != null && host != null && !_versionAtLeast(host, minimum)) {
    throw const RuntimeUnavailable(RuntimeKind.mach9, RuntimeBlock.macosTooOld);
  }
  return version;
}

/// D5 on the copy (MR5): [_mach9Version], and the app signed by its
/// developer, all of it (`--deep`). Returns its version.
Future<String> _trustedMach9(String app) async {
  final version = _mach9Version(app);
  final team = await hostPlatform.signingTeam(app, deep: true);
  if (team != mach9Identity.team) {
    throw RuntimeNotTrusted(app, 'signed by team $team');
  }
  return version;
}

/// This Mac's version, or null where `sw_vers` is missing.
String? _macosVersion() {
  try {
    final result = Process.runSync('/usr/bin/sw_vers', ['-productVersion']);
    return result.exitCode == 0 ? '${result.stdout}'.trim() : null;
  } on ProcessException {
    return null;
  }
}

/// [BottleOpen] when a Mach9 bottle's wineserver runs (MR8): switching the
/// runtime under it would mix two Wine versions in one prefix.
Future<void> _noMach9BottleOpen(String home) async {
  final String rt;
  try {
    rt = runtimeDir(home, RuntimeKind.mach9);
  } on RuntimeNotInstalled {
    return;
  }
  if (await _openMach9Bottle(home, rt) case final bottle?) {
    throw BottleOpen(bottle);
  }
}

/// The first Mach9 bottle whose wineserver from the runtime [rt] runs.
Future<String?> _openMach9Bottle(String home, String rt) async {
  final bottles = Directory('$home/bottles');
  if (!bottles.existsSync() ||
      !File('$rt/engine/bin/wineserver').existsSync()) {
    return null;
  }
  for (final dir
      in bottles.listSync(followLinks: false).whereType<Directory>()) {
    try {
      if (_bottleRuntimeIn(dir.path) != RuntimeKind.mach9) continue;
    } on EngineFailure {
      continue;
    }
    if (await _serverRunning(rt, dir.path)) return dir.path.split('/').last;
  }
  return null;
}

/// Design §2.1: what a Mach9 runtime must hold under `engine/`.
const _mach9Required = [
  'bin/wine',
  'bin/wineserver',
  'lib/wine/aarch64-unix/ntdll.so',
  'lib/wine/aarch64-unix/compatdb.so',
  'lib/wine/aarch64-unix/wine.app',
  'lib/wine/aarch64-windows/kernel32.dll',
  'lib/wine/i386-windows/kernel32.dll',
  'lib/wine/dxgi/dxmt',
  'lib/wine/dxgi/wined3d',
  'lib/wine/d3d9/mtld3d',
  'lib/wine/d3d9/wined3d',
  'lib/external/libfreetype.6.dylib',
  'lib/external/libgnutls.30.dylib',
];

/// The checks after the copy (MR6), which only read: the required files, the
/// loader link, the signatures of the parts that run, and a Wine that starts.
Future<void> _checkMach9Copy(String tmp, {required String source}) async {
  final engine = '$tmp/engine';
  for (final file in _mach9Required) {
    if (FileSystemEntity.typeSync('$engine/$file', followLinks: false) ==
        FileSystemEntityType.notFound) {
      throw IncompleteArchive(source, file);
    }
  }
  // The loader must run from inside the signed wine.app (LogHint.loaderNotSigned).
  if (!FileSystemEntity.isLinkSync('$engine/bin/wine')) {
    throw IncompleteArchive(source, 'bin/wine (a link)');
  }
  for (final part in [
    'lib/wine/aarch64-unix/wine.app',
    'bin/wineserver',
    'lib/wine/aarch64-unix/ntdll.so',
    'lib/wine/aarch64-unix/compatdb.so',
  ]) {
    final team = await hostPlatform.signingTeam('$engine/$part');
    if (team != mach9Identity.team) {
      throw RuntimeNotTrusted('$engine/$part', 'signed by team $team');
    }
  }
  // --version never creates the prefix it is given.
  final run = await Process.run(
    '$engine/bin/wine',
    ['--version'],
    environment: {
      ...hostPlatform.baseEnv(Platform.environment),
      'WINEPREFIX': '$tmp/prefix',
    },
    includeParentEnvironment: false,
  );
  if (!'${run.stdout}'.startsWith('wine-')) {
    throw ProcessFailed(
      'wine --version',
      run.exitCode,
      '${run.stdout}${run.stderr}',
    );
  }
}

/// A `Mach9.app` in [HostPlatform.applicationDirs], with its version, or null
/// (MR4). Reads its Info.plist only: the signature is checked when it is
/// installed.
({String path, String version})? findMach9App() {
  for (final dir in hostPlatform.applicationDirs) {
    final app = '$dir/Mach9.app';
    final plist = '$app/Contents/Info.plist';
    if (!File(plist).existsSync()) continue;
    if (_plistString(plist, 'CFBundleIdentifier') != mach9Identity.bundleId) {
      continue;
    }
    final version = _plistString(plist, 'CFBundleShortVersionString');
    if (version != null) return (path: app, version: version);
  }
  return null;
}

/// A string value of an Info.plist: XML read here, binary through plutil.
String? _plistString(String plist, String key) {
  try {
    final bytes = File(plist).readAsBytesSync();
    if (bytes.length >= 6 && latin1.decode(bytes.sublist(0, 6)) == 'bplist') {
      final result = Process.runSync('/usr/bin/plutil', [
        '-extract',
        key,
        'raw',
        plist,
      ]);
      return result.exitCode == 0 ? '${result.stdout}'.trim() : null;
    }
    return RegExp(
      '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]*)</string>',
    ).firstMatch(utf8.decode(bytes, allowMalformed: true))?.group(1)?.trim();
  } on Object {
    return null;
  }
}

/// Installs Wine Mono into a Mach9 bottle (MB7) and returns the log; null for
/// a bodega bottle or when Mono is already there. The MSI is the runtime's;
/// only when it is missing is it downloaded again, the one use of the network
/// after the install (I5). A failure stops the bottle and keeps it.
Future<String?> installMono(
  String home,
  String name, {
  Duration limit = const Duration(minutes: 10),
}) async {
  final dir = _existing(home, name);
  if (_bottleRuntimeIn(dir) != RuntimeKind.mach9) return null;
  if (!monoMissing(home, name)) return null;
  final rt = runtimeDir(home, RuntimeKind.mach9);
  final prefix = '$dir/prefix';
  // The MSI the runtime keeps (MU3), else the one its appwiz.cpl names,
  // from its GitHub release.
  final kept = Directory(rt)
      .listSync()
      .whereType<File>()
      .where(
        (file) => RegExp(r'/wine-mono-[0-9.]+-x86\.msi$').hasMatch(file.path),
      )
      .firstOrNull;
  var msi = kept?.path;
  if (msi == null) {
    final version = monoVersionOf('$rt/engine');
    if (version == null)
      throw IncompleteArchive(rt, 'appwiz.cpl naming wine-mono');
    final release = await monoRelease(version);
    msi = await _download(
      home,
      release.url,
      release.sha256,
      name: release.file,
    );
  }
  final log = await _launchIn(
    home,
    name,
    'msiexec',
    ['/i', msi, '/qn'],
    backend: 'wine',
    label: 'wine-mono',
  );
  final code = await exitOf(log).timeout(
    limit,
    onTimeout: () async {
      await _wineserver(rt, prefix, '-k');
      return -1;
    },
  );
  if (!_installerOk.contains(code)) {
    await _wineserver(rt, prefix, '-k');
    throw WineToolFailed(WineTool.mono, code, log);
  }
  // The registry reaches the disk when the server ends.
  await _wineserver(
    rt,
    prefix,
    '-w',
  ).timeout(limit, onTimeout: () => _wineserver(rt, prefix, '-k'));
  if (monoMissing(home, name)) {
    throw InstallerNoExe(r'C:\windows\mono\mono-2.0', log);
  }
  return log;
}

/// Whether a Mach9 bottle lacks Wine Mono (MB8): false for a bodega one.
bool monoMissing(String home, String name) {
  final dir = _existing(home, name);
  if (_bottleRuntimeIn(dir) != RuntimeKind.mach9) return false;
  // PE9: .NET Framework 4 replaces Mono on purpose (dotnet48's marker, S3).
  if (File(
    '$dir/prefix/drive_c/windows/Microsoft.NET/Framework/v4.0.30319/clr.dll',
  ).existsSync()) {
    return false;
  }
  return FileSystemEntity.typeSync(
        '$dir/prefix/drive_c/windows/mono/mono-2.0',
        followLinks: false,
      ) !=
      FileSystemEntityType.directory;
}

/// What [moveToNative] is doing, for a UI (PE12).
enum NativeMoveStep { creating, copying, finishing }

/// Turns the Rosetta bottle [name] into a Native engine one under the same
/// name (PE12, P17–P19). A new Mach9 bottle is made under a free temporary
/// name and filled with what the old one's user and programs wrote; only
/// then is the old one deleted and the new one renamed, so a failure leaves
/// the old one as it was. Returns the runtimes (`<id> <arch>`) the old bottle
/// had installed, which do not move.
Future<List<String>> moveToNative(
  String home,
  String name, {
  void Function(NativeMoveStep step)? onStep,
}) async {
  final dir = _existing(home, name);
  if (_bottleRuntimeIn(dir) == RuntimeKind.mach9) {
    throw const BadChoice(ChoiceKind.runtime, 'mach9', ['bodega']);
  }
  if (hostPlatform.mach9Block case final block?) {
    throw RuntimeUnavailable(RuntimeKind.mach9, block);
  }
  runtimeDir(home, RuntimeKind.mach9);
  if (_installedRuntime(home, dir) case final rt?
      when await _serverRunning(rt, dir)) {
    throw BottleOpen(name);
  }
  final settings = _settings(dir);
  final runtimes = [
    for (final row in dependencyTable)
      for (final arch in row.files.keys)
        if (dependencyStatus(home, name, row.id, arch) == true)
          '${row.id} $arch',
  ];
  final base = name.length > 56 ? name.substring(0, 56) : name;
  var temp = '$base-native';
  for (var n = 2; Directory(bottleDir(home, temp)).existsSync(); n++) {
    temp = '$base-native$n';
  }

  try {
    onStep?.call(NativeMoveStep.creating);
    await createBottle(home, temp, runtime: RuntimeKind.mach9);
    if (settings.user.isNotEmpty) {
      await setBottleUser(home, temp, settings.user);
    }
    if (settings.windows != _defaults.windows) {
      await setWindowsVersion(home, temp, settings.windows);
    }
    onStep?.call(NativeMoveStep.copying);
    final to = bottleDir(home, temp);
    await stopBottle(home, temp);
    await _mergeInto(
      '$dir/prefix/drive_c',
      '$to/prefix/drive_c',
      skip: const {'windows'},
    );
    for (final entry in const ['apps.json', 'icons']) {
      if (FileSystemEntity.typeSync('$dir/$entry', followLinks: false) !=
          FileSystemEntityType.notFound) {
        await hostPlatform.copyTree('$dir/$entry', '$to/$entry');
      }
    }
    String? kept(String? backend) =>
        backend != null && backendNamesFor(RuntimeKind.mach9).contains(backend)
        ? backend
        : null;
    final now = _settings(to);
    _saveSettings(
      to,
      _with(
        now,
        backend: kept(settings.backend) ?? 'auto',
        programs: {
          for (final MapEntry(:key, :value) in settings.programs.entries)
            key: (backend: kept(value.backend), env: value.env, hud: value.hud),
        },
        env: settings.env,
        gpu: settings.gpu,
        gamemode: settings.gamemode,
        configOff: settings.configOff,
        verdicts: settings.verdicts,
        // ER7: a Rosetta bottle's migrated retina; its old default, off,
        // takes the new bottle's.
        retina: settings.retina == 'off' ? now.retina : settings.retina,
      ),
    );
  } on Object {
    if (Directory(bottleDir(home, temp)).existsSync()) {
      await removeBottle(home, temp);
    }
    rethrow;
  }
  onStep?.call(NativeMoveStep.finishing);
  await removeBottle(home, name);
  await renameBottle(home, temp, name);
  return runtimes;
}

/// Copies [from]'s entries into [to] (P17): one [to] lacks is copied whole
/// with [HostPlatform.copyTree], which keeps links as links; a folder both
/// have is merged the same way; any other entry [to] has stays as it is. A
/// link in [to] is never followed, so nothing is written through the links a
/// prefix keeps to the Mac's own folders. [skip] is matched without case.
Future<void> _mergeInto(
  String from,
  String to, {
  Set<String> skip = const {},
}) async {
  for (final entry in Directory(from).listSync(followLinks: false)) {
    final name = entry.path.split('/').last;
    if (skip.contains(name.toLowerCase())) continue;
    final target = '$to/$name';
    final there = FileSystemEntity.typeSync(target, followLinks: false);
    if (there == FileSystemEntityType.notFound) {
      await hostPlatform.copyTree(entry.path, target);
    } else if (there == FileSystemEntityType.directory &&
        FileSystemEntity.typeSync(entry.path, followLinks: false) ==
            FileSystemEntityType.directory) {
      await _mergeInto(entry.path, target);
    }
  }
}
