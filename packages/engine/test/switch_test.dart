import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '_mac.dart';

/// The game (SE23): an empty file with a made-up name and id.
const gameName = 'Bodega Test [0100F00DBA5E0000][v0] (EU).nsp';

/// The extensions of Ryubing's row, in its order.
const extensions = ['xci', 'nsp', 'pfs0', 'nca', 'nro', 'nso'];

/// Mode-000 files show that nothing is read, which root could read anyway: the
/// cases that make them skip as root.
final asRoot = '${Process.runSync('id', ['-u']).stdout}'.trim() == '0';

const rootSkip = 'root reads mode-000 files';

File touch(String path) => File(path)..createSync(recursive: true);

void chmod(String mode, String path) =>
    Process.runSync('/bin/chmod', [mode, path]);

/// The real plutil runs on the Mac only (SN5).
final needsPlutil = File('/usr/bin/plutil').existsSync()
    ? false
    : 'needs plutil';

/// The real `xattr` runs on the Mac only: Linux's differs (SN5).
final needsMacOS = Platform.isMacOS ? false : 'needs macOS';

/// The session keys of "wineEnv is hermetic", which an emulator keeps (SN4).
const session = {
  'HOME': '/Users/q',
  'USER': 'q',
  'LOGNAME': 'q',
  'TMPDIR': '/var/folders/x/T/',
  '__CF_USER_TEXT_ENCODING': '0x1F5:0x0:0x8',
};

/// What an emulator never gets (SE14, SN4): Wine's, .NET's and Bodega's keys,
/// nxnative's `DM_` ones, the language and the caller's PATH.
const keptOut = {
  'PATH': '/opt/homebrew/bin',
  'LANG': 'es_ES.UTF-8',
  'WINEPREFIX': '/b/p',
  'WINEDEBUG': '+all',
  'WINEMSYNC': '1',
  'ROSETTA_ADVERTISE_AVX': '1',
  'MVK_CONFIG_LOG_LEVEL': '2',
  'DOTNET_EnableWriteXorExecute': '0',
  'DOTNET_ROOT': '/usr/local/share/dotnet',
  'DYLD_LIBRARY_PATH': '/opt/homebrew/lib',
  'BODEGA_HOME': '/b',
  'BODEGA_WINEDEBUG': '+loaddll',
  'DM_LAUNCHER': '0',
  'DM_FPS_TARGET': '30',
};

/// The fixture's executable (SE23), after `fakeWine`: it writes its arguments
/// one per line, its folder, its environment, its pid and its parent's pid
/// under `$HOME`, ignores SIGTERM while `deaf` is there, waits while `hang` is
/// there, and exits with the code in `code`, or 0.
const fakeEmulator = r'''#!/bin/sh
for a in "$@"; do printf '%s\n' "$a"; done >"$HOME/argv"
pwd >"$HOME/cwd"
env >"$HOME/env"
echo $$ >"$HOME/pid"
echo $PPID >"$HOME/ppid"
if [ -e "$HOME/deaf" ]; then trap '' TERM; fi
while [ -e "$HOME/hang" ]; do sleep 0.1; done
exit "$(cat "$HOME/code" 2>/dev/null || echo 0)"
''';

/// An `Info.plist` with no DOCTYPE, as `backends_test.dart` writes one: a
/// string per key whose value is not null.
String infoPlist(Map<String, String?> keys) =>
    '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>'
    '${[for (final MapEntry(:key, :value) in keys.entries)
      if (value != null) '<key>$key</key><string>$value</string>'].join()}'
    '</dict></plist>';

/// The fixture (SE23): a fake `Ryujinx.app` at [app], version 1.3.3, whose
/// `Contents/MacOS/Ryujinx` is [fakeEmulator] at mode 755. [id], [executable],
/// [version], [mode] and [plist] each break it one way.
String fakeRyujinx(
  String app, {
  String id = 'org.ryujinx.Ryujinx',
  String executable = 'Ryujinx',
  String? version = '1.3.3',
  String mode = '755',
  bool plist = true,
}) {
  final exe = touch('$app/Contents/MacOS/Ryujinx')
    ..writeAsStringSync(fakeEmulator);
  chmod(mode, exe.path);
  if (plist) {
    File('$app/Contents/Info.plist').writeAsStringSync(
      infoPlist({
        'CFBundleIdentifier': id,
        'CFBundleExecutable': executable,
        'CFBundleShortVersionString': version,
      }),
    );
  }
  return app;
}

/// The title id in the native fixture's `Info.plist`, made up.
const nativeTitleId = '0100F00DBA5E0000';

/// The native fixture (SE23): a fake native app at [app] whose `Info.plist`
/// has `DMTitleID` and `CFBundleExecutable` `nxnative`, and whose
/// `Contents/MacOS/nxnative` is [fakeEmulator] at mode 755. [dmTitleId],
/// [executable], [mode] and [plist] each break it one way. Never mark it in
/// quarantine and then start it: macOS would hold the run behind a prompt
/// that only the user sees.
String fakeNative(
  String app, {
  String? dmTitleId = nativeTitleId,
  String? executable = 'nxnative',
  String mode = '755',
  bool plist = true,
}) {
  final exe = touch('$app/Contents/MacOS/nxnative')
    ..writeAsStringSync(fakeEmulator);
  chmod(mode, exe.path);
  final info = File('$app/Contents/Info.plist');
  if (plist) {
    info.writeAsStringSync(
      infoPlist({'DMTitleID': dmTitleId, 'CFBundleExecutable': executable}),
    );
  } else if (info.existsSync()) {
    info.deleteSync();
  }
  return app;
}

/// The `plistKey` seam (SN5): [key]'s string in a fixture's XML, as
/// `plutil -extract <key> raw` gives it, or null.
Future<String?> fixtureKey(String plist, String key) async {
  final file = File(plist);
  if (!file.existsSync()) return null;
  return RegExp('<key>${RegExp.escape(key)}</key><string>([^<]*)</string>')
      .firstMatch(file.readAsStringSync())
      ?.group(1);
}

/// The test Mac (SE23): a [TestMac] whose emulators the test gives.
class SwitchMac extends TestMac {
  SwitchMac(this.emulators);

  @override
  final EmulatorHost emulators;
}

