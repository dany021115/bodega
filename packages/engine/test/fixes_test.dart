import 'dart:convert';
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '_mac.dart';
import 'engine_test.dart' show fakeRuntime;

Map<String, Object?> env(
  String name,
  String value, [
  List<String>? platforms,
]) => {
  'type': 'env',
  'name': name,
  'value': value,
  'platforms': platforms ?? ['mac'],
};

Map<String, Object?> registry(String data, [List<String>? platforms]) => {
  'type': 'registry',
  'key': r'HKCU\Software\Game',
  'name': 'Value',
  'valueType': 'REG_SZ',
  'data': data,
  'platforms': platforms ?? ['mac'],
};

Map<String, Object?> override(String value) => {
  'type': 'dlloverride',
  'value': value,
  'platforms': ['mac'],
};

/// The fixes file with one game, Steam app 9.
String fixes(
  List<Map<String, Object?>> steps, {
  bool optIn = false,
  Map<String, String> backends = const {},
}) => jsonEncode([
  {
    'id': 'game',
    'title': 'Game',
    'steam': 9,
    'backends': backends,
    'optIn': optIn,
    'steps': steps,
    'notes': <String>[],
    'knownIssues': <Object?>[],
    'source': 'recipes/games/game.json',
    'verified': null,
  },
]);

/// Bodega's fixes file with [entries], each completed with the fields every
/// fix has.
String bodegas(List<Map<String, Object?>> entries) => jsonEncode([
  for (final entry in entries)
    {
      'title': 'Game',
      'steam': null,
      'exes': <String>[],
      'optIn': false,
      'requires': <String>[],
      'steps': <Object?>[],
      'notes': <String>[],
      'knownIssues': <Object?>[],
      'source': 'bodega',
      'verified': null,
      ...entry,
    },
]);

/// An app of the bottle `b`, for matching.
InstalledApp app({
  String key = 'hand',
  String exe = 'Games/game.exe',
  String title = '',
}) => (
  bottle: 'b',
  key: key,
  id: key,
  title: title,
  exe: exe,
  args: const [],
  inLibrary: true,
  hud: false,
);

/// NFS13's settings file, as the game writes it: CRLF, and its key in [Sound].
const nfsConfig =
    '[Display]\r\nWidth=2048\r\nHeight=1330\r\n[Sound]\r\nMusicVolume=8\r\n'
    'Reverb=1\r\n[Gameplay]\r\nEnableVibration=true\r\n';

