part of 'engine.dart';

// Nintendo Switch games, and the emulator the user installs to play them, or
// the Mac apps users make of their own games with nxnative, which play alone
// (design §1–§8). Switch lives in this one part: removing it is deleting this
// file and the few lines elsewhere that name its types.

/// One emulator, as data: another emulator or Linux arrives as a row or a
/// sub-record, not as new code.
typedef Emulator = ({
  /// The row's key, as `ryubing`.
  String id,

  /// A brand, shown as it is.
  String name,

  /// Its official download page, the one link Switch's code holds: the
  /// CLI's status names it and the app opens it in the browser while no
  /// install is found. Bodega never downloads the emulator itself.
  String page,

  /// What it opens: lower case, no dot.
  List<String> extensions,
  EmulatorArgs args,
  EmulatorOnMac? mac,

  /// Null until the second phase.
  EmulatorOnLinux? linux,
});

/// What an emulator takes on its command line, in this order: [headless] and
/// [fullscreen] when the settings say so, then [game], where `{game}` is the
/// game's path.
typedef EmulatorArgs = ({
  List<String> headless,
  List<String> fullscreen,
  List<String> game,
});

/// An emulator's Mac app: the bundle id and the executable its `Info.plist`
/// must name, and [app], the file name it is looked for by.
typedef EmulatorOnMac = ({
  String bundleId,
  String app,
  String executable,
  EmulatorFiles files,
});

/// An emulator on Linux, for the second phase: its AppImages, its Flatpak id
/// and its commands.
typedef EmulatorOnLinux = ({
  List<String> appImages,
  String? flatpak,
  List<String> commands,
  EmulatorFiles files,
});

/// Where an emulator keeps the keys and the firmware the user brings. `~` is
/// HOME, `<bin>` the executable's folder, `<dir>` the folder that holds the
/// install, `<data>` the data folder in use. The last [data] entry is the
/// default one, and [userKeys] counts only while that one is in use or no data
/// folder exists.
typedef EmulatorFiles = ({
  List<String> data,
  String keys,
  String? userKeys,
  String firmware,
});

/// A game in the list. [path] is its key: absolute, as the picker or the scan
/// gave it. [title] and [titleId] come from the file name alone (SE12).
typedef SwitchGame = ({
  String path,
  String title,
  String? titleId,
  DateTime added,
});

/// The Switch settings: the emulator picked by hand, if any, and how games
/// open.
typedef SwitchSettings = ({String? picked, bool fullscreen, bool headless});

/// An emulator found on this host (design §2): [app] is the install and [exe]
/// what starts it; [version] is its own, when it gives one; [picked] tells the
/// pick from a copy in a fixed place; [quarantined] whether macOS keeps it in
/// quarantine, which Bodega reports and never removes (SE7).
typedef EmulatorInstall = ({
  String app,
  String exe,
  String? version,
  bool picked,
  bool quarantined,
});

/// A native app (design §4): a Mac app a user made of their own game with
/// nxnative, which plays without the emulator. [titleId] is the `DMTitleID`
/// of its `Info.plist`; [exe] is what starts it,
/// `Contents/MacOS/<CFBundleExecutable>`, or null when that is no regular
/// file with an exec bit, which only a launch minds; [quarantined] is whether
/// macOS keeps it in quarantine, which Bodega reports and never removes (SE7).
typedef NativeApp = ({String titleId, String? exe, bool quarantined});

/// What [checkSwitch] found (design §3): the table's one row, its install or
/// null, and whether the keys and the firmware the user brings are there.
typedef SwitchStatus = ({
  Emulator emulator,
  EmulatorInstall? install,
  bool keys,
  bool firmware,
});

/// The emulators Bodega opens games with (design §1). One row, Ryubing's, from
/// Ryubing's own sources at commit a61a426 (MIT), named by file:
/// - extensions: `src/Ryujinx/Systems/AppLibrary/ApplicationLibrary.cs`;
/// - args: `src/Ryujinx/Utilities/CommandLineState.cs` and
///   `src/Ryujinx/Headless/Options.cs`;
/// - mac: `distribution/macos/Info.plist` and
///   `distribution/macos/create_app_bundle.sh`;
/// - data folders: `src/Ryujinx.Common/Configuration/AppDataManager.cs`;
/// - keys: `src/Ryujinx.HLE/FileSystem/VirtualFileSystem.cs`;
/// - firmware: `ContentManager.cs` and `ContentPath.cs`.
///
/// `page` is Ryubing's official download page, and this row is the only
/// place that holds it (SN10). A host reads only its own sub-record (`mac`,
/// `linux`).
const switchEmulators = <Emulator>[
  (
    id: 'ryubing',
    name: 'Ryubing',
    page: 'https://ryujinx.app/download',
    extensions: ['xci', 'nsp', 'pfs0', 'nca', 'nro', 'nso'],
    args: (
      headless: ['--no-gui', '--use-main-config'],
      fullscreen: ['--fullscreen'],
      game: ['{game}'],
    ),
    mac: (
      bundleId: 'org.ryujinx.Ryujinx',
      app: 'Ryujinx.app',
      executable: 'Ryujinx',
      files: (
        data: [
          '<bin>/portable',
          '<dir>/portable',
          '~/Library/Application Support/Ryujinx',
        ],
        keys: '<data>/system/prod.keys',
        userKeys: '~/.switch/prod.keys',
        firmware: '<data>/bis/system/Contents/registered',
      ),
    ),
    linux: null,
  ),
];

/// The emulator in use: the table's one row.
Emulator get _switchEmulator => switchEmulators.first;

/// Whether [path] is a native app's (design §4): its name ends in `.app`,
/// without case. The one rule the store, the scan, the launch, the CLI and
/// the app share, so the store keeps no kind.
bool isNativeApp(String path) =>
    _switchPath(path).toLowerCase().endsWith('.app');

