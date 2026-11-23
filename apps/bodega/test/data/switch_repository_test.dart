// The Switch repository on the fake Mac (specs/app.md): a Mac whose emulators
// work over a temporary folder, with HOME under it, so that no emulator, data
// folder or game of the machine that runs the tests is ever found, read or
// started. It runs on Linux too.

import 'dart:io';

import 'package:bodega/data/repository/switch_repository_impl.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/path_problem.dart';
import 'package:bodega/domain/entities/switch_game.dart';
import 'package:bodega/domain/entities/switch_status.dart';
import 'package:engine/engine.dart' as engine;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '_home.dart';

/// A game file with a made-up name and id.
const _gameName = 'Bodega Test [0100F00DBA5E0000][v0] (EU).nsp';

/// The made-up title id of that game and of the native app.
const _titleId = '0100F00DBA5E0000';

/// What Ryubing opens, in the order of its row.
const _extensions = ['xci', 'nsp', 'pfs0', 'nca', 'nro', 'nso'];

/// The program of the fake apps: it writes nothing, waits while a `hang` file
/// is beside it, and exits with the code in a `code` file beside it, or 0.
const _program = r'''#!/bin/sh
d="${0%/*}"
while [ -e "$d/hang" ]; do sleep 0.1; done
exit "$(cat "$d/code" 2>/dev/null || echo 0)"
''';

/// An `Info.plist` with no DOCTYPE, a string per key.
String _infoPlist(Map<String, String> keys) => [
  '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>',
  for (final MapEntry(:key, :value) in keys.entries)
    '<key>$key</key><string>$value</string>',
  '</dict></plist>',
].join();

/// An app at [app] whose `Info.plist` holds [keys] and, if [executable] is
/// given, whose `Contents/MacOS/<executable>` is [_program] at mode 755.
String _app(String app, Map<String, String> keys, {String? executable}) {
  if (executable != null) {
    final program = File('$app/Contents/MacOS/$executable')
      ..createSync(recursive: true)
      ..writeAsStringSync(_program);
    Process.runSync('/bin/chmod', ['755', program.path]);
  }
  File('$app/Contents/Info.plist')
    ..createSync(recursive: true)
    ..writeAsStringSync(_infoPlist(keys));
  return app;
}

/// The fake `Ryujinx.app` at [app], version 1.3.3.
String _ryujinx(String app) => _app(app, const {
  'CFBundleIdentifier': 'org.ryujinx.Ryujinx',
  'CFBundleExecutable': 'Ryujinx',
  'CFBundleShortVersionString': '1.3.3',
}, executable: 'Ryujinx');

/// The fake native app at [app]: a Mac app made of a game with nxnative.
String _native(String app) => _app(app, const {
  'DMTitleID': _titleId,
  'CFBundleExecutable': 'nxnative',
}, executable: 'nxnative');

/// The `plistKey` seam: [key]'s string in a fake app's XML, or null, as the
/// system's tool gives it.
Future<String?> _fixtureKey(String plist, String key) async {
  final file = File(plist);
  if (!file.existsSync()) return null;
  return RegExp('<key>${RegExp.escape(key)}</key><string>([^<]*)</string>')
      .firstMatch(file.readAsStringSync())
      ?.group(1);
}

/// The `quarantine` seam: whether macOS keeps an app in quarantine, as [apps]
/// says. An isolate gets a copy of [apps] as they are when the call is sent.
Future<bool> Function(String) _quarantineOf(Set<String> apps) =>
    (app) async => apps.contains(app);

/// The fake Mac: a Mac whose emulators the test gives.
class _SwitchMac extends engine.MacPlatform {
  _SwitchMac(this.emulators);

  @override
  final engine.EmulatorHost emulators;
}

/// The code a call failed with, without its detail: the engine's English
/// message, which `repository_call_test.dart` checks.
Future<AppError?> _code(Future<Either<AppError, Object?>> call) async =>
    (await call).getLeft().toNullable()?.copyWith(detail: null);

/// What a call that works gives.
Future<T> _right<T>(Future<Either<AppError, T>> call) async =>
    (await call).getOrElse((error) => fail('$error'));

