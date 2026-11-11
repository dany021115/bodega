import 'dart:convert';
import 'dart:io';

import 'package:engine/catalog_data.dart';
import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '_mac.dart';
import 'engine_test.dart' show fakeRuntime;

void main() {
  useMac();
  group('engine for the app', engineForApp);
  catalog();
}

void catalog() {
  late String tmp, home;

  /// An entry whose installer is [script]: the fake wine sources it.
  CatalogEntry fake(
    String script, {
    String id = 'x',
    String status = 'reported',
    String backend = 'wine',
    String? sha256,
    String? url,
    bool msi = false,
    Map<String, String> env = const {},
    List<Map<String, String>> registry = const [],
  }) {
    final source = File('$tmp/src-$id')..writeAsStringSync(script);
    return CatalogEntry.fromJson({
      'id': id,
      'title': 'Program X',
      'status': status,
      'statusNote': 'reason',
      'installer': {
        'url': url ?? 'file://${source.path}',
        'sha256': sha256,
        'args': ['/S'],
        'msi': msi,
      },
      'exe': 'Prog/x.exe',
      'args': ['--one'],
      'backend': backend,
      'sync': 'none',
      'env': env,
      'registry': registry,
      'notes': <String>[],
      'knownIssues': <Map<String, String>>[],
      'source': {'repo': 'test'},
    });
  }

  const makeExe =
      r'mkdir -p "$WINEPREFIX/drive_c/Prog"; '
      r'touch "$WINEPREFIX/drive_c/Prog/x.exe"';

  setUp(() async {
    tmp = Directory.systemTemp
        .createTempSync('bodega')
        .resolveSymbolicLinksSync();
    home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
    final (engine, hostlibs) = await fakeRuntime(tmp, 'engine-c');
    await installRuntime(home, engine, hostlibs);
  });
  tearDown(() => Directory(tmp).deleteSync(recursive: true));

  test('catalog data', () {
    final entries = catalogEntries();
    expect(entries.map((e) => e.id), [
      'steam',
      'rockstar',
      'ea-app',
      'ubisoft-connect',
      'battle-net',
      'epic-games',
      'gog-galaxy',
    ]);
    expect(jsonDecode(catalogJson), hasLength(7));
    for (final entry in entries) {
      expect(bottleDir('/h', entry.id), '/h/bottles/${entry.id}');
      expect(entry.url, startsWith('https://'), reason: entry.id);
      expect(backendNames, contains(entry.backend), reason: entry.id);
      expect(['msync', 'none'], contains(entry.sync), reason: entry.id);
      expect(entry.exe, isNot(startsWith('/')), reason: entry.id);
      expect(entry.exe, isNot(contains('..')), reason: entry.id);
      expect(entry.exe, isNot(contains(r'\')), reason: entry.id);
      expect(entry.source['license'], 'CC0-1.0', reason: entry.id);
      expect(entry.statusNote, isNotEmpty, reason: entry.id);
      expect(
        ['tested', 'reported', 'untested', 'blocked'],
        contains(entry.status),
        reason: entry.id,
      );
      for (final key in entry.env.keys) {
        expect(key, isNot(startsWith('DYLD_')), reason: entry.id);
        expect(
          ['WINEPREFIX', 'WINEMSYNC', 'PATH', 'HOME'],
          isNot(contains(key)),
          reason: entry.id,
        );
      }
    }
    String status(String id) => catalogEntry(id).status;
    expect(status('steam'), 'tested');
    expect(status('battle-net'), 'untested');
    expect(status('epic-games'), 'blocked');
    expect(status('gog-galaxy'), 'blocked');
    expect(catalogEntry('ea-app').flaky, isNotNull);
    // A field the recipe has no data for is null, not text (E8).
    expect(catalogEntry('gog-galaxy').source, containsPair('verified', null));
    expect(catalogEntry('steam').source['verified'], startsWith('2026-'));
    expect(
      () => catalogEntry('nope'),
      throwsA(
        isA<BadChoice>()
            .having((f) => f.kind, 'kind', ChoiceKind.catalogApp)
            .having((f) => f.value, 'value', 'nope'),
      ),
    );
  });

  test('catalogEntries', () {
    expect(catalogEntries(), hasLength(7));
    expect(catalogEntries('STEAM').map((e) => e.id), ['steam']);
    expect(catalogEntries('rockstar games').map((e) => e.id), ['rockstar']);
    expect(catalogEntries('zzz'), isEmpty);
  });

  group('installEntry', () {
    test('installs', () async {
      final steps = <InstallStep>[];
      final dir = await installEntry(
        home,
        fake(makeExe, env: {'FOO': '1'}),
        onStep: steps.add,
      );
      expect(dir, '$home/bottles/x');
      final prefix = '$dir/prefix';
      expect(File('$prefix/setup-args').readAsStringSync(), contains('/S'));
      final settings = jsonDecode(
        File('$dir/settings.json').readAsStringSync(),
      );
      expect(settings['sync'], 'none');
      expect(settings['programs']['x.exe'], {
        'backend': 'wine',
        'env': {'FOO': '1'},
      });
      final app = jsonDecode(
        File('$dir/apps.json').readAsStringSync(),
      )['apps'][0];
      expect(app['id'], 'x');
      expect(app['exe'], 'Prog/x.exe');
      expect(File('$prefix/server.log').readAsStringSync(), contains('k'));
      expect(File('$home/downloads/x-setup.exe').existsSync(), isFalse);
      // Each step as a code with what it names (E2). A file URL has no host.
      expect(steps, [
        (kind: InstallStepKind.unpinnedDownload, subject: ''),
        (kind: InstallStepKind.downloading, subject: null),
        (kind: InstallStepKind.creatingBottle, subject: 'x'),
        (kind: InstallStepKind.runningInstaller, subject: null),
        (kind: InstallStepKind.waiting, subject: null),
      ]);
      final logs = Directory('$dir/logs').listSync().map((e) => e.path);
      expect(logs, contains(endsWith('-x-setup.log')));

      await expectLater(
        installEntry(home, fake(makeExe)),
        throwsA(isA<BottleExists>().having((f) => f.bottle, 'bottle', 'x')),
      );
    });

    test('refuses before creating anything', () async {
      for (final (entry, failure) in [
        (
          fake(makeExe, status: 'blocked'),
          isA<CatalogBlocked>().having((f) => f.id, 'id', 'x'),
        ),
        (
          fake(makeExe, backend: 'dxmt'),
          isA<BackendNotInstalled>().having(
            (f) => f.backend,
            'backend',
            'dxmt',
          ),
        ),
        (
          fake(makeExe, url: 'http://example.com/x.exe'),
          isA<NotHttps>().having(
            (f) => f.url,
            'url',
            'http://example.com/x.exe',
          ),
        ),
        (
          fake(makeExe, sha256: '0' * 64),
          isA<ChecksumMismatch>().having(
            (f) => f.file,
            'file',
            '$home/downloads/x-setup.exe',
          ),
        ),
      ]) {
        await expectLater(installEntry(home, entry), throwsA(failure));
        expect(Directory('$home/bottles/x').existsSync(), isFalse);
        expect(File('$home/downloads/x-setup.exe').existsSync(), isFalse);
      }
      await expectLater(
        installEntry(home, catalogEntry('epic-games')),
        throwsA(isA<CatalogBlocked>().having((f) => f.id, 'id', 'epic-games')),
      );
      expect(Directory('$home/bottles/epic-games').existsSync(), isFalse);
    });

    test('keeps a pinned installer', () async {
      final entry = fake(makeExe);
      await installEntry(
        home,
        fake(
          makeExe,
          sha256: (await sha256Line('$tmp/src-x')).split(' ').first,
        ),
      );
      expect(
        File('$home/downloads/${entry.id}-setup.exe').existsSync(),
        isTrue,
      );
    });

    test('msi', () async {
      await installEntry(home, fake(makeExe, msi: true));
      final args = File('$home/bottles/x/prefix/msi-args')
          .readAsStringSync()
          .trim();
      expect(args, startsWith('msiexec /i $home/downloads/x-setup.msi /qn'));
      expect(args, endsWith('/S'));
    });

    test('exit codes', () async {
      await installEntry(home, fake('$makeExe; exit 194', id: 'ok'));
      expect(File('$home/bottles/ok/apps.json').existsSync(), isTrue);

      await expectLater(
        installEntry(home, fake('$makeExe; exit 5', id: 'bad')),
        throwsA(
          isA<WineToolFailed>()
              .having((f) => f.tool, 'tool', WineTool.installer)
              .having((f) => f.exitCode, 'exitCode', 5)
              .having((f) => f.log, 'log', endsWith('-bad-setup.log')),
        ),
      );
      expect(File('$home/bottles/bad/apps.json').existsSync(), isFalse);
      expect(Directory('$home/bottles/bad/logs').existsSync(), isTrue);
      expect(
        File('$home/bottles/bad/prefix/server.log').readAsStringSync(),
        contains('k'),
      );
    });

    test('missing exe', () async {
      await expectLater(
        installEntry(home, fake('true')),
        throwsA(
          isA<InstallerNoExe>()
              .having((f) => f.exe, 'exe', 'Prog/x.exe')
              .having((f) => f.log, 'log', endsWith('-x-setup.log')),
        ),
      );
      expect(File('$home/bottles/x/apps.json').existsSync(), isFalse);
    });

    test('registry', () async {
      const value = {
        'key': r'HKLM\Some Key',
        'name': 'Value',
        'type': 'REG_DWORD',
        'data': '16',
      };
      await installEntry(home, fake(makeExe, registry: const [value]));
      // The bottle's own values for gamepads go first (see _ensureGamepads).
      expect(
        File('$home/bottles/x/prefix/reg.log')
            .readAsStringSync()
            .trim()
            .split('\n'),
        [
          contains('Enable SDL'),
          contains('DisableInput'),
          r'reg add HKLM\Some Key /v Value /t REG_DWORD /d 16 /f',
        ],
      );
      await expectLater(
        installEntry(
          home,
          fake(
            makeExe,
            id: 'y',
            registry: [
              {...value, 'data': 'FAIL'},
            ],
          ),
        ),
        throwsA(
          isA<WineToolFailed>()
              .having((f) => f.tool, 'tool', WineTool.reg)
              .having((f) => f.exitCode, 'exitCode', 3),
        ),
      );
    });

    test('waits for the server', () async {
      final clock = Stopwatch()..start();
      await installEntry(home, fake(makeExe));
      expect(clock.elapsed, lessThan(const Duration(seconds: 10)));

      clock.reset();
      const hang = r'touch "$WINEPREFIX/hang"';
      await installEntry(
        home,
        fake('$makeExe; $hang', id: 'late'),
        grace: const Duration(seconds: 1),
      );
      expect(clock.elapsed, greaterThanOrEqualTo(const Duration(seconds: 1)));
      expect(
        File('$home/bottles/late/prefix/server.log').readAsStringSync(),
        contains('k'),
      );

      await expectLater(
        installEntry(
          home,
          fake(hang, id: 'never'),
          limit: const Duration(seconds: 1),
        ),
        throwsA(
          isA<InstallerNoExe>().having((f) => f.exe, 'exe', 'Prog/x.exe'),
        ),
      );
    });
  });

  test('antiCheatHints', () async {
    await createBottle(home, 'b');
    expect(antiCheatHints(home, 'b'), isEmpty);
    final eac =
        '$home/bottles/b/prefix/drive_c/users/q/AppData/Roaming/EasyAntiCheat';
    // Lines as the launcher writes them, CRLF included.
    const failed =
        '[21:33:53:436] [Windows] [EAC Launcher] [Info]  - ProcessTitle: POLYGON.\r\n'
        '[21:34:06:645] [Windows] [EAC Launcher] [Err!] Failed to map the '
        'anti-cheat module.\r\n'
        "[21:34:06:648] [Windows] [EAC Launcher] [Info] Launcher finished with: "
        "206, 'Failed to load the anti-cheat module.'.\r\n";
    final log = File('$eac/product/deployment/anticheatlauncher.log')
      ..createSync(recursive: true)
      ..writeAsStringSync(failed);

    expect(antiCheatHints(home, 'b'), [(game: 'POLYGON')]);

    final after = log.lastModifiedSync().add(const Duration(seconds: 2));
    expect(antiCheatHints(home, 'b', since: after), isEmpty);

    // A log that does not name its game still fails: for no game.
    log.writeAsStringSync(failed.split('\r\n').skip(1).join('\r\n'));
    expect(antiCheatHints(home, 'b'), [(game: null)]);

    log.writeAsStringSync('${failed}Launcher finished with: 0, \'ok\'.\r\n');
    expect(antiCheatHints(home, 'b'), isEmpty);
    log.writeAsStringSync('- ProcessTitle: POLYGON.\r\n');
    expect(antiCheatHints(home, 'b'), isEmpty);
    expect(
      () => antiCheatHints(home, 'nope'),
      throwsA(isA<BottleNotFound>().having((f) => f.bottle, 'bottle', 'nope')),
    );
  });

  test('installedApps', () async {
    expect(installedApps(home), isEmpty);
    await createBottle(home, 'no-app');
    await expectLater(
      openApp(home, 'no-app'),
      throwsA(
        isA<AppNotFound>()
            .having((f) => f.bottle, 'bottle', 'no-app')
            .having((f) => f.key, 'key', isNull),
      ),
    );

    await installEntry(
      home,
      fake(makeExe, env: {'FOO': '1', 'WINEDEBUG': '-all'}),
    );
    await installEntry(home, fake(makeExe, id: 'a'), bottle: 'b');
    final apps = installedApps(home);
    expect(apps.map((app) => app.bottle), ['b', 'x']);
    expect(apps.last.title, 'Program X');
    expect(apps.last.args, ['--one']);

    final prefix = '$home/bottles/x/prefix';
    final log = await openApp(home, 'x');
    expect(await exitOf(log), 7);
    final text = File(log).readAsStringSync();
    expect(text, contains(r'C:\Prog\x.exe --one'));
    expect(text, contains('# cwd $prefix/drive_c/Prog\n'));
    expect(text, contains('# backend wine (exe)\n'));
    final env = File('$prefix/last-env').readAsStringSync();
    for (final line in ['FOO=1', 'WINEMSYNC=0', 'WINEDEBUG=-all']) {
      expect(env, contains('$line\n'), reason: line);
    }

    final other = await runInBottle(home, 'x', 'notepad', []);
    await exitOf(other);
    expect(
      File('$prefix/last-env').readAsStringSync(),
      isNot(contains('FOO=1')),
    );
    expect(
      File('$prefix/last-env').readAsStringSync(),
      contains('WINEMSYNC=0'),
    );

    File('$home/bottles/b/apps.json').writeAsStringSync('{broken');
    expect(
      () => installedApps(home),
      throwsA(
        isA<CorruptData>().having(
          (f) => f.source,
          'source',
          '$home/bottles/b/apps.json',
        ),
      ),
    );
  });
}

void engineForApp() {
  late String tmp, home;
  const makeExe =
      r'mkdir -p "$WINEPREFIX/drive_c/Prog"; '
      r'touch "$WINEPREFIX/drive_c/Prog/x.exe"';

  CatalogEntry fake({String? sha256, String id = 'x'}) =>
      CatalogEntry.fromJson({
        'id': id,
        'title': 'X',
        'status': 'reported',
        'statusNote': '',
        'installer': {
          'url': 'http://unused/x.exe',
          'sha256': sha256,
          'args': <String>[],
          'msi': false,
        },
        'exe': 'Prog/x.exe',
        'args': <String>[],
        'backend': 'wine',
        'sync': 'none',
        'env': <String, String>{},
        'registry': <Map<String, String>>[],
        'notes': <String>[],
        'knownIssues': <Map<String, String>>[],
        'source': <String, String>{},
      });

  setUp(() async {
    tmp = Directory.systemTemp
        .createTempSync('bodega')
        .resolveSymbolicLinksSync();
    home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
  });
  tearDown(() => Directory(tmp).deleteSync(recursive: true));

  Future<void> runtime() async {
    final (engine, hostlibs) = await fakeRuntime(tmp, 'engine-e');
    await installRuntime(home, engine, hostlibs);
  }

  test('hasRuntime', () async {
    expect(hasRuntime(home), isFalse);
    await runtime();
    expect(hasRuntime(home), isTrue);
    Directory(currentRuntime(home)).deleteSync(recursive: true);
    expect(hasRuntime(home), isFalse);
  });

  test('installEntry with a downloaded setup', () async {
    await runtime();
    final setup = File('$tmp/x-setup.exe')..writeAsStringSync(makeExe);
    final dir = await installEntry(home, fake(), setup: setup.path);
    expect(File('$dir/apps.json').existsSync(), isTrue);
    expect(setup.existsSync(), isFalse);

    final again = File('$tmp/y-setup.exe')..writeAsStringSync(makeExe);
    await expectLater(
      installEntry(
        home,
        fake(id: 'y', sha256: '0' * 64),
        setup: again.path,
      ),
      throwsA(
        isA<ChecksumMismatch>().having((f) => f.file, 'file', again.path),
      ),
    );
    expect(Directory('$home/bottles/y').existsSync(), isFalse);
    expect(again.existsSync(), isTrue);
  });

  test('listBottles', () async {
    await runtime();
    expect(listBottles(home), isEmpty);
    await createBottle(home, 'empty');
    final setup = File('$tmp/x-setup.exe')..writeAsStringSync(makeExe);
    await installEntry(home, fake(), setup: setup.path);
    Directory('$home/bottles/broken').createSync();
    final list = listBottles(home);
    expect(list.map((b) => b.name), ['broken', 'empty', 'x']);
    expect(list.map((b) => b.ready), [false, true, true]);
    expect(list.map((b) => b.apps.firstOrNull?.title), [null, null, 'X']);
    expect(installedApps(home).map((a) => a.bottle), ['x']);
  });

  test('removeBottle', () async {
    await runtime();
    await createBottle(home, 't');
    final outside = File('$tmp/outside/data.txt')..createSync(recursive: true);
    Link('$home/bottles/t/prefix/z').createSync('$tmp/outside');
    await removeBottle(home, 't');
    expect(Directory('$home/bottles/t').existsSync(), isFalse);
    expect(outside.existsSync(), isTrue);
    await expectLater(
      removeBottle(home, 't'),
      throwsA(isA<BottleNotFound>().having((f) => f.bottle, 'bottle', 't')),
    );
  });

  test('bottleLogs', () async {
    await runtime();
    await createBottle(home, 't');
    final run = await runInBottle(home, 't', 'notepad', []);
    await exitOf(run);
    final logs = bottleLogs(home, 't');
    expect(logs.first.path, run);
    expect(logs.first.exitCode, 7);
    expect(logs.last.name, endsWith('-wineboot.log'));
    File(logs.last.path.replaceFirst(RegExp(r'\.log$'), '.exit')).deleteSync();
    expect(bottleLogs(home, 't').last.exitCode, isNull);
  });

  test('addApp', () async {
    await runtime();
    await createBottle(home, 'a');
    await createBottle(home, 'b');
    final drive = '$home/bottles/a/prefix/drive_c';
    File('$drive/Game/g.exe').createSync(recursive: true);
    addApp(home, 'a', 'Inside', 'Game/g.exe');
    expect(installedApps(home).single.title, 'Inside');
    expect(
      () => addApp(home, 'a', 'Another', 'Game/g.exe'),
      throwsA(isA<AppAlreadyAdded>().having((f) => f.bottle, 'bottle', 'a')),
    );
    expect(
      () => addApp(home, 'b', 'Nothing', 'Game/g.exe'),
      throwsA(
        isA<MissingFile>().having(
          (f) => f.path,
          'path',
          '$home/bottles/b/prefix/drive_c/Game/g.exe',
        ),
      ),
    );

    final inside = await openApp(home, 'a');
    await exitOf(inside);
    expect(File(inside).readAsStringSync(), contains(r'C:\Game\g.exe'));

    final free = File('$tmp/Outside/free.exe')..createSync(recursive: true);
    addApp(home, 'b', 'Outside', free.path);
    final outside = await openApp(home, 'b');
    await exitOf(outside);
    expect(File(outside).readAsStringSync(), contains('# cwd $tmp/Outside\n'));
  });
}