/// Adds game files and native apps to the list (SE10). Each [paths] entry is
/// taken as [_switchPath] gives it. A native app's path ([isNativeApp]) is
/// [NotAvailable] where the host has no emulators, [MissingFile] when nothing
/// is there, and [NotASwitchGame] when [EmulatorHost.nativeApp] finds none:
/// [emulators] is asked, or else the host's, and only about such a path. Any
/// other path must have one of the emulator's extensions, compared without
/// case, and be a file; else it throws [NotASwitchGame], or [MissingFile]
/// when nothing is there. All of it comes before anything is written. It
/// reads nothing from the files and copies none, nor anything of an app but
/// what [EmulatorHost.nativeApp] reads. `known` counts the paths already
/// listed or given twice.
Future<({int added, int known})> addSwitchGames(
  String home,
  List<String> paths, {
  EmulatorHost? emulators,
}) async {
  final extensions = _switchEmulator.extensions;
  final games = <String>[];
  for (final given in paths) {
    final path = _switchPath(given);
    if (isNativeApp(path)) {
      await _nativeAppAt(path, emulators ?? hostPlatform.emulators);
    } else if (!extensions.contains(_extensionOf(path))) {
      throw NotASwitchGame(path, extensions);
    } else {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.notFound) throw MissingFile(path);
      if (type != FileSystemEntityType.file) {
        throw NotASwitchGame(path, extensions);
      }
    }
    games.add(path);
  }
  return _addSwitchPaths(home, games);
}

/// The native app at [path], as [emulators] finds it (SE10): [NotAvailable]
/// where they are not supported, [MissingFile] when nothing is there, and
/// [NotASwitchGame] when its `Info.plist` has no `DMTitleID`.
Future<NativeApp> _nativeAppAt(String path, EmulatorHost emulators) async {
  if (!emulators.supported) {
    throw NotAvailable('switch', hostPlatform.displayName);
  }
  if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
    throw MissingFile(path);
  }
  return await emulators.nativeApp(path) ??
      (throw NotASwitchGame(path, _switchEmulator.extensions));
}

/// Scans [folder] once and adds what it finds, as [addSwitchGames] does
/// (SE11). It reads names only, in [folder] and two levels below it,
/// following no link and passing over hidden entries, the folders it may not
/// list and `.nca` files, which in an unpacked title are parts, not games.
/// Each `*.app` folder it meets is a native app's path, which [emulators], or
/// else the host's, is asked about: it is added when it holds a native app
/// and passed over otherwise, and where the host has no emulators every one
/// is passed over. A scan never goes inside an app, the [folder] itself
/// included. It keeps no folder, so nothing is ever scanned again. A [folder]
/// that is not there is [MissingFile].
Future<({int added, int known})> addSwitchFolder(
  String home,
  String folder, {
  EmulatorHost? emulators,
}) async {
  final root = _switchPath(folder);
  if (FileSystemEntity.typeSync(root) != FileSystemEntityType.directory) {
    throw MissingFile(root);
  }
  final extensions = {..._switchEmulator.extensions}..remove('nca');
  final games = <String>[];
  final apps = <String>[];
  void scan(String dir, int depth) {
    final List<FileSystemEntity> entries;
    try {
      entries = Directory(dir).listSync(followLinks: false)
        ..sort((a, b) => a.path.compareTo(b.path));
    } on FileSystemException {
      return;
    }
    for (final entry in entries) {
      final name = entry.path.split('/').last;
      if (name.startsWith('.')) continue;
      if (entry is Directory && isNativeApp(entry.path)) {
        apps.add(entry.path);
      } else if (entry is Directory && depth < 2) {
        scan(entry.path, depth + 1);
      } else if (entry is File && extensions.contains(_extensionOf(name))) {
        games.add(entry.path);
      }
    }
  }

  if (isNativeApp(root)) {
    apps.add(root);
  } else {
    scan(root, 0);
  }
  // The host is asked only once an app is met (SE9).
  if (apps.isNotEmpty) {
    final host = emulators ?? hostPlatform.emulators;
    if (host.supported) {
      for (final app in apps) {
        if (await host.nativeApp(app) != null) games.add(app);
      }
    }
  }
  return _addSwitchPaths(home, games);
}

/// The list, sorted by title without case and then by path, as [_appsIn]
/// sorts (SE13). It stats no game: one whose file is gone is still listed.
List<SwitchGame> switchGames(String home) =>
    [for (final json in _readSwitchGames(home)) _switchGameOf(json)]
      ..sort((a, b) {
        final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        return byTitle != 0 ? byTitle : a.path.compareTo(b.path);
      });

/// Forgets a listed game and leaves its file where it is (SE13).
void removeSwitchGame(String home, String path) {
  final key = _switchPath(path);
  final games = _readSwitchGames(home);
  final before = games.length;
  games.removeWhere((json) => json['path'] == key);
  if (games.length == before) throw SwitchGameNotFound(key);
  _writeSwitchGames(home, games);
}

/// The settings while `switch/settings.json` says nothing: no pick, full
/// screen and headless (SE4).
const SwitchSettings _switchDefaults = (
  picked: null,
  fullscreen: true,
  headless: true,
);

/// `switch/settings.json`, or the defaults for what it does not hold (SE4). A
/// value of the wrong type is [CorruptData], never ignored (SE3).
SwitchSettings switchSettings(String home) {
  final file = File('$home/switch/settings.json');
  if (!file.existsSync()) return _switchDefaults;
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return (
      picked: json['picked'] as String?,
      fullscreen: (json['fullscreen'] ?? _switchDefaults.fullscreen) as bool,
      headless: (json['headless'] ?? _switchDefaults.headless) as bool,
    );
  } on Object catch (e) {
    throw CorruptData(file.path, '$e');
  }
}

