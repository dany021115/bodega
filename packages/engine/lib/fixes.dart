part of 'engine.dart';

/// Where the fixes come from. A test replaces it; the app never does.
String fixesSource = fixesJson;

/// The highball-db commit the data comes from.
const fixesSourceCommit = fixesCommit;

/// One thing a fix does (F2). [platforms] says where it was verified, and a host
/// applies only its own: `env` sets a variable, `registry` writes a value and
/// `dlloverride` adds to WINEDLLOVERRIDES.
class FixStep {
  FixStep.fromJson(Map<String, dynamic> json)
    : type = json['type'] as String,
      name = json['name'] as String?,
      value = json['value'] as String?,
      key = json['key'] as String?,
      valueType = json['valueType'] as String?,
      data = json['data'] as String?,
      platforms = List<String>.from(json['platforms'] as List) {
    if (!const {'env', 'registry', 'dlloverride'}.contains(type)) {
      throw FormatException('paso de arreglo desconocido: $type');
    }
  }

  final String type;
  final String? name, value, key, valueType, data;
  final List<String> platforms;

  bool get applies => platforms.contains(hostPlatform.id);
}

/// What a game needs to run well (F1): its Steam app id, the steps, and what
/// upstream wrote about it. Notes and known issues stay in English.
class GameFix {
  GameFix.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String,
      steam = json['steam'] as int,
      optIn = json['optIn'] as bool,
      steps = [
        for (final step in json['steps'] as List)
          FixStep.fromJson(step as Map<String, dynamic>),
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
          : Map<String, String?>.from(json['verified'] as Map);

  final String id, title, source;
  final int steam;

  /// An optional fix is shown but never applied by itself: it costs something.
  final bool optIn;
  final List<FixStep> steps;
  final List<String> notes;
  final List<({String symptom, String cause, String fix})> knownIssues;
  final Map<String, String?>? verified;

  /// The steps this host applies, none for an opt-in fix (F3).
  List<FixStep> get active => optIn
      ? const []
      : [
          for (final step in steps)
            if (step.applies) step,
        ];

  /// Whether some step must be in the game's environment: variables and DLL
  /// overrides, which only a Steam that starts with them can pass on.
  bool get needsLaunchEnv => active.any((step) => step.type != 'registry');
}

/// The fixes in file order, filtered by [query] on id and title.
List<GameFix> gameFixes([String query = '']) {
  final text = query.toLowerCase();
  return [
    for (final json in jsonDecode(fixesSource) as List)
      GameFix.fromJson(json as Map<String, dynamic>),
  ].where((fix) {
    return fix.id.contains(text) || fix.title.toLowerCase().contains(text);
  }).toList();
}

/// The fix of a Steam game, or null if there is none.
GameFix? fixForSteamApp(int appid) =>
    gameFixes().where((fix) => fix.steam == appid).firstOrNull;

/// A fix by id or by Steam app id.
GameFix gameFix(String idOrApp) =>
    gameFixes()
        .where((fix) => fix.id == idOrApp || '${fix.steam}' == idOrApp)
        .firstOrNull ??
    (throw 'no hay arreglo para: $idOrApp (bodega fix list)');

/// The fix for the application with this [key] (`steam:<appid>`), if any.
GameFix? fixForApp(String key) {
  final app = key.startsWith('steam:') ? int.tryParse(key.substring(6)) : null;
  return app == null ? null : fixForSteamApp(app);
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
/// turns it into advice.
const fixNotApplied = 'arreglo sin aplicar: Steam ya estaba abierto';

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
    if (code != 0) {
      throw 'reg add de ${fix.title} salió con $code; log: $log';
    }
  }
}
