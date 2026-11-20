part of 'engine.dart';

/// Where the fixes come from. A test replaces it; the app never does.
String fixesSource = fixesJson;

/// Where Bodega's own fixes come from (D7). A test replaces it; the app never
/// does.
String bodegaFixesSource = bodegaFixesJson;

/// The highball-db commit the data comes from.
const fixesSourceCommit = fixesCommit;

/// One thing a fix does (F2). [platforms] says where it was verified, and a host
/// applies only its own: `env` sets a variable, `registry` writes a value,
/// `dlloverride` adds to WINEDLLOVERRIDES, and `ini` sets [name] in [section]
/// of [file] to [data], when the user accepts it (D8, D9). [source] names the
/// data file, for its errors.
class FixStep {
  FixStep.fromJson(Map<String, dynamic> json, [String source = _generated])
    : type = json['type'] as String,
      name = json['name'] as String?,
      value = json['value'] as String?,
      key = json['key'] as String?,
      valueType = json['valueType'] as String?,
      data = json['data'] as String?,
      file = json['file'] as String?,
      section = json['section'] as String?,
      platforms = List<String>.from(json['platforms'] as List) {
    if (!const {'env', 'registry', 'dlloverride', 'ini'}.contains(type)) {
      throw CorruptData(source, 'unknown step type: $type');
    }
    if (type == 'ini' &&
        (section == null ||
            name == null ||
            data == null ||
            !(file ?? '').toUpperCase().startsWith(r'%USERPROFILE%\'))) {
      throw CorruptData(
        source,
        r'an ini step needs a file under %USERPROFILE%\, a section, a name '
        'and data: $file',
      );
    }
  }

  final String type;
  final String? name, value, key, valueType, data, file, section;
  final List<String> platforms;

  bool get applies => platforms.contains(hostPlatform.id);
}

const _generated = 'fixes_data.dart', _bodegas = 'bodega_fixes_data.dart';

/// What a game needs to run well (F1): its Steam app id or the names of its
/// exe, the steps, the runtimes it needs, and what upstream wrote about it.
/// Notes and known issues stay in English.
class GameFix {
  GameFix.fromJson(Map<String, dynamic> json, [String source = _generated])
    : id = json['id'] as String,
      title = json['title'] as String,
      steam = json['steam'] as int?,
      exes = List<String>.from((json['exes'] ?? const <String>[]) as List),
      requires = List<String>.from(
        (json['requires'] ?? const <String>[]) as List,
      ),
      optIn = json['optIn'] as bool,
      steps = [
        for (final step in json['steps'] as List)
          FixStep.fromJson(step as Map<String, dynamic>, source),
      ],
      notes = List<String>.from(json['notes'] as List),
      knownIssues = [
        for (final issue in json['knownIssues'] as List)
          (
            symptom: issue['symptom'] as String,
            cause: issue['cause'] as String,
            fix: issue['fix'] as String,
          ),
      ],
      source = json['source'] as String,
      verified = json['verified'] == null
          ? null
          : Map<String, String?>.from(json['verified'] as Map),
      status = (json['status'] ?? 'community') as String,
      backends = Map<String, String>.from(
        (json['backends'] ?? const <String, String>{}) as Map,
      ),
      antiCheat = switch (json['antiCheat']) {
        null => null,
        final cheat => (
          names: List<String>.from(cheat['names'] as List),
          verdict: cheat['verdict'] as String,
        ),
      },
      reports = switch (json['reports']) {
        null => null,
        final reports => (
          count: reports['count'] as int,
          median: reports['median'] as int,
          last: reports['last'] as String,
        ),
      },
      nativeMac = (json['nativeMac'] ?? false) as bool {
    if (!const {'verified', 'community', 'blocked'}.contains(status)) {
      throw CorruptData(source, '$id: unknown status $status');
    }
    if (antiCheat case (verdict: final verdict, names: _)
        when verdict != 'warning' && verdict != 'blocked') {
      throw CorruptData(source, '$id: unknown anti-cheat verdict $verdict');
    }
  }

  final String id, title, source;

  /// `verified` (on Bodega), `community` (from highball-db's players) or
  /// `blocked` (anti-cheat or its publisher keeps it from working).
  final String status;

  /// The backend that worked, by platform id: highball-db's are the Mac's.
  final Map<String, String> backends;

  /// The anti-cheat's names and highball-db's verdict for the Mac: `warning`
  /// or `blocked`.
  final ({List<String> names, String verdict})? antiCheat;

  /// How many players reported a rating from 1 to 5, its median and the day
  /// of the last report.
  final ({int count, int median, String last})? reports;

  /// Whether the game also has a native Mac version.
  final bool nativeMac;

  /// The backend this host gets: only one it has.
  String? get backend => switch (backends[hostPlatform.id]) {
    final name? when backendNames.contains(name) => name,
    _ => null,
  };

  /// `blocked`, or from the reports' median: `works` (4 or 5), `playable` (3)
  /// or `broken` (1 or 2); null with no reports.
  String? get rating => status == 'blocked'
      ? 'blocked'
      : switch (reports?.median) {
          null => null,
          >= 4 => 'works',
          3 => 'playable',
          _ => 'broken',
        };

  /// Null for a game that is matched by its exe's name instead (D7).
  final int? steam;

  /// Lowercase exe file names: an application whose key ends in one of them
  /// gets this fix (D7).
  final List<String> exes;

  /// Ids of [dependencyTable] that the game needs (D5).
  final List<String> requires;

  /// An optional fix is shown but never applied by itself: it costs something.
  final bool optIn;
  final List<FixStep> steps;
  final List<String> notes;
  final List<({String symptom, String cause, String fix})> knownIssues;
  final Map<String, String?>? verified;

  /// The steps this host applies at launch, none for an opt-in fix (F3). An
  /// `ini` step is never one: the user applies it once (D9).
  List<FixStep> get active => optIn
      ? const []
      : [
          for (final step in steps)
            if (step.applies && step.type != 'ini') step,
        ];

  /// Whether some step must be in the game's environment: variables and DLL
  /// overrides, which only a Steam that starts with them can pass on.
  bool get needsLaunchEnv => active.any((step) => step.type != 'registry');
}

/// The parsed data, kept while both sources stay the same strings.
({String fixes, String bodegas, List<GameFix> all})? _parsed;

List<GameFix> _allFixes() {
  if (_parsed case final parsed?
      when identical(parsed.fixes, fixesSource) &&
          identical(parsed.bodegas, bodegaFixesSource)) {
    return parsed.all;
  }
  final all = [
    for (final json in jsonDecode(fixesSource) as List)
      GameFix.fromJson(json as Map<String, dynamic>),
  ];
  // Bodega's own entry, verified here, replaces highball-db's of that id.
  final ids = <String>{};
  for (final json in jsonDecode(bodegaFixesSource) as List) {
    final fix = GameFix.fromJson(json as Map<String, dynamic>, _bodegas);
    if (!ids.add(fix.id)) {
      throw CorruptData(_bodegas, 'the id ${fix.id} is there twice');
    }
    all.removeWhere((other) => other.id == fix.id);
    for (final id in fix.requires) {
      if (!dependencyTable.any((row) => row.id == id)) {
        throw CorruptData(_bodegas, '${fix.id} requires $id, which is unknown');
      }
    }
    all.add(fix);
  }
  _parsed = (
    fixes: fixesSource,
    bodegas: bodegaFixesSource,
    all: List.unmodifiable(all),
  );
  return _parsed!.all;
}

/// The fixes in file order, the generated ones and then Bodega's (D7),
/// filtered by [query] on id and title.
List<GameFix> gameFixes([String query = '']) {
  final text = query.toLowerCase();
  return _allFixes().where((fix) {
    return fix.id.contains(text) || fix.title.toLowerCase().contains(text);
  }).toList();
}

/// The fix of a Steam game, or null if there is none. Bodega's own come
/// first.
GameFix? fixForSteamApp(int appid) =>
    _matchOrder().where((fix) => fix.steam == appid).firstOrNull;

/// A fix by id or by Steam app id.
GameFix gameFix(String idOrApp) =>
    gameFixes()
        .where(
          (fix) =>
              fix.id == idOrApp ||
              (fix.steam != null && '${fix.steam}' == idOrApp),
        )
        .firstOrNull ??
    (throw BadChoice(ChoiceKind.fix, idOrApp));

/// How [gameFor] matched an app (G3).
enum MatchKind { steam, exe, title }

typedef GameMatch = ({GameFix fix, MatchKind by});

/// Bodega's own fixes, verified here, before highball-db's.
Iterable<GameFix> _matchOrder() {
  final all = _allFixes();
  return [
    ...all.where((fix) => fix.source == 'bodega'),
    ...all.where((fix) => fix.source != 'bodega'),
  ];
}

/// [title] lowercased, without trademark signs, with every run of other
/// characters than letters and digits as one space.
String normalTitle(String title) => title
    .toLowerCase()
    .replaceAll(RegExp('[™®©]'), '')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

/// The configuration of [app] (G3): a Steam game's by its app id only; any
/// other by its exe's file name, and else by its title.
GameMatch? gameFor(InstalledApp app) {
  if (app.key.startsWith('steam:')) {
    final id = int.tryParse(app.key.substring('steam:'.length));
    final fix = id == null ? null : fixForSteamApp(id);
    return fix == null ? null : (fix: fix, by: MatchKind.steam);
  }
  final fixes = _matchOrder();
  final exe = app.exe.split(RegExp(r'[/\\]')).last.toLowerCase();
  if (fixes.where((fix) => fix.exes.contains(exe)).firstOrNull
      case final fix?) {
    return (fix: fix, by: MatchKind.exe);
  }
  final title = normalTitle(app.title);
  if (title.isEmpty) return null;
  final fix = fixes.where((fix) => normalTitle(fix.title) == title).firstOrNull;
  return fix == null ? null : (fix: fix, by: MatchKind.title);
}

/// [app]'s configuration in the bottle at [dir], unless the user turned it
/// off (G6).
GameMatch? _gameIn(String dir, InstalledApp app) =>
    _settings(dir).configOff.contains(app.key) ? null : gameFor(app);

InstalledApp _appWithKey(String home, String bottle, String key) =>
    _appsIn(bottle, _existing(home, bottle))
        .where((app) => app.key == key)
        .firstOrNull ??
    (throw AppNotFound(bottle, key));

/// What a launch of an app gets from its game's configuration and from auto
/// (G7). [openApp] launches from the same match, so what is shown is what
/// runs.
typedef GamePlan = ({
  InstalledApp app,

  /// The app's game, or null with no entry. It stays when the user turns the
  /// configuration off, so the switch can turn it back on.
  GameMatch? match,

  /// False when the user turned the configuration off: then nothing below
  /// comes from it.
  bool on,
  ({String name, String origin}) backend,

  /// What auto read in the exe, when auto chose.
  ExeGraphics? graphics,
  Map<String, String> env,
  List<String> overrides,
  List<FixStep> registry,

  /// Settings-file steps, which the user applies (D9).
  List<FixStep> ini,
  List<String> requires,
  String? verdict,
});

/// The program [openApp] starts for [app].
String _appProgram(InstalledApp app) => app.exe.startsWith('/')
    ? app.exe
    : 'C:\\${app.exe.replaceAll('/', r'\')}';

Future<GamePlan> gamePlan(String home, String bottle, String key) async {
  final app = _appWithKey(home, bottle, key);
  final dir = _existing(home, bottle);
  final settings = _settings(dir);
  final on = !settings.configOff.contains(key);
  final match = gameFor(app);
  final fix = on ? match?.fix : null;
  final program = _appProgram(app);
  final (exe: _, cwd: _, :scan) = _programPaths('$dir/prefix/drive_c', program);
  final backend = await resolveBackend(
    home,
    dir,
    program,
    scan,
    config: fix?.backend,
  );
  final steps = fix?.active ?? const <FixStep>[];
  return (
    app: app,
    match: match,
    on: on,
    backend: backend,
    graphics: backend.origin == 'auto' && scan != null
        ? await exeGraphics(scan)
        : null,
    env: {
      for (final step in steps)
        if (step.type == 'env')
          if (fixValue(step.value!) case final value?) step.name!: value,
    },
    overrides: [
      for (final step in steps)
        if (step.type == 'dlloverride') step.value!,
    ],
    registry: [
      for (final step in steps)
        if (step.type == 'registry') step,
    ],
    ini: [
      for (final step in fix?.steps ?? const <FixStep>[])
        if (step.type == 'ini' && step.applies) step,
    ],
    requires: fix?.requires ?? const [],
    verdict: settings.verdicts[key],
  );
}

/// Turns [key]'s game configuration on or off (G6). Off first deletes the
/// registry values it writes at launch; on writes them again at the next one.
Future<void> setGameConfig(
  String home,
  String bottle,
  String key, {
  required bool on,
}) async {
  final app = _appWithKey(home, bottle, key);
  final dir = _existing(home, bottle);
  if (!on) {
    for (final step
        in gameFor(app)?.fix.active.where((step) => step.type == 'registry') ??
            const <FixStep>[]) {
      final log = await _launchIn(home, bottle, 'reg', [
        'delete',
        step.key!,
        '/v',
        step.name!,
        '/f',
      ], backend: 'wine');
      final code = await exitOf(log);
      // 1: the value is not there, which is what off wants.
      if (code != 0 && code != 1) throw WineToolFailed(WineTool.reg, code, log);
    }
  }
  final settings = _settings(dir);
  _saveSettings(
    dir,
    _with(
      settings,
      configOff: on
          ? ({...settings.configOff}..remove(key))
          : {...settings.configOff, key},
    ),
  );
}

/// Saves what the user said of [key]'s game, one of [gameVerdicts], or clears
/// it with null (G6).
void setGameVerdict(String home, String bottle, String key, String? verdict) {
  _appWithKey(home, bottle, key);
  if (verdict != null) _checkVerdict(verdict);
  final dir = _existing(home, bottle);
  final settings = _settings(dir);
  final verdicts = {...settings.verdicts}..remove(key);
  if (verdict != null) verdicts[key] = verdict;
  _saveSettings(dir, _with(settings, verdicts: verdicts));
}

/// [value] with highball-db's `${memoryMB*0.375}` worked out for this host, or
/// null if it holds a placeholder Bodega does not know, or the memory can't be
/// read: then the step is left out, rather than passed on as text.
String? fixValue(String value) {
  // With the memory unknown, a budget of 0 would be worse than none.
  if (value.contains(r'${memoryMB') && hostPlatform.memoryMB <= 0) return null;
  final sized = value.replaceAllMapped(
    RegExp(r'\$\{memoryMB\*([0-9.]+)\}'),
    (match) => '${(hostPlatform.memoryMB * double.parse(match[1]!)).round()}',
  );
  return sized.contains(r'${') ? null : sized;
}

/// The note that goes in the log when a fix could not reach the game; [hintsIn]
/// reads it back as [LogHint.fixNotApplied].
const fixNotApplied = 'fix not applied: Steam was already open';

/// [fixNotApplied], by a name that [LogHint.fixNotApplied] does not hide inside
/// its enum.
const _fixNote = fixNotApplied;

/// Whether Steam runs in the bottle. With no wineserver nothing does, which
/// takes no time to know (design §5); else `tasklist` tells, without a window.
Future<bool> _steamRunning(String home, String bottle) async {
  final prefix = '${_existing(home, bottle)}/prefix';
  final wait = await Process.start(
    '${currentRuntime(home)}/engine/bin/wineserver',
    ['-w'],
    environment: wineEnv(prefix, Platform.environment),
    includeParentEnvironment: false,
  );
  final idle = await wait.exitCode
      .then((_) => true)
      .timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {
          wait.kill();
          return false;
        },
      );
  if (idle) return false;
  final log = await _launchIn(
    home,
    bottle,
    'tasklist',
    const [],
    backend: 'wine',
    label: 'tasklist',
  );
  await exitOf(log);
  return File(log)
      .readAsLinesSync(encoding: latin1)
      .any((line) => line.toLowerCase().startsWith('steam.exe '));
}

/// Writes the registry values of [fix] into the bottle, which a variable cannot do (F3).
Future<void> _applyFixRegistry(String home, String bottle, GameFix fix) async {
  for (final step in fix.active.where((step) => step.type == 'registry')) {
    final log = await _launchIn(home, bottle, 'reg', [
      'add',
      step.key!,
      '/v',
      step.name!,
      '/t',
      step.valueType!,
      '/d',
      step.data!,
      '/f',
    ], backend: 'wine');
    final code = await exitOf(log);
    if (code != 0) throw WineToolFailed(WineTool.reg, code, log);
  }
}

/// D8: [text] with [name] in [section] set to [value], and nothing else
/// changed: the section and the key match without case, the line ends stay. A
/// key missing from its section goes after the section's last line; a missing
/// section goes at the end, with the text's own line end.
String setIniValue(String text, String section, String name, String value) {
  final end = text.contains('\r\n') ? '\r\n' : '\n';
  final lines = text.split('\n');
  final header = RegExp(r'^\s*\[(.*)\]\s*$');
  int? start, last;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].replaceFirst(RegExp(r'\r$'), '');
    if (header.firstMatch(line) case final match?) {
      if (start != null) break;
      if (match[1]!.trim().toLowerCase() == section.toLowerCase()) start = i;
      continue;
    }
    if (start == null) continue;
    if (line.trim().isNotEmpty) last = i;
    final at = line.indexOf('=');
    if (at > 0 &&
        line.substring(0, at).trim().toLowerCase() == name.toLowerCase()) {
      final cr = lines[i].endsWith('\r') ? '\r' : '';
      lines[i] = '${line.substring(0, at + 1)}$value$cr';
      return lines.join('\n');
    }
  }
  final cr = end == '\r\n' ? '\r' : '';
  if (start == null) {
    final body = text.isEmpty || text.endsWith('\n') ? text : '$text$end';
    return '$body[$section]$end$name=$value$end';
  }
  final at = (last ?? start) + 1;
  if (at < lines.length) {
    lines.insert(at, '$name=$value$cr');
  } else {
    // The section ends a text with no line end after it: it gets one, and the
    // new line ends the text as the old one did.
    lines[at - 1] = '${lines[at - 1]}$cr';
    lines.add('$name=$value');
  }
  return lines.join('\n');
}

