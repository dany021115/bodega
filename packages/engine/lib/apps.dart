part of 'engine.dart';

/// One application of a bottle. Registered ones are kept in `apps.json`;
/// detected ones are worked out each time, from what the bottle holds, so that
/// uninstalling something leaves nothing to clean up (design §2).
typedef InstalledApp = ({
  String bottle,
  String key,
  String id,
  String title,
  String exe,
  List<String> args,
  bool inLibrary,
  bool hud,
});

typedef BottleInfo = ({String name, bool ready, List<InstalledApp> apps});

/// A `.lnk` file's target as Windows sees it, and what it passes.
typedef Lnk = ({String target, String args, String? workingDir});

const _steamExe = 'Program Files (x86)/Steam/steam.exe';
const _steamRedistributables = '228980';
const _maxResources = 64 << 20;

/// What identifies an application in its bottle: `C:\Prog\A.EXE` and
/// `prog/a.exe` are the same one.
String appKey(String exe) {
  final path = exe.replaceAll(r'\', '/');
  final relative = RegExp('^[A-Za-z]:/').hasMatch(path)
      ? path.substring(3)
      : path;
  return relative.toLowerCase();
}

typedef _Store = ({
  List<Map<String, dynamic>> apps,
  List<String> hidden,
  List<String> offLibrary,
});

/// `apps.json`, or the `app.json` of a bottle from before it existed.
_Store _readStore(String dir) {
  final current = File('$dir/apps.json');
  final file = current.existsSync() ? current : File('$dir/app.json');
  if (!file.existsSync()) return (apps: [], hidden: [], offLibrary: []);
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final _Store store = file.path == current.path
        ? (
            apps: List<Map<String, dynamic>>.from(json['apps'] as List),
            hidden: List<String>.from((json['hidden'] ?? const []) as List),
            // Missing in files from before it existed: every app is in.
            offLibrary: List<String>.from(
              (json['offLibrary'] ?? const []) as List,
            ),
          )
        : (apps: [json], hidden: [], offLibrary: []);
    store.apps.forEach((app) => _appOf('', app, store.offLibrary));
    return store;
  } on Object catch (e) {
    throw '${file.path} is not valid: $e';
  }
}

/// `app.json` goes only once `apps.json` is safely written (M1).
void _writeStore(String dir, _Store store) {
  _writeJson('$dir/apps.json', {
    'apps': store.apps,
    'hidden': store.hidden,
    'offLibrary': store.offLibrary,
  });
  final legacy = File('$dir/app.json');
  if (legacy.existsSync()) legacy.deleteSync();
}

InstalledApp _appOf(
  String bottle,
  Map<String, dynamic> json,
  List<String> offLibrary,
) {
  final exe = json['exe'] as String;
  final key = appKey(exe);
  return (
    bottle: bottle,
    key: key,
    id: json['id'] as String,
    title: json['title'] as String,
    exe: exe,
    args: List<String>.from(json['args'] as List),
    inLibrary: !offLibrary.contains(key),
    hud: false, // set by _withHud
  );
}

/// [app] with the HUD its program has in the bottle's settings.
InstalledApp _withHud(InstalledApp app, BottleSettings settings) => (
  bottle: app.bottle,
  key: app.key,
  id: app.id,
  title: app.title,
  exe: app.exe,
  args: app.args,
  inLibrary: app.inLibrary,
  hud: settings.programs[_exeKey(app.exe)]?.hud ?? false,
);

void _registerApp(
  String dir,
  String id,
  String title,
  String exe,
  List<String> args,
) {
  final store = _readStore(dir);
  final key = appKey(exe);
  // Installing again over it replaces it.
  store.apps.removeWhere((app) => _appOf('', app, store.offLibrary).key == key);
  store.apps.add({
    'id': id,
    'title': title,
    'exe': exe,
    'args': args,
    'installedAt': DateTime.now().toUtc().toIso8601String(),
  });
  store.hidden.remove(key);
  _writeStore(dir, store);
}

