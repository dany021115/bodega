import 'dart:convert';
import 'dart:core';
import 'dart:core' as core;
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '_mac.dart';
import 'backends_test.dart' show fakePe;
import 'fixes_test.dart' show env, fixes, override;
import 'runtimes_test.dart'
    show
        fakeCurrent,
        fakeMach9App,
        fakeMach9Runtime,
        fakeMach9Wine,
        mach9Bottle;

void main() {
  useMac();
  late String tmp, home;
  final shipped = fixesSource;
  setUp(() {
    tmp = Directory.systemTemp
        .createTempSync('bodega')
        .resolveSymbolicLinksSync();
    home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
  });
  tearDown(() {
    fixesSource = shipped;
    Directory(tmp).deleteSync(recursive: true);
  });

  const menu = 'dll_overrides=winemenubuilder.exe=';
  const mach9Debug =
      'fixme-all,-dbghelp_msc,-dbghelp_dwarf,-dbghelp_pdb,-dbghelp_macho';

  Map<String, String> lastEnv(String bottle) => {
    for (final line in File(
      '$home/bottles/$bottle/prefix/last-env',
    ).readAsLinesSync())
      if (line.indexOf('=') case final at when at > 0)
        line.substring(0, at): line.substring(at + 1),
  };

  /// The `WINE_COMPATDB` of the last Wine call in [bottle].
  String compatdb(String bottle) =>
      File('$home/bottles/$bottle/prefix/compatdb').readAsStringSync();

  /// What no Mach9 process may get (MG6).
  bool forbidden(String key) =>
      const {
        'WINEDLLOVERRIDES',
        'WINEDLLPATH_PREPEND',
        'WINE_COMPATDB_FILE',
        'WINE_LARGE_ADDRESS_AWARE',
        'WINE_PROF_SERVICE',
        'MTL_HUD_ENABLED',
      }.contains(key) ||
      [
        'ROSETTA_',
        'MVK_',
        'DOTNET_',
        'CX_',
        'DXVK_',
        'DXMT_',
        'D3DM_',
        'DYLD_',
        'VK_',
        'GST_',
      ].any(key.startsWith);

  group('MG6 the Mach9 environment', () {
    test('wineEnv is exact and keeps out what the parent has', () {
      final dir = mach9Bottle(home, 'm9');
      const kept = {
        'HOME': '/Users/q',
        'USER': 'q',
        'LOGNAME': 'q',
        'TMPDIR': '/var/folders/x/T/',
        '__CF_USER_TEXT_ENCODING': '0x1F5:0x0:0x8',
      };
      final parent = {
        ...kept,
        'WINE_COMPATDB': 'exe=*;d3d9=wined3d',
        'WINE_COMPATDB_FILE': '/tmp/rules',
        'WINEDLLOVERRIDES': 'd3d9=n',
        'WINE_PROF_SERVICE': '1',
        'WINE_LARGE_ADDRESS_AWARE': '1',
        'DYLD_INSERT_LIBRARIES': '/x.dylib',
        'PATH': '/opt/homebrew/bin',
      };
      expect(wineEnv('$dir/prefix', parent), {
        ...kept,
        'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
        'WINEMSYNC': '1',
        'WINEPREFIX': '$dir/prefix',
        'WINE_COMPATDB': 'exe=*;$menu',
        // ER1: winedevice.exe gets the pad's input from SDL3.
        'SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS': '1',
        'WINEDEBUG': mach9Debug,
      });
      expect(
        wineEnv('$dir/prefix', {
          ...parent,
          'BODEGA_WINEDEBUG': '+loaddll',
        })['WINEDEBUG'],
        '+loaddll',
      );
    });

    test('a launch with DLSS, the HUD and AVX off', () async {
      fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'm9', '{"dlss": true, "sync": "none"}');
      await exitOf(
        await runInBottle(home, 'm9', 'game.exe', [], hud: true, avx: false),
      );
      final seen = lastEnv('m9');
      expect(compatdb('m9'), 'exe=*;metal_hud=true;$menu');
      expect(seen['VKD3D_SHADER_CACHE_PATH'], '$dir/cache/vkd3d');
      expect(Directory('$dir/cache/vkd3d').existsSync(), isTrue);
      expect(seen['WINEMSYNC'], '0');
      expect(seen['WINEDEBUG'], mach9Debug);
      expect(seen.keys.where(forbidden), isEmpty);
    });

    test('the user can still set WINEDLLOVERRIDES themselves', () async {
      fakeMach9Wine(home);
      mach9Bottle(home, 'm9', '{"env": {"WINEDLLOVERRIDES": "x=n"}}');
      await exitOf(await runInBottle(home, 'm9', 'game.exe', []));
      expect(lastEnv('m9')['WINEDLLOVERRIDES'], 'x=n');
    });

    test('an ARM64 program runs on the native engine (AA1)', () async {
      fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'm9', '{}');
      fakePe('$dir/prefix/drive_c/Games/arm.exe', 0xAA64, '');
      final log = await runInBottle(home, 'm9', r'C:\Games\arm.exe', []);
      expect(await exitOf(log), 7);
      expect(File('$dir/prefix/last-env').existsSync(), isTrue);
    });

    test('a launch appends the user rules after its own', () async {
      fakeMach9Wine(home);
      mach9Bottle(
        home,
        'm9',
        '{"env": {"WINE_COMPATDB": "exe=a.exe;d3d9=wined3d"}}',
      );
      final log = await runInBottle(
        home,
        'm9',
        'game.exe',
        [],
        backend: 'dxmt',
        env: {'WINE_COMPATDB': 'exe=b.exe;d3d9=mtld3d'},
      );
      await exitOf(log);
      expect(
        compatdb('m9'),
        'exe=*;dxgi=dxmt;$menu\n'
        'exe=game.exe;dxgi=dxmt\n'
        'exe=b.exe;d3d9=mtld3d',
      );
      // The log's line has Bodega's lines only.
      expect(
        File(log).readAsLinesSync(),
        contains('# rules exe=*;dxgi=dxmt;$menu | exe=game.exe;dxgi=dxmt'),
      );
    });

    test('a Rosetta bottle keeps its environment', () async {
      fakeCurrent(home);
      Directory('$home/bottles/x86/logs').createSync(recursive: true);
      final prefix = '$home/bottles/x86/prefix';
      Directory('$prefix/drive_c/windows/syswow64').createSync(recursive: true);
      File('$prefix/drive_c/windows/syswow64/kernel32.dll').createSync();
      File('$prefix/system.reg').createSync();
      final log = await runInBottle(home, 'x86', 'game.exe', []);
      await exitOf(log);
      final seen = lastEnv('x86');
      expect(seen['WINEDLLOVERRIDES'], 'winemenubuilder.exe=d');
      expect(seen['ROSETTA_ADVERTISE_AVX'], '1');
      expect(seen, isNot(contains('WINE_COMPATDB')));
      expect(seen, isNot(contains('VKD3D_SHADER_CACHE_PATH')));
      expect(File(log).readAsStringSync(), isNot(contains('# rules')));
    });
  });

  group('MG11 the log header', () {
    test('auto, then the rules last', () async {
      fakeMach9Wine(home);
      mach9Bottle(home, 'm9');
      final log = await runInBottle(home, 'm9', 'game.exe', []);
      await exitOf(log);
      final lines = File(log).readAsLinesSync();
      expect(lines[0], '# runtime mach9-0.4.0');
      expect(lines[1], '# backend auto (auto)');
      expect(backendOf(log), 'backend auto (auto)');
      // PE4's line comes before the rules, which stay last (MG11).
      expect(lines[4], '# retina off (auto)');
      expect(lines[5], '# rules exe=*;$menu');
      expect(lines[6], isNot(startsWith('# ')));
    });
  });

  group('ER1 SDL3 pads before the session boots', () {
    String regLog(String dir) => File('$dir/prefix/reg.log').existsSync()
        ? File('$dir/prefix/reg.log').readAsStringSync()
        : '';

    test('missing values are written, then the session ends', () async {
      fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'm9');
      File('$dir/prefix/system.reg').writeAsStringSync('');
      final log = await runInBottle(home, 'm9', 'game.exe', []);
      await exitOf(log);
      for (final (value, data) in [
        ('DisableHidraw', 1),
        ('Enable SDL', 1),
        ('DisableInput', 0),
      ]) {
        expect(
          regLog(dir),
          contains('$value /t REG_DWORD /d $data'),
          reason: value,
        );
      }
      final lines = File('$home/bottles/m9/mach9-calls')
          .readAsStringSync()
          .trim()
          .split('\n');
      final kill = lines.indexOf('wineserver -k');
      expect(kill, greaterThan(0));
      expect(
        lines.indexWhere((l) => l.contains('game.exe')),
        greaterThan(kill),
      );
      expect(File(log).readAsLinesSync(), contains('# pads sdl3'));
      expect(bottleSettings(home, 'm9').gamepads, 3);
    });

    test('values already there cost nothing', () async {
      fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'm9', '{"retina": "off"}');
      await exitOf(await runInBottle(home, 'm9', 'game.exe', []));
      expect(regLog(dir), isNot(contains('WineBus')));
    });

    test('a running session keeps its own until the next', () async {
      fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'm9', '{"retina": "off"}');
      File('$dir/prefix/system.reg').writeAsStringSync('');
      File('$dir/prefix/hang').createSync();
      final log = await runInBottle(home, 'm9', 'game.exe', []);
      File('$dir/prefix/hang').deleteSync();
      await exitOf(log);
      expect(regLog(dir), isNot(contains('WineBus')));
      expect(
        File(log).readAsLinesSync(),
        contains('# pads wait for the next session'),
      );
    });
  });

  group('PE4 retina before the session boots', () {
    String calls(String bottle) =>
        File('$home/bottles/$bottle/mach9-calls').readAsStringSync();
    String regLog(String dir) => File('$dir/prefix/reg.log').existsSync()
        ? File('$dir/prefix/reg.log').readAsStringSync()
        : '';
    String userReg({required bool retina}) =>
        'WINE REGISTRY Version 2\n\n'
        '[Control Panel\\\\Desktop] 1700000000\n'
        '#time=1da0000000000000\n'
        '"LogPixels"=dword:${retina ? '000000c0' : '00000060'}\n\n'
        '[Software\\\\Wine\\\\Mac Driver] 1700000000\n'
        '#time=1da0000000000000\n'
        '"RetinaMode"="${retina ? 'y' : 'n'}"\n';

    test('values that differ are written, then the session ends', () async {
      fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'm9', '{"retina": "on"}');
      final log = await runInBottle(home, 'm9', 'game.exe', []);
      await exitOf(log);
      expect(regLog(dir), contains('RetinaMode /t REG_SZ /d y'));
      expect(regLog(dir), contains('LogPixels /t REG_DWORD /d 192'));
      final lines = calls('m9').trim().split('\n');
      final kill = lines.indexOf('wineserver -k');
      expect(kill, greaterThan(0));
      expect(lines[kill + 1], 'wineserver -w');
      expect(
        lines.indexWhere((l) => l.contains('game.exe')),
        greaterThan(kill),
      );
      expect(File(log).readAsLinesSync(), contains('# retina on (on)'));
    });

    test('values already in user.reg cost nothing', () async {
      fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'm9', '{"retina": "on"}');
      File('$dir/prefix/user.reg').writeAsStringSync(userReg(retina: true));
      await exitOf(await runInBottle(home, 'm9', 'game.exe', []));
      expect(regLog(dir), isEmpty);
      expect(calls('m9'), isNot(contains('wineserver -k')));
    });

    test('auto follows the display: on with a HiDPI main display', () async {
      hostPlatform = const TestMac(hiDpi: true);
      fakeMach9Wine(home);
      mach9Bottle(home, 'm9');
      final log = await runInBottle(home, 'm9', 'game.exe', []);
      await exitOf(log);
      expect(File(log).readAsLinesSync(), contains('# retina on (auto)'));
    });

    test('a running session keeps its own until the next', () async {
      fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'm9', '{"retina": "on"}');
      File('$dir/prefix/hang').createSync();
      final log = await runInBottle(home, 'm9', 'game.exe', []);
      File('$dir/prefix/hang').deleteSync();
      await exitOf(log);
      expect(regLog(dir), isEmpty);
      expect(
        File(log).readAsLinesSync(),
        containsAll([
          '# retina on (on)',
          '# retina waits for the next session',
        ]),
      );
    });

    test('ER7 a Rosetta bottle follows its retina too', () async {
      fakeCurrent(home);
      final dir = '$home/bottles/x86';
      // The user's Fifa22: high resolution on, RetinaMode y in user.reg, on
      // a display mode that isn't HiDPI.
      File('$dir/settings.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"highRes": true}');
      File('$dir/prefix/drive_c/windows/syswow64/kernel32.dll')
          .createSync(recursive: true);
      File('$dir/prefix/system.reg').createSync();
      File('$dir/prefix/user.reg').writeAsStringSync(
        'WINE REGISTRY Version 2\n\n'
        '[Software\\\\Wine\\\\Mac Driver] 1700000000\n'
        '"RetinaMode"="y"\n',
      );
      Directory('$dir/logs').createSync();
      final log = await runInBottle(home, 'x86', 'game.exe', []);
      await exitOf(log);
      expect(File(log).readAsLinesSync(), contains('# retina off (auto)'));
      expect(
        File('$dir/prefix/reg.log').readAsStringSync(),
        contains('RetinaMode /t REG_SZ /d n'),
      );
    });
  });

  group('MG8 and MG13 fixes in a Mach9 bottle', () {
    setUp(() {
      fakeMach9Wine(home);
      final dir = mach9Bottle(
        home,
        'b',
        '{"programs": {"steam.exe": {"backend": "dxmt"}}}',
      );
      final steam = '$dir/prefix/drive_c/Program Files (x86)/Steam';
      File('$steam/steam.exe').createSync(recursive: true);
      File('$steam/steamapps/appmanifest_9.acf')
        ..createSync(recursive: true)
        ..writeAsStringSync('"appid" "9"\n"name" "Game"\n"StateFlags" "4"');
    });

    test('variables are set, overrides become rules', () async {
      fixesSource = fixes([
        env('FIX_VAR', '1'),
        override('gameoverlayrenderer64,gameoverlayrenderer=d'),
      ]);
      await exitOf(await openApp(home, 'b', key: 'steam:9'));
      final seen = lastEnv('b');
      expect(seen['FIX_VAR'], '1');
      expect(seen, isNot(contains('WINEDLLOVERRIDES')));
      expect(
        compatdb('b'),
        'exe=*;dxgi=dxmt;$menu;'
        'dll_overrides=gameoverlayrenderer64,gameoverlayrenderer=d\n'
        // PE8: the Steam game's own line names its app id.
        'exe=steam:9;dxgi=dxmt',
      );
    });

    test(
      'PE6 Rosetta-only variables stay out, and the log names them',
      () async {
        fixesSource = fixes([
          env('D3DM_ENABLE_METALFX', '1'),
          env('DXVK_ASYNC', '1'),
          env('VKD3D_CONFIG', 'dxr'),
        ]);
        final log = await openApp(home, 'b', key: 'steam:9');
        await exitOf(log);
        final seen = lastEnv('b');
        expect(seen['VKD3D_CONFIG'], 'dxr');
        expect(seen.keys, isNot(contains('D3DM_ENABLE_METALFX')));
        expect(seen.keys, isNot(contains('DXVK_ASYNC')));
        expect(
          File(log).readAsLinesSync(),
          contains('# skipped D3DM_ENABLE_METALFX, DXVK_ASYNC'),
        );
        expect((await gamePlan(home, 'b', 'steam:9')).env, {
          'VKD3D_CONFIG': 'dxr',
        });
      },
    );

    test('an open Steam is asked through the Mach9 runtime', () async {
      final prefix = '$home/bottles/b/prefix';
      File('$prefix/hang').createSync();
      File('$prefix/tasks').writeAsStringSync('steam.exe  24 Console 1 0 K\n');
      fixesSource = fixes([env('X', '1')]);
      final log = await openApp(home, 'b', key: 'steam:9');
      await exitOf(log);
      expect(await hintsIn(log), [LogHint.fixNotApplied]);
      expect(
        File('$home/bottles/b/mach9-calls').readAsLinesSync(),
        containsAllInOrder(['wineserver -w', 'wine tasklist']),
      );
    });
  });

  group('MB8 no launch installs Mono', () {
    test('a Mach9 bottle without Mono launches without msiexec', () async {
      fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'm9');
      expect(monoMissing(home, 'm9'), isTrue);
      await exitOf(await runInBottle(home, 'm9', 'game.exe', []));
      expect(File('$dir/prefix/msi-args').existsSync(), isFalse);
      expect(
        File('$dir/mach9-calls').readAsStringSync(),
        isNot(contains('msiexec')),
      );
    });
  });

  group('MG3 choices against the bottle kind', () {
    Matcher notFor(String backend, RuntimeKind kind) => throwsA(
      isA<BackendNotForRuntime>()
          .having((f) => f.backend, 'backend', backend)
          .having((f) => f.runtime, 'runtime', kind),
    );

    test('Rosetta names on Mach9 and mtld3d on Rosetta', () async {
      fakeMach9Wine(home);
      mach9Bottle(home, 'm9');
      for (final name in ['dxvk', 'dxvk9', 'd3dmetal']) {
        expect(
          () => setBackend(home, 'm9', name),
          notFor(name, RuntimeKind.mach9),
        );
        expect(
          () => setBackend(home, 'm9', name, exe: 'g.exe'),
          notFor(name, RuntimeKind.mach9),
        );
        await expectLater(
          runInBottle(home, 'm9', 'g.exe', [], backend: name),
          notFor(name, RuntimeKind.mach9),
        );
        await expectLater(
          backendTest(home, 'm9', name),
          notFor(name, RuntimeKind.mach9),
        );
      }
      Directory('$home/bottles/x86').createSync();
      expect(
        () => setBackend(home, 'x86', 'mtld3d'),
        notFor('mtld3d', RuntimeKind.bodega),
      );
      await expectLater(
        backendTest(home, 'x86', 'mtld3d'),
        notFor('mtld3d', RuntimeKind.bodega),
      );
    });

    test('an unknown name lists the Mach9 names', () async {
      mach9Bottle(home, 'm9');
      final badChoice = throwsA(
        isA<BadChoice>()
            .having((f) => f.kind, 'kind', ChoiceKind.backend)
            .having((f) => f.value, 'value', 'foo')
            .having((f) => f.choices, 'choices', ['wine', 'dxmt', 'mtld3d']),
      );
      expect(() => setBackend(home, 'm9', 'foo'), badChoice);
      await expectLater(
        backendTest(home, 'm9', 'foo'),
        throwsA(
          isA<BadChoice>()
              .having((f) => f.kind, 'kind', ChoiceKind.testBackend)
              .having((f) => f.choices, 'choices', ['wine', 'dxmt', 'mtld3d']),
        ),
      );
    });

    test('a hand-edited dxvk is read, and a launch refuses it', () async {
      fakeMach9Wine(home);
      mach9Bottle(home, 'm9', '{"backend": "dxvk"}');
      expect(bottleSettings(home, 'm9').backend, 'dxvk');
      await expectLater(
        runInBottle(home, 'm9', 'g.exe', []),
        notFor('dxvk', RuntimeKind.mach9),
      );
    });

    test('auto does not scan the exe on Mach9', () async {
      fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'm9');
      // A DX11 exe that would pick dxmt under Rosetta.
      final exe = File('$tmp/game.exe')..writeAsStringSync('MZ d3d11.dll');
      final log = await runInBottle(home, 'm9', exe.path, []);
      await exitOf(log);
      expect(backendOf(log), 'backend auto (auto)');
      expect(Directory(dir).existsSync(), isTrue);
    });

    test('a Mach9 name the runtime lacks is not installed', () async {
      fakeMach9Runtime(home, skip: ['dxgi/dxmt']);
      mach9Bottle(home, 'm9');
      expect(() => setBackend(home, 'm9', 'dxmt'), returnsNormally);
      await expectLater(
        resolveBackend(home, '$home/bottles/m9', 'g.exe', null),
        throwsA(
          isA<BackendNotInstalled>().having((f) => f.backend, 'b', 'dxmt'),
        ),
      );
    });
  });

  group('MG10 probes in a Mach9 bottle', () {
    test('dxmt runs three cases, the probe override as a rule', () async {
      fakeMach9Wine(home);
      mach9Bottle(home, 'm9');
      final results = await backendTest(home, 'm9', 'dxmt');
      expect(
        [for (final r in results) (r.bits, r.d3d)],
        [(32, '11'), (64, '11'), (64, '12')],
      );
      final seen = lastEnv('m9');
      expect(
        compatdb('m9'),
        'exe=*;dxgi=dxmt;$menu;dll_overrides=winedbg.exe=\n'
        'exe=probe-64.exe;dxgi=dxmt',
      );
      expect(seen, isNot(contains('WINEDLLOVERRIDES')));
    });

    test('mtld3d and wine have their cases', () async {
      fakeMach9Wine(home);
      mach9Bottle(home, 'm9');
      final mtld3d = await backendTest(home, 'm9', 'mtld3d');
      expect([for (final r in mtld3d) (r.bits, r.d3d)], [(32, '9'), (64, '9')]);
      final wine = await backendTest(home, 'm9', 'wine');
      expect(
        [for (final r in wine) (r.bits, r.d3d)],
        [(32, '9'), (64, '9'), (64, '11')],
      );
    });
  });

  installTests(() => (tmp: tmp, home: home));
}