/// The host path of an `ini` step's file (D9): `%USERPROFILE%` is the profile
/// of the bottle's Windows user, or of the host's.
String _settingsPath(String dir, FixStep step) {
  final saved = _settings(dir).user;
  final user = saved.isEmpty ? hostUser : saved;
  final rest = step.file!
      .substring('%USERPROFILE%'.length)
      .replaceAll(r'\', '/');
  return '$dir/prefix/drive_c/users/$user$rest';
}

/// [path] if it is there, its real place being in the bottle's prefix or under
/// [env]'s HOME; null if it is not there. The profile's `Documents` is a link
/// to the host's own folder, which the game itself writes through; a link
/// that leads anywhere else is refused (D9).
String? _settingsFile(String dir, String path, Map<String, String> env) {
  if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) return null;
  final real = File(path).resolveSymbolicLinksSync();
  final prefix = Directory('$dir/prefix').resolveSymbolicLinksSync();
  final homes = [
    if (env['HOME'] case final home? when Directory(home).existsSync())
      Directory(home).resolveSymbolicLinksSync(),
  ];
  if (![prefix, ...homes].any((root) => real.startsWith('$root/'))) {
    throw UnexpectedLink(path);
  }
  return real;
}

/// Where an `ini` step of a fix stands in the bottle (D9). [env] stands for
/// this process's environment, whose HOME bounds where the file may be.
SettingState fixStepState(
  String home,
  String bottle,
  FixStep step, [
  Map<String, String>? env,
]) {
  final dir = _existing(home, bottle);
  final file = _settingsFile(
    dir,
    _settingsPath(dir, step),
    env ?? Platform.environment,
  );
  if (file == null) return SettingState.noFile;
  final text = latin1.decode(File(file).readAsBytesSync());
  return setIniValue(text, step.section!, step.name!, step.data!) == text
      ? SettingState.applied
      : SettingState.notApplied;
}

/// D9: applies the `ini` steps of fix [fixId] that this host applies, once,
/// at the user's word: never at launch. Refused while the bottle runs, since
/// the game writes its file again when it exits; a file not there yet is
/// [MissingFile], since the game makes it on its first run. The file is
/// read and written as bytes, through a temporary file renamed over it.
Future<void> applyFixSettings(
  String home,
  String bottle,
  String fixId, [
  Map<String, String>? env,
]) async {
  final fix = gameFix(fixId);
  final steps = [
    for (final step in fix.steps)
      if (step.type == 'ini' && step.applies) step,
  ];
  if (steps.isEmpty) return;
  final dir = _existing(home, bottle);
  if (await _serverRunning(home, dir)) throw BottleOpen(bottle);
  for (final step in steps) {
    final path = _settingsPath(dir, step);
    final file =
        _settingsFile(dir, path, env ?? Platform.environment) ??
        (throw MissingFile(path));
    final text = latin1.decode(File(file).readAsBytesSync());
    final changed = setIniValue(text, step.section!, step.name!, step.data!);
    if (changed == text) continue;
    final tmp = File('$file.bodega-tmp')
      ..writeAsBytesSync(latin1.encode(changed), flush: true);
    tmp.renameSync(file);
  }
}
