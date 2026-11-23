part of 'engine.dart';

/// The Mach9 release Bodega is checked with, and the Wine Mono that its
/// `appwiz.cpl` asks for, in one record so that a bump re-checks both (MR3).
typedef Mach9Release = ({
  String version,
  String url,
  String sha256,
  int bytes,
  String file,

  /// What the copied runtime takes on disk.
  int diskBytes,
  String bundleId,
  String team,

  /// The oldest Mach9 accepted: older ones drop rules without `name=`.
  String minimumVersion,
  String minimumMacos,
  ({String version, String url, String sha256, int bytes, String file}) mono,
});

/// The pin (D4, D11). Tests may replace it; the app only reads it.
Mach9Release mach9Release = (
  version: '0.4.0',
  url: 'https://github.com/athei/mach9/releases/download/v0.4.0/Mach9.dmg',
  sha256: '3b5dd83ee7b08d55e6c4a84dabb32db994dc6a5bfb2a1500fb50d0b45436e6d9',
  bytes: 200499232,
  file: 'Mach9-0.4.0.dmg',
  diskBytes: 1061000000,
  bundleId: 'app.mach9',
  team: 'WLKUUJD25W',
  minimumVersion: '0.4.0',
  minimumMacos: '26.4',
  mono: (
    version: '11.3.0',
    url: 'https://dl.winehq.org/wine/wine-mono/11.3.0/wine-mono-11.3.0-x86.msi',
    sha256: 'df2dfc1665c2511882e7cabd56eafd0c0a3d94e5a7e86f969277f6c189d418d3',
    bytes: 83348992,
    file: 'wine-mono-11.3.0-x86.msi',
  ),
);

/// What [installMach9] is doing, for a UI to word in its own language.
enum Mach9Step {
  downloadingMono('Downloading Wine Mono'),
  downloading('Downloading Mach9'),
  mounting('Opening the dmg'),
  checkingSignature("Checking Mach9's signature"),
  copying('Copying Mach9'),
  checking('Checking the copy'),
  switching('Switching to the new version');

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
/// at it (MR4–MR9), from [source] (a `.dmg` or a `.app`), else the pinned
/// `Mach9.app` in the applications folders, else the pinned dmg. [pinned]
/// says the caller downloaded the pinned dmg, whose hash must then match.
/// [mono] is the Wine Mono MSI, else downloaded; its hash is always checked.
/// The signature is checked on the copy, and installs run one at a time
/// (`runtimes/.mach9.lock`). Nothing under the copy's `engine/` is ever written, signed or stripped
/// (I3); a failure or [cancelled] leaves no `.tmp-*`, no changed link and no
/// mounted volume (I6). Returns the runtime's folder.
Future<String> installMach9(
  String home, {
  String? source,
  bool pinned = false,
  String? mono,
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

  // Mono first: a bad MSI must stop the install before anything is copied.
  final String msi;
  if (mono != null) {
    msi = mono;
  } else {
    onStep?.call(Mach9Step.downloadingMono);
    msi = await _download(
      home,
      mach9Release.mono.url,
      mach9Release.mono.sha256,
      name: mach9Release.mono.file,
    );
    downloaded.add(msi);
  }
  if (!File(msi).existsSync() ||
      await sha256Of(msi) != mach9Release.mono.sha256) {
    throw ChecksumMismatch(msi);
  }
  stopIfCancelled();

  var from = source;
  String origin;
  if (from != null) {
    origin = pinned ? 'download' : (_isDmg(from) ? 'dmg' : 'app');
  } else if (findMach9App() case final app?
      when app.version == mach9Release.version) {
    from = app.path;
    origin = 'app';
  } else {
    onStep?.call(Mach9Step.downloading);
    from = await _download(
      home,
      mach9Release.url,
      mach9Release.sha256,
      name: mach9Release.file,
    );
    downloaded.add(from);
    pinned = true;
    origin = 'download';
  }
  if (pinned && await sha256Of(from) != mach9Release.sha256) {
    throw ChecksumMismatch(from);
  }
  stopIfCancelled();

  final image = from;
  // One install at a time, in this process and across processes (the app
  // and the CLI): they share the staging folder and the link.
  final dest = await _oneMach9Install(runtimes.path, () async {
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
      if (_mach9Linked(runtimes.path) == id) throw AlreadyInstalled(dest);
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
        File(msi).copySync('${tmp.path}/${mach9Release.mono.file}');
        _writeJson('${tmp.path}/runtime.json', {
          'kind': RuntimeKind.mach9.name,
          'version': version,
          'source': origin,
          'checked': version == mach9Release.version,
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
      final link = Link('${runtimes.path}/mach9.tmp');
      if (FileSystemEntity.typeSync(link.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        link.deleteSync();
      }
      (link..createSync(id)).renameSync('${runtimes.path}/mach9');
      return dest;
    } finally {
      if (mount != null) await _detach(mount);
    }
  });
  // Older versions go: only the one the link names is ever used (MR8). One a
  // bottle still runs on stays, for the next install to remove.
  await _oneMach9Install(
    runtimes.path,
    () => _removeUnusedMach9(home, runtimes.path),
  );
  for (final file in downloaded) {
    if (File(file).existsSync()) File(file).deleteSync();
  }
  return dest;
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
  if (id != mach9Release.bundleId) {
    throw RuntimeNotTrusted(app, 'bundle id ${id ?? 'missing'}');
  }
  final version = _plistString(plist, 'CFBundleShortVersionString') ?? '';
  if (!_versionAtLeast(version, mach9Release.minimumVersion)) {
    throw RuntimeTooOld(version, mach9Release.minimumVersion);
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
  if (team != mach9Release.team) {
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
    if (team != mach9Release.team) {
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
    if (_plistString(plist, 'CFBundleIdentifier') != mach9Release.bundleId) {
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
  var msi = '$rt/${mach9Release.mono.file}';
  if (!File(msi).existsSync()) {
    msi = await _download(
      home,
      mach9Release.mono.url,
      mach9Release.mono.sha256,
      name: mach9Release.mono.file,
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
        retina: settings.highRes ? 'on' : now.retina,
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