/// The fake Mach9.app of `runtimes.md` with its wine tree under
/// `Contents/Resources/wine`: design §2.1's files, `bin/wine` a relative link
/// into `wine.app` whose loader prints `wine-11.21-test`.
String fakeMach9Tree(
  String root, {
  String id = 'app.mach9',
  String version = '0.4.0',
  List<String> skip = const [],
}) {
  final app = fakeMach9App(root, id: id, version: version);
  final wine = '$app/Contents/Resources/wine';
  const dirs = [
    'lib/wine/dxgi/dxmt',
    'lib/wine/dxgi/wined3d',
    'lib/wine/d3d9/mtld3d',
    'lib/wine/d3d9/wined3d',
  ];
  const files = [
    'lib/wine/aarch64-unix/ntdll.so',
    'lib/wine/aarch64-unix/compatdb.so',
    'lib/wine/aarch64-windows/kernel32.dll',
    'lib/wine/i386-windows/kernel32.dll',
    'lib/external/libfreetype.6.dylib',
    'lib/external/libgnutls.30.dylib',
  ];
  for (final dir in dirs.where((d) => !skip.contains(d))) {
    Directory('$wine/$dir').createSync(recursive: true);
  }
  for (final file in files.where((f) => !skip.contains(f))) {
    File('$wine/$file').createSync(recursive: true);
  }
  // MU3: the Wine Mono this Mach9 asks for, named in UTF-16 as Wine has it.
  if (!skip.contains('appwiz.cpl')) {
    File('$wine/lib/wine/aarch64-windows/appwiz.cpl')
      ..createSync(recursive: true)
      ..writeAsBytesSync([
        for (final unit
            in 'x\u0000wine-mono-11.3.0-x86.msi\u0000'.codeUnits) ...[
          unit & 0xff,
          unit >> 8,
        ],
      ]);
  }
  final loader = File(
    '$wine/lib/wine/aarch64-unix/wine.app/Contents/MacOS/wine',
  )..createSync(recursive: true);
  loader.writeAsStringSync('#!/bin/sh\necho wine-11.21-test\n');
  final server = File('$wine/bin/wineserver')
    ..createSync(recursive: true)
    ..writeAsStringSync('#!/bin/sh\nexit 0\n');
  Process.runSync('/bin/chmod', ['+x', loader.path, server.path]);
  Link('$wine/bin/wine')
      .createSync('../lib/wine/aarch64-unix/wine.app/Contents/MacOS/wine');
  return app;
}

