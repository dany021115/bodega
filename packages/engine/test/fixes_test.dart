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
String fixes(List<Map<String, Object?>> steps, {bool optIn = false}) =>
    jsonEncode([
      {
        'id': 'game',
        'title': 'Game',
        'steam': 9,
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

/// NFS13's settings file, as the game writes it: CRLF, and its key in [Sound].
const nfsConfig =
    '[Display]\r\nWidth=2048\r\nHeight=1330\r\n[Sound]\r\nMusicVolume=8\r\n'
    'Reverb=1\r\n[Gameplay]\r\nEnableVibration=true\r\n';

void main() {
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

  group('the shipped data', () {
    test('parses, with unique ids and Steam apps', () {
      final all = gameFixes();
      expect(all, isNotEmpty);
      expect({for (final fix in all) fix.id}.length, all.length);
      // highball-db's are Steam games with steps; Bodega's follow them (D7).
      final generated = [
        for (final fix in all)
          if (fix.source != 'bodega') fix,
      ];
      expect({for (final fix in generated) fix.steam}.length, generated.length);
      for (final fix in generated) {
        expect(fix.steam, isNotNull, reason: fix.id);
        expect(fix.steps, isNotEmpty, reason: fix.id);
        expect(fix.source, startsWith('recipes/games/'), reason: fix.id);
      }
      expect(all.skip(generated.length).map((fix) => fix.id), [
        'blur',
        'need-for-speed-most-wanted-2012',
      ]);
    });

    test(
      'finds a fix by Steam app and by id, and an unknown one is an error',
      () {
        final first = gameFixes().first;
        expect(fixForSteamApp(first.steam!)?.id, first.id);
        expect(fixForApp('steam:${first.steam}')?.id, first.id);
        expect(gameFix(first.id).steam, first.steam);
        expect(gameFix('${first.steam}').id, first.id);
        expect(fixForApp('steam:0'), isNull);
        expect(fixForApp('something-else'), isNull);
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
      final blur = fixForApp('/users/x/games/blur/blur.exe')!;
      expect(blur.id, 'blur');
      expect(blur.steam, isNull);
      expect(blur.requires, ['vcrun2008']);
      expect(fixForApp('program files/blur/Blur.exe')?.id, 'blur');
      expect(fixForApp('steam:19680')?.id, 'alice-madness-returns');
      expect(fixForApp('/users/x/games/other.exe'), isNull);
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
        (<String, Object?>{'id': 'alice-madness-returns'}, 'twice'),
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
        bodegaFixesSource = bodegas([entry]);
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