/// Registers the user's own program in the bottle (E8, M6). [exe] is relative
/// to `drive_c`, or an absolute Unix path for a program kept outside the bottle.
/// [env] goes to the program's settings, for every launch of that exe (M11).
void addApp(
  String home,
  String bottle,
  String title,
  String exe, {
  List<String> args = const [],
  Map<String, String> env = const {},
}) {
  final dir = _existing(home, bottle);
  final path = exe.startsWith('/') ? exe : findCI('$dir/prefix/drive_c', exe);
  if (!File(path).existsSync()) throw '$path does not exist';
  final key = appKey(exe);
  final store = _readStore(dir);
  if (store.apps.any(
    (app) => _appOf(bottle, app, store.offLibrary).key == key,
  )) {
    throw 'the bottle $bottle already has that application';
  }
  _registerApp(dir, 'custom', title, exe, args);
  if (env.isNotEmpty) {
    final settings = _settings(dir);
    final program = _exeKey(exe);
    _saveSettings(
      dir,
      _with(
        settings,
        programs: {
          ...settings.programs,
          program: (
            backend: settings.programs[program]?.backend,
            env: {...?settings.programs[program]?.env, ...env},
            hud: settings.programs[program]?.hud ?? false,
          ),
        },
      ),
    );
  }
}

/// Turns the HUD on or off for every launch of the application's program (S4).
/// A Steam game's program is steam.exe, so its games share the setting, as
/// they share the backend.
void setAppHud(String home, String bottle, String key, bool value) {
  final dir = _existing(home, bottle);
  final app = _appsIn(bottle, dir).where((app) => app.key == key).firstOrNull;
  if (app == null) throw '$bottle has no application $key';
  final settings = _settings(dir);
  final program = _exeKey(app.exe);
  final current = settings.programs[program];
  _saveSettings(
    dir,
    _with(
      settings,
      programs: {
        ...settings.programs,
        program: (
          backend: current?.backend,
          env: current?.env ?? const <String, String>{},
          hud: value,
        ),
      },
    ),
  );
}

/// Takes the application out of the list. A registered one is forgotten, and
/// also hidden, because its shortcuts would bring it back.
void hideApp(String home, String bottle, String key) {
  final dir = _existing(home, bottle);
  final store = _readStore(dir);
  store.apps.removeWhere(
    (app) => _appOf(bottle, app, store.offLibrary).key == key,
  );
  store.offLibrary.remove(key);
  if (!store.hidden.contains(key)) store.hidden.add(key);
  _writeStore(dir, store);
}

/// Puts the application in the library, or takes it out. It stays installed
/// and launchable either way.
void setInLibrary(String home, String bottle, String key, bool value) {
  final dir = _existing(home, bottle);
  if (!_appsIn(bottle, dir).any((app) => app.key == key)) {
    throw '$bottle has no application $key';
  }
  final store = _readStore(dir);
  store.offLibrary.remove(key);
  if (!value) store.offLibrary.add(key);
  _writeStore(dir, store);
}

/// Registered applications first, then the detected ones by title (M4, M5).
List<InstalledApp> bottleApps(String home, String bottle) =>
    _appsIn(bottle, _existing(home, bottle));