void main() {
  group('the CLI (E8)', cliMain, testOn: 'mac-os');

  late String tmp, home;
  final shipped = fixesSource;
  final shippedBodegas = bodegaFixesSource;

  setUp(() {
    tmp = Directory.systemTemp
        .createTempSync('bodega-fixes')
        .resolveSymbolicLinksSync();
    home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
    hostPlatform = const TestMac();
  });

  tearDown(() {
    fixesSource = shipped;
    bodegaFixesSource = shippedBodegas;
    hostPlatform = HostPlatform.detect();
    Directory(tmp).deleteSync(recursive: true);
  });

  group('the shipped data (E2)', () {
    test('parses, with unique ids and Steam apps, Bodega\'s last', () {
      final all = gameFixes();
      expect(all.length, greaterThanOrEqualTo(890));
      expect({for (final fix in all) fix.id}.length, all.length);
      final steam = [
        for (final fix in all)
          if (fix.steam != null) fix.steam,
      ];
      expect(steam.toSet().length, steam.length);
      expect(all.skip(all.length - 2).map((fix) => fix.id), [
        'blur',
        'need-for-speed-most-wanted-2012',
      ]);
      for (final fix in all.take(all.length - 2)) {
        expect(fix.source, 'db/games/${fix.id}.json', reason: fix.id);
        expect(fix.status, isNot('verified'), reason: fix.id);
      }
      expect(fixesSourceCommit, startsWith('bc72f85'));
    });

    test('keeps the fixes it had, and names only what Bodega has', () {
      final ids = {for (final fix in gameFixes()) fix.id};
      // The 20 fixes of highball-db at 7a008d5.
      for (final id in const [
        'alice-madness-returns', 'assetto-corsa', 'bloody-spell', //
        'csgo-legacy', 'cyberpunk-2077', 'death-stranding-directors-cut',
        'death-stranding', 'five-nights-at-freddys-2', //
        'five-nights-at-freddys', 'forza-horizon-6', 'half-life-2',
        'helldivers-2', 'hogwarts-legacy', 'marvels-guardians-of-the-galaxy',
        'microsoft-flight-simulator-2024', 'portal-2', //
        'raceroom-racing-experience', 'red-dead-redemption-2',
        'the-last-caretaker', 'warframe',
      ]) {
        expect(ids, contains(id));
      }
      final runtimes = {for (final row in dependencies) row.id};
      const macBackends = {'wine', 'dxmt', 'dxvk', 'd3dmetal'};
      for (final fix in gameFixes()) {
        expect(runtimes, containsAll(fix.requires), reason: fix.id);
        expect(macBackends, containsAll(fix.backends.values), reason: fix.id);
        expect(fix.backends.keys, everyElement('mac'), reason: fix.id);
      }
      expect(gameFix('blur').status, 'verified');
      expect(gameFix('need-for-speed-most-wanted-2012').status, 'verified');
      expect(gameFixes().where((fix) => fix.status == 'blocked'), isNotEmpty);
      expect(gameFixes().where((fix) => fix.reports != null), isNotEmpty);
    });

    test(
      'finds a fix by Steam app and by id, and an unknown one is an error',
      () {
        final first = gameFixes().firstWhere((fix) => fix.steam != null);
        expect(fixForSteamApp(first.steam!)?.id, first.id);
        expect(gameFix(first.id).steam, first.steam);
        expect(gameFix('${first.steam}').id, first.id);
        expect(fixForSteamApp(0), isNull);
        expect(
          () => gameFix('nope'),
          throwsA(
            isA<BadChoice>()
                .having((f) => f.kind, 'kind', ChoiceKind.fix)
                .having((f) => f.value, 'value', 'nope'),
          ),
        );
      },
    );

    test('a step of an unknown kind is refused, not skipped', () {
      fixesSource = fixes([
        {
          'type': 'rm',
          'platforms': ['mac'],
        },
      ]);
      expect(
        gameFixes,
        throwsA(
          isA<CorruptData>()
              .having((f) => f.source, 'source', 'fixes_data.dart')
              .having((f) => f.detail, 'detail', contains('rm')),
        ),
      );
    });
  });

  group('the model (E3)', () {
    setUp(() => bodegaFixesSource = '[]');

    Map<String, Object?> entry(String id, Map<String, Object?> fields) => {
      'id': id,
      'title': id,
      'steam': null,
      'optIn': false,
      'steps': <Object?>[],
      'notes': <String>[],
      'knownIssues': <Object?>[],
      'source': 'db/games/$id.json',
      'verified': null,
      ...fields,
    };

    ({int count, int median, String last}) reports(int median) =>
        (count: 2, median: median, last: '2026-11-11');

    test('a backend only where it was verified, and one the host has', () {
      fixesSource = jsonEncode([
        entry('a', {
          'backends': {'mac': 'dxmt'},
        }),
        entry('b', {
          'backends': {'linux': 'dxmt'},
        }),
        entry('c', {
          'backends': {'linux': 'dxvk'},
        }),
      ]);
      expect(
        [for (final fix in gameFixes()) fix.backend],
        ['dxmt', null, null],
      );
      hostPlatform = const LinuxPlatform();
      expect(
        [for (final fix in gameFixes()) fix.backend],
        [null, null, 'dxvk'],
      );
    });

    test('the rating comes from the median, blocked first', () {
      fixesSource = jsonEncode([
        for (final (id, median) in [('a', 5), ('b', 4), ('c', 3), ('d', 2)])
          entry(id, {
            'reports': {'count': 2, 'median': median, 'last': '2026-11-11'},
          }),
        entry('e', {}),
        entry('f', {
          'status': 'blocked',
          'reports': {'count': 1, 'median': 5, 'last': '2026-11-11'},
          'antiCheat': {
            'names': ['Easy Anti-Cheat'],
            'verdict': 'blocked',
          },
        }),
      ]);
      final all = gameFixes();
      expect(
        [for (final fix in all) fix.rating],
        ['works', 'works', 'playable', 'broken', null, 'blocked'],
      );
      expect(all.first.reports, reports(5));
      expect(all.last.antiCheat?.names, ['Easy Anti-Cheat']);
      expect(all.last.antiCheat?.verdict, 'blocked');
    });

    test('the old shape reads as community, with no backend', () {
      fixesSource = fixes([]);
      final fix = gameFixes().single;
      expect(fix.status, 'community');
      expect(fix.backends, isEmpty);
      expect(fix.antiCheat, isNull);
      expect(fix.reports, isNull);
      expect(fix.nativeMac, isFalse);
    });

    test('a bad status or verdict is refused', () {
      for (final fields in [
        <String, Object?>{'status': 'great'},
        <String, Object?>{
          'antiCheat': {'names': <String>[], 'verdict': 'maybe'},
        },
      ]) {
        fixesSource = jsonEncode([entry('a', fields)]);
        expect(gameFixes, throwsA(isA<CorruptData>()));
      }
    });

    test('the data is parsed once while its source stays the same', () {
      bodegaFixesSource = shippedBodegas;
      final first = gameFixes();
      expect(identical(gameFixes().first, first.first), isTrue);
      fixesSource = fixes([]);
      expect(gameFixes().first.id, 'game');
      fixesSource = shipped;
      expect(identical(gameFixes().first, first.first), isFalse);
    });
  });

  group('matching (E4)', () {
    setUp(() {
      fixesSource = jsonEncode([
        for (final (id, title, steam, exes) in [
          ('a', 'Alpha™: Game', 10, <String>[]),
          ('b', 'Beta', null, ['beta.exe']),
          ('c', 'Gamma', null, <String>[]),
        ])
          {
            'id': id,
            'title': title,
            'steam': steam,
            'exes': exes,
            'optIn': false,
            'steps': <Object?>[],
            'notes': <String>[],
            'knownIssues': <Object?>[],
            'source': 'db/games/$id.json',
            'verified': null,
          },
      ]);
      bodegaFixesSource = '[]';
    });

    String? found(InstalledApp app) {
      final match = gameFor(app);
      return match == null ? null : '${match.fix.id} ${match.by.name}';
    }

    test('by Steam app, exe and title, in that order', () {
      expect(found(app(key: 'steam:10')), 'a steam');
      expect(found(app(key: 'steam:99', title: 'Gamma')), isNull);
      expect(found(app(exe: 'Games/BETA.EXE')), 'b exe');
      expect(found(app(title: 'alpha: game')), 'a title');
      expect(found(app(title: 'gamma 2')), isNull);
      expect(found(app(exe: r'C:\x\beta.exe', title: 'Gamma')), 'b exe');
      expect(normalTitle('  Alpha™: Game!  '), 'alpha game');
    });

    test("Bodega's own entry comes before highball-db's", () {
      bodegaFixesSource = bodegas([
        {'id': 'mine', 'title': 'Gamma'},
      ]);
      expect(found(app(title: 'Gamma')), 'mine title');
    });
  });

  group('which steps a host applies', () {
    test('only those tagged for it, and none of an opt-in fix', () {
      fixesSource = fixes([
        env('A', '1', ['mac']),
        env('B', '1', ['linux']),
        env('C', '1', ['mac', 'linux']),
      ]);
      expect([for (final s in gameFix('game').active) s.name], ['A', 'C']);

      hostPlatform = const LinuxPlatform();
      expect([for (final s in gameFix('game').active) s.name], ['B', 'C']);

      fixesSource = fixes([
        env('A', '1', ['linux']),
      ], optIn: true);
      expect(gameFix('game').active, isEmpty);
      expect(gameFix('game').steps, hasLength(1));
    });
  });

  group('launching a Steam game', () {
    late String prefix;

    setUp(() async {
      final (engine, hostlibs) = await fakeRuntime(tmp, 'engine');
      await installRuntime(home, engine, hostlibs);
      await createBottle(home, 'b');
      prefix = '$home/bottles/b/prefix';
      final steam = '$prefix/drive_c/Program Files (x86)/Steam';
      File('$steam/steam.exe').createSync(recursive: true);
      File('$steam/steamapps/appmanifest_9.acf')
        ..createSync(recursive: true)
        ..writeAsStringSync('"appid" "9"\n"name" "Game"\n"StateFlags" "4"');
    });

    Map<String, String> lastEnv() => {
      for (final line in File('$prefix/last-env').readAsLinesSync())
        if (line.indexOf('=') case final at when at > 0)
          line.substring(0, at): line.substring(at + 1),
    };

    List<String> regLog() {
      final file = File('$prefix/reg.log');
      return !file.existsSync()
          ? []
          : [
              for (final line in file.readAsLinesSync())
                if (line.contains(r'HKCU\Software\Game')) line,
            ];
    }

    Future<void> open({bool? avx}) async =>
        exitOf(await openApp(home, 'b', key: 'steam:9', avx: avx));

    test('PE6 a Rosetta bottle keeps every variable', () async {
      fixesSource = fixes([
        env('D3DM_ENABLE_METALFX', '1'),
        env('DXVK_ASYNC', '1'),
      ]);
      final log = await openApp(home, 'b', key: 'steam:9');
      await exitOf(log);
      expect(lastEnv(), containsPair('D3DM_ENABLE_METALFX', '1'));
      expect(lastEnv(), containsPair('DXVK_ASYNC', '1'));
      expect(File(log).readAsStringSync(), isNot(contains('# skipped')));
    });

    test('the plan is what runs (E7)', () async {
      Directory('$home/backends/dxmt/wine').createSync(recursive: true);
      fixesSource = fixes(
        [env('FIX_ONLY', 'fix'), override('foo=n'), registry('1')],
        backends: {'mac': 'dxmt'},
      );
      final plan = await gamePlan(home, 'b', 'steam:9');
      expect(plan.on, isTrue);
      expect(plan.match?.fix.id, 'game');
      expect(plan.match?.by, MatchKind.steam);
      expect(plan.backend, (name: 'dxmt', origin: 'config'));
      expect(plan.graphics, isNull);
      expect(plan.env, {'FIX_ONLY': 'fix'});
      expect(plan.overrides, ['foo=n']);
      expect(plan.registry.single.data, '1');
      expect(plan.ini, isEmpty);
      final log = await openApp(home, 'b', key: 'steam:9');
      await exitOf(log);
      expect(
        File(log).readAsStringSync(),
        contains('# backend ${plan.backend.name} (${plan.backend.origin})'),
      );
      expect(lastEnv()['FIX_ONLY'], 'fix');
      expect(lastEnv()['WINEDLLOVERRIDES'], contains('foo=n'));
    });

    test('an app with no entry gets auto (E7)', () async {
      fixesSource = '[]';
      final plan = await gamePlan(home, 'b', 'steam:9');
      expect(plan.match, isNull);
      expect(plan.on, isTrue);
      expect(plan.backend.origin, 'auto');
      expect(plan.env, isEmpty);
      await expectLater(
        gamePlan(home, 'b', 'steam:1'),
        throwsA(isA<AppNotFound>()),
      );
    });

    test('switched off, it gets nothing, and its values go (E6)', () async {
      fixesSource = fixes([env('FIX_ONLY', 'fix'), registry('1')]);
      await setGameConfig(home, 'b', 'steam:9', on: false);
      expect(bottleSettings(home, 'b').configOff, {'steam:9'});
      expect(regLog(), [r'reg delete HKCU\Software\Game /v Value /f']);
      final plan = await gamePlan(home, 'b', 'steam:9');
      expect(plan.on, isFalse);
      expect(plan.match?.fix.id, 'game');
      expect(plan.env, isEmpty);
      expect(plan.registry, isEmpty);
      await open();
      expect(regLog(), hasLength(1));
      expect(lastEnv(), isNot(contains('FIX_ONLY')));

      await setGameConfig(home, 'b', 'steam:9', on: true);
      expect(bottleSettings(home, 'b').configOff, isEmpty);
      await open();
      expect(regLog().last, startsWith('reg add'));
      expect(lastEnv()['FIX_ONLY'], 'fix');
      final saved = jsonDecode(
        File('$home/bottles/b/settings.json').readAsStringSync(),
      );
      expect(saved, isNot(contains('configOff')));
    });

    test('a value already gone is fine; another failure stops (E6)', () async {
      Map<String, Object?> step(String name) => {
        ...registry('1'),
        'name': name,
      };
      fixesSource = fixes([step('GONE')]);
      await setGameConfig(home, 'b', 'steam:9', on: false);
      expect(bottleSettings(home, 'b').configOff, {'steam:9'});
      await setGameConfig(home, 'b', 'steam:9', on: true);
      fixesSource = fixes([step('FAIL')]);
      await expectLater(
        setGameConfig(home, 'b', 'steam:9', on: false),
        throwsA(
          isA<WineToolFailed>()
              .having((f) => f.tool, 'tool', WineTool.reg)
              .having((f) => f.exitCode, 'exitCode', 3),
        ),
      );
      expect(bottleSettings(home, 'b').configOff, isEmpty);
      await expectLater(
        setGameConfig(home, 'b', 'steam:1', on: false),
        throwsA(isA<AppNotFound>()),
      );
    });

    test('the verdict is saved, cleared and checked (E6)', () async {
      setGameVerdict(home, 'b', 'steam:9', 'playable');
      expect(bottleSettings(home, 'b').verdicts, {'steam:9': 'playable'});
      expect((await gamePlan(home, 'b', 'steam:9')).verdict, 'playable');
      setGameVerdict(home, 'b', 'steam:9', null);
      expect(bottleSettings(home, 'b').verdicts, isEmpty);
      expect(
        () => setGameVerdict(home, 'b', 'steam:9', 'great'),
        throwsA(
          isA<BadChoice>().having((f) => f.kind, 'kind', ChoiceKind.verdict),
        ),
      );
      expect(
        () => setGameVerdict(home, 'b', 'steam:1', 'works'),
        throwsA(isA<AppNotFound>()),
      );
      final saved = jsonDecode(
        File('$home/bottles/b/settings.json').readAsStringSync(),
      );
      expect(saved, isNot(contains('verdicts')));
    });

    test(
      'its variables reach the game, below the bottle and the launch',
      () async {
        fixesSource = fixes([
          env('FIX_ONLY', 'fix'),
          env('BOTTLE', 'fix'),
          env('LAUNCH', 'fix'),
        ]);
        setBottleOptions(home, 'b', env: {'BOTTLE': 'bottle'});
        await exitOf(
          await openApp(home, 'b', key: 'steam:9', env: {'LAUNCH': 'launch'}),
        );
        final seen = lastEnv();
        expect(seen['FIX_ONLY'], 'fix');
        expect(seen['BOTTLE'], 'bottle');
        expect(seen['LAUNCH'], 'launch');
      },
    );

    test('turning AVX off still beats a fix that advertises it', () async {
      fixesSource = fixes([env('ROSETTA_ADVERTISE_AVX', '1')]);
      await open();
      expect(lastEnv()['ROSETTA_ADVERTISE_AVX'], '1');
      await open(avx: false);
      expect(lastEnv(), isNot(contains('ROSETTA_ADVERTISE_AVX')));
    });

    test('a DLL override is added to the ones already there', () async {
      fixesSource = fixes([override('amd_ags_x64='), override('foo=n')]);
      await open();
      final value = lastEnv()['WINEDLLOVERRIDES']!;
      expect(value, endsWith(';amd_ags_x64=;foo=n'));
      // Added to what the launch already had, not replacing it.
      expect(value.split(';').length, greaterThan(2));
    });

    test('a value sized to the memory is worked out for this host', () async {
      fixesSource = fixes([
        env('DXVK_CONFIG', r'dxgi.maxVideoMemoryBudget=${memoryMB*0.375}'),
        env('ODD_VALUE', r'${somethingElse}'),
      ]);
      await open();
      final budget = (hostPlatform.memoryMB * 0.375).round();
      expect(hostPlatform.memoryMB, greaterThan(0));
      expect(lastEnv()['DXVK_CONFIG'], 'dxgi.maxVideoMemoryBudget=$budget');
      // A placeholder Bodega does not know is left out, not passed as text.
      expect(lastEnv(), isNot(contains('ODD_VALUE')));
    });

    group('with Steam already open', () {
      List<String> tasklistLogs() => [
        for (final log in bottleLogs(home, 'b'))
          if (log.name.endsWith('-tasklist.log')) log.path,
      ];

      setUp(() {
        // The fake wineserver -w waits while this exists: a running bottle.
        File('$prefix/hang').createSync();
        File('$prefix/tasks').writeAsStringSync(
          'steam.exe                      24 Console 1 0 K\n',
        );
      });

      test('the log says its variables did not reach the game', () async {
        fixesSource = fixes([env('X', '1')]);
        final log = await openApp(home, 'b', key: 'steam:9');
        await exitOf(log);
        expect(
          File(log).readAsStringSync(),
          contains('# note fix not applied: Steam was already open\n'),
        );
        expect(await hintsIn(log), [LogHint.fixNotApplied]);
        expect(tasklistLogs(), hasLength(1));
      });

      test('a bottle running something else is no reason to warn', () async {
        File('$prefix/tasks').writeAsStringSync('explorer.exe  20 Console\n');
        fixesSource = fixes([override('foo=n')]);
        final log = await openApp(home, 'b', key: 'steam:9');
        await exitOf(log);
        expect(await hintsIn(log), isEmpty);
      });

      test('a fix that only writes the registry does not ask', () async {
        fixesSource = fixes([registry('one')]);
        final log = await openApp(home, 'b', key: 'steam:9');
        await exitOf(log);
        expect(tasklistLogs(), isEmpty);
        expect(await hintsIn(log), isEmpty);
        expect(regLog(), hasLength(1));
      });
    });

    test('with Steam closed there is nothing to ask or warn', () async {
      fixesSource = fixes([env('X', '1')]);
      final log = await openApp(home, 'b', key: 'steam:9');
      await exitOf(log);
      expect(lastEnv()['X'], '1');
      expect(await hintsIn(log), isEmpty);
      expect(
        bottleLogs(home, 'b').where((l) => l.name.endsWith('-tasklist.log')),
        isEmpty,
      );
    });

    test('its registry values are written before the game starts', () async {
      fixesSource = fixes([registry('one'), registry('two')]);
      await open();
      expect(regLog(), [
        r'reg add HKCU\Software\Game /v Value /t REG_SZ /d one /f',
        r'reg add HKCU\Software\Game /v Value /t REG_SZ /d two /f',
      ]);
    });

    test('a registry write that fails stops the launch', () async {
      fixesSource = fixes([registry('FAIL')]);
      await expectLater(
        openApp(home, 'b', key: 'steam:9'),
        throwsA(
          isA<WineToolFailed>()
              .having((f) => f.tool, 'tool', WineTool.reg)
              .having((f) => f.exitCode, 'exitCode', 3)
              .having((f) => f.log, 'log', endsWith('-reg.log')),
        ),
      );
      expect(File('$prefix/last-env').existsSync(), isFalse);
    });

    test(
      'an opt-in fix, a fix of another host and another game do nothing',
      () async {
        fixesSource = fixes([env('X', '1'), registry('one')], optIn: true);
        await open();
        expect(lastEnv(), isNot(contains('X')));
        expect(regLog(), isEmpty);

        fixesSource = fixes([
          env('X', '1', ['linux']),
          registry('one', ['linux']),
        ]);
        await open();
        expect(lastEnv(), isNot(contains('X')));
        expect(regLog(), isEmpty);

        fixesSource = fixes([env('X', '1')]);
        File('$prefix/drive_c/P/b.exe').createSync(recursive: true);
        await exitOf(await runInBottle(home, 'b', r'C:\P\b.exe', []));
        expect(lastEnv(), isNot(contains('X')));
      },
    );
  });

  group("Bodega's own fixes (DE7)", () {
    test('follow the generated ones, and match by exe', () {
      final ids = [for (final fix in gameFixes()) fix.id];
      expect(ids.sublist(ids.length - 2), [
        'blur',
        'need-for-speed-most-wanted-2012',
      ]);
      final blur = gameFor(app(exe: '/users/x/games/blur/blur.exe'))!;
      expect(blur.fix.id, 'blur');
      expect(blur.by, MatchKind.exe);
      expect(blur.fix.steam, isNull);
      expect(blur.fix.requires, ['vcrun2008']);
      expect(gameFor(app(exe: r'C:\Games\Blur\Blur.exe'))?.fix.id, 'blur');
      expect(gameFor(app(key: 'steam:19680'))?.fix.id, 'alice-madness-returns');
      expect(gameFor(app(exe: '/users/x/games/other.exe')), isNull);
      // `fix show null` must not find a fix that has no Steam app.
      expect(() => gameFix('null'), throwsA(isA<BadChoice>()));
    });

    test('an ini step is never applied at launch', () {
      final nfs = gameFix('need-for-speed-most-wanted-2012');
      expect(nfs.steps.single.type, 'ini');
      expect(nfs.steps.single.applies, isTrue);
      expect(nfs.active, isEmpty);
      expect(nfs.needsLaunchEnv, isFalse);
    });

    test('a repeated id, an unknown runtime or a bad ini step is refused', () {
      for (final (entry, detail) in [
        (<String, Object?>{'id': 'blur'}, 'twice'),
        (
          <String, Object?>{
            'id': 'x',
            'requires': ['vcrun1999'],
          },
          'vcrun1999',
        ),
        (
          <String, Object?>{
            'id': 'y',
            'steps': [
              {
                'type': 'ini',
                'file': r'C:\\game.ini',
                'section': 'S',
                'name': 'N',
                'data': '1',
                'platforms': ['mac'],
              },
            ],
          },
          'USERPROFILE',
        ),
      ]) {
        bodegaFixesSource = bodegas([entry, if (entry['id'] == 'blur') entry]);
        expect(
          gameFixes,
          throwsA(
            isA<CorruptData>()
                .having((f) => f.source, 'source', 'bodega_fixes_data.dart')
                .having((f) => f.detail, 'detail', contains(detail)),
          ),
          reason: detail,
        );
      }
    });
  });

  group('the ini edit (DE8)', () {
    test('changes one value and keeps everything else', () {
      expect(
        setIniValue(nfsConfig, 'Sound', 'Reverb', '0'),
        nfsConfig.replaceFirst('Reverb=1', 'Reverb=0'),
      );
      expect(
        setIniValue('[sound]\nreverb = 1\n', 'Sound', 'Reverb', '0'),
        '[sound]\nreverb =0\n',
      );
      expect(
        setIniValue('[Sound]\nMusic=8\n[Other]\nA=1\n', 'Sound', 'Reverb', '0'),
        '[Sound]\nMusic=8\nReverb=0\n[Other]\nA=1\n',
      );
      expect(
        setIniValue('[Sound]\r\nMusic=8', 'Sound', 'Reverb', '0'),
        '[Sound]\r\nMusic=8\r\nReverb=0',
      );
      expect(
        setIniValue('[A]\r\nB=1\r\n', 'Sound', 'Reverb', '0'),
        '[A]\r\nB=1\r\n[Sound]\r\nReverb=0\r\n',
      );
      expect(setIniValue('', 'Sound', 'Reverb', '0'), '[Sound]\nReverb=0\n');
      // A key of the same name in another section is left alone.
      expect(
        setIniValue(
          '[Video]\nReverb=1\n[Sound]\nReverb=1\n',
          'Sound',
          'Reverb',
          '0',
        ),
        '[Video]\nReverb=1\n[Sound]\nReverb=0\n',
      );
    });

    test('bytes above 127 come back as they were', () {
      final text = latin1.decode([
        ...latin1.encode('[Sound]\nName=Caf'),
        0xE9,
        10,
        ...latin1.encode('Reverb=1\n'),
      ]);
      final out = latin1.encode(setIniValue(text, 'Sound', 'Reverb', '0'));
      expect(out, contains(0xE9));
      expect(latin1.decode(out), endsWith('Reverb=0\n'));
    });
  });

  group("applying a fix's settings (DE9)", () {
    late String profile, documents, file;
    const nfs = 'need-for-speed-most-wanted-2012';
    final env = <String, String>{};

    setUp(() async {
      final (engine, hostlibs) = await fakeRuntime(tmp, 'engine');
      await installRuntime(home, engine, hostlibs);
      await createBottle(home, 'b');
      env['HOME'] = '$tmp/host';
      documents = '$tmp/host/Documents';
      Directory(documents).createSync(recursive: true);
      profile = '$home/bottles/b/prefix/drive_c/users/$hostUser';
      Directory(profile).createSync(recursive: true);
      // As Wine makes it on the Mac: the profile's Documents is the host's.
      Link('$profile/Documents').createSync(documents);
      file =
          '$documents/Criterion Games/Need For Speed(TM) Most Wanted/config.NFS13Save';
    });

    FixStep step() => gameFix(nfs).steps.single;

    test('reads where it stands, and applies it once', () async {
      expect(fixStepState(home, 'b', step(), env), SettingState.noFile);
      await expectLater(
        applyFixSettings(home, 'b', nfs, env),
        throwsA(
          isA<MissingFile>().having(
            (f) => f.path,
            'path',
            contains('config.NFS13Save'),
          ),
        ),
      );
      File(file)
        ..createSync(recursive: true)
        ..writeAsStringSync(nfsConfig);
      expect(fixStepState(home, 'b', step(), env), SettingState.notApplied);
      await applyFixSettings(home, 'b', nfs, env);
      expect(
        File(file).readAsStringSync(),
        nfsConfig.replaceFirst('Reverb=1', 'Reverb=0'),
      );
      expect(fixStepState(home, 'b', step(), env), SettingState.applied);
      expect(File(file).parent.listSync().map((e) => e.path.split('/').last), [
        'config.NFS13Save',
      ]);
    });

    test('a link that leads elsewhere is refused', () async {
      Directory('$tmp/elsewhere/Criterion Games/Need For Speed(TM) Most Wanted')
          .createSync(recursive: true);
      final outside =
          '$tmp/elsewhere/Criterion Games/Need For Speed(TM) Most Wanted/config.NFS13Save';
      File(outside).writeAsStringSync(nfsConfig);
      Link('$profile/Documents')
        ..deleteSync()
        ..createSync('$tmp/elsewhere');
      expect(
        () => fixStepState(home, 'b', step(), env),
        throwsA(isA<UnexpectedLink>()),
      );
      await expectLater(
        applyFixSettings(home, 'b', nfs, env),
        throwsA(isA<UnexpectedLink>()),
      );
      expect(File(outside).readAsStringSync(), nfsConfig);
    });

    test('an open bottle is refused; another host does nothing', () async {
      File(file)
        ..createSync(recursive: true)
        ..writeAsStringSync(nfsConfig);
      File('$home/bottles/b/prefix/hang').createSync();
      await expectLater(
        applyFixSettings(home, 'b', nfs, env),
        throwsA(isA<BottleOpen>()),
      );
      File('$home/bottles/b/prefix/hang').deleteSync();
      hostPlatform = const LinuxPlatform();
      await applyFixSettings(home, 'b', nfs, env);
      expect(File(file).readAsStringSync(), nfsConfig);
    });
  });
}

