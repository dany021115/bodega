import 'dart:convert';
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '_mac.dart';
import 'backends_test.dart' show fakePe;
import 'engine_test.dart' show fakeWine, fakeWineserver;

/// A Mach9 runtime of [version] with the graphics folders of design §2.1,
/// linked as `runtimes/mach9` unless [link] is false.
String fakeMach9Runtime(
  String home, {
  String version = '0.4.0',
  bool link = true,
  List<String> skip = const [],
}) {
  final dir = '$home/runtimes/mach9-$version';
  for (final sub in [
    'dxgi/wined3d',
    'dxgi/dxmt',
    'd3d9/wined3d',
    'd3d9/mtld3d',
  ]) {
    if (!skip.contains(sub)) {
      Directory('$dir/engine/lib/wine/$sub').createSync(recursive: true);
    }
  }
  File('$dir/runtime.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      '{"kind":"mach9","version":"$version","source":"app","checked":'
      '${version == '0.4.0'}}',
    );
  if (link) Link('$home/runtimes/mach9').createSync('mach9-$version');
  return dir;
}

/// [fakeMach9Runtime] with `bin/wine` and `bin/wineserver` scripts that act
/// as the engine tests' fakes and log each call to `$WINEPREFIX/../<log>`
/// (`bottles.md`'s fake Mach9 runtime).
String fakeMach9Wine(String home, {String log = 'mach9-calls'}) {
  final dir = fakeMach9Runtime(home);
  writeFakeWine('$dir/engine', log);
  return dir;
}

/// Wine and wineserver fakes in `<engine>/bin` that log every call. Wine
/// also keeps the `WINE_COMPATDB` of its last call in `$WINEPREFIX/compatdb`,
/// whose lines `env` would mix with the other variables.
void writeFakeWine(String engine, String log) {
  String logged(String script, String tool) => script.replaceFirst(
    '#!/bin/sh\n',
    '#!/bin/sh\necho "$tool \$*" >>"\$WINEPREFIX/../$log"\n',
  );
  const keep =
      '#!/bin/sh\n'
      r'printf %s "$WINE_COMPATDB" >"$WINEPREFIX/compatdb" 2>/dev/null'
      '\n';
  final wine = File('$engine/bin/wine')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      logged(fakeWine.replaceFirst('#!/bin/sh\n', keep), 'wine'),
    );
  final server = File('$engine/bin/wineserver')
    ..writeAsStringSync(logged(fakeWineserver, 'wineserver'));
  Process.runSync('/bin/chmod', ['+x', wine.path, server.path]);
}

/// A Bodega runtime as `current`, whose fakes log to `current-calls`.
String fakeCurrent(String home) {
  final dir = '$home/runtimes/engine-test';
  writeFakeWine('$dir/engine', 'current-calls');
  Directory('$dir/engine/lib/wine/x86_64-unix').createSync(recursive: true);
  Link('$home/runtimes/current').createSync('engine-test');
  return dir;
}

