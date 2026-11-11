part of 'engine.dart';

/// One application of the catalog (C1). Its prose (status note, flaky note,
/// notes and known issues) is English, as the CLI prints it; the app words it
/// from its own ARBs, by [id] (design §7).
class CatalogEntry {
  CatalogEntry.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String,
      status = json['status'] as String,
      statusNote = json['statusNote'] as String,
      flaky = json['flaky'] as String?,
      url = json['installer']['url'] as String,
      sha256 = json['installer']['sha256'] as String?,
      installerArgs = List<String>.from(json['installer']['args'] as List),
      msi = json['installer']['msi'] as bool,
      exe = json['exe'] as String,
      args = List<String>.from(json['args'] as List),
      backend = json['backend'] as String,
      sync = json['sync'] as String,
      env = Map<String, String>.from(json['env'] as Map),
      registry = [
        for (final value in json['registry'] as List)
          (
            key: value['key'] as String,
            name: value['name'] as String,
            type: value['type'] as String,
            data: value['data'] as String,
          ),
      ],
      notes = List<String>.from(json['notes'] as List),
      knownIssues = [
        for (final issue in json['knownIssues'] as List)
          (symptom: issue['symptom'] as String, fix: issue['fix'] as String),
      ],
      source = Map<String, String?>.from(json['source'] as Map);

  final String id, title, status, statusNote, url, exe, backend, sync;
  final String? flaky, sha256;
  final bool msi;
  final List<String> installerArgs, args, notes;
  final Map<String, String> env;

  /// Where the recipe comes from (repo, commit, path, license, verified),
  /// with null for a field the recipe has no data for.
  final Map<String, String?> source;
  final List<({String key, String name, String type, String data})> registry;
  final List<({String symptom, String fix})> knownIssues;
}

/// The entries in display order, filtered by [query] on id and title (C3).
List<CatalogEntry> catalogEntries([String query = '']) {
  final text = query.toLowerCase();
  return [
    for (final json in jsonDecode(catalogJson) as List)
      CatalogEntry.fromJson(json as Map<String, dynamic>),
  ].where((entry) {
    return entry.id.contains(text) || entry.title.toLowerCase().contains(text);
  }).toList();
}

CatalogEntry catalogEntry(String id) =>
    catalogEntries().where((entry) => entry.id == id).firstOrNull ??
    (throw BadChoice(ChoiceKind.catalogApp, id));

/// 0, and 1638, 3010 and 1641 truncated to 8 bits (`HB/Recipe.swift:154-156`).
const _installerOk = {0, 102, 194, 105};

/// What [installEntry] is doing, for a UI to word in its own language (E2).
/// [subject] is what the step names, null for the steps that name nothing.
typedef InstallStep = ({InstallStepKind kind, String? subject});

/// The steps of a catalog install, in the order they come.
enum InstallStepKind {
  /// The catalog pins no checksum for the installer, so its download relies
  /// on HTTPS and on the server: the subject is the server's host.
  unpinnedDownload,
  downloading,

  /// Into an existing bottle whose sync is not the entry's: the bottle keeps
  /// its own (M12), which is the subject.
  syncMismatch,

  /// The subject is the bottle.
  creatingBottle,

  /// Writes one of the entry's registry values: the subject is its name.
  registry,
  runningInstaller,

  /// The installer exited: what it left running settles (I6).
  waiting,
}