void main() {
  useMac();
  late String tmp, home;

  /// SE23's env: HOME under tmp, the session's other keys but USER, and what
  /// an emulator must not get.
  late Map<String, String> env;

  /// The apps the test Mac's `quarantine` seam says macOS keeps in quarantine.
  late Set<String> quarantined;
  Future<bool> inQuarantine(String app) async => quarantined.contains(app);

  setUp(() {
    tmp = Directory.systemTemp
        .createTempSync('bodega-switch')
        .resolveSymbolicLinksSync();
    home = bodegaHome({'BODEGA_HOME': '$tmp/bodega'});
    Directory('$tmp/home').createSync();
    env = {...session, ...keptOut, 'HOME': '$tmp/home'}..remove('USER');
    quarantined = {};
    hostPlatform = SwitchMac(
      MacEmulators(root: tmp, plistKey: fixtureKey, quarantine: inQuarantine),
    );
  });

  tearDown(() => Directory(tmp).deleteSync(recursive: true));

  // Declared after the deletion, so it runs before it: tmp goes only once no
  // process started from it is left. macOS checks a new app's executable
  // while it starts, and one whose files vanish meanwhile (a test that failed
  // halfway) stays held behind a prompt on the user's screen.
  tearDown(() async {
    final hang = File('$tmp/home/hang');
    if (hang.existsSync()) hang.deleteSync();
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
            if (int.tryParse(line.trim().split(' ').first) case final pid?) pid,
      ];
    }

    for (var i = 0; i < 100 && (await left()).isNotEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    for (final pid in await left()) {
      Process.killPid(pid, ProcessSignal.sigkill);
    }
  });

  /// The names in [dir], or none when it does not exist.
  List<String> names(String dir) => Directory(dir).existsSync()
      ? [
          for (final entry in Directory(dir).listSync())
            entry.path.split('/').last,
        ]
      : [];

  /// Runs `bodega switch <args>` as the CLI's block does, with SE23's env:
  /// expects [code] and gives the lines it wrote (SE21).
  Future<List<String>> cli(List<String> args, {int code = 0}) async {
    final out = StringBuffer();
    expect(await switchVerb(args, out, env)!(home), code, reason: '$args');
    return const LineSplitter().convert('$out');
  }

  /// SE21's quarantine note for [app]; [who] is what may not start: the
  /// emulator's name, or `it` for a native app.
  String quarantineNote(String app, String who) =>
      'note: macOS keeps $app in quarantine: if $who does not start, open it '
      'once from the Finder; if macOS blocks it, allow it in System Settings > '
      'Privacy & Security';

  test('the table holds one row, Ryubing, field by field (SE2)', () {
    final row = switchEmulators.single;
    expect(row.id, 'ryubing');
    expect(row.name, 'Ryubing');
    // Its official download page: the one link of Switch's code (SN10).
    expect(row.page, 'https://ryujinx.app/download');
    expect(row.extensions, extensions);
    expect(row.args.headless, ['--no-gui', '--use-main-config']);
    expect(row.args.fullscreen, ['--fullscreen']);
    expect(row.args.game, ['{game}']);
    final mac = row.mac!;
    expect(mac.bundleId, 'org.ryujinx.Ryujinx');
    expect(mac.app, 'Ryujinx.app');
    expect(mac.executable, 'Ryujinx');
    expect(mac.files.data, [
      '<bin>/portable',
      '<dir>/portable',
      '~/Library/Application Support/Ryujinx',
    ]);
    expect(mac.files.keys, '<data>/system/prod.keys');
    expect(mac.files.userKeys, '~/.switch/prod.keys');
    expect(mac.files.firmware, '<data>/bis/system/Contents/registered');
    expect(row.linux, isNull);
  });

  group('the store', () {
    test('switch/ is made by the first add, which writes games.json '
        'atomically (SE3)', () async {
      final game = touch('$tmp/games/$gameName').path;
      expect(home, '$tmp/bodega');
      expect(switchGames(home), isEmpty);
      expect(switchSettings(home), (
        picked: null,
        fullscreen: true,
        headless: true,
      ));
      expect((await checkSwitch(home, env)).install, isNull);
      expect(names(home), containsAll(['runtimes', 'bottles']));
      expect(names(home), isNot(contains('switch')));

      expect(await addSwitchGames(home, [game]), (added: 1, known: 0));
      final file = File('$home/switch/games.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final added = (json['games'] as List).single['added'] as String;
      expect(json, {
        'games': [
          {
            'path': game,
            'title': 'Bodega Test',
            'titleId': '0100F00DBA5E0000',
            'added': added,
          },
        ],
      });
      expect(DateTime.parse(added).isUtc, isTrue);
      expect(names('$home/switch'), ['games.json']);
    });

    test('a games.json that does not parse or has another shape is '
        'CorruptData, and stays as it was (SE3)', () async {
      final game = touch('$tmp/games/$gameName').path;
      final file = File('$home/switch/games.json')..createSync(recursive: true);
      final corrupt = throwsA(
        isA<CorruptData>().having((f) => f.source, 'source', file.path),
      );
      for (final text in [
        'not json',
        '{"games": 3}',
        '{"games": [{"title": "x", "added": "2026-11-11T08:00:00.000Z"}]}',
      ]) {
        file.writeAsStringSync(text);
        expect(() => switchGames(home), corrupt, reason: text);
        await expectLater(addSwitchGames(home, [game]), corrupt, reason: text);
        expect(() => removeSwitchGame(home, game), corrupt, reason: text);
        expect(file.readAsStringSync(), text);
      }
    });

    test('a game at mode 000 is added unread; a path listed or given twice '
        'is known (SE10)', () async {
      final game = touch('$tmp/games/$gameName').path;
      final other = touch('$tmp/games/OTHER.XCI').path;
      chmod('000', game);
      expect(await addSwitchGames(home, [game, other]), (added: 2, known: 0));
      expect(await addSwitchGames(home, [game, '$tmp/games/x/../$gameName']), (
        added: 0,
        known: 2,
      ));
      expect(switchGames(home).map((game) => game.path), [game, other]);
    }, skip: asRoot ? rootSkip : false);

    test('each path is made absolute, with . and .. worked out from the text '
        'and links kept (SE10)', () async {
      final game = touch('$tmp/games/$gameName').path;
      final link = Link('$tmp/link.nsp')..createSync(game);
      // Relative to the current folder: up past / and down again.
      final up = '../' * (Directory.current.path.split('/').length + 1);
      expect(
        await addSwitchGames(home, [
          '$up${game.substring(1)}',
          '${link.path}/',
          '$tmp/games/./x/y/../../$gameName/',
        ]),
        (added: 2, known: 1),
      );
      expect(switchGames(home).map((game) => game.path), [game, link.path]);
    });

    test('a path that is not a game file, or is missing, is refused before '
        'anything is written; a .nca picked by hand is taken (SE10)', () async {
      final other = touch('$tmp/games/OTHER.XCI').path;
      final readme = touch('$tmp/games/readme.txt').path;
      final folder = (Directory('$tmp/games/folder.nsp')..createSync()).path;
      Future<void> refused() async {
        await expectLater(
          addSwitchGames(home, [other, readme]),
          throwsA(
            isA<NotASwitchGame>()
                .having((f) => f.path, 'path', readme)
                .having((f) => f.extensions, 'extensions', extensions),
          ),
        );
        // A folder is not a game file, whatever its name.
        await expectLater(
          addSwitchGames(home, [other, folder]),
          throwsA(isA<NotASwitchGame>().having((f) => f.path, 'path', folder)),
        );
        await expectLater(
          addSwitchGames(home, [other, '$tmp/games/nope.nsp']),
          throwsA(
            isA<MissingFile>().having(
              (f) => f.path,
              'path',
              '$tmp/games/nope.nsp',
            ),
          ),
        );
      }

      await refused();
      expect(names(home), isNot(contains('switch')));
      await addSwitchGames(home, [touch('$tmp/games/$gameName').path]);
      final file = File('$home/switch/games.json');
      final before = file.readAsStringSync();
      await refused();
      expect(file.readAsStringSync(), before);

      final part = touch('$tmp/games/part.nca').path;
      expect(await addSwitchGames(home, [part]), (added: 1, known: 0));
      expect(switchGames(home).map((game) => game.path), contains(part));
    });

    const titles = [
      (gameName, 'Bodega Test', '0100F00DBA5E0000'),
      (
        'bodega_test__demo (v1.0) [0100f00dba5e0001].XCI',
        'bodega test demo',
        '0100F00DBA5E0001',
      ),
      (
        'Bodega Test [0100F00DBA5E0000][0100F00DBA5E0800][v65536].nsp',
        'Bodega Test',
        '0100F00DBA5E0000',
      ),
      ('Homebrew Tool.nro', 'Homebrew Tool', null),
      (
        'Bodega Test [0100F00DBA5E00001] (0100F00DBA5E0002).nsp',
        'Bodega Test',
        null,
      ),
      ('[0100F00DBA5E0003].nsp', '[0100F00DBA5E0003].nsp', '0100F00DBA5E0003'),
    ];
    for (final (name, title, titleId) in titles) {
      test('$name gives "$title" and ${titleId ?? 'no id'} (SE12)', () async {
        final path = touch('$tmp/games/$name').path;
        expect(await addSwitchGames(home, [path]), (added: 1, known: 0));
        final game = switchGames(home).single;
        expect(game.path, path);
        expect(game.title, title);
        expect(game.titleId, titleId);
      });
    }

    test('Bodega Test.app gives "Bodega Test" and no id: its DMTitleID does '
        'not feed them (SE12)', () async {
      final app = fakeNative('$tmp/games/Bodega Test.app');
      expect(await addSwitchGames(home, [app]), (added: 1, known: 0));
      final game = switchGames(home).single;
      expect(game.path, app);
      expect(game.title, 'Bodega Test');
      expect(game.titleId, isNull);
    });

    test("a native app's path is one whose name ends in .app, without case "
        '(SE10)', () {
      expect(isNativeApp('$tmp/apps/Bodega Test.app'), isTrue);
      expect(isNativeApp('$tmp/apps/GAME.APP/'), isTrue);
      expect(isNativeApp('$tmp/games/$gameName'), isFalse);
      expect(isNativeApp('$tmp/apps/Game.app/h.nsp'), isFalse);
      expect(isNativeApp('$tmp/apps/app'), isFalse);
    });

    test('a native app is added by its path, with no Ryubing anywhere; a .app '
        'without DMTitleID is NotASwitchGame and a missing one MissingFile, '
        'before anything is written (SE10)', () async {
      final native = fakeNative('$tmp/apps/Bodega Test.app');
      final tool = '$tmp/apps/Tool.app';
      File('$tool/Contents/Info.plist')
        ..createSync(recursive: true)
        ..writeAsStringSync(infoPlist({'CFBundleExecutable': 'tool'}));
      final game = touch('$tmp/games/$gameName').path;
      expect(await addSwitchGames(home, [native, game]), (added: 2, known: 0));
      expect(switchGames(home).map((game) => game.path), [native, game]);
      final file = File('$home/switch/games.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      // The same entry as a game file's: the store keeps no kind.
      expect((json['games'] as List).first, {
        'path': native,
        'title': 'Bodega Test',
        'added': isA<String>(),
      });
      expect(await addSwitchGames(home, ['$native/']), (added: 0, known: 1));

      final before = file.readAsStringSync();
      await expectLater(
        addSwitchGames(home, [game, tool]),
        throwsA(
          isA<NotASwitchGame>()
              .having((f) => f.path, 'path', tool)
              .having((f) => f.extensions, 'extensions', extensions),
        ),
      );
      await expectLater(
        addSwitchGames(home, [game, '$tmp/apps/nope.app']),
        throwsA(
          isA<MissingFile>().having(
            (f) => f.path,
            'path',
            '$tmp/apps/nope.app',
          ),
        ),
      );
      expect(file.readAsStringSync(), before);
    });

    test('the list is sorted by title without case, then by path, and stats '
        'no game (SE13)', () async {
      await addSwitchGames(home, [
        for (final name in ['zeta.nsp', 'b/Alpha.nsp', 'Alpha.xci', 'beta.nro'])
          touch('$tmp/games/$name').path,
      ]);
      final game = touch('$tmp/games/$gameName');
      await addSwitchGames(home, [game.path]);
      game.deleteSync();
      expect(switchGames(home).map((game) => game.path), [
        '$tmp/games/Alpha.xci',
        '$tmp/games/b/Alpha.nsp',
        '$tmp/games/beta.nro',
        game.path,
        '$tmp/games/zeta.nsp',
      ]);
    });

    test('removing forgets a listed game and keeps its file; one not listed '
        'is SwitchGameNotFound (SE13)', () async {
      final game = touch('$tmp/games/$gameName').path;
      final other = touch('$tmp/games/OTHER.XCI').path;
      await addSwitchGames(home, [game, other]);
      removeSwitchGame(home, '$tmp/games/x/../$gameName');
      expect(switchGames(home).map((game) => game.path), [other]);
      expect(File(game).existsSync(), isTrue);
      expect(
        () => removeSwitchGame(home, game),
        throwsA(isA<SwitchGameNotFound>().having((f) => f.path, 'path', game)),
      );
    });
  });

  group('the scan', () {
    /// SE11's tree under `<tmp>/lib`, with `a.nsp` and `locked/` at mode 000,
    /// and `Game.app`, a copy of the native fixture that also holds `h.nsp`.
    String tree() {
      final lib = '$tmp/lib';
      for (final name in [
        'a.nsp',
        'x/b.XCI',
        'x/y/c.nro',
        'x/y/z/d.nsp',
        'x/e.nca',
        '.h/f.nsp',
        '.g.nsp',
        'Tool.app/g.nsp',
        'readme.txt',
        'locked/k.nsp',
      ]) {
        touch('$lib/$name');
      }
      fakeNative('$lib/Game.app');
      touch('$lib/Game.app/h.nsp');
      touch('$tmp/elsewhere/l.nsp');
      touch('$tmp/elsewhere/m.nsp');
      Link('$lib/l.nsp').createSync('$tmp/elsewhere/l.nsp');
      Link('$lib/ld').createSync('$tmp/elsewhere/');
      chmod('000', '$lib/a.nsp');
      chmod('000', '$lib/locked');
      addTearDown(() => chmod('755', '$lib/locked'));
      return lib;
    }

    test('adds the game files and native apps it finds by name, two levels '
        'deep, following no link, going inside no app and passing over '
        'hidden entries, other apps, .nca files and the folders it may not '
        'list (SE11)', () async {
      final lib = tree();
      expect(await addSwitchFolder(home, lib), (added: 4, known: 0));
      expect(switchGames(home).map((game) => game.path), [
        '$lib/a.nsp',
        '$lib/x/b.XCI',
        '$lib/x/y/c.nro',
        '$lib/Game.app',
      ]);
      expect(await addSwitchFolder(home, '$lib/'), (added: 0, known: 4));
      expect(switchGames(home), hasLength(4));
      final json = jsonDecode(
        File('$home/switch/games.json').readAsStringSync(),
      );
      expect((json as Map).keys, ['games']);
    }, skip: asRoot ? rootSkip : false);

    test('on a Linux host it passes over every app and throws nothing for '
        'them (SE11)', () async {
      final lib = tree();
      hostPlatform = const LinuxPlatform(mangoHud: false);
      expect(await addSwitchFolder(home, lib), (added: 3, known: 0));
      expect(switchGames(home).map((game) => game.path), [
        '$lib/a.nsp',
        '$lib/x/b.XCI',
        '$lib/x/y/c.nro',
      ]);
    }, skip: asRoot ? rootSkip : false);

    test('a folder that is itself an app is taken as one, and never gone '
        'into (SE11)', () async {
      final game = fakeNative('$tmp/lib/Game.app');
      touch('$game/h.nsp');
      touch('$tmp/lib/Tool.app/g.nsp');
      expect(await addSwitchFolder(home, '$tmp/lib/Tool.app'), (
        added: 0,
        known: 0,
      ));
      expect(names(home), isNot(contains('switch')));
      expect(await addSwitchFolder(home, game), (added: 1, known: 0));
      expect(switchGames(home).map((game) => game.path), [game]);
    });

    test('a missing folder is MissingFile; an empty one adds nothing and '
        'writes nothing (SE11)', () async {
      await expectLater(
        addSwitchFolder(home, '$tmp/nope'),
        throwsA(isA<MissingFile>().having((f) => f.path, 'path', '$tmp/nope')),
      );
      final empty = (Directory('$tmp/empty')..createSync()).path;
      expect(await addSwitchFolder(home, empty), (added: 0, known: 0));
      expect(names(home), isNot(contains('switch')));
    });

    test('a games.json that does not parse is CorruptData, and stays as it '
        'was (SE3)', () async {
      touch('$tmp/lib/a.nsp');
      final file = File('$home/switch/games.json')..createSync(recursive: true);
      file.writeAsStringSync('{"games": 3}');
      await expectLater(
        addSwitchFolder(home, '$tmp/lib'),
        throwsA(
          isA<CorruptData>().having((f) => f.source, 'source', file.path),
        ),
      );
      expect(file.readAsStringSync(), '{"games": 3}');
    });
  });

  group('the settings', () {
    Object? saved() =>
        jsonDecode(File('$home/switch/settings.json').readAsStringSync());

    test('settings.json keeps only what differs from the defaults (SE4)', () {
      setSwitchOptions(home, fullscreen: false);
      expect(saved(), {'fullscreen': false});
      expect(switchSettings(home), (
        picked: null,
        fullscreen: false,
        headless: true,
      ));
      setSwitchOptions(home, fullscreen: true, headless: false);
      expect(saved(), {'headless': false});
      expect(switchSettings(home), (
        picked: null,
        fullscreen: true,
        headless: false,
      ));
      setSwitchOptions(home, headless: true);
      expect(saved(), <String, Object?>{});
      expect(switchSettings(home), (
        picked: null,
        fullscreen: true,
        headless: true,
      ));
    });

    test('a confirmed app is saved as the pick, and null forgets it '
        '(SE4)', () async {
      final app = fakeRyujinx('$tmp/picked/Ryujinx.app');
      await chooseEmulator(home, app);
      expect(saved(), {'picked': app});
      expect(switchSettings(home).picked, app);
      await chooseEmulator(home, null);
      expect(saved(), <String, Object?>{});
      expect(switchSettings(home).picked, isNull);
    });

    test('an option leaves the pick as it is (SE4)', () {
      final picked = '$tmp/picked/Ryujinx.app';
      File('$home/switch/settings.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode({'picked': picked}));
      setSwitchOptions(home, fullscreen: false);
      expect(saved(), {'picked': picked, 'fullscreen': false});
      expect(switchSettings(home), (
        picked: picked,
        fullscreen: false,
        headless: true,
      ));
    });

    test('a settings.json with a value of the wrong type is CorruptData, and '
        'stays as it was (SE3)', () {
      final file = File('$home/switch/settings.json')
        ..createSync(recursive: true);
      final corrupt = throwsA(
        isA<CorruptData>().having((f) => f.source, 'source', file.path),
      );
      for (final text in [
        '{"fullscreen": "yes"}',
        '{"headless": 1}',
        '{"picked": true}',
        '[]',
        'not json',
      ]) {
        file.writeAsStringSync(text);
        expect(() => switchSettings(home), corrupt, reason: text);
        expect(
          () => setSwitchOptions(home, fullscreen: false),
          corrupt,
          reason: text,
        );
        expect(file.readAsStringSync(), text);
      }
    });
  });

  group('the emulator host', () {
    final row = switchEmulators.single;
    final notHere = isA<NotAvailable>()
        .having((f) => f.what, 'what', 'switch')
        .having((f) => f.host, 'host', 'Linux');

    test('the Mac gives MacEmulators, and Linux the stub (SN1)', () {
      hostPlatform = const TestMac();
      expect(
        hostPlatform.emulators,
        isA<MacEmulators>().having((e) => e.supported, 'supported', isTrue),
      );
      hostPlatform = const LinuxPlatform(mangoHud: false);
      expect(
        hostPlatform.emulators,
        isA<LinuxEmulators>().having((e) => e.supported, 'supported', isFalse),
      );
    });

    test('the stub finds nothing, and the rest is NotAvailable: at once for '
        'files and env, as a failed future for the others (SN1)', () async {
      const linux = LinuxEmulators();
      expect(await linux.find(row, {'HOME': '/home/q'}), isNull);
      expect(() => linux.files(row), throwsA(notHere));
      expect(() => linux.env({'HOME': '/home/q'}), throwsA(notHere));
      for (final call in [
        () => linux.confirm(row, '/home/q/Ryujinx.app'),
        () => linux.nativeApp('/home/q/Game.app'),
        () => linux.runs(999999, '/bin/sleep'),
        () => linux.stop(999999, '/bin/sleep'),
      ]) {
        final future = call();
        await expectLater(future, throwsA(notHere));
      }
    });

    test('runs tells a pid that runs its exe, and stop signals only that, '
        'SIGTERM or SIGKILL (SN1)', () async {
      final mac = MacEmulators(root: tmp);
      final term = await Process.start('/bin/sleep', ['30']);
      final kill = await Process.start('/bin/sleep', ['30']);
      addTearDown(() {
        term.kill(ProcessSignal.sigkill);
        kill.kill(ProcessSignal.sigkill);
      });
      expect(await mac.runs(term.pid, '/bin/sleep'), isTrue);
      // As for a pid that was reused by another program.
      expect(await mac.runs(term.pid, '/bin/cat'), isFalse);
      await mac.stop(term.pid, '/bin/cat');
      expect(await mac.runs(term.pid, '/bin/sleep'), isTrue);

      await mac.stop(term.pid, '/bin/sleep');
      const within = Duration(seconds: 5);
      expect(
        await term.exitCode.timeout(within),
        -ProcessSignal.sigterm.signalNumber,
      );
      expect(await mac.runs(term.pid, '/bin/sleep'), isFalse);
      await mac.stop(kill.pid, '/bin/sleep', kill: true);
      expect(
        await kill.exitCode.timeout(within),
        -ProcessSignal.sigkill.signalNumber,
      );
      expect(await mac.runs(kill.pid, '/bin/sleep'), isFalse);
    });

    test("the Mac's files are the row's mac.files (SN1)", () {
      final files = MacEmulators(root: tmp).files(row);
      expect(files, row.mac!.files);
      expect(files!.data, [
        '<bin>/portable',
        '<dir>/portable',
        '~/Library/Application Support/Ryujinx',
      ]);
      expect(files.keys, '<data>/system/prod.keys');
      expect(files.userKeys, '~/.switch/prod.keys');
      expect(files.firmware, '<data>/bis/system/Contents/registered');
      expect(row.linux, isNull);
    });

    test("the emulator's environment is the session's, and only it (SN4)", () {
      final mac = MacEmulators(root: tmp);
      const path = {'PATH': '/usr/bin:/bin:/usr/sbin:/sbin'};
      expect(mac.env({...session, ...keptOut}), {...session, ...path});
      expect(mac.env({'HOME': '/Users/q'}), {'HOME': '/Users/q', ...path});
    });

    test('switchGames is the emulators being supported, not a literal '
        '(SN3)', () {
      hostPlatform = const TestMac();
      expect(hostCapabilities().switchGames, isTrue);
      expect(hostCapabilities().switchGames, hostPlatform.emulators.supported);
      hostPlatform = const LinuxPlatform(mangoHud: false);
      expect(hostCapabilities().switchGames, isFalse);
      expect(hostCapabilities().switchGames, hostPlatform.emulators.supported);
      hostPlatform = SwitchMac(const LinuxEmulators());
      expect(hostCapabilities().switchGames, isFalse);
    });

    test('find confirms the fixture through the seams, and finds nothing '
        'when no key reads (SN5)', () async {
      final app = fakeRyujinx('$tmp/Applications/Ryujinx.app');
      final emulators = hostPlatform.emulators;
      expect(await emulators.find(row, env), (
        app: app,
        exe: '$app/Contents/MacOS/Ryujinx',
        version: '1.3.3',
        picked: false,
        quarantined: false,
      ));
      quarantined.add(app);
      expect((await emulators.find(row, env))?.quarantined, isTrue);
      final native = fakeNative('$tmp/apps/Bodega Test.app');
      expect((await emulators.nativeApp(native))?.titleId, nativeTitleId);
      final unread = MacEmulators(root: tmp, plistKey: (_, _) async => null);
      expect(await unread.find(row, env), isNull);
      expect(await unread.nativeApp(native), isNull);
    });

    test('a native app is one whose Info.plist has DMTitleID, read through '
        'the seam; its executable must be a regular file with an exec bit in '
        'Contents/MacOS/, or it is null (SE6)', () async {
      final emulators = hostPlatform.emulators;
      final app = fakeNative('$tmp/apps/Bodega Test.app');
      final exe = '$app/Contents/MacOS/nxnative';
      final found = (titleId: nativeTitleId, exe: exe, quarantined: false);
      expect(await emulators.nativeApp(app), found);
      expect(await emulators.nativeApp('$app/'), found);
      fakeNative(app, executable: null);
      expect(await emulators.nativeApp(app), (
        titleId: nativeTitleId,
        exe: null,
        quarantined: false,
      ));
      fakeNative(app, mode: '644');
      expect((await emulators.nativeApp(app))?.exe, isNull);
      // A name that leaves Contents/MacOS/, even to come back, is none.
      fakeNative(app, executable: '../MacOS/nxnative');
      expect((await emulators.nativeApp(app))?.exe, isNull);
      fakeNative(app, dmTitleId: null);
      expect(await emulators.nativeApp(app), isNull);
      fakeNative(app, plist: false);
      expect(await emulators.nativeApp(app), isNull);
      expect(await emulators.nativeApp('$tmp/apps/nope.app'), isNull);
    });

    test("a native app's quarantine is what the seam says (SE7)", () async {
      final emulators = hostPlatform.emulators;
      final app = fakeNative('$tmp/apps/Bodega Test.app');
      expect((await emulators.nativeApp(app))?.quarantined, isFalse);
      quarantined.add(app);
      expect((await emulators.nativeApp(app))?.quarantined, isTrue);
    });

    test('find reads the fixture with the real plutil (SN5)', () async {
      final app = fakeRyujinx('$tmp/Applications/Ryujinx.app');
      final install = await MacEmulators(root: tmp).find(row, env);
      expect(install?.app, app);
      expect(install?.exe, '$app/Contents/MacOS/Ryujinx');
      expect(install?.version, '1.3.3');
      expect(install?.picked, isFalse);
    }, skip: needsPlutil);
  });

  group('the status', () {
    /// The install SE5 expects at [app].
    EmulatorInstall installAt(String app, {bool picked = false}) => (
      app: app,
      exe: '$app/Contents/MacOS/Ryujinx',
      version: '1.3.3',
      picked: picked,
      quarantined: false,
    );

    test('Ryubing is looked for in /Applications, then in ~/Applications, '
        'then at the pick (SE5)', () async {
      final fixed = fakeRyujinx('$tmp/Applications/Ryujinx.app');
      final mine = fakeRyujinx('$tmp/home/Applications/Ryujinx.app');
      final picked = fakeRyujinx('$tmp/picked/Ryujinx.app');
      await chooseEmulator(home, picked);
      Future<EmulatorInstall?> install() async =>
          (await checkSwitch(home, env)).install;

      expect(await install(), installAt(fixed));
      Directory(fixed).deleteSync(recursive: true);
      expect(await install(), installAt(mine));
      Directory(mine).deleteSync(recursive: true);
      expect(await install(), installAt(picked, picked: true));
      Directory(picked).deleteSync(recursive: true);
      expect(await install(), isNull);
    });

    test('an app that is not Ryubing is passed over, never an error '
        '(SE5)', () async {
      fakeRyujinx('$tmp/Applications/Ryujinx.app', id: 'com.yuzu-emu.yuzu');
      final mine = fakeRyujinx('$tmp/home/Applications/Ryujinx.app');
      expect((await checkSwitch(home, env)).install, installAt(mine));
    });

    test('only an app whose Info.plist names Ryubing, and whose executable '
        'can run, is confirmed or picked (SE6)', () async {
      setSwitchOptions(home, fullscreen: false);
      final settings = File('$home/switch/settings.json');
      final before = settings.readAsStringSync();
      final app = '$tmp/Applications/Ryujinx.app';
      for (final (broken, make) in [
        ('id', () => fakeRyujinx(app, id: 'com.yuzu-emu.yuzu')),
        ('executable', () => fakeRyujinx(app, executable: 'eden')),
        ('mode 644', () => fakeRyujinx(app, mode: '644')),
        ('no Info.plist', () => fakeRyujinx(app, plist: false)),
      ]) {
        make();
        await expectLater(
          chooseEmulator(home, app),
          throwsA(
            isA<NotAnEmulator>()
                .having((f) => f.path, 'path', app)
                .having((f) => f.name, 'name', 'Ryubing'),
          ),
          reason: broken,
        );
        expect(settings.readAsStringSync(), before, reason: broken);
        expect((await checkSwitch(home, env)).install, isNull, reason: broken);
        Directory(app).deleteSync(recursive: true);
      }
      await expectLater(
        chooseEmulator(home, '$tmp/nope.app'),
        throwsA(
          isA<NotAnEmulator>()
              .having((f) => f.path, 'path', '$tmp/nope.app')
              .having((f) => f.name, 'name', 'Ryubing'),
        ),
      );
      expect(settings.readAsStringSync(), before);
    });

    test('an app without a version is confirmed with none, and a pick is '
        'kept without its trailing / (SE6)', () async {
      final app = fakeRyujinx('$tmp/picked/Ryujinx.app', version: null);
      await chooseEmulator(home, '$app/');
      expect(switchSettings(home).picked, app);
      expect((await checkSwitch(home, env)).install, (
        app: app,
        exe: '$app/Contents/MacOS/Ryujinx',
        version: null,
        picked: true,
        quarantined: false,
      ));
    });

    test('the real plutil confirms the fixture and refuses another id '
        '(SE6)', () async {
      final mac = MacEmulators(root: tmp);
      final row = switchEmulators.single;
      final app = fakeRyujinx('$tmp/Applications/Ryujinx.app');
      expect((await mac.confirm(row, app))?.version, '1.3.3');
      final other = fakeRyujinx('$tmp/b/Ryujinx.app', id: 'com.yuzu-emu.yuzu');
      expect(await mac.confirm(row, other), isNull);
      final native = fakeNative('$tmp/apps/Bodega Test.app');
      final found = await mac.nativeApp(native);
      expect(found?.titleId, nativeTitleId);
      expect(found?.exe, '$native/Contents/MacOS/nxnative');
      fakeNative(native, dmTitleId: null);
      expect(await mac.nativeApp(native), isNull);
    }, skip: needsPlutil);

    test('quarantine is what the seam says, per copy (SE7)', () async {
      final fixed = fakeRyujinx('$tmp/Applications/Ryujinx.app');
      final mine = fakeRyujinx('$tmp/home/Applications/Ryujinx.app');
      quarantined.add(fixed);
      expect((await checkSwitch(home, env)).install?.quarantined, isTrue);
      Directory(fixed).deleteSync(recursive: true);
      expect((await checkSwitch(home, env)).install?.app, mine);
      expect((await checkSwitch(home, env)).install?.quarantined, isFalse);
    });

    test('keys and firmware are found by name, never read: an empty '
        'prod.keys at mode 000 counts (SE8)', () async {
      fakeRyujinx('$tmp/Applications/Ryujinx.app');
      final data = '$tmp/home/Library/Application Support/Ryujinx';
      chmod('000', touch('$data/system/prod.keys').path);
      final registered = '$data/bis/system/Contents/registered';
      Directory(registered).createSync(recursive: true);
      var status = await checkSwitch(home, env);
      expect((status.keys, status.firmware), (true, false));
      chmod('000', touch('$registered/made-up.nca').path);
      status = await checkSwitch(home, env);
      expect((status.keys, status.firmware), (true, true));
    }, skip: asRoot ? rootSkip : false);

    test("the user's own keys count only with the default data folder, or "
        'with none (SE8)', () async {
      fakeRyujinx('$tmp/Applications/Ryujinx.app');
      touch('$tmp/home/.switch/prod.keys');
      Future<bool> keys() async => (await checkSwitch(home, env)).keys;
      expect(await keys(), isTrue, reason: 'no data folder');
      Directory('$tmp/home/Library/Application Support/Ryujinx')
          .createSync(recursive: true);
      expect(await keys(), isTrue, reason: 'the default one');
      Directory('$tmp/Applications/portable').createSync();
      expect(await keys(), isFalse, reason: '<dir>/portable');
      touch(
        '$tmp/Applications/Ryujinx.app/Contents/MacOS/portable/system/'
        'prod.keys',
      );
      expect(await keys(), isTrue, reason: '<bin>/portable');
    });

    test('with nothing there, the status says so and throws nothing; nothing '
        'outside tmp is looked at (SE8, SN5)', () async {
      final status = await checkSwitch(home, env);
      expect(status.emulator, switchEmulators.single);
      expect(status.install, isNull);
      expect(status.keys, isFalse);
      expect(status.firmware, isFalse);
    });
  });

  test('on Linux, what needs an emulator is NotAvailable before it touches '
      'switch/ (SE9, SN2)', () async {
    final game = touch('$tmp/games/$gameName').path;
    await addSwitchGames(home, [game]);
    final games = File('$home/switch/games.json').readAsStringSync();
    fakeRyujinx('$tmp/Applications/Ryujinx.app');
    final native = fakeNative('$tmp/apps/Bodega Test.app');
    hostPlatform = const LinuxPlatform(mangoHud: false);
    final notHere = throwsA(
      isA<NotAvailable>()
          .having((f) => f.what, 'what', 'switch')
          .having((f) => f.host, 'host', 'Linux'),
    );
    await expectLater(checkSwitch(home, env), notHere);
    await expectLater(
      chooseEmulator(home, '$tmp/Applications/Ryujinx.app'),
      notHere,
    );
    await expectLater(chooseEmulator(home, null), notHere);
    await expectLater(openSwitchGame(home, game, env), notHere);
    await expectLater(stopSwitchGame(home, game), notHere);
    await expectLater(switchRuns(home), notHere);
    // A native app needs the host, as an emulator does (SE10).
    await expectLater(addSwitchGames(home, [native]), notHere);
    await expectLater(addSwitchGames(home, ['$tmp/apps/nope.app']), notHere);
    expect(names('$home/switch'), ['games.json']);
    expect(File('$home/switch/games.json').readAsStringSync(), games);

    // The store works as on the Mac (SN2).
    final other = touch('$tmp/games/Homebrew Tool.nro').path;
    expect(await addSwitchGames(home, [other, game]), (added: 1, known: 1));
    expect(switchGames(home).map((game) => game.path), [game, other]);
    removeSwitchGame(home, other);
    expect(switchGames(home).map((game) => game.path), [game]);
    expect(names('$home/switch'), ['games.json']);
  });

  group('the launch', () {
    late String app, exe;

    setUp(() {
      app = fakeRyujinx('$tmp/Applications/Ryujinx.app');
      exe = '$app/Contents/MacOS/Ryujinx';
    });

    /// The game, or a game file named [name], in the list.
    Future<String> listed([String name = gameName]) async {
      final game = touch('$tmp/games/$name').path;
      await addSwitchGames(home, [game]);
      return game;
    }

    /// What the fake wrote in `$HOME/<name>`, line by line.
    List<String> recorded(String name) =>
        File('$tmp/home/$name').readAsLinesSync();

    /// Opens [game] with [parent], or else SE23's env, and waits for the run's
    /// end. With [hang], it waits instead until the fake has written what it
    /// got, the last being `ppid`, and has the run end before tmp goes away.
    Future<String> open(
      String game, {
      bool hang = false,
      Map<String, String>? parent,
    }) async {
      for (final name in ['argv', 'cwd', 'env', 'pid', 'ppid']) {
        final file = File('$tmp/home/$name');
        if (file.existsSync()) file.deleteSync();
      }
      final hanging = File('$tmp/home/hang');
      if (hang) hanging.createSync();
      final log = await openSwitchGame(home, game, parent ?? env);
      const wait = Duration(seconds: 10);
      if (!hang) {
        await exitOf(log).timeout(wait);
        return log;
      }
      addTearDown(() async {
        if (hanging.existsSync()) hanging.deleteSync();
        await exitOf(log).timeout(wait);
      });
      final ppid = File('$tmp/home/ppid');
      final clock = Stopwatch()..start();
      while (!(ppid.existsSync() && ppid.readAsStringSync().endsWith('\n'))) {
        if (clock.elapsed > wait) fail('the fake did not start');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return log;
    }

    /// What a run that lives leaves: a log whose header names [game] and the
    /// fixture, and a `.pid` holding [pid], with no `.exit`.
    String fakeRun(String label, int pid, String game) {
      final log = '$home/switch/logs/2026-01-01T00-00-00.000000Z-$label.log';
      File(log)
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '# emulator Ryubing 1.3.3\n# exe $exe\n# game $game\n'
          '# cwd $tmp/home\n# argv $exe $game\n',
        );
      File('${log.substring(0, log.length - 4)}.pid')
          .writeAsStringSync('$pid\n');
      return log;
    }

    test('the argv follows the settings, the game last, and the emulator '
        'starts in HOME with no keys or firmware there (SE14)', () async {
      final game = await listed();
      await open(game);
      expect(recorded('argv'), [
        '--no-gui',
        '--use-main-config',
        '--fullscreen',
        game,
      ]);
      expect(recorded('cwd'), ['$tmp/home']);
      setSwitchOptions(home, fullscreen: false);
      await open(game);
      expect(recorded('argv'), ['--no-gui', '--use-main-config', game]);
      setSwitchOptions(home, fullscreen: true, headless: false);
      await open(game);
      expect(recorded('argv'), ['--fullscreen', game]);
      setSwitchOptions(home, fullscreen: false);
      await open(game);
      expect(recorded('argv'), [game]);
    });

    test("the emulator gets the session from env, and none of Wine's, "
        ".NET's, Bodega's or DM_ keys, nor a USER env lacks (SE14)", () async {
      final game = await listed();
      await open(game);
      final lines = recorded('env');
      expect(
        lines,
        containsAll([
          'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
          'HOME=$tmp/home',
          'LOGNAME=q',
          'TMPDIR=/var/folders/x/T/',
          '__CF_USER_TEXT_ENCODING=0x1F5:0x0:0x8',
        ]),
      );
      for (final out in [
        'WINE',
        'DOTNET_',
        'ROSETTA_',
        'MVK_',
        'DYLD_',
        'LANG=',
        'BODEGA_',
        'DM_',
        'USER=',
      ]) {
        expect(
          lines.where((line) => line.startsWith(out)),
          isEmpty,
          reason: out,
        );
      }
    });

    test('open checks, in order, the list, the file, the runs and the '
        'emulator (SE14)', () async {
      Directory(app).deleteSync(recursive: true);
      final game = touch('$tmp/games/$gameName').path;
      await expectLater(
        openSwitchGame(home, game, env),
        throwsA(isA<SwitchGameNotFound>().having((f) => f.path, 'path', game)),
      );
      await addSwitchGames(home, [game]);
      File(game).deleteSync();
      await expectLater(
        openSwitchGame(home, game, env),
        throwsA(isA<MissingFile>().having((f) => f.path, 'path', game)),
      );
      touch(game);
      await expectLater(
        openSwitchGame(home, game, env),
        throwsA(
          isA<NoEmulator>()
              .having((f) => f.name, 'name', 'Ryubing')
              .having((f) => f.app, 'app', 'Ryujinx.app'),
        ),
      );
      fakeRyujinx(app);
      await open(game, hang: true);
      File('$app/Contents/Info.plist').deleteSync();
      await expectLater(
        openSwitchGame(home, game, env),
        throwsA(isA<SwitchGameRunning>().having((f) => f.path, 'path', game)),
      );
    });

    test('each run has its own log, stamped and labelled, whose header never '
        'holds the environment (SE15)', () async {
      final game = await listed();
      final log = await open(game);
      final name = log.split('/').last;
      expect(log, '$home/switch/logs/$name');
      expect(name, endsWith('-Bodega_Test.log'));
      expect(
        name.substring(0, name.length - '-Bodega_Test.log'.length),
        matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d-\d\d-\d\d\.\d{6}Z$')),
      );
      final header = File(log).readAsLinesSync().take(5).toList();
      expect(header, [
        '# emulator Ryubing 1.3.3',
        '# exe $exe',
        '# game $game',
        '# cwd $tmp/home',
        '# argv $exe --no-gui --use-main-config --fullscreen $game',
      ]);
      expect(
        header.where(
          (line) => line.contains('PATH=') || line.contains('HOME='),
        ),
        isEmpty,
      );
    });

    test('the label is the title, made safe and cut at 40, and a Ryubing '
        'without a version is named alone (SE15)', () async {
      fakeRyujinx(app, version: null);
      final long = await listed('${'a' * 50}.nsp');
      expect((await open(long)).split('/').last, endsWith('-${'a' * 40}.log'));
      final log = await open(await listed('Bodega Test: Tøst.nsp'));
      expect(log.split('/').last, endsWith('-Bodega_Test__T_st.log'));
      expect(File(log).readAsLinesSync().first, '# emulator Ryubing');
    });

    test("the .pid holds the emulator's pid, not the shell's, and the shell "
        'writes # exit and .exit, which exitOf reads (SE16, SE17)', () async {
      final game = await listed();
      File('$tmp/home/code').writeAsStringSync('7\n');
      final log = await open(game, hang: true);
      final stem = log.substring(0, log.length - '.log'.length);
      final pid = File('$stem.pid').readAsStringSync().trim();
      expect(pid, recorded('pid').single);
      expect(pid, isNot(recorded('ppid').single));
      final ps = await Process.run('/bin/ps', [
        '-ww',
        '-p',
        pid,
        '-o',
        'command=',
      ]);
      expect(ps.exitCode, 0);
      expect('${ps.stdout}', contains(exe));
      expect(File('$stem.exit').existsSync(), isFalse);

      File('$tmp/home/hang').deleteSync();
      expect(await exitOf(log), 7);
      expect(File(log).readAsLinesSync().last, '# exit=7');
      expect(File('$stem.exit').readAsStringSync(), '7\n');
      expect(
        names('$home/switch/logs')
            .where((name) => name.endsWith('.p') || name.endsWith('.x')),
        isEmpty,
      );
    });

    test('a HOME that is not there is ProcessFailed, with no exit code '
        '(SE16)', () async {
      final game = await listed();
      await expectLater(
        openSwitchGame(home, game, {...env, 'HOME': '$tmp/nope'}),
        throwsA(
          isA<ProcessFailed>()
              .having((f) => f.command, 'command', exe)
              .having((f) => f.exitCode, 'exitCode', isNull),
        ),
      );
    });

    test('switchRuns finds the run that lives: not one that ended, nor a pid '
        'that runs something else or nothing (SE18)', () async {
      final game = await listed();
      await open(game);
      final live = await open(game, hang: true);
      final sleep = await Process.start('/bin/sleep', ['30']);
      addTearDown(sleep.kill);
      final gone = await Process.start('/usr/bin/true', []);
      await gone.exitCode;
      fakeRun('sleep', sleep.pid, game);
      fakeRun('gone', gone.pid, game);
      expect(await switchRuns(home), [(game: game, log: live)]);
    });

    test('a log whose pid runs something else does not keep the game from '
        'opening (SE18)', () async {
      final game = await listed();
      final sleep = await Process.start('/bin/sleep', ['30']);
      addTearDown(sleep.kill);
      final stale = fakeRun('sleep', sleep.pid, game);
      expect(await switchRuns(home), isEmpty);
      final log = await open(game);
      expect(log, isNot(stale));
      expect(await exitOf(log), 0);
      expect(
        await MacEmulators(root: tmp).runs(sleep.pid, '/bin/sleep'),
        isTrue,
      );
    });

    test("a run is followed with Wine's exitOf, which waits for the .exit "
        'the shell writes (SE17)', () async {
      final game = await listed();
      File('$tmp/home/code').writeAsStringSync('7\n');
      final log = await open(game, hang: true);
      int? code;
      final following = exitOf(log).then((exit) => code = exit);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(code, isNull, reason: 'the game still runs');
      File('$tmp/home/hang').deleteSync();
      expect(await following.timeout(const Duration(seconds: 10)), 7);
    });

    test('Stop sends SIGTERM to the emulator and never to the shell, which '
        'lives to write 143 (SE19)', () async {
      final game = await listed();
      final log = await open(game, hang: true);
      final stem = log.substring(0, log.length - '.log'.length);
      expect(
        File('$stem.pid').readAsStringSync().trim(),
        recorded('pid').single,
      );
      await stopSwitchGame(home, game);
      expect(File('$tmp/home/hang').existsSync(), isTrue);
      expect(File('$stem.exit').readAsStringSync(), '143\n');
      expect(File(log).readAsLinesSync().last, '# exit=143');
      expect(await exitOf(log), 143);
      expect(await switchRuns(home), isEmpty);
    });

    test('an emulator deaf to SIGTERM gets SIGKILL after about 5 s: 137 '
        '(SE19)', () async {
      final game = await listed();
      File('$tmp/home/deaf').createSync();
      final log = await open(game, hang: true);
      final clock = Stopwatch()..start();
      await stopSwitchGame(home, game);
      expect(clock.elapsed, greaterThanOrEqualTo(const Duration(seconds: 5)));
      expect(clock.elapsed, lessThan(const Duration(seconds: 10)));
      expect(await exitOf(log).timeout(const Duration(seconds: 5)), 137);
      expect(File(log).readAsLinesSync().last, '# exit=137');
    });

    test('a game removed from the list while it runs is still stopped '
        '(SE19)', () async {
      final game = await listed();
      final log = await open(game, hang: true);
      removeSwitchGame(home, game);
      await stopSwitchGame(home, '$tmp/games/x/../$gameName');
      expect(await exitOf(log).timeout(const Duration(seconds: 5)), 143);
    });

    test('Stop of a listed game with no live run is a no-op that signals '
        'nothing; of a path neither listed nor running, SwitchGameNotFound '
        '(SE19)', () async {
      final game = await listed();
      await stopSwitchGame(home, game);
      final sleep = await Process.start('/bin/sleep', ['30']);
      addTearDown(sleep.kill);
      final stale = fakeRun('sleep', sleep.pid, game);
      await stopSwitchGame(home, game);
      expect(
        await MacEmulators(root: tmp).runs(sleep.pid, '/bin/sleep'),
        isTrue,
      );
      expect(
        File(stale.replaceFirst(RegExp(r'\.log$'), '.exit')).existsSync(),
        isFalse,
      );
      final other = '$tmp/games/other.nsp';
      await expectLater(
        stopSwitchGame(home, other),
        throwsA(isA<SwitchGameNotFound>().having((f) => f.path, 'path', other)),
      );
    });

    test("the emulator's whole environment is the host's env of the parent "
        '(SN4)', () async {
      final game = await listed();
      final parent = {...session, ...keptOut, 'HOME': '$tmp/home'};
      await open(game, parent: parent);
      final got = {
        for (final line in recorded('env'))
          if (line.indexOf('=') case final at when at > 0)
            line.substring(0, at): line.substring(at + 1),
      }..removeWhere((key, _) => {'PWD', 'SHLVL', '_', 'OLDPWD'}.contains(key));
      expect(got, hostPlatform.emulators.env(parent));
      expect(got, {
        ...session,
        'HOME': '$tmp/home',
        'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
      });
    });

    test("the CLI's open prints the run's log, waits for its end and gives "
        'its code (SE21)', () async {
      final game = await listed();
      File('$tmp/home/code').writeAsStringSync('7\n');
      final lines = await cli(['open', game], code: 7);
      final logs = [
        for (final name in names('$home/switch/logs'))
          if (name.endsWith('.log')) '$home/switch/logs/$name',
      ];
      expect(lines, ['log: ${logs.single}']);
      expect(recorded('argv').last, game);
    });

    test("the CLI's stop ends a running game with 143, is a no-op for a "
        'listed game with no run, and refuses a path neither listed nor '
        'running (SE21, SE19)', () async {
      final game = await listed();
      expect(await cli(['stop', game]), isEmpty);
      final log = await open(game, hang: true);
      expect(await cli(['stop', game]), isEmpty);
      expect(await exitOf(log).timeout(const Duration(seconds: 10)), 143);
      final other = '$tmp/games/other.nsp';
      await expectLater(
        cli(['stop', other]),
        throwsA(isA<SwitchGameNotFound>().having((f) => f.path, 'path', other)),
      );
    });

    test('the real tools report the quarantine, and checkSwitch and '
        'openSwitchGame leave it as it was (SE7)', () async {
      const attribute = 'com.apple.quarantine', value = '0081;00000000;Test;';
      final mark = await Process.run('/usr/bin/xattr', [
        '-w',
        attribute,
        value,
        app,
      ]);
      expect(mark.exitCode, 0);
      hostPlatform = SwitchMac(MacEmulators(root: tmp));
      expect((await checkSwitch(home, env)).install?.quarantined, isTrue);
      // Never the exec: macOS holds a quarantined app that was never opened
      // until the user answers its prompt, which only the user sees (SN19).
      // A HOME that is not there stops the launch right before it.
      await expectLater(
        openSwitchGame(home, await listed(), {...env, 'HOME': '$tmp/nope'}),
        throwsA(isA<ProcessFailed>().having((f) => f.command, 'command', exe)),
      );
      final read = await Process.run('/usr/bin/xattr', ['-p', attribute, app]);
      expect(read.exitCode, 0);
      expect('${read.stdout}'.trim(), value);
    }, skip: needsMacOS);

    group('of a native app', () {
      late String native, nativeExe;

      setUp(() async {
        // No Ryubing anywhere: a native app needs none, nor keys or firmware.
        Directory(app).deleteSync(recursive: true);
        native = fakeNative('$tmp/apps/Bodega Test.app');
        nativeExe = '$native/Contents/MacOS/nxnative';
        await addSwitchGames(home, [native]);
      });

      test('starts its executable alone, in HOME, whatever the settings say '
          '(SE14)', () async {
        await open(native);
        expect(recorded('argv'), isEmpty);
        expect(recorded('cwd'), ['$tmp/home']);
        setSwitchOptions(home, fullscreen: false, headless: false);
        await open(native);
        expect(recorded('argv'), isEmpty);
      });

      test('checks, in order, the list, the app, the runs and what makes a '
          'native app: one that lost DMTitleID or whose executable cannot '
          'run is NotASwitchGame, never NoEmulator (SE14)', () async {
        final other = '$tmp/apps/Other.app';
        await expectLater(
          openSwitchGame(home, other, env),
          throwsA(
            isA<SwitchGameNotFound>().having((f) => f.path, 'path', other),
          ),
        );
        fakeNative(other);
        await addSwitchGames(home, [other]);
        Directory(other).deleteSync(recursive: true);
        await expectLater(
          openSwitchGame(home, other, env),
          throwsA(isA<MissingFile>().having((f) => f.path, 'path', other)),
        );

        final notOne = throwsA(
          isA<NotASwitchGame>()
              .having((f) => f.path, 'path', native)
              .having((f) => f.extensions, 'extensions', extensions),
        );
        fakeNative(native, dmTitleId: null);
        await expectLater(openSwitchGame(home, native, env), notOne);
        fakeNative(native, mode: '644');
        await expectLater(openSwitchGame(home, native, env), notOne);
        expect(names('$home/switch'), isNot(contains('logs')));

        fakeNative(native);
        await open(native, hang: true);
        // Only the Info.plist changes: the running script stays as it is.
        File('$native/Contents/Info.plist')
            .writeAsStringSync(infoPlist({'CFBundleExecutable': 'nxnative'}));
        await expectLater(
          openSwitchGame(home, native, env),
          throwsA(
            isA<SwitchGameRunning>().having((f) => f.path, 'path', native),
          ),
        );
      });

      test("gets the host's env of the parent, with no DM_ variable, nor "
          'USER where env lacks it (SE14, SN4)', () async {
        final parent = {...session, ...keptOut, 'HOME': '$tmp/home'};
        await open(native, parent: parent);
        final got =
            {
              for (final line in recorded('env'))
                if (line.indexOf('=') case final at when at > 0)
                  line.substring(0, at): line.substring(at + 1),
            }..removeWhere(
              (key, _) => {'PWD', 'SHLVL', '_', 'OLDPWD'}.contains(key),
            );
        expect(got, hostPlatform.emulators.env(parent));

        await open(native);
        final lines = recorded('env');
        expect(
          lines,
          containsAll([
            'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
            'HOME=$tmp/home',
            'LOGNAME=q',
            'TMPDIR=/var/folders/x/T/',
            '__CF_USER_TEXT_ENCODING=0x1F5:0x0:0x8',
          ]),
        );
        for (final out in [
          'WINE',
          'DOTNET_',
          'ROSETTA_',
          'MVK_',
          'DYLD_',
          'LANG=',
          'BODEGA_',
          'DM_',
          'USER=',
        ]) {
          expect(
            lines.where((line) => line.startsWith(out)),
            isEmpty,
            reason: out,
          );
        }
      });

      test('its header starts with its title id, and its log is labelled by '
          'its title (SE15)', () async {
        final log = await open(native);
        expect(log.split('/').last, endsWith('-Bodega_Test.log'));
        expect(File(log).readAsLinesSync().take(5), [
          '# native $nativeTitleId',
          '# exe $nativeExe',
          '# game $native',
          '# cwd $tmp/home',
          '# argv $nativeExe',
        ]);
      });

      test('its .pid holds its own pid, its run is found, and .exit keeps '
          'the 134 of an abort as it is (SE16, SE18)', () async {
        File('$tmp/home/code').writeAsStringSync('134\n');
        final log = await open(native, hang: true);
        final stem = log.substring(0, log.length - '.log'.length);
        expect(
          File('$stem.pid').readAsStringSync().trim(),
          recorded('pid').single,
        );
        expect(await switchRuns(home), [(game: native, log: log)]);
        File('$tmp/home/hang').deleteSync();
        expect(await exitOf(log).timeout(const Duration(seconds: 10)), 134);
        expect(File('$stem.exit').readAsStringSync(), '134\n');
        expect(await switchRuns(home), isEmpty);
      });

      test('Stop ends its run with 143 (SE19)', () async {
        final log = await open(native, hang: true);
        await stopSwitchGame(home, native);
        expect(File('$tmp/home/hang').existsSync(), isTrue);
        expect(await exitOf(log), 143);
        expect(File(log).readAsLinesSync().last, '# exit=143');
      });

      test("the CLI's open needs no Ryubing and gives its 134 as it is "
          '(SE21)', () async {
        File('$tmp/home/code').writeAsStringSync('134\n');
        final lines = await cli(['open', native], code: 134);
        expect(lines, [startsWith('log: $home/switch/logs/')]);
        expect(recorded('argv'), isEmpty);
      });

      test('the real tools report its quarantine, and nativeApp and '
          'openSwitchGame leave it as it was (SE7)', () async {
        const attribute = 'com.apple.quarantine';
        const value = '0081;00000000;Test;';
        final mark = await Process.run('/usr/bin/xattr', [
          '-w',
          attribute,
          value,
          native,
        ]);
        expect(mark.exitCode, 0);
        hostPlatform = SwitchMac(MacEmulators(root: tmp));
        expect(
          (await hostPlatform.emulators.nativeApp(native))?.quarantined,
          isTrue,
        );
        // Never the exec, as for the emulator: a HOME that is not there stops
        // the launch right before it.
        await expectLater(
          openSwitchGame(home, native, {...env, 'HOME': '$tmp/nope'}),
          throwsA(
            isA<ProcessFailed>().having((f) => f.command, 'command', nativeExe),
          ),
        );
        final read = await Process.run('/usr/bin/xattr', [
          '-p',
          attribute,
          native,
        ]);
        expect(read.exitCode, 0);
        expect('${read.stdout}'.trim(), value);
      }, skip: needsMacOS);
    });
  });

  test('a native app is asked of the emulators given, so that it adds the '
      'same in Isolate.run, whose own host is the one the test runs on '
      '(SE9)', () async {
    final native = fakeNative('$tmp/apps/Bodega Test.app');
    final emulators = hostPlatform.emulators;
    final homes = [
      for (final name in ['outside', 'inside', 'no-host'])
        bodegaHome({'BODEGA_HOME': '$tmp/$name'}),
    ];
    final [outside, inside, noHost] = homes;
    expect(await addSwitchGames(outside, [native], emulators: emulators), (
      added: 1,
      known: 0,
    ));
    expect(
      await Isolate.run(
        () => addSwitchGames(inside, [native], emulators: emulators),
      ),
      (added: 1, known: 0),
    );
    // Only the emulators given are asked: a host whose every member throws
    // changes nothing, for an add or a scan.
    expect(
      await Isolate.run(() async {
        hostPlatform = NoHost();
        return [
          await addSwitchGames(noHost, [native], emulators: emulators),
          await addSwitchFolder(noHost, '$tmp/apps', emulators: emulators),
        ];
      }),
      [(added: 1, known: 0), (added: 0, known: 1)],
    );
    for (final home in homes) {
      expect(
        switchGames(home).map((game) => (game.path, game.title, game.titleId)),
        [(native, 'Bodega Test', null)],
        reason: home,
      );
    }
  });

  test('the store never asks the host, so it gives the same on any host and '
      'in Isolate.run (SE9)', () async {
    expect(() => NoHost().displayName, throwsStateError);
    final game = touch('$tmp/games/$gameName').path;
    final lib = '$tmp/lib';
    touch('$lib/Homebrew Tool.nro');
    touch('$lib/x/OTHER.XCI');
    final homes = [
      for (final name in ['mac', 'no-host', 'isolate'])
        bodegaHome({'BODEGA_HOME': '$tmp/$name'}),
    ];

    final onMac = await storeCalls(homes[0], game, lib);
    expect(onMac, [
      (added: 1, known: 0),
      (added: 2, known: 0),
      [
        (game, 'Bodega Test', '0100F00DBA5E0000', true),
        ('$lib/Homebrew Tool.nro', 'Homebrew Tool', null, true),
        ('$lib/x/OTHER.XCI', 'OTHER', null, true),
      ],
      ['$lib/Homebrew Tool.nro', '$lib/x/OTHER.XCI'],
      (picked: null, fullscreen: true, headless: true),
      (picked: null, fullscreen: false, headless: true),
    ]);

    hostPlatform = NoHost();
    expect(await storeCalls(homes[1], game, lib), onMac);
    final isolated = homes[2];
    expect(
      await Isolate.run(() {
        hostPlatform = NoHost();
        return storeCalls(isolated, game, lib);
      }),
      onMac,
    );
  });

  group('the CLI', () {
    /// The keys and a firmware entry, in the default data folder.
    void keysAndFirmware() {
      final data = '$tmp/home/Library/Application Support/Ryujinx';
      touch('$data/system/prod.keys');
      touch('$data/bis/system/Contents/registered/made-up.nca');
    }

    test('needsHost is false for the switch verbs alone, as parseOpen is '
        'tested (SE22)', () {
      expect(needsHost(['switch', 'status']), isFalse);
      expect(needsHost(['switch', 'open', '/a b.nsp']), isFalse);
      expect(needsHost(['switch']), isFalse);
      expect(needsHost(['open', 'steam']), isTrue);
      expect(needsHost(['pads']), isTrue);
      expect(needsHost(['apps']), isTrue);
      expect(needsHost([]), isTrue);
    });

    test('a bad usage is no verb, which the CLI answers with its usage '
        '(SE21)', () {
      for (final args in [
        <String>[],
        ['nope'],
        ['add'],
        ['open', 'a', 'b'],
        ['option', 'fullscreen', 'maybe'],
        ['option', 'volume', 'on'],
        ['emulator'],
        ['list', 'all'],
      ]) {
        expect(switchVerb(args, StringBuffer(), env), isNull, reason: '$args');
      }
    });

    test('status names the emulator, the keys and the firmware, and gives 0 '
        'only when all three are there (SE21)', () async {
      final app = fakeRyujinx('$tmp/Applications/Ryujinx.app');
      final data = '$tmp/home/Library/Application Support/Ryujinx';
      final keys = touch('$data/system/prod.keys');
      final firmware = touch(
        '$data/bis/system/Contents/registered/made-up.nca',
      );
      final found = 'emulator: Ryubing 1.3.3 at $app';
      expect(await cli(['status']), [found, 'keys: found', 'firmware: found']);
      quarantined.add(app);
      expect(await cli(['status']), [
        found,
        'keys: found',
        'firmware: found',
        quarantineNote(app, 'Ryubing'),
      ]);
      quarantined.clear();
      keys.deleteSync();
      expect(await cli(['status'], code: 1), [
        found,
        'keys: missing (prod.keys)',
        'firmware: found',
      ]);
      touch(keys.path);
      firmware.deleteSync();
      expect(await cli(['status'], code: 1), [
        found,
        'keys: found',
        'firmware: missing',
      ]);
      Directory(app).deleteSync(recursive: true);
      expect(await cli(['status'], code: 1), [
        'emulator: missing',
        'keys: found',
        'firmware: missing',
        'note: Ryubing not found: Bodega looks for Ryujinx.app in '
            '/Applications and ~/Applications, or takes one from bodega '
            'switch emulator <path>',
        'note: download Ryubing from https://ryujinx.app/download, put '
            'Ryujinx.app in /Applications, then run bodega switch status '
            'again',
      ]);
    });

    test('status marks a pick, and names an emulator without a version '
        'alone (SE21)', () async {
      keysAndFirmware();
      final app = fakeRyujinx('$tmp/picked/Ryujinx.app', version: null);
      expect(await cli(['emulator', '$app/']), isEmpty);
      expect(
        (await cli(['status'])).first,
        'emulator: Ryubing at $app (picked)',
      );
      fakeRyujinx(app);
      expect(
        (await cli(['status'])).first,
        'emulator: Ryubing 1.3.3 at $app (picked)',
      );
    });

    test('status adds a note for each listed native app in quarantine, and '
        'gives what it gives without them (SE21)', () async {
      final native = fakeNative('$tmp/apps/Bodega Test.app');
      final other = fakeNative('$tmp/apps/Other.app');
      final game = touch('$tmp/games/$gameName').path;
      await cli(['add', native, other, game]);
      final none = await cli(['status'], code: 1);
      quarantined.addAll([native, game]);
      expect(await cli(['status'], code: 1), [
        ...none,
        quarantineNote(native, 'it'),
      ]);
      final app = fakeRyujinx('$tmp/Applications/Ryujinx.app');
      keysAndFirmware();
      final found = ['emulator: Ryubing 1.3.3 at $app', 'keys: found'];
      expect(await cli(['status']), [
        ...found,
        'firmware: found',
        quarantineNote(native, 'it'),
      ]);
      quarantined.add(app);
      expect(await cli(['status']), [
        ...found,
        'firmware: found',
        quarantineNote(app, 'Ryubing'),
        quarantineNote(native, 'it'),
      ]);
    });

    test('add scans a folder and names what it added, by title, then how '
        'many were listed already; list gives title, id and path '
        '(SE21)', () async {
      final game = touch('$tmp/games/$gameName').path;
      final tool = touch('$tmp/games/Homebrew Tool.nro').path;
      expect(await cli(['add', '$tmp/games']), [
        'added: Bodega Test',
        'added: Homebrew Tool',
        'already listed: 0',
      ]);
      expect(await cli(['add', '$tmp/games']), ['already listed: 2']);
      expect(await cli(['list']), [
        'Bodega Test  0100F00DBA5E0000  $game',
        'Homebrew Tool  -  $tool',
      ]);
    });

    test('add takes an app as an item, never as a folder to scan '
        '(SE21)', () async {
      final native = fakeNative('$tmp/apps/Bodega Test.app');
      touch('$native/h.nsp');
      expect(await cli(['add', native]), [
        'added: Bodega Test',
        'already listed: 0',
      ]);
      expect(await cli(['list']), ['Bodega Test  -  $native']);
      // A scan would pass over an app that is not a native app; an item is
      // refused (SE10).
      final tool = fakeNative('$tmp/apps/Tool.app', dmTitleId: null);
      await expectLater(
        cli(['add', tool]),
        throwsA(isA<NotASwitchGame>().having((f) => f.path, 'path', tool)),
      );
    });

    test('add checks its files and apps in one call before it writes, and '
        'then scans its folders (SE21, SE10)', () async {
      final game = touch('$tmp/games/$gameName').path;
      final readme = touch('$tmp/games/readme.txt').path;
      touch('$tmp/lib/x/b.XCI');
      await expectLater(
        cli(['add', '$tmp/lib', game, readme]),
        throwsA(isA<NotASwitchGame>().having((f) => f.path, 'path', readme)),
      );
      expect(names(home), isNot(contains('switch')));
      final native = fakeNative('$tmp/apps/Bodega Test.app');
      expect(await cli(['add', '$tmp/lib', native, game]), [
        'added: b',
        'added: Bodega Test',
        'added: Bodega Test',
        'already listed: 0',
      ]);
      expect(await cli(['add', game, '$tmp/lib', '$tmp/apps']), [
        'already listed: 3',
      ]);
    });

    test('emulator, option and remove print nothing; auto forgets the pick '
        '(SE21)', () async {
      final picked = fakeRyujinx('$tmp/picked/Ryujinx.app');
      expect(await cli(['emulator', picked]), isEmpty);
      expect(switchSettings(home).picked, picked);
      expect(await cli(['emulator', 'auto']), isEmpty);
      expect(switchSettings(home).picked, isNull);
      await expectLater(
        cli(['emulator', '$tmp/nope.app']),
        throwsA(
          isA<NotAnEmulator>().having((f) => f.path, 'path', '$tmp/nope.app'),
        ),
      );

      expect(await cli(['option', 'fullscreen', 'off']), isEmpty);
      expect(await cli(['option', 'headless', 'off']), isEmpty);
      expect(switchSettings(home), (
        picked: null,
        fullscreen: false,
        headless: false,
      ));
      expect(await cli(['option', 'fullscreen', 'on']), isEmpty);
      expect(await cli(['option', 'headless', 'on']), isEmpty);
      expect(
        jsonDecode(File('$home/switch/settings.json').readAsStringSync()),
        <String, Object?>{},
      );

      final game = touch('$tmp/games/$gameName').path;
      await cli(['add', game]);
      expect(await cli(['remove', game]), isEmpty);
      expect(await cli(['list']), isEmpty);
      expect(File(game).existsSync(), isTrue);
      await expectLater(
        cli(['remove', game]),
        throwsA(isA<SwitchGameNotFound>().having((f) => f.path, 'path', game)),
      );
    });

    test(
      'on Linux, status, open, stop, emulator and an app are NotAvailable, '
      'while game files are added, listed, set and removed (SE21, SN2)',
      () async {
        final game = touch('$tmp/games/Bodega Test.nsp').path;
        final readme = touch('$tmp/games/readme.txt').path;
        final native = fakeNative('$tmp/lib/Game.app');
        hostPlatform = const LinuxPlatform(mangoHud: false);
        final notHere = throwsA(
          isA<NotAvailable>()
              .having((f) => f.what, 'what', 'switch')
              .having((f) => f.host, 'host', 'Linux'),
        );
        await expectLater(cli(['status']), notHere);
        expect(await cli(['add', game]), [
          'added: Bodega Test',
          'already listed: 0',
        ]);
        expect(await cli(['list']), ['Bodega Test  -  $game']);
        expect(await cli(['option', 'fullscreen', 'off']), isEmpty);
        await expectLater(
          cli(['add', readme]),
          throwsA(isA<NotASwitchGame>().having((f) => f.path, 'path', readme)),
        );
        await expectLater(cli(['add', native]), notHere);
        await expectLater(cli(['open', game]), notHere);
        await expectLater(cli(['stop', game]), notHere);
        await expectLater(cli(['emulator', 'auto']), notHere);
        expect(await cli(['remove', game]), isEmpty);
        expect(await cli(['list']), isEmpty);
        expect(
          names('$home/switch'),
          unorderedEquals(['games.json', 'settings.json']),
        );
      },
    );
  });
}

/// A host whose every member throws: what the store must never ask (SE9).
class NoHost implements HostPlatform {
  @override
  Never noSuchMethod(Invocation invocation) =>
      throw StateError('the host was asked for ${invocation.memberName}');
}

/// The six store functions on [home], one call each: the game added, [folder]
/// scanned, the list read, the game removed, the settings read and an option
/// set. What they give, but the dates, which only have to be UTC (SE9).
Future<List<Object?>> storeCalls(
  String home,
  String game,
  String folder,
) async {
  final added = await addSwitchGames(home, [game]);
  final scanned = await addSwitchFolder(home, folder);
  final listed = [
    for (final game in switchGames(home))
      (game.path, game.title, game.titleId, game.added.isUtc),
  ];
  removeSwitchGame(home, game);
  final left = [for (final game in switchGames(home)) game.path];
  final settings = switchSettings(home);
  setSwitchOptions(home, fullscreen: false);
  return [added, scanned, listed, left, settings, switchSettings(home)];
}