/// A ready Mach9 bottle: settings.json with the runtime and a prefix that
/// `_ready` accepts, with `system32/kernel32.dll` an arm64 PE.
String mach9Bottle(String home, String name, [String settings = '{}']) {
  final dir = '$home/bottles/$name';
  final json = jsonDecode(settings) as Map<String, dynamic>;
  File('$dir/settings.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode({'runtime': 'mach9', ...json}));
  final windows = '$dir/prefix/drive_c/windows';
  fakePe('$windows/system32/kernel32.dll', 0xAA64, '');
  fakePe('$windows/syswow64/kernel32.dll', 0x14C, '');
  File('$dir/prefix/system.reg').writeAsStringSync('');
  Directory('$dir/logs').createSync();
  return dir;
}

/// The fake Mach9.app of `runtimes.md`: its XML Info.plist, under [root].
String fakeMach9App(
  String root, {
  String id = 'app.mach9',
  String version = '0.4.0',
}) {
  final app = '$root/Mach9.app';
  File('$app/Contents/Info.plist')
    ..createSync(recursive: true)
    ..writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>$id</string>
	<key>CFBundleShortVersionString</key>
	<string>$version</string>
	<key>LSMinimumSystemVersion</key>
	<string>26.4</string>
</dict>
</plist>
''');
  return app;
}

void main() {
  useMac();
  late String tmp, home;
  setUp(() {
    tmp = Directory.systemTemp
        .createTempSync('bodega')
        .resolveSymbolicLinksSync();
    home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
  });
  tearDown(() => Directory(tmp).deleteSync(recursive: true));

  String bottle(String name, [String? settings]) {
    final dir = '$home/bottles/$name';
    Directory(dir).createSync(recursive: true);
    if (settings != null)
      File('$dir/settings.json').writeAsStringSync(settings);
    return dir;
  }

  String kernel32(String dir) =>
      '$dir/prefix/drive_c/windows/system32/kernel32.dll';

  group('MR1 listRuntimes', () {
    test('Linux knows bodega alone', () {
      hostPlatform = LinuxPlatform(bundle: tmp);
      final list = listRuntimes(home);
      expect(list.map((info) => info.kind), [RuntimeKind.bodega]);
      expect(list.single.installed, isFalse);
      expect(list.single.checked, isTrue);
      expect(list.single.version, isNull);
    });

    test('the Mac knows bodega, then mach9, installed or not', () {
      final none = listRuntimes(home);
      expect(none.map((info) => info.kind), [
        RuntimeKind.bodega,
        RuntimeKind.mach9,
      ]);
      expect(none.last.installed, isFalse);
      expect(none.last.id, isNull);
      expect(none.last.blocked, isNull);
      expect(none.last.app, isNull);

      fakeMach9Runtime(home, version: '0.5.0');
      final mach9 = listRuntimes(home).last;
      expect(mach9.installed, isTrue);
      expect(mach9.id, 'mach9-0.5.0');
      expect(mach9.version, '0.5.0');
      expect(mach9.checked, isFalse);
    });

    test('the pinned version counts as checked', () {
      fakeMach9Runtime(home);
      final mach9 = listRuntimes(home).last;
      expect(mach9.version, mach9Release.version);
      expect(mach9.checked, isTrue);
    });

    test('bodega names the folder current points at', () {
      Directory('$home/runtimes/engine-x').createSync();
      Link('$home/runtimes/current').createSync('engine-x');
      final bodega = listRuntimes(home).first;
      expect(bodega.installed, isTrue);
      expect(bodega.id, 'engine-x');
    });

    test('a Mach9.app in the applications folder is offered', () {
      hostPlatform = TestMac(applications: '$tmp/Applications');
      expect(listRuntimes(home).last.app, isNull);
      final app = fakeMach9App('$tmp/Applications');
      expect(listRuntimes(home).last.app, (path: app, version: '0.4.0'));
      expect(findMach9App(), (path: app, version: '0.4.0'));
    });

    test('another app named Mach9.app is not', () {
      hostPlatform = TestMac(applications: '$tmp/Applications');
      fakeMach9App('$tmp/Applications', id: 'com.other');
      expect(findMach9App(), isNull);
    });
  });

  group('MR2 where Mach9 runs', () {
    test('a blocked Mac says why, and creating a Mach9 bottle fails', () async {
      hostPlatform = const TestMac(mach9Block: RuntimeBlock.macosTooOld);
      expect(listRuntimes(home).last.blocked, RuntimeBlock.macosTooOld);
      await expectLater(
        createBottle(home, 'm9', runtime: RuntimeKind.mach9),
        throwsA(
          isA<RuntimeUnavailable>()
              .having((f) => f.runtime, 'runtime', RuntimeKind.mach9)
              .having((f) => f.reason, 'reason', RuntimeBlock.macosTooOld),
        ),
      );
    });

    test('Linux is never a place for Mach9', () {
      expect(LinuxPlatform(bundle: tmp).mach9Block, RuntimeBlock.notThisHost);
      expect(LinuxPlatform(bundle: tmp).applicationDirs, isEmpty);
    });

    test('this Mac reads its own answer', () {
      // Apple silicon and macOS 26.4+ give null; anything else a reason.
      expect(
        const MacPlatform().mach9Block,
        anyOf(isNull, isA<RuntimeBlock>()),
      );
      expect(const MacPlatform().mach9Block, isNot(RuntimeBlock.notThisHost));
    }, skip: Platform.isMacOS ? false : 'needs macOS');
  });

  group('MR10 runtimeDir', () {
    test('bodega without current is NoRuntime', () {
      expect(
        () => runtimeDir(home, RuntimeKind.bodega),
        throwsA(isA<NoRuntime>()),
      );
    });

    test('mach9 missing or dangling is RuntimeNotInstalled', () {
      Matcher notInstalled() => throwsA(
        isA<RuntimeNotInstalled>().having(
          (f) => f.runtime,
          'runtime',
          RuntimeKind.mach9,
        ),
      );
      expect(() => runtimeDir(home, RuntimeKind.mach9), notInstalled());
      Link('$home/runtimes/mach9').createSync('mach9-9.9.9');
      expect(() => runtimeDir(home, RuntimeKind.mach9), notInstalled());
    });

    test('mach9 resolves its link', () {
      final dir = fakeMach9Runtime(home);
      expect(runtimeDir(home, RuntimeKind.mach9), dir);
    });
  });

  group('MB1 the runtime in settings.json', () {
    test('a missing key is bodega', () {
      bottle('old', '{"backend": "auto", "sync": "msync", "programs": {}}');
      expect(bottleSettings(home, 'old').runtime, RuntimeKind.bodega);
      bottle('bare');
      expect(bottleSettings(home, 'bare').runtime, RuntimeKind.bodega);
    });

    test('mach9 survives every save', () async {
      // installEntry: MB9's 'into an existing Mach9 bottle' in mach9_test.
      fakeMach9Wine(home);
      final dir = mach9Bottle(
        home,
        'm9',
        '{"backend": "mtld3d", "sync": "msync"}',
      );
      File('$dir/prefix/drive_c/P/a.exe').createSync(recursive: true);
      addApp(home, 'm9', 'A', 'P/a.exe');
      expect(bottleSettings(home, 'm9').runtime, RuntimeKind.mach9);
      expect(bottleSettings(home, 'm9').backend, 'mtld3d');
      final saves = <String, Future<void> Function()>{
        'setBackend': () async =>
            setBackend(home, 'm9', 'wine', exe: 'game.exe'),
        'setSync': () => setSync(home, 'm9', 'none'),
        'setBottleOptions': () async =>
            setBottleOptions(home, 'm9', dlss: true, env: {'A': 'b'}),
        'setHighRes': () => setHighRes(home, 'm9', true),
        'setBottleUser': () => setBottleUser(home, 'm9', 'player'),
        'setWindowsVersion': () => setWindowsVersion(home, 'm9', 'win7'),
        'setAppHud': () async => setAppHud(home, 'm9', 'p/a.exe', true),
      };
      for (final MapEntry(key: save, value: run) in saves.entries) {
        await run();
        final text = File('$dir/settings.json').readAsStringSync();
        expect(text, contains('"runtime": "mach9"'), reason: save);
        expect(bottleSettings(home, 'm9').runtime, RuntimeKind.mach9);
      }
      final settings = bottleSettings(home, 'm9');
      expect(settings.programs['game.exe']?.backend, 'wine');
      expect(settings.programs['a.exe']?.hud, isTrue);
      expect(
        (
          settings.sync,
          settings.dlss,
          // PE2: high-res on a Mach9 bottle is its retina mode.
          settings.retina,
          settings.user,
          settings.windows,
        ),
        ('none', true, 'on', 'player', 'win7'),
      );
    });

    test('a legacy file is written back byte for byte', () async {
      // installEntry: MB9's legacy test in mach9_test.
      fakeCurrent(home);
      final dir = mach9Bottle(home, 'old');
      // An x86_64 kernel32: a Rosetta bottle (MB2).
      fakePe('$dir/prefix/drive_c/windows/system32/kernel32.dll', 0x8664, '');
      File('$dir/prefix/drive_c/P/a.exe').createSync(recursive: true);
      addApp(home, 'old', 'A', 'P/a.exe');
      const legacy =
          '{\n'
          '  "backend": "auto",\n'
          '  "sync": "msync",\n'
          '  "programs": {\n'
          '    "a.exe": {\n'
          '      "hud": true\n'
          '    }\n'
          '  },\n'
          '  "highRes": true,\n'
          '  "windows": "win7",\n'
          '  "user": "player"\n'
          '}';
      File('$dir/settings.json').writeAsStringSync(legacy);
      final saves = <String, Future<void> Function()>{
        'setBackend': () async => setBackend(home, 'old', 'auto'),
        'setSync': () => setSync(home, 'old', 'msync'),
        'setBottleOptions': () async =>
            setBottleOptions(home, 'old', dlss: false),
        'setHighRes': () => setHighRes(home, 'old', true),
        'setBottleUser': () => setBottleUser(home, 'old', 'player'),
        'setWindowsVersion': () => setWindowsVersion(home, 'old', 'win7'),
        'setAppHud': () async => setAppHud(home, 'old', 'p/a.exe', true),
      };
      for (final MapEntry(key: save, value: run) in saves.entries) {
        await run();
        expect(
          File('$dir/settings.json').readAsStringSync(),
          legacy,
          reason: save,
        );
      }
    });

    test('an unknown runtime is corrupt data', () {
      bottle('arm', '{"runtime": "arm"}');
      expect(
        () => bottleSettings(home, 'arm'),
        throwsA(
          isA<CorruptData>().having(
            (f) => f.detail,
            'detail',
            '${const BadChoice(ChoiceKind.runtime, 'arm')}',
          ),
        ),
      );
    });
  });

  group('MB2 the prefix has the last word', () {
    test('kernel32 0xAA64 is mach9 without a key', () {
      fakePe(kernel32(bottle('a')), 0xAA64, '');
      expect(bottleRuntime(home, 'a'), RuntimeKind.mach9);
    });

    test('kernel32 0x8664 or 0x14C is bodega whatever settings say', () {
      for (final (name, machine) in [('b', 0x8664), ('c', 0x14C)]) {
        fakePe(kernel32(bottle(name, '{"runtime": "mach9"}')), machine, '');
        expect(bottleRuntime(home, name), RuntimeKind.bodega, reason: name);
      }
    });

    test('an empty, short or missing kernel32 leaves it to settings', () {
      final empty = bottle('e', '{"runtime": "mach9"}');
      File(kernel32(empty)).createSync(recursive: true);
      expect(bottleRuntime(home, 'e'), RuntimeKind.mach9);
      final short = bottle('s', '{"runtime": "mach9"}');
      File(kernel32(short))
        ..createSync(recursive: true)
        ..writeAsStringSync('MZ');
      expect(bottleRuntime(home, 's'), RuntimeKind.mach9);
      bottle('m', '{"runtime": "mach9"}');
      expect(bottleRuntime(home, 'm'), RuntimeKind.mach9);
      bottle('n');
      expect(bottleRuntime(home, 'n'), RuntimeKind.bodega);
    });

    test('only syswow64, as the fake wineboot writes, stays bodega', () {
      final dir = bottle('w');
      fakePe('$dir/prefix/drive_c/windows/syswow64/kernel32.dll', 0xAA64, '');
      expect(bottleRuntime(home, 'w'), RuntimeKind.bodega);
    });

    test('listBottles gives the effective kind', () {
      fakePe(kernel32(bottle('a')), 0xAA64, '');
      bottle('b', '{"runtime": "mach9"}');
      bottle('c');
      expect(
        {for (final info in listBottles(home)) info.name: info.runtime},
        {
          'a': RuntimeKind.mach9,
          'b': RuntimeKind.mach9,
          'c': RuntimeKind.bodega,
        },
      );
    });
  });

  group('PE2 the retina setting', () {
    test('a Mach9 bottle keeps off and on, and auto leaves the file', () async {
      final m9 = bottle('m9', '{"runtime": "mach9"}');
      String file() => File('$m9/settings.json').readAsStringSync();
      expect(bottleSettings(home, 'm9').retina, 'auto');
      expect(await setRetina(home, 'm9', 'off'), isTrue);
      expect(jsonDecode(file())['retina'], 'off');
      expect(await setRetina(home, 'm9', 'off'), isFalse);
      expect(await setHighRes(home, 'm9', true), isTrue);
      expect(bottleSettings(home, 'm9').retina, 'on');
      expect(bottleSettings(home, 'm9').highRes, isFalse);
      await setRetina(home, 'm9', 'auto');
      expect(jsonDecode(file()), isNot(contains('retina')));
    });

    test('another mode is a bad choice, in the file too', () async {
      bottle('m9', '{"runtime": "mach9"}');
      expect(
        () => setRetina(home, 'm9', 'max'),
        throwsA(
          isA<BadChoice>()
              .having((f) => f.kind, 'kind', ChoiceKind.retina)
              .having((f) => f.message, 'message', contains('auto, on, off')),
        ),
      );
      bottle('bad', '{"runtime": "mach9", "retina": "max"}');
      expect(() => bottleSettings(home, 'bad'), throwsA(isA<CorruptData>()));
    });

    test('a Rosetta bottle has no auto', () {
      bottle('x86', '{}');
      expect(
        () => setRetina(home, 'x86', 'auto'),
        throwsA(
          isA<BadChoice>().having(
            (f) => f.message,
            'message',
            'unknown retina mode: auto (on, off)',
          ),
        ),
      );
    });
  });

  group('PE7 the native options in settings.json', () {
    test('they read back sorted by app, and an unknown one is corrupt', () {
      bottle(
        'm9',
        '{"runtime": "mach9", "native": {"steam:220": ["noForceNx"], '
            '"game.exe": ["largeAddressAware", "cglOpenGl"]}}',
      );
      expect(bottleSettings(home, 'm9').native, {
        'steam:220': ['noForceNx'],
        'game.exe': ['largeAddressAware', 'cglOpenGl'],
      });
      bottle('bad', '{"runtime": "mach9", "native": {"a.exe": ["turbo"]}}');
      expect(() => bottleSettings(home, 'bad'), throwsA(isA<CorruptData>()));
    });
  });

  group('MB8 monoMissing', () {
    test('only a Mach9 bottle without mono-2.0', () {
      final m9 = bottle('m9', '{"runtime": "mach9"}');
      expect(monoMissing(home, 'm9'), isTrue);
      Directory('$m9/prefix/drive_c/windows/mono/mono-2.0')
          .createSync(recursive: true);
      expect(monoMissing(home, 'm9'), isFalse);
      bottle('x86');
      expect(monoMissing(home, 'x86'), isFalse);
    });

    test('PE9 .NET Framework 4 in the prefix is no missing Mono', () {
      final m9 = bottle('m9', '{"runtime": "mach9"}');
      final clr = File(
        '$m9/prefix/drive_c/windows/Microsoft.NET/Framework/v4.0.30319/clr.dll',
      );
      expect(monoMissing(home, 'm9'), isTrue);
      clr.createSync(recursive: true);
      expect(monoMissing(home, 'm9'), isFalse);
    });
  });

  group('MG1 names per kind', () {
    test('bodega has the host names, mach9 its three', () {
      expect(backendNamesFor(RuntimeKind.bodega), backendNames);
      expect(backendNamesFor(RuntimeKind.mach9), ['wine', 'dxmt', 'mtld3d']);
      expect(backendNamesFor(RuntimeKind.bodega), isNot(contains('mtld3d')));
      for (final name in ['dxvk', 'dxvk9', 'd3dmetal']) {
        expect(backendNamesFor(RuntimeKind.mach9), isNot(contains(name)));
      }
    });
  });

  group('MG2 installed, fits and catalog mapping', () {
    test('the Mach9 runtime gives its three names, none without it', () {
      expect(listBackends(home, runtime: RuntimeKind.mach9), {
        'wine': false,
        'dxmt': false,
        'mtld3d': false,
      });
      fakeMach9Runtime(home);
      expect(listBackends(home, runtime: RuntimeKind.mach9), {
        'wine': true,
        'dxmt': true,
        'mtld3d': true,
      });
      expect(listBackends(home).keys, backendNames);
    });

    test('wine needs both wined3d folders', () {
      fakeMach9Runtime(home, skip: ['d3d9/wined3d']);
      expect(listBackends(home, runtime: RuntimeKind.mach9)['wine'], isFalse);
    });

    test('on Mach9 only wine with DX12 misfits', () {
      for (final directx in ['', 'DX9', 'DX10', 'DX11', 'DX12']) {
        for (final bits in [32, 64]) {
          final exe = (bits: bits, directx: directx);
          for (final name in backendNamesFor(RuntimeKind.mach9)) {
            expect(
              backendFitsFor(RuntimeKind.mach9, name, exe),
              !(name == 'wine' && directx == 'DX12'),
              reason: '$name $exe',
            );
          }
        }
      }
      const dx9 = (bits: 32, directx: 'DX9');
      expect(
        backendFitsFor(RuntimeKind.bodega, 'dxmt', dx9),
        hostPlatform.backendFits('dxmt', dx9),
      );
    });

    test('the catalog maps to wine or auto on Mach9', () {
      for (final name in ['dxmt', 'dxvk', 'd3dmetal', 'auto']) {
        expect(mapBackendFor(RuntimeKind.mach9, name), 'auto', reason: name);
        expect(
          mapBackendFor(RuntimeKind.bodega, name),
          hostPlatform.mapBackend(name),
        );
      }
      expect(mapBackendFor(RuntimeKind.mach9, 'wine'), 'wine');
    });
  });

  group('MR3 the release pin', () {
    test('both hashes and HTTPS URLs', () {
      expect(
        mach9Release.sha256,
        '3b5dd83ee7b08d55e6c4a84dabb32db994dc6a5bfb2a1500fb50d0b45436e6d9',
      );
      expect(
        mach9Release.mono.sha256,
        'df2dfc1665c2511882e7cabd56eafd0c0a3d94e5a7e86f969277f6c189d418d3',
      );
      expect(Uri.parse(mach9Release.url).scheme, 'https');
      expect(Uri.parse(mach9Release.mono.url).scheme, 'https');
      expect(mach9Release.file, 'Mach9-${mach9Release.version}.dmg');
    });
  });

  group('MB3 every operation on the bottle runtime', () {
    List<String> calls(String name, String log) {
      final file = File('$home/bottles/$name/$log');
      return file.existsSync() ? file.readAsLinesSync() : [];
    }

    test('a Mach9 bottle reaches its own Wine, never current', () async {
      fakeCurrent(home);
      fakeMach9Wine(home);
      mach9Bottle(home, 'm9');
      expect(await exitOf(await runInBottle(home, 'm9', 'game.exe', [])), 7);
      expect(await waitBottle(home, 'm9'), 0);
      expect(await stopBottle(home, 'm9'), 0);
      await renameBottle(home, 'm9', 'm10');
      expect(calls('m10', 'mach9-calls'), [
        'wine game.exe',
        'wineserver -w',
        'wineserver -k',
        'wineserver -w',
      ]);
      expect(calls('m10', 'current-calls'), isEmpty);
      // Removal deletes the bottle folder and the logs in it: these log one
      // level up, in bottles/.
      writeFakeWine('$home/runtimes/mach9-0.4.0/engine', '../mach9-calls');
      writeFakeWine('$home/runtimes/engine-test/engine', '../current-calls');
      await removeBottle(home, 'm10');
      expect(Directory('$home/bottles/m10').existsSync(), isFalse);
      expect(File('$home/bottles/mach9-calls').readAsLinesSync(), [
        'wineserver -k',
        'wineserver -w',
      ]);
      expect(File('$home/bottles/current-calls').existsSync(), isFalse);
    });

    test('a bodega bottle stays on current', () async {
      fakeCurrent(home);
      fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'x86');
      // The prefix has the last word: an x86_64 kernel32 is bodega.
      fakePe('$dir/prefix/drive_c/windows/system32/kernel32.dll', 0x8664, '');
      expect(await stopBottle(home, 'x86'), 0);
      expect(calls('x86', 'current-calls'), ['wineserver -k']);
      expect(calls('x86', 'mach9-calls'), isEmpty);
    });

    test(
      'without Mach9, stop, wait and remove go on; a launch fails',
      () async {
        fakeCurrent(home);
        mach9Bottle(home, 'm9');
        expect(await stopBottle(home, 'm9'), 0);
        expect(await waitBottle(home, 'm9'), 0);
        await expectLater(
          runInBottle(home, 'm9', 'game.exe', []),
          throwsA(
            isA<RuntimeNotInstalled>().having(
              (f) => f.runtime,
              'runtime',
              RuntimeKind.mach9,
            ),
          ),
        );
        expect(calls('m9', 'current-calls'), isEmpty);
        await removeBottle(home, 'm9');
        expect(Directory('$home/bottles/m9').existsSync(), isFalse);
      },
    );

    test('a launch on a blocked Mac says why', () async {
      fakeMach9Wine(home);
      mach9Bottle(home, 'm9');
      hostPlatform = const TestMac(mach9Block: RuntimeBlock.macosTooOld);
      await expectLater(
        runInBottle(home, 'm9', 'game.exe', []),
        throwsA(
          isA<RuntimeUnavailable>().having(
            (f) => f.reason,
            'reason',
            RuntimeBlock.macosTooOld,
          ),
        ),
      );
    });
  });

  group('MB4 host preparation by kind', () {
    test('a Mach9 launch writes no WineBus value', () async {
      fakeMach9Wine(home);
      final dir = mach9Bottle(home, 'm9');
      await exitOf(await runInBottle(home, 'm9', 'game.exe', []));
      final reg = File('$dir/prefix/reg.log');
      expect(
        reg.existsSync() ? reg.readAsStringSync() : '',
        isNot(contains('WineBus')),
      );
      expect(bottleSettings(home, 'm9').gamepads, 0);
    });

    test('a bodega launch still prepares its gamepads', () async {
      fakeCurrent(home);
      final dir = mach9Bottle(home, 'x86', '{"runtime": "bodega"}');
      fakePe('$dir/prefix/drive_c/windows/system32/kernel32.dll', 0x8664, '');
      await exitOf(await runInBottle(home, 'x86', 'game.exe', []));
      expect(
        File('$dir/prefix/reg.log').readAsStringSync(),
        contains('WineBus'),
      );
    });
  });
}