/// How games open, from their next launch (SE4); what is not given stays.
void setSwitchOptions(String home, {bool? fullscreen, bool? headless}) {
  final settings = switchSettings(home);
  _saveSwitchSettings(home, (
    picked: settings.picked,
    fullscreen: fullscreen ?? settings.fullscreen,
    headless: headless ?? settings.headless,
  ));
}

/// Only what differs from [_switchDefaults], as [_saveSettings] writes, so a
/// default changed later reaches everyone who never set it (SE4).
void _saveSwitchSettings(String home, SwitchSettings settings) {
  Directory('$home/switch').createSync(recursive: true);
  _writeJson('$home/switch/settings.json', {
    'picked': ?settings.picked,
    if (settings.fullscreen != _switchDefaults.fullscreen)
      'fullscreen': settings.fullscreen,
    if (settings.headless != _switchDefaults.headless)
      'headless': settings.headless,
  });
}

/// The emulator, the keys and the firmware, as the host finds them (SE5–SE8),
/// with [env] or else this process's environment, whose HOME is `~`. It only
/// stats paths and asks one folder whether it is empty: it never opens, reads,
/// sizes or hashes a file, so an empty `prod.keys` counts. What is missing is
/// data, never a throw, and nothing waits on it: [checkHost] does not call
/// it, and a launch needs only the emulator. Where the host has no emulators
/// it throws [NotAvailable], before it reads anything.
Future<SwitchStatus> checkSwitch(
  String home, [
  Map<String, String>? env,
]) async {
  final emulators = _switchHost();
  final environment = env ?? Platform.environment;
  final emulator = _switchEmulator;
  final install = await emulators.find(
    emulator,
    environment,
    picked: switchSettings(home).picked,
  );
  final files = emulators.files(emulator);
  if (files == null) {
    return (emulator: emulator, install: install, keys: false, firmware: false);
  }
  // `<bin>` and `<dir>` are known only with an install: else the entries that
  // name them are passed over.
  String? place(String template, [String? data]) {
    for (final (mark, path) in [
      ('~', environment['HOME']),
      ('<bin>', install == null ? null : File(install.exe).parent.path),
      ('<dir>', install == null ? null : File(install.app).parent.path),
      ('<data>', data),
    ]) {
      if (template.startsWith(mark)) {
        return path == null ? null : '$path${template.substring(mark.length)}';
      }
    }
    return template;
  }

  bool isFolder(String? path) =>
      path != null &&
      FileSystemEntity.typeSync(path) == FileSystemEntityType.directory;
  bool isFile(String? path) =>
      path != null &&
      FileSystemEntity.typeSync(path) == FileSystemEntityType.file;

  // The data folder in use is the first that exists; the last is the
  // default, the only one with which the user's own keys count.
  final folders = [for (final entry in files.data) place(entry)];
  final at = folders.indexWhere(isFolder);
  final data = at < 0 ? null : folders[at];
  final userKeys = files.userKeys;
  final keys =
      (data != null && isFile(place(files.keys, data))) ||
      ((at < 0 || at == folders.length - 1) &&
          userKeys != null &&
          isFile(place(userKeys)));
  final registered = data == null ? null : place(files.firmware, data);
  return (
    emulator: emulator,
    install: install,
    keys: keys,
    firmware:
        registered != null &&
        isFolder(registered) &&
        await _holdsAny(registered),
  );
}

/// Saves [app] as the emulator to use while the fixed places hold none, or
/// forgets the pick for null, the CLI's `auto` (SE4, SE6). [app] is kept as
/// [_switchPath] gives it, and only once the host confirms it: else it throws
/// [NotAnEmulator] and saves nothing. Where the host has no emulators it
/// throws [NotAvailable], before it touches `switch/`.
Future<void> chooseEmulator(String home, String? app) async {
  final emulators = _switchHost();
  final settings = switchSettings(home);
  final emulator = _switchEmulator;
  final picked = app == null ? null : _switchPath(app);
  if (picked != null && await emulators.confirm(emulator, picked) == null) {
    throw NotAnEmulator(picked, emulator.name);
  }
  _saveSwitchSettings(home, (
    picked: picked,
    fullscreen: settings.fullscreen,
    headless: settings.headless,
  ));
}

/// The host's emulators, or [NotAvailable] where it has none (SE9, SN2).
EmulatorHost _switchHost() {
  final emulators = hostPlatform.emulators;
  if (!emulators.supported) {
    throw NotAvailable('switch', hostPlatform.displayName);
  }
  return emulators;
}

/// Whether the folder [dir] holds at least one entry: the listing stops at
/// the first name, and one that cannot be made counts as none.
Future<bool> _holdsAny(String dir) async {
  try {
    return !await Directory(dir).list(followLinks: false).isEmpty;
  } on FileSystemException {
    return false;
  }
}