/// A GitHub API folder for [githubApi] (MU2, MU3): Mach9's latest release
/// [version] with [dmg] as its `Mach9.dmg` and, with [macos], an appcast
/// asking for it; and the Wine Mono release whose MSI is [msi].
Future<String> fakeGithub(
  String root, {
  String version = '0.4.0',
  required String dmg,
  required String msi,
  String? macos,
  String? digest,
}) async {
  final api = '$root/api';
  Map<String, Object> asset(String name, String path, String hash) => {
    'name': name,
    'size': File(path).lengthSync(),
    'digest': 'sha256:$hash',
    'browser_download_url': Uri.file(path).toString(),
  };
  final assets = [asset('Mach9.dmg', dmg, digest ?? await sha256Of(dmg))];
  if (macos != null) {
    final appcast = File('$root/appcast.xml')
      ..writeAsStringSync(
        '<rss><channel><item><title>$version</title>'
        '<sparkle:version>$version</sparkle:version>'
        '<sparkle:minimumSystemVersion>$macos</sparkle:minimumSystemVersion>'
        '</item></channel></rss>',
      );
    assets.add(
      asset('appcast.xml', appcast.path, await sha256Of(appcast.path)),
    );
  }
  File('$api/repos/athei/mach9/releases/latest')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode({'tag_name': 'v$version', 'assets': assets}),
    );
  File('$api/repos/madewokherd/wine-mono/releases/tags/wine-mono-11.3.0')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode({
        'tag_name': 'wine-mono-11.3.0',
        'assets': [asset('wine-mono-11.3.0-x86.msi', msi, await sha256Of(msi))],
      }),
    );
  return Uri.directory(api).toString().replaceFirst(RegExp(r'/$'), '');
}

