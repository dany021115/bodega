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
  'key': r'HKCU\Software\Juego',
  'name': 'Valor',
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
String fixes(List<Map<String, Object?>> steps, {bool optIn = false}) =>
    jsonEncode([
      {
        'id': 'juego',
        'title': 'Juego',
        'steam': 9,
        'optIn': optIn,
        'steps': steps,
        'notes': <String>[],
        'knownIssues': <Object?>[],
        'source': 'recipes/games/juego.json',
        'verified': null,
      },
    ]);

void main() {
  late String tmp, home;
  final shipped = fixesSource;

  setUp(() {
    tmp = Directory.systemTemp
        .createTempSync('bodega-fixes')
        .resolveSymbolicLinksSync();
    home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
    hostPlatform = const TestMac();
  });

  tearDown(() {
    fixesSource = shipped;
    hostPlatform = HostPlatform.detect();
    Directory(tmp).deleteSync(recursive: true);
  });

  group('the shipped data', () {
    test('parses, with unique ids and Steam apps', () {
      final all = gameFixes();
      expect(all, isNotEmpty);
      expect({for (final fix in all) fix.id}.length, all.length);
      expect({for (final fix in all) fix.steam}.length, all.length);
      for (final fix in all) {
        expect(fix.steps, isNotEmpty, reason: fix.id);
        expect(fix.source, startsWith('recipes/games/'), reason: fix.id);
      }
    });

    test(
      'finds a fix by Steam app and by id, and an unknown one is an error',
      () {
        final first = gameFixes().first;
        expect(fixForSteamApp(first.steam)?.id, first.id);
        expect(fixForApp('steam:${first.steam}')?.id, first.id);
        expect(gameFix(first.id).steam, first.steam);
        expect(gameFix('${first.steam}').id, first.id);
        expect(fixForApp('steam:0'), isNull);
        expect(fixForApp('otra-cosa'), isNull);
        expect(() => gameFix('no-existe'), throwsA(contains('no fix for')));
      },
    );

    test('a step of an unknown kind is refused, not skipped', () {
      fixesSource = fixes([
        {
          'type': 'rm',
          'platforms': ['mac'],
        },
      ]);
      expect(gameFixes, throwsFormatException);
    });
  });

  group('which steps a host applies', () {
    test('only those tagged for it, and none of an opt-in fix', () {
      fixesSource = fixes([
        env('A', '1', ['mac']),
        env('B', '1', ['linux']),
        env('C', '1', ['mac', 'linux']),
      ]);
      expect([for (final s in gameFix('juego').active) s.name], ['A', 'C']);

      hostPlatform = const LinuxPlatform();
      expect([for (final s in gameFix('juego').active) s.name], ['B', 'C']);

      fixesSource = fixes([
        env('A', '1', ['linux']),
      ], optIn: true);
      expect(gameFix('juego').active, isEmpty);
      expect(gameFix('juego').steps, hasLength(1));
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
        ..writeAsStringSync('"appid" "9"\n"name" "Juego"\n"StateFlags" "4"');
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
                if (line.contains(r'HKCU\Software\Juego')) line,
            ];
    }

    Future<void> open({bool? avx}) async =>
        exitOf(await openApp(home, 'b', key: 'steam:9', avx: avx));

    test(
      'its variables reach the game, below the bottle and the launch',
      () async {
        fixesSource = fixes([
          env('FIX_ONLY', 'fix'),
          env('BOTELLA', 'fix'),
          env('LANZAMIENTO', 'fix'),
        ]);
        setBottleOptions(home, 'b', env: {'BOTELLA': 'botella'});
        await exitOf(
          await openApp(
            home,
            'b',
            key: 'steam:9',
            env: {'LANZAMIENTO': 'lanzamiento'},
          ),
        );
        final seen = lastEnv();
        expect(seen['FIX_ONLY'], 'fix');
        expect(seen['BOTELLA'], 'botella');
        expect(seen['LANZAMIENTO'], 'lanzamiento');
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
        env('RARO', r'${otraCosa}'),
      ]);
      await open();
      final budget = (hostPlatform.memoryMB * 0.375).round();
      expect(hostPlatform.memoryMB, greaterThan(0));
      expect(lastEnv()['DXVK_CONFIG'], 'dxgi.maxVideoMemoryBudget=$budget');
      // A placeholder Bodega does not know is left out, not passed as text.
      expect(lastEnv(), isNot(contains('RARO')));
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
        expect(File(log).readAsStringSync(), contains('# note $fixNotApplied'));
        final hints = await hintsIn(log);
        expect(hints.map((hint) => hint.id), ['fixNotApplied']);
        expect(hints.single.text, contains('Steam was already open'));
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
        fixesSource = fixes([registry('uno')]);
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
      fixesSource = fixes([registry('uno'), registry('dos')]);
      await open();
      expect(regLog(), [
        r'reg add HKCU\Software\Juego /v Valor /t REG_SZ /d uno /f',
        r'reg add HKCU\Software\Juego /v Valor /t REG_SZ /d dos /f',
      ]);
    });

    test('a registry write that fails stops the launch', () async {
      fixesSource = fixes([registry('FAIL')]);
      await expectLater(
        openApp(home, 'b', key: 'steam:9'),
        throwsA(contains('reg add for Juego exited with 3')),
      );
      expect(File('$prefix/last-env').existsSync(), isFalse);
    });

    test(
      'an opt-in fix, a fix of another host and another game do nothing',
      () async {
        fixesSource = fixes([env('X', '1'), registry('uno')], optIn: true);
        await open();
        expect(lastEnv(), isNot(contains('X')));
        expect(regLog(), isEmpty);

        fixesSource = fixes([
          env('X', '1', ['linux']),
          registry('uno', ['linux']),
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
}