/// Opens a listed game and returns its run's log (SE14–SE16): a game file
/// with the emulator, and a native app ([isNativeApp]) by itself. It throws,
/// in this order, [NotAvailable] where the host has no emulators,
/// [SwitchGameNotFound] for a path not listed, [MissingFile] when nothing is
/// at it, [SwitchGameRunning] while a run of it lives, and last [NoEmulator]
/// when no emulator is found for a game file, or [NotASwitchGame] when a
/// native app is none or has no executable; it checks neither the keys nor
/// the firmware. The emulator gets the row's arguments as the settings say,
/// then the game, and a native app no argument at all; either starts detached
/// in `$HOME`, with the host's environment and nothing else. The `.pid` and
/// `.exit` beside the log are the contract, which [switchRuns] and [exitOf]
/// read.
Future<String> openSwitchGame(
  String home,
  String path, [
  Map<String, String>? env,
]) async {
  final emulators = _switchHost();
  final game = _switchPath(path);
  final listed = switchGames(home)
      .where((entry) => entry.path == game)
      .firstOrNull;
  if (listed == null) throw SwitchGameNotFound(game);
  if (FileSystemEntity.typeSync(game) == FileSystemEntityType.notFound) {
    throw MissingFile(game);
  }
  if ((await switchRuns(home)).any((run) => run.game == game)) {
    throw SwitchGameRunning(game);
  }
  final environment = env ?? Platform.environment;
  final (:first, :argv) = isNativeApp(game)
      ? await _nativeCommand(emulators, game)
      : await _emulatorCommand(home, emulators, environment, game);
  // Ryubing will not start from Downloads or iCloud (design §5).
  final cwd = environment['HOME'] ?? '/';
  final log = _newSwitchLog(home, listed.title, [
    first,
    'exe ${argv.first}',
    'game $game',
    'cwd $cwd',
    'argv ${argv.join(' ')}',
  ]);
  await _startSwitchRun(log, argv, cwd, emulators.env(environment));
  return log;
}

/// How the emulator opens [game]: the first line of the log's header, and
/// the found install's executable with the row's arguments as the settings
/// say, then the game. No emulator found is [NoEmulator].
Future<({String first, List<String> argv})> _emulatorCommand(
  String home,
  EmulatorHost emulators,
  Map<String, String> env,
  String game,
) async {
  final emulator = _switchEmulator;
  final settings = switchSettings(home);
  final install = await emulators.find(emulator, env, picked: settings.picked);
  if (install == null) throw _noEmulator(emulator);
  final args = emulator.args;
  return (
    first: 'emulator ${[emulator.name, ?install.version].join(' ')}',
    argv: [
      install.exe,
      if (settings.headless) ...args.headless,
      if (settings.fullscreen) ...args.fullscreen,
      for (final arg in args.game) arg.replaceAll('{game}', game),
    ],
  );
}

/// How the native app at [app] opens (design §5): the first line of the
/// log's header, with its title id, and its executable alone, with no
/// argument whatever the settings say, so its own settings window and the
/// user's choices apply. One that is not a native app, or has no executable,
/// is [NotASwitchGame].
Future<({String first, List<String> argv})> _nativeCommand(
  EmulatorHost emulators,
  String app,
) async {
  final native = await emulators.nativeApp(app);
  final exe = native?.exe;
  if (native == null || exe == null) {
    throw NotASwitchGame(app, _switchEmulator.extensions);
  }
  return (first: 'native ${native.titleId}', argv: [exe]);
}

/// The runs that live (SE18): each `switch/logs/*.log` with a `.pid`, no
/// `.exit` and a pid that still runs its `# exe`, with the game of its
/// `# game` line. The engine keeps no run in memory, so a run is found again
/// after Bodega or the CLI restarts, and a pid that runs nothing, or something
/// else, marks a run that ended. Where the host has no emulators it throws
/// [NotAvailable].
Future<List<({String game, String log})>> switchRuns(String home) async => [
  for (final run in await _liveSwitchRuns(home)) (game: run.game, log: run.log),
];

/// The runs of [switchRuns], each with the pid and the `# exe` it was found
/// by, which a stop signals.
Future<List<({String game, String log, int pid, String exe})>> _liveSwitchRuns(
  String home,
) async {
  final emulators = _switchHost();
  final logs = Directory('$home/switch/logs');
  if (!logs.existsSync()) return [];
  final runs = <({String game, String log, int pid, String exe})>[];
  final paths = [
    for (final entry in logs.listSync())
      if (entry.path.endsWith('.log')) entry.path,
  ]..sort();
  for (final log in paths) {
    final stem = _switchStem(log);
    try {
      final pidFile = File('$stem.pid');
      if (File('$stem.exit').existsSync() || !pidFile.existsSync()) continue;
      final pid = int.tryParse(pidFile.readAsStringSync().trim());
      final header = await _switchHeader(log);
      final (exe, game) = (header['exe'], header['game']);
      if (pid != null &&
          exe != null &&
          game != null &&
          await emulators.runs(pid, exe)) {
        runs.add((game: game, log: log, pid: pid, exe: exe));
      }
    } on FileSystemException {
      // A log removed while it was read is no run.
    }
  }
  return runs;
}

