part of 'engine.dart';

/// One application of the catalog (C1). Its strings are what a UI shows.
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
      source = Map<String, String>.from(json['source'] as Map);

  final String id, title, status, statusNote, url, exe, backend, sync;
  final String? flaky, sha256;
  final bool msi;
  final List<String> installerArgs, args, notes;
  final Map<String, String> env, source;
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
    (throw 'no está en el catálogo: $id (bodega catalog list)');

/// 0, and 1638, 3010 and 1641 truncated to 8 bits (`HB/Recipe.swift:154-156`).
const _installerOk = {0, 102, 194, 105};

/// Installs [entry] in a bottle of its own (I1, I2) and returns the bottle's
/// folder. A failure after the bottle exists leaves it, with its logs, and
/// without the entry in `apps.json` that would make it count as installed. A [setup]
/// that is already on disk replaces the download, so that a UI can show its
/// progress (E6).
Future<String> installEntry(
  String home,
  CatalogEntry entry, {
  String? bottle,
  String? setup,
  void Function(String step)? onStep,
  Duration grace = const Duration(seconds: 60),
  Duration limit = const Duration(minutes: 30),
}) async {
  final name = bottle ?? entry.id;
  final dir = bottleDir(home, name);
  if (entry.status == 'blocked') {
    throw '${entry.title} está bloqueada: ${entry.statusNote}';
  }
  if (!_installed(home, entry.backend)) throw _notInstalled(entry.backend);
  if (Directory(dir).existsSync()) {
    throw 'ya existe $dir; para empezar de cero: '
        'bodega stop $name y rm -rf "$dir"';
  }
  final rt = currentRuntime(home);
  final String file;
  if (setup == null) {
    final uri = Uri.parse(entry.url);
    if (uri.scheme != 'https' && uri.scheme != 'file') {
      throw 'la URL no es https: ${entry.url}';
    }
    if (entry.sha256 == null) {
      onStep?.call('sin checksum fijo: se confía en HTTPS y en ${uri.host}');
    }
    onStep?.call('Descargando el instalador');
    file = await _download(
      home,
      entry.url,
      entry.sha256,
      name: '${entry.id}-setup.${entry.msi ? 'msi' : 'exe'}',
    );
  } else {
    file = setup;
    if (entry.sha256 case final want?) {
      final got = await _sha256(file);
      if (got != want) {
        throw 'checksum incorrecto en $file: $got, se esperaba $want';
      }
    }
  }

  onStep?.call('Creando la botella $name');
  await createBottle(home, name);
  _saveSettings(dir, (
    backend: 'auto',
    sync: entry.sync,
    programs: {_exeKey(entry.exe): (backend: entry.backend, env: entry.env)},
  ));

  for (final value in entry.registry) {
    onStep?.call('Registro: ${value.name}');
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
    if (code != 0) throw 'reg add salió con $code; log: $log';
  }

  onStep?.call('Ejecutando el instalador');
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
    throw 'el instalador salió con $code; log: $log';
  }

  onStep?.call('Esperando a que termine la instalación');
  final exe = File('$prefix/drive_c/${entry.exe}');
  await _settle(rt, prefix, exe, grace, limit);
  if (!exe.existsSync()) {
    throw 'el instalador terminó pero no está ${entry.exe}; log: $log';
  }
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
  File exe,
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
      !(clock.elapsed >= grace && exe.existsSync())) {
    await Future.any<Object?>([
      server,
      Future<void>.delayed(const Duration(milliseconds: 500)),
    ]);
  }
  await _wineserver(rt, prefix, '-k');
  await server;
}

/// Easy Anti-Cheat's failure under Wine on macOS, one hint per game (I11). It
/// fails outside any log of ours: a launcher starts the game, and EAC writes
/// to its own folder. [since] leaves out what older runs wrote.
List<String> antiCheatHints(String home, String bottle, {DateTime? since}) {
  final users = Directory('${_existing(home, bottle)}/prefix/drive_c/users');
  if (!users.existsSync()) return [];
  return [
    for (final user in users.listSync().whereType<Directory>())
      if (Directory('${user.path}/AppData/Roaming/EasyAntiCheat') case final eac
          when eac.existsSync())
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

String? _eacFailure(File log) {
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
  return '${title ?? 'Este juego'} usa Easy Anti-Cheat y no pudo cargarlo con '
      'Wine en Mac (error 206). No es un fallo de tu instalación: depende de '
      'los desarrolladores del juego y de Epic.';
}