void main() {
  final host = engine.hostPlatform;
  late String tmp;

  /// The data root, `<tmp>/bodega`.
  late String home;

  /// The apps the fake Mac's `quarantine` seam says macOS keeps in quarantine.
  late Set<String> quarantined;
  late SwitchRepositoryImpl repository;

  setUp(() {
    tmp = Directory.systemTemp
        .createTempSync('bodega-switch')
        .resolveSymbolicLinksSync();
    home = '$tmp/bodega';
    Directory(home).createSync();
    Directory('$tmp/home').createSync();
    quarantined = {};
    engine.hostPlatform = _SwitchMac(
      engine.MacEmulators(
        root: tmp,
        plistKey: _fixtureKey,
        quarantine: _quarantineOf(quarantined),
      ),
    );
    repository = SwitchRepositoryImpl(TestHome(home))
      ..environment = {'HOME': '$tmp/home'};
  });

  tearDown(() {
    engine.hostPlatform = host;
    Directory(tmp).deleteSync(recursive: true);
  });

  // Declared after the deletion, so it runs before it: <tmp> goes only once no
  // process started from it is left. macOS checks a new program while it
  // starts, and one whose files vanish meanwhile stays held behind a prompt
  // on the user's screen.
  tearDown(() async {
    for (final entry in Directory(
      tmp,
    ).listSync(recursive: true, followLinks: false)) {
      if (entry is File && entry.path.endsWith('/hang')) entry.deleteSync();
    }
    Future<List<int>> left() async {
      final ps = await Process.run('/bin/ps', [
        '-A',
        '-ww',
        '-o',
        'pid=,command=',
      ]);
      return [
        for (final line in '${ps.stdout}'.split('\n'))
          if (line.contains('$tmp/'))
            ?int.tryParse(line.trim().split(' ').first),
      ];
    }

    for (var i = 0; i < 100 && (await left()).isNotEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    for (final pid in await left()) {
      Process.killPid(pid, ProcessSignal.sigkill);
    }
  });

  /// An empty game file at [path].
  String game(String path) {
    File(path).createSync(recursive: true);
    return path;
  }

  Future<SwitchStatus> status() => _right(repository.status());
  Future<List<SwitchGame>> games() => _right(repository.games());

  group('the status (SA4)', () {
    test('names the emulator, its keys and firmware, full screen and the '
        'extensions, and finds none outside the temporary folder', () async {
      final app = _ryujinx('$tmp/Applications/Ryujinx.app');
      final data = '$tmp/home/Library/Application Support/Ryujinx';
      File('$data/system/prod.keys').createSync(recursive: true);
      final registered = Directory('$data/bis/system/Contents/registered')
        ..createSync(recursive: true);

      expect(
        await status(),
        SwitchStatus(
          emulator: 'Ryubing',
          appName: 'Ryujinx.app',
          page: 'https://ryujinx.app/download',
          install: EmulatorInstall(
            app: app,
            version: '1.3.3',
            picked: false,
            quarantined: false,
          ),
          keys: true,
          firmware: false,
          fullscreen: true,
          extensions: _extensions,
        ),
      );

      File('${registered.path}/made-up.nca').createSync();
      expect((await status()).firmware, isTrue);

      quarantined.add(app);
      expect((await status()).install?.quarantined, isTrue);

      Directory(app).deleteSync(recursive: true);
      expect((await status()).install, isNull);
    });

    test('is unknown where the host has no emulators', () async {
      engine.hostPlatform = const engine.LinuxPlatform(mangoHud: false);
      expect(
        (await repository.status()).getLeft().toNullable(),
        AppError.unknown(
          detail: const engine.NotAvailable('switch', 'Linux').message,
        ),
      );
    });
  });

  group('the games (SA4)', () {
    test('come sorted by title, without case', () async {
      await _right(
        repository.addFiles([
          game('$tmp/g/beta.nsp'),
          game('$tmp/g/Alpha.xci'),
          game('$tmp/g/gamma.nro'),
        ]),
      );
      expect(
        [for (final game in await games()) game.title],
        ['Alpha', 'beta', 'gamma'],
      );
    });

    test('tell a native game, and whether macOS keeps its app in '
        'quarantine', () async {
      final native = _native('$tmp/apps/Bodega Test.app');
      final file = game('$tmp/g/$_gameName');
      await _right(repository.addFiles([native, file]));

      expect(await games(), [
        SwitchGame(path: native, title: 'Bodega Test', native: true),
        SwitchGame(path: file, title: 'Bodega Test', titleId: _titleId),
      ]);

      quarantined.add(native);
      expect(await games(), [
        SwitchGame(
          path: native,
          title: 'Bodega Test',
          native: true,
          quarantined: true,
        ),
        SwitchGame(path: file, title: 'Bodega Test', titleId: _titleId),
      ]);
    });

    test('a list that does not parse is corrupt data', () async {
      final list = File('$home/switch/games.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('not json');
      expect(await _code(repository.games()), AppError.corruptData(list.path));
    });
  });

  group('adding and removing (SA5)', () {
    test('a game file is added once, its title and id from its name', () async {
      final file = game('$tmp/g/$_gameName');
      expect(await _right(repository.addFiles([file])), (added: 1, known: 0));
      expect(await _right(repository.addFiles([file])), (added: 0, known: 1));
      expect(await games(), [
        SwitchGame(path: file, title: 'Bodega Test', titleId: _titleId),
      ]);
    });

    test('a folder adds the games in it and below it, but no .nca', () async {
      game('$tmp/g/a.xci');
      game('$tmp/g/sub/b.nsp');
      game('$tmp/g/sub/content.nca');
      expect(await _right(repository.addFolder('$tmp/g')), (
        added: 2,
        known: 0,
      ));
    });

    test('what is no game, or not there, is refused', () async {
      final notes = game('$tmp/g/notes.txt');
      expect(
        await _code(repository.addFiles([notes])),
        AppError.notASwitchGame(notes),
      );
      expect(
        await _code(repository.addFiles(['$tmp/g/gone.nsp'])),
        AppError.badPath(PathProblem.missing('$tmp/g/gone.nsp')),
      );
      expect(await games(), isEmpty);
    });

    test('a native game is added with or without the emulator; an app that is '
        'none is refused; a folder adds a copy', () async {
      final native = _native('$tmp/apps/Bodega Test.app');
      expect(await _right(repository.addFiles([native])), (added: 1, known: 0));

      await _right(repository.remove(native));
      _ryujinx('$tmp/Applications/Ryujinx.app');
      expect(await _right(repository.addFiles([native])), (added: 1, known: 0));

      final other = _app('$tmp/Other.app', const {
        'CFBundleIdentifier': 'org.example.other',
        'CFBundleExecutable': 'Other',
      });
      expect(
        await _code(repository.addFiles([other])),
        AppError.notASwitchGame(other),
      );

      final copy = _native('$tmp/more/Bodega Test.app');
      expect(await _right(repository.addFolder('$tmp/more')), (
        added: 1,
        known: 0,
      ));
      // Same title, so by path.
      expect([for (final game in await games()) game.path], [native, copy]);
    });

    test('the host\'s emulators are the ones asked about an app, also in the '
        'isolate that adds it', () async {
      // A Mac with no emulators: the isolate's own host, this machine's,
      // would find the native app.
      engine.hostPlatform = _SwitchMac(const engine.LinuxEmulators());
      final native = _native('$tmp/apps/Bodega Test.app');
      expect(await _code(repository.addFiles([native])), isA<UnknownError>());
      expect(await _right(repository.addFolder('$tmp/apps')), (
        added: 0,
        known: 0,
      ));
      expect(await games(), isEmpty);
    });

    test('removing forgets a game and leaves its file; one never listed is '
        'not found', () async {
      final file = game('$tmp/g/$_gameName');
      await _right(repository.addFiles([file]));

      await _right(repository.remove(file));
      expect(await games(), isEmpty);
      expect(File(file).existsSync(), isTrue);

      expect(
        await _code(repository.remove(file)),
        AppError.switchGameNotFound(file),
      );
    });
  });

  group('the emulator and full screen (SA6)', () {
    test('a pick is used while the fixed places hold no emulator, and never '
        'over one', () async {
      final elsewhere = _ryujinx('$tmp/elsewhere/Ryujinx.app');
      await _right(repository.chooseEmulator(elsewhere));
      expect(
        (await status()).install,
        EmulatorInstall(app: elsewhere, version: '1.3.3', picked: true),
      );

      final fixed = _ryujinx('$tmp/Applications/Ryujinx.app');
      expect(
        (await status()).install,
        EmulatorInstall(app: fixed, version: '1.3.3', picked: false),
      );
    });

    test('an app that is not the emulator is refused, and the pick stays as '
        'it was', () async {
      final elsewhere = _ryujinx('$tmp/elsewhere/Ryujinx.app');
      await _right(repository.chooseEmulator(elsewhere));
      final settings = File('$home/switch/settings.json');
      final saved = settings.readAsStringSync();

      final other = _app('$tmp/Other.app', const {
        'CFBundleIdentifier': 'org.example.other',
        'CFBundleExecutable': 'Other',
      });
      expect(
        await _code(repository.chooseEmulator(other)),
        AppError.notAnEmulator(other, 'Ryubing'),
      );
      expect(settings.readAsStringSync(), saved);
      expect((await status()).install?.app, elsewhere);
    });

    test('full screen is saved for the next status', () async {
      await _right(repository.setFullscreen(false));
      expect((await status()).fullscreen, isFalse);
      await _right(repository.setFullscreen(true));
      expect((await status()).fullscreen, isTrue);
    });
  });

  // Each run here ends before its test does: no test rewrites a program or
  // deletes an app while a run of it may still be starting.
  group('the keys and the firmware', () {
    test("the keys the user picked are copied where Ryubing reads them, and "
        'the status then finds them', () async {
      final keys = File('$tmp/dump/prod.keys')..createSync(recursive: true);
      expect((await status()).keys, isFalse);
      expect(await _right(repository.installKeys([keys.path])), ['prod.keys']);
      expect(
        File('$tmp/home/Library/Application Support/Ryujinx/system/prod.keys')
            .existsSync(),
        isTrue,
      );
      expect((await status()).keys, isTrue);
    });

    test('a pick with no .keys file, or none at all, is a code', () async {
      final notes = game('$tmp/dump/notes.txt');
      expect(
        await _code(repository.installKeys([notes])),
        AppError.noSwitchKeys(notes),
      );
      expect(
        await _code(repository.installKeys(['$tmp/nope.keys'])),
        AppError.badPath(PathProblem.missing('$tmp/nope.keys')),
      );
    });

    test("the firmware opens Ryubing's installer, and needs Ryubing", () async {
      final firmware = game('$tmp/dump/fw.zip');
      expect(
        await _code(repository.installFirmware(firmware)),
        const AppError.noEmulator('Ryubing', 'Ryujinx.app'),
      );
      _ryujinx('$tmp/Applications/Ryujinx.app');
      expect(await _right(repository.installFirmware(firmware)), unit);
    });
  });

  group('runs (SA7)', () {
    test('a game runs until Stop, which ends it with 143, and a run that ends '
        'by itself gives its code', () async {
      final macOS =
          '${_ryujinx('$tmp/Applications/Ryujinx.app')}/Contents/MacOS';
      final file = game('$tmp/g/$_gameName');
      await _right(repository.addFiles([file]));
      File('$macOS/hang').createSync();

      final log = await _right(repository.open(file));
      expect(log, startsWith('$home/switch/logs/'));
      expect(await repository.running(), [SwitchRun(game: file, log: log)]);
      expect(
        await _code(repository.open(file)),
        AppError.switchGameRunning(file),
      );

      await _right(repository.stop(file));
      expect(await repository.waitRun(log), 143);
      expect(await repository.running(), isEmpty);

      File('$macOS/hang').deleteSync();
      File('$macOS/code').writeAsStringSync('3');
      expect(await repository.waitRun(await _right(repository.open(file))), 3);
    });

    test('a native game runs with no emulator anywhere, and Stop ends it '
        'with 143', () async {
      final native = _native('$tmp/apps/Bodega Test.app');
      await _right(repository.addFiles([native]));
      File('$native/Contents/MacOS/hang').createSync();

      final log = await _right(repository.open(native));
      expect(log, startsWith('$home/switch/logs/'));
      expect(await repository.running(), [SwitchRun(game: native, log: log)]);

      await _right(repository.stop(native));
      expect(await repository.waitRun(log), 143);
    });

    test('a game file with no emulator, a path never listed and a game whose '
        'file is gone are refused', () async {
      final file = game('$tmp/g/$_gameName');
      await _right(repository.addFiles([file]));
      expect(
        await _code(repository.open(file)),
        const AppError.noEmulator('Ryubing', 'Ryujinx.app'),
      );

      final never = '$tmp/g/never.nsp';
      expect(
        await _code(repository.open(never)),
        AppError.switchGameNotFound(never),
      );
      expect(
        await _code(repository.stop(never)),
        AppError.switchGameNotFound(never),
      );

      File(file).deleteSync();
      expect(
        await _code(repository.open(file)),
        AppError.badPath(PathProblem.missing(file)),
      );
      expect(await repository.running(), isEmpty);
    });

    test('a wait that cannot be told gives null, and a host with no emulators '
        'runs nothing; neither throws', () async {
      final exit = File('$tmp/l/a.exit')
        ..createSync(recursive: true)
        ..writeAsStringSync('not a code');
      expect(await repository.waitRun('${exit.parent.path}/a.log'), isNull);

      engine.hostPlatform = const engine.LinuxPlatform(mangoHud: false);
      expect(await repository.running(), isEmpty);
    });
  });
}