/// Stops the live run of [path], listed or not (SE19): the host sends its
/// program SIGTERM, then SIGKILL if no `.exit` shows within 5 s and the pid
/// still runs the log's `# exe`. The shell is never signalled, so it lives to
/// write `# exit=N` and the `.exit` that [exitOf] follows (SE17). A listed
/// game with no live run is a no-op, as [stopBottle] takes "no server"; a
/// path neither listed nor running is [SwitchGameNotFound]. Where the host
/// has no emulators it throws [NotAvailable], before it reads anything.
Future<void> stopSwitchGame(String home, String path) async {
  final emulators = _switchHost();
  final game = _switchPath(path);
  final runs = [
    for (final run in await _liveSwitchRuns(home))
      if (run.game == game) run,
  ];
  if (runs.isEmpty) {
    if (_readSwitchGames(home).any((json) => json['path'] == game)) return;
    throw SwitchGameNotFound(game);
  }
  for (final run in runs) {
    await emulators.stop(run.pid, run.exe);
  }
  bool ended(({String game, String log, int pid, String exe}) run) =>
      File('${_switchStem(run.log)}.exit').existsSync();
  final clock = Stopwatch()..start();
  while (!runs.every(ended) && clock.elapsed < const Duration(seconds: 5)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  for (final run in runs) {
    // The host signals only while the pid still runs the `# exe`.
    if (!ended(run)) await emulators.stop(run.pid, run.exe, kill: true);
  }
}

/// A run's log path without `.log`, which its `.pid` and `.exit` share.
String _switchStem(String log) => log.substring(0, log.length - '.log'.length);

/// [_launch] with the program in the background, so that the shell writes its
/// pid before it waits (design §5): the output appended to the log, then
/// `# exit=N`, `.pid` and `.exit` each written atomically, and no `exec`, so
/// that the shell lives to write them.
const _launchPid =
    r'l=$1; shift; "$@" >>"$l" 2>&1 </dev/null & p=$!; '
    r'echo "$p" >"$l.p" && mv -f "$l.p" "${l%.log}.pid"; '
    r'wait "$p"; s=$?; echo "# exit=$s" >>"$l"; '
    r'echo "$s" >"$l.x" && mv -f "$l.x" "${l%.log}.exit"; exit $s';

/// A new `switch/logs/<UTC>-<label>.log` holding [header] as `# ` lines, and
/// never the environment (SE15). The stamp is made as [_newLog] makes it and
/// the label from [title] as [_launchIn] makes one, copied so that Wine's
/// code stays as it is.
String _newSwitchLog(String home, String title, List<String> header) {
  final now = DateTime.now().toUtc();
  final iso = now.toIso8601String();
  // toIso8601String leaves the microseconds out when they are 000.
  final stamp = (now.microsecond == 0 ? iso.replaceFirst('Z', '000Z') : iso)
      .replaceAll(':', '-');
  final tag = title.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final label = tag.length > 40 ? tag.substring(0, 40) : tag;
  final logs = Directory('$home/switch/logs')..createSync(recursive: true);
  final log = File('${logs.path}/$stamp-$label.log')
    ..createSync(exclusive: true)
    ..writeAsStringSync([for (final line in header) '# $line\n'].join());
  return log.path;
}

/// Starts [argv] detached through [_launchPid], in [cwd] with [env] alone,
/// and returns once the run's `.pid` is there, or throws [ProcessFailed]
/// after 2 s. The Process is dropped, as [_launchIn] drops its own: a
/// detached start gives no exit code, and the files are the contract (SE16).
Future<void> _startSwitchRun(
  String log,
  List<String> argv,
  String cwd,
  Map<String, String> env,
) async {
  final exe = argv.first;
  try {
    await Process.start(
      '/bin/sh',
      ['-c', _launchPid, 'bodega', log, ...argv],
      workingDirectory: cwd,
      environment: env,
      includeParentEnvironment: false,
      mode: ProcessStartMode.detached,
    );
  } on ProcessException {
    // Dart's own message is garbled for a detached start, so the folder,
    // the usual cause, is named instead.
    throw ProcessFailed(exe, null, 'could not start /bin/sh in $cwd');
  }
  final pid = File('${_switchStem(log)}.pid');
  final clock = Stopwatch()..start();
  while (!pid.existsSync()) {
    if (clock.elapsed > const Duration(seconds: 2)) {
      throw ProcessFailed(exe, null, 'no pid within 2 s');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// The `# <key> <value>` lines a run's log starts with (SE15), up to the
/// first other line: a log grows with the emulator's output and is never read
/// whole.
Future<Map<String, String>> _switchHeader(String log) async {
  final header = <String, String>{};
  final line = RegExp(r'^# ([a-z]+) (.*)$');
  final lines = File(log)
      .openRead(0, 1 << 16)
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
  await for (final text in lines) {
    final match = line.firstMatch(text);
    if (match == null) break;
    header[match[1]!] = match[2]!;
  }
  return header;
}

/// A game's title and title id, from its file name alone (SE12): the name
/// without its extension and without every `[…]` and `(…)`, runs of spaces
/// and `_` as one space, trimmed, or the whole name if nothing is left; the id
/// is the first `[…]` of exactly 16 hex digits, upper-cased.
({String title, String? titleId}) _switchTitleOf(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  final title = (dot < 0 ? name : name.substring(0, dot))
      .replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)'), '')
      .replaceAll(RegExp(r'[ _]+'), ' ')
      .trim();
  final id = RegExp(r'\[([0-9A-Fa-f]{16})\]').firstMatch(name)?.group(1);
  return (title: title.isEmpty ? name : title, titleId: id?.toUpperCase());
}

/// [path] as every Switch function keeps it: absolute against the current
/// folder, with `.` and `..` worked out from the text alone, so links stay
/// links and a missing folder before `..` does not matter, and no trailing
/// `/`.
String _switchPath(String path) {
  final full = path.startsWith('/') ? path : '${Directory.current.path}/$path';
  final parts = <String>[];
  for (final part in full.split('/')) {
    if (part == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (part.isNotEmpty && part != '.') {
      parts.add(part);
    }
  }
  return '/${parts.join('/')}';
}

/// The file name's extension, lower case, or `''` when it has none.
String _extensionOf(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// Adds [paths], already checked, to `switch/games.json`, which it writes only
/// when one of them is new.
({int added, int known}) _addSwitchPaths(String home, List<String> paths) {
  final games = _readSwitchGames(home);
  final listed = {for (final json in games) json['path'] as String};
  final now = DateTime.now().toUtc().toIso8601String();
  var added = 0, known = 0;
  for (final path in paths) {
    if (!listed.add(path)) {
      known++;
      continue;
    }
    final (:title, :titleId) = _switchTitleOf(path);
    games.add({
      'path': path,
      'title': title,
      'titleId': ?titleId,
      'added': now,
    });
    added++;
  }
  if (added > 0) _writeSwitchGames(home, games);
  return (added: added, known: known);
}

/// The entries of `switch/games.json`, each checked as a [SwitchGame] and kept
/// as it was read; none while the file does not exist. A file that does not
/// parse or has another shape is [CorruptData], never ignored (SE3).
List<Map<String, dynamic>> _readSwitchGames(String home) {
  final file = File('$home/switch/games.json');
  if (!file.existsSync()) return [];
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final games = [
      for (final game in json['games'] as List) game as Map<String, dynamic>,
    ];
    games.forEach(_switchGameOf);
    return games;
  } on Object catch (e) {
    throw CorruptData(file.path, '$e');
  }
}

/// One entry of `games.json`; a field that is missing or of another type
/// throws.
SwitchGame _switchGameOf(Map<String, dynamic> json) => (
  path: json['path'] as String,
  title: json['title'] as String,
  titleId: json['titleId'] as String?,
  added: DateTime.parse(json['added'] as String),
);

/// `switch/` is made by the first write, never by [bodegaHome] (SE3).
void _writeSwitchGames(String home, List<Map<String, dynamic>> games) {
  Directory('$home/switch').createSync(recursive: true);
  _writeJson('$home/switch/games.json', {'games': games});
}

/// What a launch throws, and what the status notes, when no [emulator] is
/// found.
NoEmulator _noEmulator(Emulator emulator) =>
    NoEmulator(emulator.name, emulator.mac?.app ?? emulator.name);

/// Whether the CLI checks the host before the verb [args] runs (SE22):
/// Rosetta and the rest of [checkHost] are Wine's needs, so `bodega switch …`
/// runs without them. The data root is made for every verb all the same.
bool needsHost(List<String> args) => args.firstOrNull != 'switch';

/// `bodega switch <args>` (SE21): the work of the verb [args] names, which
/// writes its output to [out] and gives the exit code, or null for a bad
/// usage, which the CLI answers with its usage before it touches anything.
/// [env] stands for this process's environment, whose HOME is `~`. A failure
/// is thrown, for the CLI to print. `open` has no hints and no anti-cheat
/// watch: those are Wine's.
Future<int> Function(String home)? switchVerb(
  List<String> args,
  StringSink out, [
  Map<String, String>? env,
]) => switch (args) {
  ['status'] => (home) => _switchStatus(home, out, env),
  ['emulator', final app] => (home) async {
    await chooseEmulator(home, app == 'auto' ? null : app);
    return 0;
  },
  ['option', final option, final mode]
      when (option == 'fullscreen' || option == 'headless') &&
          (mode == 'on' || mode == 'off') =>
    (home) async {
      final on = mode == 'on';
      setSwitchOptions(
        home,
        fullscreen: option == 'fullscreen' ? on : null,
        headless: option == 'headless' ? on : null,
      );
      return 0;
    },
  ['add', _, ...] => (home) => _switchAdd(home, args.sublist(1), out),
  ['list'] => (home) async {
    for (final game in switchGames(home)) {
      out.writeln('${game.title}  ${game.titleId ?? '-'}  ${game.path}');
    }
    return 0;
  },
  ['remove', final game] => (home) async {
    removeSwitchGame(home, game);
    return 0;
  },
  ['open', final game] => (home) async {
    final log = await openSwitchGame(home, game, env);
    out.writeln('log: $log');
    // The run is detached and its files tell its end, so Ctrl-C ends only
    // this wait (SE16, SE18).
    return exitOf(log);
  },
  ['stop', final game] => (home) async {
    await stopSwitchGame(home, game);
    return 0;
  },
  _ => null,
};

/// `bodega switch status` (SE21): the emulator, the keys and the firmware,
/// then, for a missing emulator, a note on where Bodega looks and one with
/// its download page and what to do next, and a note for each app macOS
/// keeps in quarantine, the emulator's and each listed native app's. It
/// gives 0 only when the emulator, the keys and the firmware are all there,
/// as `bodega pads` does, whatever the native apps. Everything is found
/// before anything is written, so a failure leaves no half status.
Future<int> _switchStatus(
  String home,
  StringSink out,
  Map<String, String>? env,
) async {
  final (:emulator, :install, :keys, :firmware) = await checkSwitch(home, env);
  final emulators = _switchHost();
  final natives = [
    for (final game in switchGames(home))
      if (isNativeApp(game.path) &&
          ((await emulators.nativeApp(game.path))?.quarantined ?? false))
        game.path,
  ];
  final keysFile = switch (emulators.files(emulator)) {
    final files? => ' (${files.keys.split('/').last})',
    null => '',
  };
  final found = install == null
      ? 'missing'
      : '${[emulator.name, ?install.version].join(' ')} at ${install.app}'
            '${install.picked ? ' (picked)' : ''}';
  out
    ..writeln('emulator: $found')
    ..writeln('keys: ${keys ? 'found' : 'missing$keysFile'}')
    ..writeln('firmware: ${firmware ? 'found' : 'missing'}');
  if (install == null) {
    final missing = _noEmulator(emulator);
    out
      ..writeln('note: ${missing.message}')
      ..writeln(
        'note: download ${emulator.name} from ${emulator.page}, put '
        '${missing.app} in /Applications, then run bodega switch status again',
      );
  }
  if (install != null && install.quarantined) {
    out.writeln(_quarantineNote(install.app, emulator.name));
  }
  for (final app in natives) {
    out.writeln(_quarantineNote(app, 'it'));
  }
  return install != null && keys && firmware ? 0 : 1;
}

/// The note for an [app] that macOS keeps in quarantine (SE7): the attribute
/// stays once the user approves the app, so the words are conditional. [who]
/// is what may not start.
String _quarantineNote(String app, String who) =>
    'note: macOS keeps $app in quarantine: if $who does not start, open it '
    'once from the Finder; if macOS blocks it, allow it in System Settings > '
    'Privacy & Security';

/// `bodega switch add` (SE21): the file and `.app` arguments in one
/// [addSwitchGames], which checks them all before it writes, then each other
/// folder argument scanned; an app is an item, never a folder to scan. It
/// names each game it added, by title, then how many were already listed.
Future<int> _switchAdd(String home, List<String> paths, StringSink out) async {
  final before = {for (final game in switchGames(home)) game.path};
  final items = <String>[], folders = <String>[];
  for (final path in paths) {
    final folder = !isNativeApp(path) && FileSystemEntity.isDirectorySync(path);
    (folder ? folders : items).add(path);
  }
  var known = items.isEmpty ? 0 : (await addSwitchGames(home, items)).known;
  for (final folder in folders) {
    known += (await addSwitchFolder(home, folder)).known;
  }
  for (final game in switchGames(home)) {
    if (!before.contains(game.path)) out.writeln('added: ${game.title}');
  }
  out.writeln('already listed: $known');
  return 0;
}

/// A host's Switch emulators (design §7): where an install is, what confirms
/// one, what makes a native app, the files an emulator needs, the
/// environment either gets, and whether a run still lives. A host reads only
/// its own sub-record of a row (`mac`, `linux`), so a fork that renames its
/// app is a table edit.
abstract class EmulatorHost {
  const EmulatorHost();

  /// Whether Bodega finds and starts emulators on this host.
  bool get supported;

  /// The first install of [emulator] confirmed in the host's fixed places,
  /// then at [picked], or null. A candidate that is not confirmed is passed
  /// over, never an error.
  Future<EmulatorInstall?> find(
    Emulator emulator,
    Map<String, String> env, {
    String? picked,
  });

  /// [path] as an install of [emulator], with `picked` false, or null when it
  /// is not one.
  Future<EmulatorInstall?> confirm(Emulator emulator, String path);

  /// A native app (design §4), or null when its `Info.plist` has no
  /// `DMTitleID`.
  Future<NativeApp?> nativeApp(String app);

  /// Where [emulator] keeps the keys and the firmware on this host.
  EmulatorFiles? files(Emulator emulator);

  /// The whole environment of an emulator or a native app: nothing else
  /// from [parent].
  Map<String, String> env(Map<String, String> parent);

  /// Whether [pid] still runs [exe]: a pid that ended, or that runs something
  /// else because it was reused, marks a run that ended.
  Future<bool> runs(int pid, String exe);

  /// SIGTERM, or SIGKILL when [kill], through Process.killPid, and only
  /// while [pid] runs [exe].
  Future<void> stop(int pid, String exe, {bool kill = false});
}

/// The Mac's emulators (design §2): looked for in `/Applications`, then in
/// `~/Applications` and then at the pick, confirmed from their `Info.plist`,
/// and started by exec. Never through Spotlight, which can be off and lists
/// copies on disk images and other volumes.
class MacEmulators extends EmulatorHost {
  /// The seams, so that this code runs on any host (SN5): [root] goes before
  /// `/Applications`, [plistKey] reads a key in place of `/usr/bin/plutil`,
  /// and [quarantine] tells the quarantine attribute in place of the system
  /// tool, for the emulator and for native apps alike.
  const MacEmulators({this.root = '', this.plistKey, this.quarantine});

  /// What goes before `/Applications`: nothing on a real Mac, a test's
  /// temporary folder in a test.
  final String root;

  /// One key of a plist as text, or null when it cannot be read.
  final Future<String?> Function(String plist, String key)? plistKey;

  /// Whether macOS keeps [app] in quarantine.
  final Future<bool> Function(String app)? quarantine;

  @override
  bool get supported => true;

  @override
  Future<EmulatorInstall?> find(
    Emulator emulator,
    Map<String, String> env, {
    String? picked,
  }) async {
    final app = emulator.mac?.app;
    if (app == null) return null;
    // HOME from the map, as defaultHome takes it, never from this process.
    for (final dir in [
      '$root/Applications',
      if (env['HOME'] case final home?) '$home/Applications',
    ]) {
      if (await confirm(emulator, '$dir/$app') case final install?) {
        return install;
      }
    }
    if (picked == null) return null;
    return switch (await confirm(emulator, picked)) {
      final install? => (
        app: install.app,
        exe: install.exe,
        version: install.version,
        picked: true,
        quarantined: install.quarantined,
      ),
      null => null,
    };
  }

  /// Confirmed means the `Info.plist` names the row's bundle id and
  /// executable, since another emulator may reuse an old id, and that
  /// executable is a regular file with an exec bit (SE6).
  @override
  Future<EmulatorInstall?> confirm(Emulator emulator, String path) async {
    final mac = emulator.mac;
    if (mac == null) return null;
    final app = _switchPath(path);
    final plist = '$app/Contents/Info.plist';
    if (FileSystemEntity.typeSync(plist) != FileSystemEntityType.file ||
        await _key(plist, 'CFBundleIdentifier') != mac.bundleId ||
        await _key(plist, 'CFBundleExecutable') != mac.executable) {
      return null;
    }
    final exe = '$app/Contents/MacOS/${mac.executable}';
    if (!_isExecutableFile(exe)) return null;
    return (
      app: app,
      exe: exe,
      version: await _key(plist, 'CFBundleShortVersionString'),
      picked: false,
      quarantined: await _quarantined(app),
    );
  }

  /// A native app is a `.app` whose `Info.plist` holds `DMTitleID`: nothing
  /// else makes or refuses one (SE6). Of it only that key,
  /// `CFBundleExecutable` and the quarantine attribute are read, and its
  /// executable must be a regular file with an exec bit in
  /// `Contents/MacOS/`. Its path is used as given, never under [root].
  @override
  Future<NativeApp?> nativeApp(String app) async {
    final path = _switchPath(app);
    final plist = '$path/Contents/Info.plist';
    if (FileSystemEntity.typeSync(plist) != FileSystemEntityType.file) {
      return null;
    }
    final titleId = await _key(plist, 'DMTitleID');
    if (titleId == null) return null;
    final name = await _key(plist, 'CFBundleExecutable');
    final exe = '$path/Contents/MacOS/$name';
    return (
      titleId: titleId,
      exe: name != null && !name.contains('/') && _isExecutableFile(exe)
          ? exe
          : null,
      quarantined: await _quarantined(path),
    );
  }

  @override
  EmulatorFiles? files(Emulator emulator) => emulator.mac?.files;

  /// The session part of [MacPlatform.baseEnv], without its Wine and .NET
  /// keys (SN4): Ryubing is a .NET program, which Wine's
  /// `DOTNET_EnableWriteXorExecute=0` must not reach.
  @override
  Map<String, String> env(Map<String, String> parent) => {
    for (final key in const [
      'HOME',
      'USER',
      'LOGNAME',
      'TMPDIR',
      '__CF_USER_TEXT_ENCODING',
    ])
      if (parent[key] case final value?) key: value,
    'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
  };

  /// `ps` exits 0 and its line holds [exe], for the real emulator and for a
  /// script alike: Dart has no signal 0. In `/bin`, not where
  /// [MacPlatform.tool] looks; `-ww` keeps the line whole whatever COLUMNS
  /// says.
  @override
  Future<bool> runs(int pid, String exe) async {
    try {
      final ps = await Process.run('/bin/ps', [
        '-ww',
        '-p',
        '$pid',
        '-o',
        'command=',
      ]);
      return ps.exitCode == 0 && '${ps.stdout}'.contains(exe);
    } on ProcessException {
      return false;
    }
  }

  @override
  Future<void> stop(int pid, String exe, {bool kill = false}) async {
    if (await runs(pid, exe)) {
      Process.killPid(
        pid,
        kill ? ProcessSignal.sigkill : ProcessSignal.sigterm,
      );
    }
  }

  /// One read of [key], as [d3dmetalVersion] reads one; a failure or an empty
  /// value is null, which means "not this candidate", never an error.
  Future<String?> _key(String plist, String key) async {
    final value = await (plistKey ?? _plutilKey)(plist, key);
    return value == null || value.isEmpty ? null : value;
  }

  /// Read, never removed: an approved app keeps the attribute (SE7).
  Future<bool> _quarantined(String app) async {
    if (quarantine case final seam?) return seam(app);
    try {
      const attribute = 'com.apple.quarantine';
      final read = await Process.run('/usr/bin/xattr', ['-p', attribute, app]);
      return read.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}

/// Linux's emulators: not yet (design §7). [find] finds none, and the rest
/// throws [NotAvailable].
class LinuxEmulators extends EmulatorHost {
  const LinuxEmulators();

  static const _notYet = NotAvailable('switch', 'Linux');

  @override
  bool get supported => false;

  @override
  Future<EmulatorInstall?> find(
    Emulator emulator,
    Map<String, String> env, {
    String? picked,
  }) async => null;

  @override
  Future<EmulatorInstall?> confirm(Emulator emulator, String path) async =>
      throw _notYet;

  @override
  Future<NativeApp?> nativeApp(String app) async => throw _notYet;

  @override
  EmulatorFiles? files(Emulator emulator) => throw _notYet;

  @override
  Map<String, String> env(Map<String, String> parent) => throw _notYet;

  @override
  Future<bool> runs(int pid, String exe) async => throw _notYet;

  @override
  Future<void> stop(int pid, String exe, {bool kill = false}) async =>
      throw _notYet;
}

/// `/usr/bin/plutil -extract <key> raw <plist>`, or null when it fails or is
/// missing, as off macOS.
Future<String?> _plutilKey(String plist, String key) async {
  try {
    final result = await Process.run('/usr/bin/plutil', [
      '-extract',
      key,
      'raw',
      plist,
    ]);
    return result.exitCode == 0 ? '${result.stdout}'.trim() : null;
  } on ProcessException {
    return null;
  }
}

/// A regular file with an exec bit, the test [_onPath] makes.
bool _isExecutableFile(String path) {
  final stat = FileStat.statSync(path);
  return stat.type == FileSystemEntityType.file && (stat.mode & 0x49) != 0;
}

/// No emulator where Bodega looks for it, and no pick that is one.
final class NoEmulator extends EngineFailure {
  const NoEmulator(this.name, this.app);

  /// The emulator's name, as `Ryubing`.
  final String name;

  /// The app's file name, as `Ryujinx.app`.
  final String app;

  @override
  String get message =>
      '$name not found: Bodega looks for $app in /Applications and '
      '~/Applications, or takes one from bodega switch emulator <path>';
}

/// An app picked as the emulator whose `Info.plist` names another app.
final class NotAnEmulator extends EngineFailure {
  const NotAnEmulator(this.path, this.name);

  final String path;

  /// The emulator it was picked as, as `Ryubing`.
  final String name;

  @override
  String get message => '$path is not $name: its Info.plist names another app';
}

/// A path that is neither a game file the emulator opens nor an nxnative app.
final class NotASwitchGame extends EngineFailure {
  const NotASwitchGame(this.path, this.extensions);

  final String path;

  /// What the emulator opens: lower case, no dot.
  final List<String> extensions;

  @override
  String get message =>
      '$path is not a Switch game: '
      '${[for (final extension in extensions) '.$extension'].join(' ')}, '
      'or an nxnative app';
}

/// A path that is not in the list of Switch games, and has no run.
final class SwitchGameNotFound extends EngineFailure {
  const SwitchGameNotFound(this.path);

  final String path;

  @override
  String get message =>
      '$path is not among the Switch games: bodega switch list';
}

/// A game that already has a live run.
final class SwitchGameRunning extends EngineFailure {
  const SwitchGameRunning(this.path);

  final String path;

  /// The hint quotes the path: game names hold spaces and brackets, which a
  /// shell splits or globs.
  @override
  String get message => '$path is already running: bodega switch stop "$path"';
}