/// E8: the CLI, built once, against the shipped data and a fake bottle.
void cliMain() {
  late String tmp, home, bin;

  setUpAll(() async {
    tmp = Directory.systemTemp
        .createTempSync('bodega-cli')
        .resolveSymbolicLinksSync();
    bin = '$tmp/bodega';
    final build = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      'bin/bodega.dart',
      '-o',
      bin,
    ]);
    expect(build.exitCode, 0, reason: '${build.stderr}');
    home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
    hostPlatform = const TestMac();
    final (engine, hostlibs) = await fakeRuntime(tmp, 'engine');
    await installRuntime(home, engine, hostlibs);
    await createBottle(home, 'b');
    final steam = '$home/bottles/b/prefix/drive_c/Program Files (x86)/Steam';
    File('$steam/steam.exe').createSync(recursive: true);
    File('$steam/steamapps/appmanifest_19680.acf')
      ..createSync(recursive: true)
      ..writeAsStringSync('"appid" "19680"\n"name" "Alice"\n"StateFlags" "4"');
  });

  tearDownAll(() {
    hostPlatform = HostPlatform.detect();
    Directory(tmp).deleteSync(recursive: true);
  });

  Future<ProcessResult> cli(List<String> args) =>
      Process.run(bin, args, environment: {'BODEGA_HOME': home});

  test('game show and use print the plan and switch it', () async {
    var run = await cli(['game', 'show', 'b', 'steam:19680']);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(
      run.stdout,
      allOf(
        contains(
          'match: Alice: Madness Returns (alice-madness-returns), '
          'by steam, community',
        ),
        contains('backend: '),
        contains(r'registry: HKCU\Software\Wine\AppDefaults'),
      ),
    );
    run = await cli(['game', 'use', 'b', 'steam:19680', 'off']);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    run = await cli(['game', 'show', 'b', 'steam:19680']);
    expect(run.stdout, contains('match: off'));
    expect(run.stdout, isNot(contains('registry:')));
    run = await cli(['game', 'use', 'b', 'steam:19680', 'maybe']);
    expect(run.exitCode, 64);
  });

  test('fix show prints the status, backend, anti-cheat and reports', () async {
    final run = await cli(['fix', 'show', 'armored-core-vi']);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(
      run.stdout,
      allOf(
        contains('status: community'),
        contains('backend: d3dmetal (mac d3dmetal)'),
        contains('anti-cheat: Easy Anti-Cheat, warning on the Mac'),
        contains('reports: 1, median 4/5, last 2026-11-03'),
      ),
    );
    final native = await cli([
      'fix',
      'show',
      'baldur-s-gate-3',
    ]);
    expect(native.stdout, contains('native mac: yes'));
  });
}