/// Installs [entry] in a bottle of its own (I1, I2), or with [intoExisting]
/// in [bottle], which must be ready (M12), and returns the bottle's folder. A
/// failure after the bottle exists leaves it, with its logs, and without the
/// entry in `apps.json` that would make it count as installed. A [setup] that
/// is already on disk replaces the download, so that a UI can show its
/// progress (E6). [onStep] hears each [InstallStep] as it starts.
Future<String> installEntry(
  String home,
  CatalogEntry entry, {
  String? bottle,
  bool intoExisting = false,
  String? setup,
  void Function(InstallStep step)? onStep,
  Duration grace = const Duration(seconds: 60),
  Duration limit = const Duration(minutes: 30),
}) async {
  void step(InstallStepKind kind, [String? subject]) =>
      onStep?.call((kind: kind, subject: subject));

  final name = bottle ?? entry.id;
  final dir = bottleDir(home, name);
  if (entry.status == 'blocked') throw CatalogBlocked(entry.id);
  final backend = hostPlatform.mapBackend(entry.backend);
  if (!_installed(home, backend)) throw BackendNotInstalled(backend);
  final exists = Directory(dir).existsSync();
  if (exists && !intoExisting) throw BottleExists(name);
  if (intoExisting && !(exists && _ready('$dir/prefix'))) {
    throw BottleNotReady(name);
  }
  final rt = currentRuntime(home);
  final String file;
  if (setup == null) {
    final uri = Uri.parse(entry.url);
    if (uri.scheme != 'https' && uri.scheme != 'file') {
      throw NotHttps(entry.url);
    }
    if (entry.sha256 == null) step(InstallStepKind.unpinnedDownload, uri.host);
    step(InstallStepKind.downloading);
    file = await _download(
      home,
      entry.url,
      entry.sha256,
      name: '${entry.id}-setup.${entry.msi ? 'msi' : 'exe'}',
    );
  } else {
    file = setup;
    if (entry.sha256 case final want?) {
      if (await sha256Of(file) != want) throw ChecksumMismatch(file);
    }
  }

  final program = (backend: backend, env: entry.env, hud: false);
  if (intoExisting) {
    // The bottle keeps its backend and sync: other things live in it (M12).
    final settings = _settings(dir);
    if (settings.sync != entry.sync) {
      step(InstallStepKind.syncMismatch, settings.sync);
    }
    // The HUD is the user's choice, not the catalog's: it survives a reinstall.
    final hud = settings.programs[_exeKey(entry.exe)]?.hud ?? false;
    _saveSettings(
      dir,
      _with(
        settings,
        programs: {
          ...settings.programs,
          _exeKey(entry.exe): (backend: backend, env: entry.env, hud: hud),
        },
      ),
    );
  } else {
    step(InstallStepKind.creatingBottle, name);
    await createBottle(home, name);
    _saveSettings(
      dir,
      _with(
        _settings(dir),
        backend: 'auto',
        sync: entry.sync,
        programs: {_exeKey(entry.exe): program},
      ),
    );
  }

  for (final value in entry.registry) {
    step(InstallStepKind.registry, value.name);
    final log = await _launchIn(home, name, 'reg', [
      'add',
      value.key,
      '/v',
      value.name,
      '/t',
      value.type,
      '/d',
      value.data,
      '/f',
    ], backend: 'wine');
    final code = await exitOf(log);
    if (code != 0) throw WineToolFailed(WineTool.reg, code, log);
  }

  step(InstallStepKind.runningInstaller);
  final log = await _launchIn(
    home,
    name,
    entry.msi ? 'msiexec' : file,
    [
      if (entry.msi) ...['/i', file, '/qn'],
      ...entry.installerArgs,
    ],
    backend: 'wine',
    label: '${entry.id}-setup',
  );
  final code = await exitOf(log);
  final prefix = '$dir/prefix';
  if (!_installerOk.contains(code)) {
    await _wineserver(rt, prefix, '-k');
    throw WineToolFailed(WineTool.installer, code, log);
  }

  step(InstallStepKind.waiting);
  // Looked up each time: the installer may write it with another case.
  File exe() => File(findCI('$prefix/drive_c', entry.exe));
  await _settle(rt, prefix, exe, grace, limit);
  if (!exe().existsSync()) throw InstallerNoExe(entry.exe, log);
  _registerApp(dir, entry.id, entry.title, entry.exe, entry.args);
  if (entry.sha256 == null) File(file).deleteSync();
  return dir;
}

/// I6: waits for the server to end by itself, but no longer than [grace] once
/// the exe exists, because some installers leave services behind, or [limit]
/// in all. Then it stops the bottle, so the first launch is a cold start with
/// the app's own settings (design §3).
Future<void> _settle(
  String rt,
  String prefix,
  File Function() exe,
  Duration grace,
  Duration limit,
) async {
  var ended = false;
  final server = _wineserver(rt, prefix, '-w')
    ..whenComplete(() => ended = true);
  // ponytail: grace counts from the installer exit, not from when the exe
  // appears; enough for these 7, a slow exe would just get less of it.
  final clock = Stopwatch()..start();
  while (!ended &&
      clock.elapsed < limit &&
      !(clock.elapsed >= grace && exe().existsSync())) {
    await Future.any<Object?>([
      server,
      Future<void>.delayed(const Duration(milliseconds: 500)),
    ]);
  }
  await _wineserver(rt, prefix, '-k');
  await server;
}

/// Easy Anti-Cheat failed to load under Wine (error 206) for [game], the title
/// its log names, or for a game it does not name (null) (I11).
typedef AntiCheatHint = ({String? game});

/// Easy Anti-Cheat's failure under Wine on macOS, one hint per game (I11). It
/// fails outside any log of ours: a launcher starts the game, and EAC writes
/// to its own folder. [since] leaves out what older runs wrote.
List<AntiCheatHint> antiCheatHints(
  String home,
  String bottle, {
  DateTime? since,
}) {
  final drive = '${_existing(home, bottle)}/prefix/drive_c';
  final users = Directory(findCI(drive, 'users'));
  if (!users.existsSync()) return [];
  return [
    for (final user in users.listSync().whereType<Directory>())
      if (Directory(findCI(user.path, 'AppData/Roaming/EasyAntiCheat'))
          case final eac when eac.existsSync())
        // Never follow links inside a bottle: z: points to /.
        for (final file
            in eac
                .listSync(recursive: true, followLinks: false)
                .whereType<File>())
          if (file.path.endsWith('/anticheatlauncher.log') &&
              (since == null || !file.lastModifiedSync().isBefore(since)))
            ?_eacFailure(file),
  ];
}

AntiCheatHint? _eacFailure(File log) {
  String? title, finished;
  for (final line in log.readAsLinesSync(encoding: latin1)) {
    if (line.contains('- ProcessTitle: ')) {
      title = line
          .split('- ProcessTitle: ')
          .last
          .replaceFirst(RegExp(r'\.$'), '');
    } else if (line.contains('Launcher finished with: ')) {
      finished = line;
    }
  }
  if (finished == null || !finished.contains('finished with: 206,'))
    return null;
  return (game: title);
}