List<InstalledApp> _appsIn(String bottle, String dir) {
  final store = _readStore(dir);
  final settings = _settings(dir);
  final registered = [
    for (final app in store.apps)
      _withHud(_appOf(bottle, app, store.offLibrary), settings),
  ];
  final seen = {...registered.map((app) => app.key), ...store.hidden};
  final drive = '$dir/prefix/drive_c';
  final detected =
      [
            ..._shortcutApps(bottle, drive, store.offLibrary),
            ..._steamGames(bottle, drive, store.offLibrary),
          ]
          .where((app) => seen.add(app.key))
          .map((app) => _withHud(app, settings))
          .toList();
  detected.sort(
    (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
  );
  return [...registered, ...detected];
}

bool _isRealDirectory(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) ==
    FileSystemEntityType.directory;

/// `users/<user>/Documents` and others point to the Mac's own folders, and
/// `dosdevices/z:` to `/`: nothing here may follow a link.
List<File> _shortcutFiles(String drive) {
  final users = findCI(drive, 'users');
  final roots = [
    if (_isRealDirectory(users))
      for (final user in Directory(
        users,
      ).listSync().whereType<Directory>()) ...[
        findCI(user.path, 'Desktop'),
        findCI(
          user.path,
          'AppData/Roaming/Microsoft/Windows/Start Menu/Programs',
        ),
      ],
    findCI(drive, 'ProgramData/Microsoft/Windows/Start Menu/Programs'),
  ];
  return [
    for (final root in roots)
      if (_isRealDirectory(root))
        for (final file in Directory(
          root,
        ).listSync(recursive: true, followLinks: false).whereType<File>())
          if (file.path.toLowerCase().endsWith('.lnk')) file,
  ];
}

Iterable<InstalledApp> _shortcutApps(
  String bottle,
  String drive,
  List<String> offLibrary,
) sync* {
  for (final file in _shortcutFiles(drive)) {
    final lnk = readLnk(file.path);
    if (lnk == null || !lnk.target.toLowerCase().startsWith(r'c:\')) continue;
    final exe = lnk.target.substring(3).replaceAll(r'\', '/');
    final name = exe.split('/').last.toLowerCase();
    if (!name.endsWith('.exe') || name.startsWith('unins')) continue;
    if (!File(findCI(drive, exe)).existsSync()) continue;
    // ponytail: the working folder is the exe's, not the shortcut's; a game
    // that needs another one won't start until `workingDir` reaches _launchIn.
    final key = appKey(exe);
    yield (
      bottle: bottle,
      key: key,
      inLibrary: !offLibrary.contains(key),
      id: 'detected',
      title: file.path
          .split('/')
          .last
          .replaceFirst(RegExp(r'\.lnk$', caseSensitive: false), ''),
      exe: exe,
      args: [
        for (final match in RegExp(r'"([^"]*)"|(\S+)').allMatches(lnk.args))
          match[1] ?? match[2]!,
      ],
      hud: false, // set by _withHud
    );
  }
}

/// Games installed by the Steam of this bottle (M5). They open through it, and
/// so with its backend (design §4).
// ponytail: only the library inside the prefix; `libraryfolders.vdf` lists the
// others, for when a bottle has one.
Iterable<InstalledApp> _steamGames(
  String bottle,
  String drive,
  List<String> offLibrary,
) sync* {
  final apps = findCI(drive, 'Program Files (x86)/Steam/steamapps');
  if (!File(findCI(drive, _steamExe)).existsSync() || !_isRealDirectory(apps)) {
    return;
  }
  final manifest = RegExp(r'/appmanifest_\d+\.acf$');
  for (final file in Directory(apps).listSync().whereType<File>()) {
    if (!manifest.hasMatch(file.path)) continue;
    final text = utf8.decode(file.readAsBytesSync(), allowMalformed: true);
    String? field(String name) => RegExp(
      '"$name"\\s+"([^"]*)"',
      caseSensitive: false,
    ).firstMatch(text)?.group(1);
    final id = field('appid'), title = field('name');
    final flags = int.tryParse(field('StateFlags') ?? '');
    if (id == null || title == null || flags == null) continue;
    if (flags & 4 == 0 || id == _steamRedistributables) continue;
    final key = 'steam:$id';
    yield (
      bottle: bottle,
      key: key,
      inLibrary: !offLibrary.contains(key),
      id: 'steam-game',
      title: title,
      exe: _steamExe,
      args: ['-applaunch', id],
      hud: false, // set by _withHud
    );
  }
}

/// Every bottle by name, with its applications (E2).
List<BottleInfo> listBottles(String home) {
  final bottles = Directory('$home/bottles').listSync().whereType<Directory>();
  return [for (final dir in bottles) _bottleInfo(dir.path)]
    ..sort((a, b) => a.name.compareTo(b.name));
}

BottleInfo _bottleInfo(String dir) {
  final name = dir.split('/').last;
  return (name: name, ready: _ready('$dir/prefix'), apps: _appsIn(name, dir));
}

/// The applications of every bottle (I8).
List<InstalledApp> installedApps(String home) => [
  for (final bottle in listBottles(home)) ...bottle.apps,
];

/// Launches an application of the bottle like [runInBottle] (I9): the one with
/// that [key], or else the first, which is the bottle's own if it has one (M6).
Future<String> openApp(
  String home,
  String bottle, {
  String? key,
  String? backend,
  bool hud = false,
  Map<String, String> env = const {},
  bool? avx,
}) async {
  final apps = bottleApps(home, bottle);
  if (apps.isEmpty) {
    throw '$bottle has no installed application; use bodega run $bottle '
        '<program>';
  }
  await hostPlatform.prepareBottle(home, bottle);
  final app = key == null
      ? apps.first
      : apps.where((app) => app.key == key).firstOrNull ??
            (throw '$bottle has no application $key');
  final fix = fixForApp(app.key);
  // A Steam already open starts the game with its own environment, so the
  // fix's variables would not reach it: the log says so instead of hiding it.
  final missed =
      fix != null && fix.needsLaunchEnv && await _steamRunning(home, bottle);
  if (fix != null) await _applyFixRegistry(home, bottle, fix);
  return _launchIn(
    home,
    bottle,
    app.exe.startsWith('/') ? app.exe : 'C:\\${app.exe.replaceAll('/', r'\')}',
    app.args,
    backend: backend,
    hud: hud,
    env: env,
    avx: avx,
    fix: fix,
    note: missed ? fixNotApplied : null,
  );
}

/// What a `.lnk` points to (MS-SHLLINK), or null for anything else: a shortcut
/// to a URL, a truncated file, or one that isn't a shortcut at all.
Lnk? readLnk(String path) {
  try {
    final bytes = File(path).readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(0, Endian.little) != 0x4C) return null;
    final flags = data.getUint32(20, Endian.little);
    var at = 76;
    if (flags & 0x01 != 0) at += 2 + data.getUint16(at, Endian.little);

    String? target;
    if (flags & 0x02 != 0) {
      final base = at + data.getUint32(at + 16, Endian.little);
      final end = bytes.indexOf(0, base);
      if (end < 0) return null;
      target = latin1.decode(bytes.sublist(base, end));
      at += data.getUint32(at, Endian.little);
    }
    if (target == null || target.isEmpty) return null;

    // Name, relative path, working folder, arguments and icon, in that order,
    // each one only if its flag says so.
    final unicode = flags & 0x80 != 0;
    String? workingDir, args;
    for (final flag in const [0x04, 0x08, 0x10, 0x20, 0x40]) {
      if (flags & flag == 0) continue;
      final length = data.getUint16(at, Endian.little);
      at += 2;
      final size = unicode ? length * 2 : length;
      final text = unicode
          ? String.fromCharCodes(
              Uint16List.sublistView(
                Uint8List.fromList(bytes.sublist(at, at + size)),
              ),
            )
          : latin1.decode(bytes.sublist(at, at + size));
      at += size;
      if (flag == 0x10) workingDir = text;
      if (flag == 0x20) args = text;
    }
    return (target: target, args: args ?? '', workingDir: workingDir);
  } on Object {
    return null;
  }
}

/// A picture of the application, or null: never an error, because a card can
/// always show the initial instead (M7). It reads little of the exe, but may
/// take long on a huge one, so a UI should call it off its main thread.
String? appIcon(String home, InstalledApp app) {
  try {
    final dir = bottleDir(home, app.bottle);
    if (app.key.startsWith('steam:')) {
      return _steamIcon(dir, app.key.substring('steam:'.length));
    }
    final exe = File(
      app.exe.startsWith('/')
          ? app.exe
          : findCI('$dir/prefix/drive_c', app.exe),
    );
    final hash = app.key.codeUnits.fold<int>(
      0xcbf29ce484222325,
      (hash, unit) => (hash ^ unit) * 0x100000001b3,
    );
    final icon = File(
      '$dir/icons/${hash.toUnsigned(64).toRadixString(16)}.ico',
    );
    // An empty file remembers that this exe has no icon.
    if (icon.existsSync() &&
        !icon.lastModifiedSync().isBefore(exe.lastModifiedSync())) {
      return icon.lengthSync() == 0 ? null : icon.path;
    }
    final bytes = _peIcon(exe.path);
    icon.parent.createSync(recursive: true);
    File('${icon.path}.tmp')
      ..writeAsBytesSync(bytes ?? const [])
      ..renameSync(icon.path);
    return bytes == null ? null : icon.path;
  } on Object {
    return null;
  }
}

/// Steam keeps a small icon named by its hash, beside its other pictures.
String? _steamIcon(String dir, String id) {
  final cache = Directory(
    findCI(
      '$dir/prefix/drive_c',
      'Program Files (x86)/Steam/appcache/librarycache/$id',
    ),
  );
  if (!cache.existsSync()) return null;
  final hashed = RegExp(r'/[0-9a-f]{40}\.jpg$');
  final files = cache.listSync(followLinks: false).whereType<File>();
  final icon = files.where((file) => hashed.hasMatch(file.path)).firstOrNull;
  if (icon != null) return icon.path;
  final logo = File('${cache.path}/logo.png');
  return logo.existsSync() ? logo.path : null;
}

/// The largest icon of a PE as an `.ico` of one image, valid for the PNG and
/// the DIB icons alike (design §3), or null if it has none.
Uint8List? _peIcon(String path) {
  final file = File(path).openSync();
  try {
    final dos = file.readSync(64);
    if (dos.length < 64 || dos[0] != 0x4D || dos[1] != 0x5A) return null;
    final pe = ByteData.sublistView(dos).getUint32(60, Endian.little);
    file.setPositionSync(pe);
    final header = ByteData.sublistView(file.readSync(24));
    final sections = header.getUint16(6, Endian.little);
    final optional = header.getUint16(20, Endian.little);
    file.setPositionSync(pe + 24 + optional);
    final table = file.readSync(40 * sections);
    for (var i = 0; i < sections; i++) {
      final row = table.sublist(i * 40, i * 40 + 40);
      if (latin1.decode(row.sublist(0, 5)) != '.rsrc') continue;
      final fields = ByteData.sublistView(row);
      final size = fields.getUint32(16, Endian.little);
      if (size > _maxResources) return null;
      file.setPositionSync(fields.getUint32(20, Endian.little));
      return _iconIn(file.readSync(size), fields.getUint32(12, Endian.little));
    }
    return null;
  } finally {
    file.closeSync();
  }
}

Uint8List? _iconIn(Uint8List resources, int address) {
  final data = ByteData.sublistView(resources);

  List<(int, int)> entries(int at) {
    final count =
        data.getUint16(at + 12, Endian.little) +
        data.getUint16(at + 14, Endian.little);
    return [
      for (var i = 0; i < count; i++)
        (
          data.getUint32(at + 16 + 8 * i, Endian.little),
          data.getUint32(at + 20 + 8 * i, Endian.little),
        ),
    ];
  }

  Uint8List leaf(int offset) {
    var at = offset;
    while (at & 0x80000000 != 0) {
      at = entries(at & 0x7fffffff).first.$2;
    }
    final start = data.getUint32(at, Endian.little) - address;
    return resources.sublist(
      start,
      start + data.getUint32(at + 4, Endian.little),
    );
  }

  const iconType = 3, groupType = 14;
  final types = entries(0);
  final group = types.where((type) => type.$1 == groupType).firstOrNull;
  final icons = types.where((type) => type.$1 == iconType).firstOrNull;
  if (group == null || icons == null) return null;

  final directory = leaf(entries(group.$2 & 0x7fffffff).first.$2);
  final rows = ByteData.sublistView(directory).getUint16(4, Endian.little);
  var best = -1, bestSide = -1;
  for (var i = 0; i < rows; i++) {
    final width = directory[6 + 14 * i];
    final side = width == 0 ? 256 : width;
    if (side > bestSide) {
      bestSide = side;
      best = 6 + 14 * i;
    }
  }
  if (best < 0) return null;

  final id = ByteData.sublistView(directory)
      .getUint16(best + 12, Endian.little);
  final icon = leaf(
    entries(icons.$2 & 0x7fffffff).firstWhere((entry) => entry.$1 == id).$2,
  );
  final out = Uint8List(22 + icon.length);
  final head = ByteData.sublistView(out)
    ..setUint16(2, 1, Endian.little)
    ..setUint16(4, 1, Endian.little);
  out.setRange(6, 18, directory, best);
  head
    ..setUint32(14, icon.length, Endian.little)
    ..setUint32(18, 22, Endian.little);
  out.setRange(22, out.length, icon);
  return out;
}