/// The test Mac without a network: curl always fails (MB10, I5).
class _OfflineMac extends TestMac {
  const _OfflineMac();

  // `override` here is fixes_test's helper.
  @core.override
  String tool(String name) =>
      name == 'curl' ? '/usr/bin/false' : super.tool(name);
}

/// The test Mac whose Mach9.app changes while it is copied: its deep
/// signature check fails on an app with the changed file.
class _TamperMac extends TestMac {
  const _TamperMac();

  static const _dll =
      'Contents/Resources/wine/lib/wine/aarch64-windows/'
      'kernel32.dll';

  @core.override
  Future<void> copyTree(String from, String to) async {
    if (File('$from/$_dll').existsSync()) {
      File('$from/$_dll').writeAsStringSync('changed');
    }
    await super.copyTree(from, to);
  }

  @core.override
  Future<String> signingTeam(String path, {bool deep = false}) async {
    final dll = File('$path/$_dll');
    if (deep && dll.existsSync() && dll.readAsStringSync() == 'changed') {
      throw RuntimeNotTrusted(path, 'a sealed resource changed');
    }
    return super.signingTeam(path, deep: deep);
  }
}

/// E5–E7: installing Mach9, Mach9 bottles, Mono, the catalog and the CLI.
void installTests(({String tmp, String home}) Function() paths) {
  final api = githubApi;
  final probe = mach9Probe;
  late String tmp, home, msi;
  setUp(() async {
    (:tmp, :home) = paths();
    // A fake MSI the fake wine sources: it makes Mono's folder.
    msi = '$tmp/mono.msi';
    File(msi).writeAsStringSync(
      r'mkdir -p "$WINEPREFIX/drive_c/windows/mono/mono-2.0"'
      '\n',
    );
    // MU2, MU3: GitHub is a folder, and the new version's probe passes.
    githubApi = await fakeGithub(tmp, dmg: msi, msi: msi);
    mach9Probe = (_) async => null;
  });
  tearDown(() {
    githubApi = api;
    mach9Probe = probe;
  });

  /// `runtime.json` without the time of its check.
  Map<String, Object?> runtimeJson(String dir) =>
      (jsonDecode(File('$dir/runtime.json').readAsStringSync()) as Map)
          .cast<String, Object?>()
        ..remove('checkedAt');

  /// The entries of `runtimes/`, links with what they point at, without the
  /// install lock, which stays, and the latest release's cache (MU2).
  Map<String, String> runtimesNow() => {
    for (final e in Directory('$home/runtimes').listSync(followLinks: false))
      if (!const [
        '.mach9.lock',
        '.mach9-latest.json',
      ].contains(e.path.split('/').last))
        e.path.split('/').last: e is Link ? e.targetSync() : 'dir',
  };

  Future<String> install({
    String? source,
    String? sha256,
    List<Mach9Step>? steps,
    bool Function()? cancelled,
    bool deleteSource = false,
  }) => installMach9(
    home,
    source: source,
    sha256: sha256,
    mono: msi,
    deleteSource: deleteSource,
    onStep: steps?.add,
    cancelled: cancelled,
  );

  group('MU2 and MU3 the latest release and its Wine Mono', () {
    test('the version, the digest, and the macOS its appcast asks', () async {
      final dmg = File('$tmp/Mach9.dmg')..writeAsStringSync('dmg');
      githubApi = await fakeGithub(
        tmp,
        version: '0.5.0',
        dmg: dmg.path,
        msi: msi,
        macos: '26.5',
      );
      final latest = await mach9Latest(home);
      expect(latest.version, '0.5.0');
      expect(latest.sha256, await sha256Of(dmg.path));
      expect(latest.bytes, 3);
      expect(latest.url, Uri.file(dmg.path).toString());
      expect(latest.minimumMacos, '26.5');
      expect(cachedMach9Latest(home), latest);
      // A young cache answers without asking.
      githubApi = 'file://$tmp/nowhere';
      expect(
        await mach9Latest(home, maxAge: const Duration(hours: 24)),
        latest,
      );
      await expectLater(mach9Latest(home), throwsA(isA<ProcessFailed>()));
    });

    test('a release Bodega cannot use is NoMach9Release', () async {
      final dmg = File('$tmp/Mach9.dmg')..writeAsStringSync('dmg');
      githubApi = await fakeGithub(tmp, dmg: dmg.path, msi: msi, digest: 'x');
      await expectLater(mach9Latest(home), throwsA(isA<NoMach9Release>()));
      githubApi = await fakeGithub(
        tmp,
        version: '0.3.1',
        dmg: dmg.path,
        msi: msi,
      );
      await expectLater(mach9Latest(home), throwsA(isA<NoMach9Release>()));
    });

    test("the Wine Mono a Mach9 names, and its release's digest", () async {
      final app = fakeMach9Tree(tmp);
      expect(monoVersionOf('$app/Contents/Resources/wine'), '11.3.0');
      expect(monoVersionOf('$tmp/nothing'), isNull);
      final release = await monoRelease('11.3.0');
      expect(release.file, 'wine-mono-11.3.0-x86.msi');
      expect(release.sha256, await sha256Of(msi));
    });

    test('runtime check mach9 says what is out', () async {
      fakeMach9Runtime(home);
      final dmg = File('$tmp/Mach9.dmg')..writeAsStringSync('dmg');
      githubApi = await fakeGithub(
        tmp,
        version: '0.5.0',
        dmg: dmg.path,
        msi: msi,
      );
      final out = StringBuffer();
      expect(await runtimeVerb(['runtime', 'check', 'mach9'], out)!(home), 0);
      expect('$out', 'installed 0.4.0\nlatest 0.5.0\nupdate available\n');
      expect(listRuntimes(home).last.latest, '0.5.0');
    });
  });

  group('MR4–MR9 installMach9', () {
    test('from the Mach9.app it finds, current untouched', () async {
      fakeCurrent(home);
      hostPlatform = TestMac(applications: '$tmp/Applications');
      fakeMach9Tree('$tmp/Applications');
      final steps = <Mach9Step>[];
      final dir = await install(steps: steps);
      expect(dir, '$home/runtimes/mach9-0.4.0');
      expect(steps, [
        Mach9Step.copying,
        Mach9Step.checkingSignature,
        Mach9Step.checking,
        Mach9Step.switching,
        Mach9Step.probing,
      ]);
      expect(runtimeJson(dir), {
        'kind': 'mach9',
        'version': '0.4.0',
        'source': 'app',
        'checked': true,
        'mono': 'wine-mono-11.3.0-x86.msi',
      });
      expect(FileSystemEntity.isLinkSync('$dir/engine/bin/wine'), isTrue);
      expect(
        File('$dir/wine-mono-11.3.0-x86.msi').readAsStringSync(),
        File(msi).readAsStringSync(),
      );
      expect(runtimesNow(), {
        'current': 'engine-test',
        'engine-test': 'dir',
        'mach9': 'mach9-0.4.0',
        'mach9-0.4.0': 'dir',
      });
      expect(runtimeDir(home, RuntimeKind.mach9), dir);
      expect(listRuntimes(home).last.checked, isTrue);
    });

    test('a Mach9.app is never deleted, whatever deleteSource says', () async {
      final app = fakeMach9Tree(tmp);
      await install(source: app, deleteSource: true);
      expect(Directory(app).existsSync(), isTrue);
    });

    test('MU3 an MSI unlike its release stops before the switch', () async {
      File(msi).writeAsStringSync('changed');
      final app = fakeMach9Tree(tmp);
      final steps = <Mach9Step>[];
      await expectLater(
        install(source: app, steps: steps),
        throwsA(isA<ChecksumMismatch>()),
      );
      expect(steps, isNot(contains(Mach9Step.switching)));
      expect(runtimesNow(), isEmpty);
    });

    test('a downloaded source must match its digest', () async {
      final app = fakeMach9Tree(tmp);
      final dmg = File('$tmp/Mach9.dmg')..writeAsStringSync('not it');
      await expectLater(
        install(source: dmg.path, sha256: '0' * 64),
        throwsA(isA<ChecksumMismatch>()),
      );
      expect(Directory(app).existsSync(), isTrue);
      expect(runtimesNow(), isEmpty);
    });

    test('another team or bundle id is not trusted', () async {
      hostPlatform = const TestMac(team: 'XXXXXXXXXX');
      await expectLater(
        install(source: fakeMach9Tree('$tmp/a')),
        throwsA(isA<RuntimeNotTrusted>()),
      );
      hostPlatform = const TestMac(team: null);
      await expectLater(
        install(source: fakeMach9Tree('$tmp/b')),
        throwsA(isA<RuntimeNotTrusted>()),
      );
      hostPlatform = const TestMac();
      await expectLater(
        install(source: fakeMach9Tree('$tmp/c', id: 'com.other')),
        throwsA(isA<RuntimeNotTrusted>()),
      );
      expect(runtimesNow(), isEmpty);
    });

    test('0.3.1 is too old; 0.5.0 installs, checked by the probe', () async {
      await expectLater(
        install(source: fakeMach9Tree('$tmp/old', version: '0.3.1')),
        throwsA(
          isA<RuntimeTooOld>()
              .having((f) => f.version, 'version', '0.3.1')
              .having((f) => f.minimum, 'minimum', '0.4.0'),
        ),
      );
      final dir = await install(
        source: fakeMach9Tree('$tmp/new', version: '0.5.0'),
      );
      expect(dir, endsWith('/mach9-0.5.0'));
      expect(runtimeJson(dir), {
        'kind': 'mach9',
        'version': '0.5.0',
        'source': 'app',
        'checked': true,
        'mono': 'wine-mono-11.3.0-x86.msi',
      });
      expect(
        describeRuntime(listRuntimes(home).last),
        'mach9: installed 0.5.0 (mach9-0.5.0)',
      );
    });

    test('MU4 a failed probe puts the previous version back', () async {
      await install(source: fakeMach9Tree('$tmp/a'));
      mach9Probe = (_) async => '64-bit D3D9: no window';
      await expectLater(
        install(source: fakeMach9Tree('$tmp/b', version: '0.5.0')),
        throwsA(
          isA<Mach9CheckFailed>()
              .having((f) => f.version, 'version', '0.5.0')
              .having((f) => f.log, 'log', '64-bit D3D9: no window'),
        ),
      );
      expect(runtimesNow(), {'mach9': 'mach9-0.4.0', 'mach9-0.4.0': 'dir'});
      expect(listRuntimes(home).last.checked, isTrue);
    });

    test(
      'MU4 with nothing before, a failed probe leaves it unchecked',
      () async {
        mach9Probe = (_) async => 'no case ran';
        await expectLater(
          install(source: fakeMach9Tree(tmp)),
          throwsA(isA<Mach9CheckFailed>()),
        );
        expect(runtimesNow(), {'mach9': 'mach9-0.4.0', 'mach9-0.4.0': 'dir'});
        expect(listRuntimes(home).last.checked, isFalse);
      },
    );

    test('a missing file leaves nothing behind', () async {
      await expectLater(
        install(source: fakeMach9Tree(tmp, skip: ['lib/wine/d3d9/mtld3d'])),
        throwsA(
          isA<IncompleteArchive>().having(
            (f) => f.missing,
            'missing',
            'lib/wine/d3d9/mtld3d',
          ),
        ),
      );
      expect(runtimesNow(), isEmpty);
    });

    test('the same version again is AlreadyInstalled', () async {
      final app = fakeMach9Tree(tmp);
      await install(source: app);
      await expectLater(install(source: app), throwsA(isA<AlreadyInstalled>()));
      expect(runtimesNow().keys, unorderedEquals(['mach9', 'mach9-0.4.0']));
    });

    test('a newer version switches the link and removes the old', () async {
      await install(source: fakeMach9Tree('$tmp/a'));
      await install(source: fakeMach9Tree('$tmp/b', version: '0.5.0'));
      expect(runtimesNow(), {'mach9': 'mach9-0.5.0', 'mach9-0.5.0': 'dir'});
    });

    test('the source is checked as copied, not before', () async {
      // The signature that MR5 checks covers every file of the app: the
      // copy's, so a change made to the source during the copy is seen.
      hostPlatform = const _TamperMac();
      await expectLater(
        install(source: fakeMach9Tree(tmp)),
        throwsA(isA<RuntimeNotTrusted>()),
      );
      expect(runtimesNow(), isEmpty);
    });

    test('a folder no link names is not installed: it is replaced', () async {
      final app = fakeMach9Tree(tmp);
      await install(source: app);
      // Killed after the rename, before the link; then during a copy.
      Link('$home/runtimes/mach9').deleteSync();
      Directory('$home/runtimes/.tmp-mach9-0.4.0/engine')
          .createSync(recursive: true);
      expect(
        () => runtimeDir(home, RuntimeKind.mach9),
        throwsA(isA<RuntimeNotInstalled>()),
      );
      await install(source: app);
      expect(runtimesNow(), {'mach9': 'mach9-0.4.0', 'mach9-0.4.0': 'dir'});
    });

    test(
      'two installs at once: one installs, one is AlreadyInstalled',
      () async {
        final app = fakeMach9Tree(tmp);
        final results = await Future.wait([
          for (var i = 0; i < 2; i++)
            install(source: app)
                .then<Object>((dir) => dir, onError: (Object e) => e),
        ]);
        expect(
          results,
          unorderedEquals([
            '$home/runtimes/mach9-0.4.0',
            isA<AlreadyInstalled>(),
          ]),
        );
        expect(runtimesNow(), {'mach9': 'mach9-0.4.0', 'mach9-0.4.0': 'dir'});
      },
    );

    test('an old version a bottle opened during the switch stays', () async {
      final rt = fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'm9');
      // Running from the third `-w` on: the check after the switch.
      File('$rt/engine/bin/wineserver').writeAsStringSync(
        '#!/bin/sh\n'
        r'c="$WINEPREFIX/../count"; n=$(($(cat "$c" 2>/dev/null || echo 0) + 1))'
        '\n'
        r'echo $n >"$c"'
        '\n'
        r'[ "$1" = -w ] && [ $n -eq 3 ] && touch "$WINEPREFIX/hang"'
        '\n'
        r'[ "$1" = -w ] && while [ -e "$WINEPREFIX/hang" ]; do sleep 0.1; done'
        '\nexit 0\n',
      );
      try {
        await install(source: fakeMach9Tree('$tmp/b', version: '0.5.0'));
      } finally {
        File('$dir/prefix/hang').deleteSync();
      }
      expect(runtimesNow(), {
        'mach9': 'mach9-0.5.0',
        'mach9-0.4.0': 'dir',
        'mach9-0.5.0': 'dir',
      });
      // Closed: the next install removes it.
      await install(source: fakeMach9Tree('$tmp/c', version: '0.6.0'));
      expect(runtimesNow(), {'mach9': 'mach9-0.6.0', 'mach9-0.6.0': 'dir'});
    });

    test('an open Mach9 bottle stops it before the copy', () async {
      fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'm9');
      File('$dir/prefix/hang').createSync();
      final steps = <Mach9Step>[];
      try {
        await expectLater(
          install(
            source: fakeMach9Tree(tmp, version: '0.5.0'),
            steps: steps,
          ),
          throwsA(isA<BottleOpen>().having((f) => f.bottle, 'bottle', 'm9')),
        );
      } finally {
        File('$dir/prefix/hang').deleteSync();
      }
      expect(steps, isNot(contains(Mach9Step.copying)));
      expect(runtimesNow(), {'mach9': 'mach9-0.4.0', 'mach9-0.4.0': 'dir'});
    });

    test('cancelled after copying leaves runtimes as it was', () async {
      fakeCurrent(home);
      final before = runtimesNow();
      final steps = <Mach9Step>[];
      await expectLater(
        install(
          source: fakeMach9Tree(tmp),
          steps: steps,
          cancelled: () => steps.contains(Mach9Step.copying),
        ),
        throwsA(isA<Cancelled>()),
      );
      expect(runtimesNow(), before);
    });

    test('a blocked host cannot install', () async {
      hostPlatform = const TestMac(mach9Block: RuntimeBlock.macosTooOld);
      await expectLater(
        install(source: fakeMach9Tree(tmp)),
        throwsA(
          isA<RuntimeUnavailable>().having(
            (f) => f.reason,
            'reason',
            RuntimeBlock.macosTooOld,
          ),
        ),
      );
    });

    Future<String> makeDmg() async {
      fakeMach9Tree('$tmp/volume');
      final dmg = '$tmp/Mach9.dmg';
      final made = await Process.run('/usr/bin/hdiutil', [
        'create',
        '-quiet',
        '-srcfolder',
        '$tmp/volume',
        '-format',
        'UDZO',
        dmg,
      ]);
      expect(made.exitCode, 0, reason: '${made.stderr}');
      return dmg;
    }

    test('from a dmg, with no mount left, the dmg kept', () async {
      final dmg = await makeDmg();
      final steps = <Mach9Step>[];
      final dir = await install(source: dmg, steps: steps);
      expect(steps.first, Mach9Step.mounting);
      expect(
        jsonDecode(File('$dir/runtime.json').readAsStringSync())['source'],
        'dmg',
      );
      final info = await Process.run('/usr/bin/hdiutil', ['info']);
      expect('${info.stdout}', isNot(contains(dmg)));
      expect(File(dmg).existsSync(), isTrue);
    }, skip: Platform.isMacOS ? false : 'needs hdiutil');

    test('once installed, deleteSource deletes the dmg, and older tries\' '
        'installers in downloads go', () async {
      final dmg = await makeDmg();
      for (final name in [
        'Mach9-0.3.9.dmg',
        'Mach9.dmg',
        'wine-mono-11.2.0-x86.msi.part',
        'dxmt.tar.gz',
      ]) {
        File('$home/downloads/$name')
          ..createSync(recursive: true)
          ..writeAsStringSync('left');
      }
      await install(source: dmg, deleteSource: true);
      expect(File(dmg).existsSync(), isFalse);
      expect(
        Directory('$home/downloads')
            .listSync()
            .map((e) => e.path.split('/').last),
        ['dxmt.tar.gz'],
      );
    }, skip: Platform.isMacOS ? false : 'needs hdiutil');

    test(
      'the real Mach9.app (BODEGA_TEST_MACH9)',
      () async {
        hostPlatform = HostPlatform.detect();
        final app = Platform.environment['BODEGA_TEST_MACH9']!;
        final dir = await install(source: app);
        final wineApp = '$dir/engine/lib/wine/aarch64-unix/wine.app';
        final verify = await Process.run('/usr/bin/codesign', [
          '--verify',
          '--strict',
          wineApp,
        ]);
        expect(verify.exitCode, 0, reason: '${verify.stderr}');
        expect(FileSystemEntity.isLinkSync('$dir/engine/bin/wine'), isTrue);
        final version = await Process.run('$dir/engine/bin/wine', [
          '--version',
        ]);
        expect('${version.stdout}', startsWith('wine-11.21'));
      },
      skip: Platform.environment['BODEGA_TEST_MACH9'] == null
          ? 'set BODEGA_TEST_MACH9 to a Mach9.app'
          : false,
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });

  /// [fakeMach9Wine] with the fake MSI in the runtime, and a wineboot that
  /// keeps the settings.json it saw.
  String mach9Runtime() {
    final rt = fakeMach9Wine(home);
    File(msi).copySync('$rt/wine-mono-11.3.0-x86.msi');
    final wine = File('$rt/engine/bin/wine');
    wine.writeAsStringSync(
      wine.readAsStringSync().replaceFirst(
        '#!/bin/sh\n',
        '#!/bin/sh\n'
            r'[ "$1" = wineboot ] && cp "${WINEPREFIX%/prefix}/settings.json" '
            r'"${WINEPREFIX%/prefix}/settings-at-boot"'
            '\n',
      ),
    );
    return rt;
  }

  group('MB5–MB7 a Mach9 bottle', () {
    test('settings first, registry values, then Mono', () async {
      final rt = mach9Runtime();
      final steps = <BottleStep>[];
      await createBottle(
        home,
        'm9',
        runtime: RuntimeKind.mach9,
        onStep: steps.add,
      );
      final dir = '$home/bottles/m9';
      expect(steps, [BottleStep.prefix, BottleStep.mono]);
      expect(
        jsonDecode(File('$dir/settings-at-boot').readAsStringSync())['runtime'],
        'mach9',
      );
      expect(bottleRuntime(home, 'm9'), RuntimeKind.mach9);
      final reg = File('$dir/prefix/reg.log').readAsStringSync();
      expect(reg, contains(r'HKCU\Software\Wine\WineDbg /v ShowCrashDialog'));
      expect(reg, contains('/t REG_DWORD /d 0 /f'));
      expect(reg, contains(r'HKCU\Software\Wine\X11 Driver /v EmulateModeset'));
      expect(reg, contains('/t REG_SZ /d Y /f'));
      expect(reg, isNot(contains('WineBus')));
      expect(
        File('$dir/prefix/msi-args').readAsStringSync().trim(),
        'msiexec /i $rt/wine-mono-11.3.0-x86.msi /qn',
      );
      expect(monoMissing(home, 'm9'), isFalse);
      expect(File('$dir/mach9-calls').readAsStringSync(), contains('reg add'));
      // PE5: the session the registry values booted ends before Mono, and
      // Mono's own ends last.
      final calls = File('$dir/mach9-calls').readAsLinesSync();
      final lastReg = calls.lastIndexWhere((c) => c.startsWith('wine reg'));
      final msi = calls.indexWhere((c) => c.startsWith('wine msiexec'));
      expect(calls.sublist(lastReg, msi), contains('wineserver -w'));
      expect(calls.last, 'wineserver -w');
    });

    test('MB3 wineboot and Mono run on Mach9, never current', () async {
      // current's tools leave a mark wherever they run, even before the
      // prefix exists (where the calls log cannot be written yet).
      final current = fakeCurrent(home);
      for (final tool in ['wine', 'wineserver']) {
        File(
          '$current/engine/bin/$tool',
        ).writeAsStringSync('#!/bin/sh\ntouch "$home/current-ran"\nexit 1\n');
      }
      mach9Runtime();
      await createBottle(home, 'm9', runtime: RuntimeKind.mach9);
      // Only the Mach9 fake's wineboot keeps this copy.
      expect(File('$home/bottles/m9/settings-at-boot').existsSync(), isTrue);
      expect(
        File('$home/bottles/m9/mach9-calls').readAsLinesSync(),
        contains(startsWith('wine msiexec')),
      );
      expect(File('$home/current-ran').existsSync(), isFalse);
    });

    test('mono: false reports only the prefix', () async {
      mach9Runtime();
      final steps = <BottleStep>[];
      await createBottle(
        home,
        'm9',
        runtime: RuntimeKind.mach9,
        mono: false,
        onStep: steps.add,
      );
      expect(steps, [BottleStep.prefix]);
      expect(File('$home/bottles/m9/prefix/msi-args').existsSync(), isFalse);
      expect(monoMissing(home, 'm9'), isTrue);
    });

    test('no Mach9 runtime is RuntimeNotInstalled', () async {
      await expectLater(
        createBottle(home, 'm9', runtime: RuntimeKind.mach9),
        throwsA(isA<RuntimeNotInstalled>()),
      );
      expect(Directory('$home/bottles/m9').existsSync(), isFalse);
    });

    test('Mono failing stops the bottle and keeps it', () async {
      final rt = mach9Runtime();
      File('$rt/wine-mono-11.3.0-x86.msi').writeAsStringSync('exit 3\n');
      mach9Bottle(home, 'm9');
      await expectLater(
        installMono(home, 'm9'),
        throwsA(
          isA<WineToolFailed>()
              .having((f) => f.tool, 'tool', WineTool.mono)
              .having((f) => f.exitCode, 'code', 3),
        ),
      );
      expect(
        File('$home/bottles/m9/prefix/server.log').readAsStringSync(),
        contains('k'),
      );
      expect(Directory('$home/bottles/m9').existsSync(), isTrue);
    });

    test('Mono exiting well without its folder is InstallerNoExe', () async {
      final rt = mach9Runtime();
      File('$rt/wine-mono-11.3.0-x86.msi').writeAsStringSync('exit 0\n');
      mach9Bottle(home, 'm9');
      await expectLater(
        installMono(home, 'm9'),
        throwsA(isA<InstallerNoExe>()),
      );
    });

    test('null for a bodega bottle or when Mono is there', () async {
      mach9Runtime();
      final dir = mach9Bottle(home, 'm9');
      Directory('$dir/prefix/drive_c/windows/mono/mono-2.0')
          .createSync(recursive: true);
      expect(await installMono(home, 'm9'), isNull);
      Directory('$home/bottles/x86').createSync();
      expect(await installMono(home, 'x86'), isNull);
      expect(File('$dir/prefix/msi-args').existsSync(), isFalse);
    });

    test('MB10 creation and a launch need no network', () async {
      hostPlatform = const _OfflineMac();
      mach9Runtime();
      await createBottle(home, 'm9', runtime: RuntimeKind.mach9);
      await exitOf(await runInBottle(home, 'm9', 'game.exe', []));
      expect(monoMissing(home, 'm9'), isFalse);
    });
  });

  group('PE12 moving a bottle to Native', () {
    /// A Rosetta bottle as the app leaves one, with what a user's programs
    /// write in it.
    String rosetta(String name) {
      fakeCurrent(home);
      final dir = '$home/bottles/$name';
      final c = '$dir/prefix/drive_c';
      File('$c/windows/syswow64/kernel32.dll').createSync(recursive: true);
      File('$c/windows/system32/old.dll').createSync(recursive: true);
      File('$dir/prefix/system.reg').createSync();
      Directory('$dir/logs').createSync();
      File('$c/Program Files (x86)/Steam/steamapps/common/G/g.exe')
          .createSync(recursive: true);
      File('$c/Program Files (x86)/Steam/steam.exe').createSync();
      File('$c/users/$hostUser/AppData/Roaming/Game/save.dat')
        ..createSync(recursive: true)
        ..writeAsStringSync('level 9');
      File('$c/Games/x.exe').createSync(recursive: true);
      File('$dir/settings.json').writeAsStringSync(
        jsonEncode({
          'backend': 'auto',
          'sync': 'none',
          'programs': {
            'g.exe': {'backend': 'dxvk'},
            'steam.exe': {'backend': 'dxmt', 'hud': true},
          },
          'highRes': true,
          'avx': false,
          'verdicts': {'program files (x86)/steam/steam.exe': 'works'},
        }),
      );
      addApp(home, name, 'Steam', 'Program Files (x86)/Steam/steam.exe');
      return dir;
    }

    List<String> bottles() => [
      for (final entry in Directory('$home/bottles').listSync())
        entry.path.split('/').last,
    ];

    test('the bottle keeps its name on Mach9, with its files and '
        'settings, and the old one is gone', () async {
      mach9Runtime();
      final dir = rosetta('Games');
      final steps = <NativeMoveStep>[];
      final again = await moveToNative(home, 'Games', onStep: steps.add);
      expect(steps, NativeMoveStep.values);
      expect(bottleRuntime(home, 'Games'), RuntimeKind.mach9);
      final c = '$dir/prefix/drive_c';
      expect(
        File('$c/Program Files (x86)/Steam/steamapps/common/G/g.exe')
            .existsSync(),
        isTrue,
      );
      expect(
        File('$c/users/$hostUser/AppData/Roaming/Game/save.dat')
            .readAsStringSync(),
        'level 9',
      );
      expect(File('$c/Games/x.exe').existsSync(), isTrue);
      // Its Windows is the old one's, which never moves (P17).
      expect(File('$c/windows/system32/old.dll').existsSync(), isFalse);
      expect(
        bottleApps(home, 'Games').map((app) => app.title),
        contains('Steam'),
      );
      final settings = bottleSettings(home, 'Games');
      expect(settings.sync, 'msync');
      expect(settings.programs['steam.exe']?.backend, 'dxmt');
      expect(settings.programs['steam.exe']?.hud, isTrue);
      expect(settings.programs['g.exe']?.backend, isNull);
      // ER7: the old highRes reads auto on the Mac, and the move keeps it.
      expect(settings.retina, 'auto');
      expect(settings.avx, isTrue);
      expect(settings.verdicts, {
        'program files (x86)/steam/steam.exe': 'works',
      });
      expect(monoMissing(home, 'Games'), isFalse);
      expect(bottles(), ['Games']);
      expect(again, isEmpty);
    });

    test('a link of the new prefix is never written through', () async {
      final rt = mach9Runtime();
      final outside = Directory('$tmp/mac-documents')..createSync();
      final wine = File('$rt/engine/bin/wine');
      wine.writeAsStringSync(
        wine.readAsStringSync().replaceFirst(
          '#!/bin/sh\n',
          '#!/bin/sh\n'
              '[ "\$1" = wineboot ] && '
              'mkdir -p "\$WINEPREFIX/drive_c/users/$hostUser" && '
              'ln -sfn "${outside.path}" '
              '"\$WINEPREFIX/drive_c/users/$hostUser/Documents"\n',
        ),
      );
      final dir = rosetta('Games');
      File('$dir/prefix/drive_c/users/$hostUser/Documents/notes.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync('old');
      await moveToNative(home, 'Games');
      expect(outside.listSync(), isEmpty);
      expect(
        FileSystemEntity.isLinkSync(
          '$dir/prefix/drive_c/users/$hostUser/Documents',
        ),
        isTrue,
      );
    });

    test('a failed copy leaves the old bottle as it was', () async {
      mach9Runtime();
      final dir = rosetta('Games');
      final before = File('$dir/settings.json').readAsStringSync();
      hostPlatform = const _NoCopyMac();
      await expectLater(
        moveToNative(home, 'Games'),
        throwsA(isA<ProcessFailed>()),
      );
      expect(bottleRuntime(home, 'Games'), RuntimeKind.bodega);
      expect(File('$dir/settings.json').readAsStringSync(), before);
      expect(bottles(), ['Games']);
    });

    test('a Native bottle, or no Mach9 runtime, is refused', () async {
      rosetta('Games');
      await expectLater(
        moveToNative(home, 'Games'),
        throwsA(isA<RuntimeNotInstalled>()),
      );
      mach9Runtime();
      mach9Bottle(home, 'm9');
      await expectLater(moveToNative(home, 'm9'), throwsA(isA<BadChoice>()));
      expect(bottles()..sort(), ['Games', 'm9']);
    });

    test('native-move prints its steps', () async {
      mach9Runtime();
      rosetta('Games');
      final out = StringBuffer();
      expect(await runtimeVerb(['native-move', 'Games'], out)!(home), 0);
      expect(
        '$out',
        'Making the Native engine bottle\n'
            'Copying programs, files and settings\n'
            'Deleting the Rosetta bottle\n'
            'Games runs on the Native engine now\n',
      );
    });
  });

  group('MB9 the catalog on Mach9', () {
    CatalogEntry entry(String backend) {
      final setup = File('$tmp/x-setup.exe')
        ..writeAsStringSync(
          r'mkdir -p "$WINEPREFIX/drive_c/Prog"; '
          r'touch "$WINEPREFIX/drive_c/Prog/x.exe"',
        );
      return CatalogEntry.fromJson({
        'id': 'x',
        'title': 'Program X',
        'status': 'reported',
        'statusNote': 'reason',
        'installer': {
          'url': 'file://${setup.path}',
          'sha256': null,
          'args': ['/S'],
          'msi': false,
        },
        'exe': 'Prog/x.exe',
        'args': <String>[],
        'backend': backend,
        'sync': 'none',
        'env': <String, String>{},
        'registry': <Map<String, String>>[],
        'notes': <String>[],
        'knownIssues': <Map<String, String>>[],
        'source': {'repo': 'test'},
      });
    }

    test('into an existing Mach9 bottle, dxmt is no exception', () async {
      mach9Runtime();
      mach9Bottle(home, 'm9');
      final dir = await installEntry(
        home,
        entry('dxmt'),
        bottle: 'm9',
        intoExisting: true,
        setup: '$tmp/x-setup.exe',
        grace: Duration.zero,
      );
      final settings = bottleSettings(home, 'm9');
      expect(settings.programs['x.exe']?.backend, isNull);
      expect(settings.runtime, RuntimeKind.mach9);
      final setupLog = Directory('$dir/logs')
          .listSync()
          .map((f) => f.path)
          .firstWhere((p) => p.endsWith('-x-setup.log'));
      expect(backendOf(setupLog), 'backend auto (auto)');
    });

    test('MB1 into a legacy bottle, its file stays byte for byte', () async {
      fakeCurrent(home);
      final dir = mach9Bottle(home, 'old');
      // An x86_64 kernel32: a Rosetta bottle (MB2).
      fakePe('$dir/prefix/drive_c/windows/system32/kernel32.dll', 0x8664, '');
      const legacy =
          '{\n'
          '  "backend": "auto",\n'
          '  "sync": "none",\n'
          '  "programs": {\n'
          '    "x.exe": {\n'
          '      "backend": "wine"\n'
          '    }\n'
          '  }\n'
          '}';
      File('$dir/settings.json').writeAsStringSync(legacy);
      await installEntry(
        home,
        entry('wine'),
        bottle: 'old',
        intoExisting: true,
        setup: '$tmp/x-setup.exe',
        grace: Duration.zero,
      );
      expect(File('$dir/settings.json').readAsStringSync(), legacy);
    });

    test(
      'a new Mach9 bottle gets Mono between creation and installer',
      () async {
        mach9Runtime();
        final steps = <InstallStepKind>[];
        await installEntry(
          home,
          entry('wine'),
          bottle: 'm9',
          runtime: RuntimeKind.mach9,
          setup: '$tmp/x-setup.exe',
          onStep: (step) => steps.add(step.kind),
          grace: Duration.zero,
        );
        expect(
          steps.where(
            (k) => {
              InstallStepKind.creatingBottle,
              InstallStepKind.installingMono,
              InstallStepKind.runningInstaller,
            }.contains(k),
          ),
          [
            InstallStepKind.creatingBottle,
            InstallStepKind.installingMono,
            InstallStepKind.runningInstaller,
          ],
        );
        final settings = bottleSettings(home, 'm9');
        expect(settings.runtime, RuntimeKind.mach9);
        expect(settings.programs['x.exe']?.backend, 'wine');
        expect(monoMissing(home, 'm9'), isFalse);
        // PE1: the entry's `none` is Rosetta's; Mach9 keeps msync.
        expect(settings.sync, 'msync');
        expect(hostPlatform.syncEnv(settings.sync), isEmpty);
      },
    );

    test('PE1 a new Rosetta bottle still takes the entry\'s sync', () async {
      fakeCurrent(home);
      await installEntry(
        home,
        entry('wine'),
        bottle: 'x86',
        setup: '$tmp/x-setup.exe',
        grace: Duration.zero,
      );
      expect(bottleSettings(home, 'x86').sync, 'none');
    });
  });

  group('MC1–MC8 the CLI', () {
    Future<(int, String)> cli(List<String> args) async {
      final out = StringBuffer();
      final verb = runtimeVerb(args, out);
      if (verb == null) return (64, '');
      return (await verb(home), '$out');
    }

    test('runtime list', () async {
      fakeMach9Runtime(home, version: '0.5.0');
      expect(
        (await cli(['runtime', 'list'])).$2,
        'bodega: not installed\n'
        'mach9: installed 0.5.0 (not checked with this Bodega)\n',
      );
      hostPlatform = const TestMac(mach9Block: RuntimeBlock.macosTooOld);
      expect(
        (await cli(['runtime', 'list'])).$2,
        contains('mach9: not available (Mach9 needs macOS 26.4 or later)'),
      );
      hostPlatform = LinuxPlatform(bundle: tmp);
      expect((await cli(['runtime', 'list'])).$2, 'bodega: not installed\n');
    });

    test('runtime list names the pinned install', () {
      fakeMach9Runtime(home);
      expect(
        describeRuntime(listRuntimes(home).last),
        'mach9: installed 0.4.0 (mach9-0.4.0)',
      );
      expect(
        describeRuntime(listRuntimes(home).first),
        'bodega: not installed',
      );
    });

    test('runtime install mach9 from an app and an MSI', () async {
      final app = fakeMach9Tree(tmp);
      final (code, out) = await cli([
        'runtime',
        'install',
        'mach9',
        app,
        '--mono',
        msi,
      ]);
      expect(code, 0);
      expect(out, contains(Mach9Step.copying.english));
      expect(Directory('$home/runtimes/mach9').existsSync(), isTrue);
      expect(parseRuntimeInstall(['--mono', msi, app]), (
        source: app,
        mono: msi,
      ));
      expect(parseRuntimeInstall([]), (source: null, mono: null));
      expect(parseRuntimeInstall(['a', 'b']), isNull);
      expect(parseRuntimeInstall(['--mono']), isNull);
    });

    test('create parses --runtime', () {
      expect(parseCreate(['x']), (runtime: RuntimeKind.bodega, bottle: 'x'));
      expect(parseCreate(['--runtime', 'mach9', 'x']), (
        runtime: RuntimeKind.mach9,
        bottle: 'x',
      ));
      expect(parseCreate(['--runtime', 'arm', 'x']), isNull);
      expect(parseCreate(['--runtime', 'mach9']), isNull);
      expect(parseCreate([]), isNull);
    });

    test('create x writes no runtime key', () async {
      fakeCurrent(home);
      await createBottle(home, 'x');
      final file = File('$home/bottles/x/settings.json');
      if (file.existsSync()) {
        expect(jsonDecode(file.readAsStringSync()), isNot(contains('runtime')));
      }
      expect(bottleRuntime(home, 'x'), RuntimeKind.bodega);
    });

    test('catalog install parses --runtime', () {
      expect(parseCatalogInstall([]), (
        bottle: null,
        runtime: RuntimeKind.bodega,
      ));
      expect(parseCatalogInstall(['b', '--runtime', 'mach9']), (
        bottle: 'b',
        runtime: RuntimeKind.mach9,
      ));
      expect(parseCatalogInstall(['--runtime', 'mach9']), (
        bottle: null,
        runtime: RuntimeKind.mach9,
      ));
      expect(parseCatalogInstall(['a', 'b']), isNull);
      expect(parseCatalogInstall(['--runtime', 'x']), isNull);
    });

    test('mono install', () async {
      mach9Runtime();
      mach9Bottle(home, 'm9');
      var (code, out) = await cli(['mono', 'install', 'm9']);
      expect(code, 0);
      expect(out, startsWith('Wine Mono installed\nlog: '));
      (code, out) = await cli(['mono', 'install', 'm9']);
      expect(out, 'Wine Mono is already installed\n');
      Directory('$home/bottles/x86').createSync();
      (code, out) = await cli(['mono', 'install', 'x86']);
      expect(out, "not needed: x86 runs on Bodega's Wine (x86_64)\n");
    });

    test('rules prints the golden string, or none for Rosetta', () async {
      fakeMach9Runtime(home);
      mach9Bottle(
        home,
        'm9',
        '{"programs": {"iw5mp.exe": {"backend": "wine"}}}',
      );
      final (code, out) = await cli(['rules', 'm9', '--hud', 'plutonium.exe']);
      expect(code, 0);
      expect(
        out,
        'exe=*;metal_hud=true;dll_overrides=winemenubuilder.exe=\n'
        'exe=iw5mp.exe;dxgi=wined3d;d3d9=wined3d\n',
      );
      Directory('$home/bottles/x86').createSync();
      expect(
        (await cli(['rules', 'x86', 'a.exe'])).$2,
        contains('takes no rules'),
      );
      expect(parseRules(['m9']), isNull);
      expect(parseRules(['--hud', 'm9', 'a.exe']), isNull);
      expect(parseRules(['m9', '--backend', 'dxmt', 'a.exe'])?.backend, 'dxmt');
    });

    test('backend list --runtime mach9; the plain one is not here', () async {
      fakeMach9Runtime(home, skip: ['dxgi/dxmt']);
      expect(
        (await cli(['backend', 'list', '--runtime', 'mach9'])).$2,
        'wine: installed\ndxmt: not installed\nmtld3d: installed\n',
      );
      expect(runtimeVerb(['backend', 'list'], StringBuffer()), isNull);
      expect(
        runtimeVerb(['backend', 'list', '--runtime', 'x'], StringBuffer()),
        isNull,
      );
    });

    test('PE11 option retina and native', () async {
      final dir = mach9Bottle(home, 'm9');
      File('$dir/prefix/drive_c/g/game.exe').createSync(recursive: true);
      addApp(home, 'm9', 'Game', 'g/game.exe');
      expect((await cli(['option', 'm9', 'retina', 'off'])).$1, 0);
      expect(bottleSettings(home, 'm9').retina, 'off');
      expect((await cli(['option', 'm9', 'retina', 'max'])).$1, 64);
      expect(await cli(['native', 'm9', 'g/game.exe', 'cgl-opengl', 'on']), (
        0,
        'cgl-opengl: on\n',
      ));
      expect(
        (await cli(['native', 'm9', 'g/game.exe'])).$2,
        'no-force-nx: off\n'
        'large-address-aware: off\n'
        'not-dpi-aware: off\n'
        'cgl-opengl: on\n'
        'vulkan-wined3d: off\n'
        'strict-code-tracking: off\n'
        'full-x87-precision: off\n',
      );
      expect(
        await cli(['native', 'm9', 'g/game.exe', 'strict-code-tracking', 'on']),
        (0, 'strict-code-tracking: on\n'),
      );
      expect(nativeOptions(home, 'm9', 'g/game.exe'), {
        NativeOption.cglOpenGl,
        NativeOption.strictCodeTracking,
      });
      expect((await cli(['native', 'm9', 'g/game.exe', 'turbo', 'on'])).$1, 64);
      expect(
        (await cli(['native', 'm9', 'g/game.exe', 'cgl-opengl', 'yes'])).$1,
        64,
      );
    });

    test('the usage lists every new verb', () {
      for (final verb in [
        'bodega option <bottle> retina auto|on|off',
        'bodega native <bottle> <key> [<option> on|off]',
        'bodega runtime list',
        'bodega runtime install mach9',
        'bodega create [--runtime bodega|mach9] <bottle>',
        'bodega mono install <bottle>',
        'bodega rules <bottle>',
        'bodega backend list [--runtime mach9]',
        'bodega catalog install <id> [bottle] [--runtime mach9]',
      ]) {
        expect(bodegaUsage, contains(verb));
      }
    });
  });
}

/// A Mac whose copies fail, as a full disk makes them (PE12).
class _NoCopyMac extends TestMac {
  const _NoCopyMac();

  @core.override
  Future<void> copyTree(String from, String to) async =>
      throw const ProcessFailed('cp -a', 1, 'No space left on device');
}
