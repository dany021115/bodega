import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '_mac.dart';
import 'engine_test.dart' show fakeRuntime;

/// A PE for the tests (T4): one section at RVA 0x1000, file offset 0x200, that
/// holds the DLL names, the manifest resource, the delay-load table and, last,
/// the import table, so that cutting the file inside the import table keeps
/// the rest readable.
Uint8List pe({
  int bits = 32,
  int machine = 0,
  List<String> imports = const [],
  List<String> delay = const [],
  String? manifest,
}) {
  const sectionRva = 0x1000, sectionRaw = 0x200;
  final body = BytesBuilder();
  int here() => sectionRva + body.length;
  void align() {
    while (body.length % 4 != 0) {
      body.addByte(0);
    }
  }

  final names = <String, int>{};
  for (final name in {...imports, ...delay}) {
    names[name] = here();
    body
      ..add(latin1.encode(name))
      ..addByte(0);
  }
  align();
  int? resourceRva;
  if (manifest != null) {
    final text = utf8.encode(manifest);
    final textRva = here();
    body.add(text);
    align();
    resourceRva = here();
    final root = ByteData(16 + 8 + 16 + 8 + 16 + 8 + 16);
    // root: one id entry (24, RT_MANIFEST) -> the type directory at 24.
    root.setUint16(14, 1, Endian.little);
    root.setUint32(16, 24, Endian.little);
    root.setUint32(20, 0x80000000 | 24, Endian.little);
    // type directory: one id entry (1) -> the name directory at 48.
    root.setUint16(24 + 14, 1, Endian.little);
    root.setUint32(24 + 16, 1, Endian.little);
    root.setUint32(24 + 20, 0x80000000 | 48, Endian.little);
    // name directory: one id entry (0x409) -> the data entry at 72.
    root.setUint16(48 + 14, 1, Endian.little);
    root.setUint32(48 + 16, 0x409, Endian.little);
    root.setUint32(48 + 20, 72, Endian.little);
    root.setUint32(72, textRva, Endian.little);
    root.setUint32(76, text.length, Endian.little);
    body.add(root.buffer.asUint8List());
  }
  int? delayRva;
  if (delay.isNotEmpty) {
    delayRva = here();
    for (final name in delay) {
      final entry = ByteData(32)
        ..setUint32(0, 1, Endian.little)
        ..setUint32(4, names[name]!, Endian.little);
      body.add(entry.buffer.asUint8List());
    }
    body.add(Uint8List(32));
  }
  int? importRva;
  if (imports.isNotEmpty) {
    importRva = here();
    for (final name in imports) {
      final entry = ByteData(20)..setUint32(12, names[name]!, Endian.little);
      body.add(entry.buffer.asUint8List());
    }
    body.add(Uint8List(20));
  }
  final section = body.toBytes();

  final wide = bits == 64;
  final optionalSize = (wide ? 112 : 96) + 16 * 8;
  final head = ByteData(sectionRaw);
  head
    ..setUint8(0, 0x4D)
    ..setUint8(1, 0x5A)
    ..setUint32(60, 0x80, Endian.little)
    ..setUint32(0x80, 0x00004550, Endian.little)
    ..setUint16(
      0x84,
      machine != 0 ? machine : (wide ? 0x8664 : 0x14C),
      Endian.little,
    )
    ..setUint16(0x86, 1, Endian.little)
    ..setUint16(0x94, optionalSize, Endian.little);
  const optional = 0x98;
  head.setUint16(optional, wide ? 0x20B : 0x10B, Endian.little);
  if (wide) {
    head.setUint64(optional + 24, 0x140000000, Endian.little);
  } else {
    head.setUint32(optional + 28, 0x400000, Endian.little);
  }
  head.setUint32(optional + (wide ? 108 : 92), 16, Endian.little);
  void directory(int index, int? rva, int size) {
    if (rva == null) return;
    final at = optional + (wide ? 112 : 96) + 8 * index;
    head
      ..setUint32(at, rva, Endian.little)
      ..setUint32(at + 4, size, Endian.little);
  }

  directory(1, importRva, 20 * (imports.length + 1));
  directory(2, resourceRva, 96);
  directory(13, delayRva, 32 * (delay.length + 1));
  final table = optional + optionalSize;
  head
    ..setUint32(table + 8, section.length, Endian.little)
    ..setUint32(table + 12, sectionRva, Endian.little)
    ..setUint32(table + 16, section.length, Endian.little)
    ..setUint32(table + 20, sectionRaw, Endian.little);
  return Uint8List.fromList([...head.buffer.asUint8List(), ...section]);
}

/// 64 bytes that start as a PE does, with [mark] where Wine puts its own.
List<int> dll([String mark = '']) =>
    latin1.encode('MZ'.padRight(64, '\u0000') + mark).toList();

const _vc90 =
    'windows/winsxs/x86_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_none_deadbeef';

void main() {
  late String tmp, home;

  setUp(() {
    tmp = Directory.systemTemp
        .createTempSync('bodega-deps')
        .resolveSymbolicLinksSync();
    home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
    hostPlatform = const TestMac();
  });

  tearDown(() {
    dependencyTable = dependencies;
    hostPlatform = HostPlatform.detect();
    Directory(tmp).deleteSync(recursive: true);
  });

  group('the table (DE2)', () {
    test('holds the six runtimes, from Microsoft, pinned', () {
      expect(dependencies.map((row) => row.id), [
        'vcrun2005',
        'vcrun2008',
        'vcrun2010',
        'vcrun2012',
        'vcrun2013',
        'vcrun2022',
      ]);
      for (final row in dependencies) {
        for (final (arch, file) in [('x86', row.x86), ('x64', row.x64)]) {
          expect(
            file.url,
            anyOf(
              startsWith('https://download.microsoft.com/'),
              startsWith('https://download.visualstudio.microsoft.com/'),
            ),
          );
          expect(file.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
          expect(file.file, '${row.id}-$arch.exe');
          expect(file.bytes, greaterThan(1000000));
          expect(file.args, isNotEmpty);
        }
        expect(row.imports, everyElement(endsWith('.dll')));
        expect(row.dlls, everyElement(isNot(contains('.'))));
      }
      final vc2008 = dependencies[1].x86;
      expect(
        vc2008.url,
        endsWith('/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe'),
      );
      expect(
        vc2008.sha256,
        '8742bcbf24ef328a72d2a27b693cc7071e38d3bb4b9b44dec42aa3d2c8d61d92',
      );
      expect(vc2008.bytes, 4483040);
      expect(vc2008.args, ['/q']);
      // Only vcrun2008 meets Wine's own assemblies at its own version (D6).
      for (final row in dependencies) {
        for (final file in [row.x86, row.x64]) {
          expect(
            file.wineManifests,
            row.id == 'vcrun2008' ? hasLength(2) : isEmpty,
            reason: file.file,
          );
        }
      }
      expect(
        dependencies[1].x64.wineManifests.first,
        'amd64_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_*.manifest',
      );
      expect(dependencies.last.windows, 'win10');
      expect(dependencies.where((row) => row.windows != null), hasLength(1));
    });

    test(
      'each installer is on Microsoft\'s server with its size and SHA-256',
      () async {
        for (final row in dependencies) {
          for (final file in [row.x86, row.x64]) {
            final dest = '$tmp/${file.file}';
            final run = await Process.run('curl', [
              '-fLsS',
              '--retry',
              '3',
              '-o',
              dest,
              file.url,
            ]);
            expect(run.exitCode, 0, reason: '${file.url}: ${run.stderr}');
            expect(File(dest).lengthSync(), file.bytes, reason: file.file);
            expect(await sha256Of(dest), file.sha256, reason: file.file);
            File(dest).deleteSync();
          }
        }
      },
      skip: Platform.environment['BODEGA_NETWORK_TESTS'] == '1'
          ? false
          : 'downloads about 85 MB: BODEGA_NETWORK_TESTS=1',
      timeout: const Timeout(Duration(minutes: 30)),
    );
  });

  group('installed is read from the bottle (DE3)', () {
    late String drive;

    setUp(() {
      drive = '$home/bottles/b/prefix/drive_c';
      Directory('$drive/windows/winsxs').createSync(recursive: true);
    });

    void put(String folder, List<int> bytes) =>
        File('$drive/$folder/msvcr90.dll')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);

    test('Wine\'s own DLL does not count; Microsoft\'s does', () {
      expect(dependencyInstalled(home, 'b', 'vcrun2008', 'x86'), isFalse);
      put(_vc90, dll('Wine builtin DLL'));
      expect(dependencyInstalled(home, 'b', 'vcrun2008', 'x86'), isFalse);
      put(_vc90, dll('Wine placeholder DLL'));
      expect(dependencyInstalled(home, 'b', 'vcrun2008', 'x86'), isFalse);
      put(_vc90, latin1.encode('not a dll at all, just text, long enough....'));
      expect(dependencyInstalled(home, 'b', 'vcrun2008', 'x86'), isFalse);
      put(_vc90, dll());
      expect(dependencyInstalled(home, 'b', 'vcrun2008', 'x86'), isTrue);
      expect(dependencyInstalled(home, 'b', 'vcrun2008', 'x64'), isFalse);
    });

    test('the folder\'s name matches without case, with any tail', () {
      put(
        'windows/winsxs/x86_Microsoft.VC90.CRT_1fc8b3b9a1e18e3b_9.0.30729.6161_x-ww_d08d0375',
        dll(),
      );
      expect(dependencyInstalled(home, 'b', 'vcrun2008', 'x86'), isTrue);
    });

    test('a folder that is a link is not followed', () {
      put('elsewhere', dll());
      Link('$drive/$_vc90').createSync('$drive/elsewhere');
      expect(dependencyInstalled(home, 'b', 'vcrun2008', 'x86'), isFalse);
    });

    test('the bottle lists each runtime and arch', () {
      File('$drive/windows/syswow64/msvcr100.dll')
        ..createSync(recursive: true)
        ..writeAsBytesSync(dll());
      final all = bottleDependencies(home, 'b');
      expect(all, hasLength(12));
      expect(
        [
          for (final line in all)
            if (line.installed) '${line.id} ${line.arch}',
        ],
        ['vcrun2010 x86'],
      );
      expect(
        () => dependencyInstalled(home, 'b', 'vcrun2099', 'x86'),
        throwsA(
          isA<BadChoice>()
              .having((f) => f.kind, 'kind', ChoiceKind.dependency)
              .having((f) => f.value, 'value', 'vcrun2099 x86'),
        ),
      );
    });
  });

  group('reading a program (DE4)', () {
    String write(String name, List<int> bytes) =>
        (File('$tmp/game/$name')
              ..createSync(recursive: true)
              ..writeAsBytesSync(bytes))
            .path;

    test(
      'a 32-bit exe: imports, delay-loads, manifest, its neighbours',
      () async {
        final exe = write(
          'Blur.exe',
          pe(
            imports: ['KERNEL32.dll', 'MSVCR90.dll'],
            delay: ['mfc90u.dll'],
            manifest:
                '<assembly><dependency><dependentAssembly><assemblyIdentity '
                'type="win32" name="Microsoft.VC90.CRT" version="9.0.21022.8"/>'
                '</dependentAssembly></dependency></assembly>',
          ),
        );
        write('binkw32.dll', [0]);
        write('readme.txt', [0]);
        final scan = (await scanProgram(exe))!;
        expect(scan.bits, 32);
        expect(scan.imports, {'kernel32.dll', 'msvcr90.dll', 'mfc90u.dll'});
        expect(scan.assemblies, {'microsoft.vc90.crt'});
        expect(scan.besideIt, {'binkw32.dll'});
      },
    );

    test('a 64-bit exe', () async {
      final scan = (await scanProgram(
        write('game.exe', pe(bits: 64, imports: ['VCRUNTIME140.dll'])),
      ))!;
      expect(scan.bits, 64);
      expect(scan.imports, {'vcruntime140.dll'});
      expect(scan.assemblies, isEmpty);
    });

    test('a table cut by the end of the file gives what was read', () async {
      final whole = pe(imports: ['first.dll', 'second.dll']);
      // The import table is last: keep its first entry and half the second.
      final exe = write('cut.exe', whole.sublist(0, whole.length - 30));
      final scan = (await scanProgram(exe))!;
      expect(scan.imports, {'first.dll'});
    });

    test('a text file or an ARM64 PE is not read', () async {
      expect(
        await scanProgram(write('notes.exe', utf8.encode('hello'))),
        isNull,
      );
      expect(
        await scanProgram(write('arm.exe', pe(bits: 64, machine: 0xAA64))),
        isNull,
      );
      expect(await scanProgram('$tmp/missing.exe'), isNull);
    });

    test('a huge exe is read only where it needs to be', () async {
      final exe = write('huge.exe', pe(imports: ['MSVCR100.dll']));
      // Sparse: 300 MB on paper, a few KB on disk.
      File(exe).openSync(mode: FileMode.append)
        ..truncateSync(300 * 1000 * 1000)
        ..closeSync();
      final watch = Stopwatch()..start();
      final scan = (await scanProgram(exe))!;
      expect(scan.imports, {'msvcr100.dll'});
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });

  group('proposals (DE5)', () {
    late String drive;

    setUp(() {
      drive = '$home/bottles/b/prefix/drive_c';
      Directory('$drive/windows/winsxs').createSync(recursive: true);
    });

    String add(String name, List<int> bytes, {String folder = 'game'}) {
      final exe = File('$tmp/$folder/$name')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
      addApp(home, 'b', name, exe.path);
      return appKey(exe.path);
    }

    test('a game with a fix gets its runtime, recommended', () async {
      final key = add('Blur.exe', pe(imports: ['MSVCR90.dll']));
      final needs = await appNeeds(home, 'b', key);
      expect(needs.key, key);
      expect(needs.dependencies, [
        (
          id: 'vcrun2008',
          arch: 'x86',
          need: Need.recommended,
          reason: NeedReason.knownFix,
          dll: null,
          fix: 'blur',
          installed: false,
        ),
      ]);
      expect(needs.settings, isEmpty);
    });

    test('an MFC import is recommended, a CRT import optional', () async {
      final mfc = add('tool.exe', pe(imports: ['MFC100.dll', 'MSVCR100.dll']));
      expect((await appNeeds(home, 'b', mfc)).dependencies.single, (
        id: 'vcrun2010',
        arch: 'x86',
        need: Need.recommended,
        reason: NeedReason.notInWine,
        dll: 'mfc100.dll',
        fix: null,
        installed: false,
      ));
      final crt = add(
        'crt.exe',
        pe(imports: ['MSVCR100.dll']),
        folder: 'other',
      );
      expect((await appNeeds(home, 'b', crt)).dependencies.single, (
        id: 'vcrun2010',
        arch: 'x86',
        need: Need.optional,
        reason: NeedReason.imported,
        dll: 'msvcr100.dll',
        fix: null,
        installed: false,
      ));
    });

    test('a runtime the game ships beside its exe proposes nothing', () async {
      File('$tmp/own/msvcr100.dll').createSync(recursive: true);
      final key = add('own.exe', pe(imports: ['MSVCR100.dll']), folder: 'own');
      expect((await appNeeds(home, 'b', key)).dependencies, isEmpty);
    });

    test('a 64-bit program gets the 64-bit runtime', () async {
      final key = add('x.exe', pe(bits: 64, imports: ['VCRUNTIME140.dll']));
      final need = (await appNeeds(home, 'b', key)).dependencies.single;
      expect(
        (need.id, need.arch, need.need),
        ('vcrun2022', 'x64', Need.optional),
      );
    });

    test('a need that is met stays, marked installed', () async {
      File('$drive/$_vc90/msvcr90.dll')
        ..createSync(recursive: true)
        ..writeAsBytesSync(dll());
      final key = add('Blur.exe', pe(imports: ['MSVCR90.dll']));
      expect(
        (await appNeeds(home, 'b', key)).dependencies.single.installed,
        isTrue,
      );
    });

    test(
      'a Steam game: nothing is read, only its fix counts',
      () async {
        final steam = File('$drive/Program Files (x86)/Steam/steam.exe')
          ..createSync(recursive: true)
          ..writeAsBytesSync(pe(imports: ['MSVCR100.dll']));
        File('$drive/Program Files (x86)/Steam/steamapps/appmanifest_9.acf')
          ..createSync(recursive: true)
          ..writeAsStringSync('"appid" "9"\n"name" "Game"\n"StateFlags" "4"');
        // Unreadable: reading it would throw.
        await Process.run('/bin/chmod', ['000', steam.path]);
        final needs = await appNeeds(home, 'b', 'steam:9');
        expect(needs.dependencies, isEmpty);
        expect(needs.settings, isEmpty);
      },
      skip: Platform.environment['USER'] == 'root'
          ? 'root reads anything'
          : false,
    );

    test('the NFS fix proposes its setting on the Mac only', () async {
      final key = add('NFS13.exe', pe(imports: ['DSOUND.dll']));
      expect((await appNeeds(home, 'b', key)).settings, [
        (
          fix: 'need-for-speed-most-wanted-2012',
          section: 'Sound',
          name: 'Reverb',
          value: '0',
          state: SettingState.noFile,
        ),
      ]);
      hostPlatform = const LinuxPlatform();
      expect((await appNeeds(home, 'b', key)).settings, isEmpty);
    });

    test('an app the bottle does not have is an error', () async {
      await expectLater(
        appNeeds(home, 'b', 'nope.exe'),
        throwsA(isA<AppNotFound>()),
      );
    });
  });

  group('installing (DE6)', () {
    late String prefix, installers;

    /// A fake installer, as the fake Wine runs it: it writes Microsoft's
    /// msvcr90.dll at vcrun2008's x86 marker unless [marker] is false, and
    /// exits with [code].
    String installer(String name, {int code = 0, bool marker = true}) {
      final script = File('$installers/$name')..createSync(recursive: true);
      script.writeAsStringSync(
        [
          if (marker) ...[
            'm="\$WINEPREFIX/drive_c/$_vc90"',
            r'mkdir -p "$m" && printf "MZ%062d" 0 >"$m/msvcr90.dll"',
          ],
          'exit $code',
          '',
        ].join('\n'),
      );
      return script.path;
    }

    /// [dependencyTable] with vcrun2008 and vcrun2022 pinned to [file].
    Future<void> pin(String file) async {
      final sha = await sha256Of(file);
      DependencyFile to(DependencyFile real) => (
        url: Uri.file(file).toString(),
        sha256: sha,
        bytes: File(file).lengthSync(),
        file: real.file,
        args: real.args,
        marker: dependencies[1].x86.marker,
        wineManifests: real.wineManifests,
      );
      dependencyTable = [
        for (final row in [dependencies[1], dependencies[5]])
          (
            id: row.id,
            name: row.name,
            imports: row.imports,
            dlls: row.dlls,
            windows: row.windows,
            x86: to(row.x86),
            x64: to(row.x64),
          ),
      ];
    }

    /// The `reg add`s of the install: the bottle's own setup writes others.
    List<String> reg() {
      final file = File('$prefix/reg.log');
      return [
        if (file.existsSync())
          for (final line in file.readAsLinesSync())
            if (line.contains(r'HKCU\Software\Wine\')) line,
      ];
    }

    setUp(() async {
      final (engine, hostlibs) = await fakeRuntime(tmp, 'engine');
      await installRuntime(home, engine, hostlibs);
      await createBottle(home, 'b');
      prefix = '$home/bottles/b/prefix';
      installers = '$tmp/installers';
    });

    test('runs the installer, then prefers its DLLs, then checks', () async {
      final file = installer('vcrun2008-x86.exe');
      await pin(file);
      final log = await installDependency(
        home,
        'b',
        'vcrun2008',
        'x86',
        file: file,
      );
      expect(log, endsWith('-vcrun2008-x86.log'));
      expect(
        File('$prefix/installer-args').readAsStringSync().trim(),
        '$file /q',
      );
      expect(reg(), [
        for (final dll in ['atl90', 'msvcm90', 'msvcp90', 'msvcr90', 'vcomp90'])
          'reg add HKCU\\Software\\Wine\\DllOverrides /v $dll /t REG_SZ '
              '/d native,builtin /f',
      ]);
      expect(dependencyInstalled(home, 'b', 'vcrun2008', 'x86'), isTrue);
    });

    test('a runtime that needs Windows 10 gets it before its run', () async {
      final file = installer('vcrun2022-x86.exe');
      await pin(file);
      await installDependency(home, 'b', 'vcrun2022', 'x86', file: file);
      expect(
        reg().first,
        r'reg add HKCU\Software\Wine\AppDefaults\vcrun2022-x86.exe /v Version '
        '/t REG_SZ /d win10 /f',
      );
      expect(
        File('$prefix/installer-args').readAsStringSync().trim(),
        '$file /install /quiet /norestart',
      );
    });

    test('a wrong checksum runs nothing', () async {
      await pin(installer('vcrun2008-x86.exe'));
      final other = installer('other/vcrun2008-x86.exe', code: 3);
      await expectLater(
        installDependency(home, 'b', 'vcrun2008', 'x86', file: other),
        throwsA(isA<ChecksumMismatch>().having((f) => f.file, 'file', other)),
      );
      expect(File('$prefix/installer-args').existsSync(), isFalse);
      expect(reg(), isEmpty);
    });

    test('a failed run sets no override; 3010 counts as done', () async {
      final failing = installer('vcrun2008-x86.exe', code: 1);
      await pin(failing);
      await expectLater(
        installDependency(home, 'b', 'vcrun2008', 'x86', file: failing),
        throwsA(
          isA<WineToolFailed>()
              .having((f) => f.tool, 'tool', WineTool.installer)
              .having((f) => f.exitCode, 'exitCode', 1)
              .having((f) => f.log, 'log', endsWith('-vcrun2008-x86.log')),
        ),
      );
      expect(reg(), isEmpty);

      final reboot = installer('again/vcrun2008-x86.exe', code: 3010);
      await pin(reboot);
      await installDependency(home, 'b', 'vcrun2008', 'x86', file: reboot);
      expect(reg(), hasLength(5));
    });

    test('a good exit with nothing in place is not installed', () async {
      final file = installer('vcrun2008-x86.exe', marker: false);
      await pin(file);
      await expectLater(
        installDependency(home, 'b', 'vcrun2008', 'x86', file: file),
        throwsA(
          isA<DependencyNotInstalled>()
              .having((f) => f.id, 'id', 'vcrun2008')
              .having((f) => f.arch, 'arch', 'x86'),
        ),
      );
    });

    test('an open bottle and an unknown choice are refused first', () async {
      final file = installer('vcrun2008-x86.exe');
      await pin(file);
      File('$prefix/hang').createSync();
      await expectLater(
        installDependency(home, 'b', 'vcrun2008', 'x86', file: file),
        throwsA(isA<BottleOpen>()),
      );
      File('$prefix/hang').deleteSync();
      expect(File('$prefix/installer-args').existsSync(), isFalse);
      for (final (id, arch) in [('vcrun2099', 'x86'), ('vcrun2008', 'arm64')]) {
        await expectLater(
          installDependency(home, 'b', id, arch),
          throwsA(
            isA<BadChoice>().having(
              (f) => f.kind,
              'kind',
              ChoiceKind.dependency,
            ),
          ),
        );
      }
    });

    test(
      "Wine's own manifests wait aside, and come back on a failure",
      () async {
        final manifests = '$prefix/drive_c/windows/winsxs/manifests';
        const names = [
          'x86_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_none_deadbeef.manifest',
          'x86_microsoft.vc90.atl_1fc8b3b9a1e18e3b_9.0.30729.6161_none_deadbeef.manifest',
        ];
        for (final name in names) {
          File('$manifests/$name')
            ..createSync(recursive: true)
            ..writeAsStringSync('wine $name');
        }
        // The installer sees neither manifest, and says so in its arguments.
        String seeing({int code = 0}) {
          final script = installer('vcrun2008-x86.exe', code: code);
          File(script).writeAsStringSync(
            '[ -e "$manifests/${names[0]}" ] && exit 9\n'
            '${File(script).readAsStringSync()}',
          );
          return script;
        }

        final failing = seeing(code: 1);
        await pin(failing);
        await expectLater(
          installDependency(home, 'b', 'vcrun2008', 'x86', file: failing),
          throwsA(isA<WineToolFailed>().having((f) => f.exitCode, 'code', 1)),
        );
        for (final name in names) {
          expect(File('$manifests/$name').readAsStringSync(), 'wine $name');
        }
        expect(
          Directory('$home/bottles/b/wine-manifests').existsSync(),
          isFalse,
        );

        final good = seeing();
        await pin(good);
        await installDependency(home, 'b', 'vcrun2008', 'x86', file: good);
        for (final name in names) {
          expect(File('$manifests/$name').existsSync(), isFalse);
        }
        expect(
          Directory('$home/bottles/b/wine-manifests').existsSync(),
          isFalse,
        );
      },
    );

    test('returns once Wine is gone, so the next one can start', () async {
      File('$prefix/linger').createSync();
      final file = installer('vcrun2008-x86.exe');
      await pin(file);
      await installDependency(home, 'b', 'vcrun2008', 'x86', file: file);
      expect(File('$prefix/hang').existsSync(), isFalse);
      final next = installer('next/vcrun2022-x86.exe');
      await pin(next);
      await installDependency(home, 'b', 'vcrun2022', 'x86', file: next);
      File('$prefix/linger').deleteSync();
    });

    test('with no file it downloads once, then reuses the download', () async {
      final source = installer('source/vcrun2008-x86.exe');
      await pin(source);
      await installDependency(home, 'b', 'vcrun2008', 'x86');
      final cached = File('$home/downloads/vcrun2008-x86.exe');
      expect(cached.existsSync(), isTrue);
      File(source).deleteSync();
      await installDependency(home, 'b', 'vcrun2008', 'x86');
      expect(
        File('$prefix/installer-args').readAsStringSync(),
        startsWith(cached.path),
      );
    });
  });

  group('the CLI (DE11)', () {
    test('parses its verbs, and refuses bad ones', () {
      final out = StringBuffer();
      for (final args in [
        ['list', 'b'],
        ['check', 'b', 'k'],
        ['install', 'b', 'vcrun2008', 'x86'],
        ['install', 'b', 'vcrun2008', 'x64', '/f.exe'],
      ]) {
        expect(depsVerb(args, out), isNotNull, reason: '$args');
      }
      for (final args in [
        ['install', 'b', 'vcrun2008'],
        ['install', 'b', 'vcrun2008', 'arm64'],
        ['install', 'b', 'vcrun2008', 'x86', 'a', 'b'],
        ['nope'],
        <String>[],
      ]) {
        expect(depsVerb(args, out), isNull, reason: '$args');
      }
    });

    test('lists every runtime and arch, and what an app needs', () async {
      final drive = '$home/bottles/b/prefix/drive_c';
      Directory('$drive/windows').createSync(recursive: true);
      final out = StringBuffer();
      expect(await depsVerb(['list', 'b'], out)!(home), 0);
      final lines = out.toString().trim().split('\n');
      expect(lines, hasLength(12));
      expect(lines[2], 'vcrun2008 x86 not installed 4.5 MB');
      final exe = File('$tmp/Blur/Blur.exe')
        ..createSync(recursive: true)
        ..writeAsBytesSync(pe(imports: ['MSVCR90.dll']));
      addApp(home, 'b', 'Blur', exe.path);
      out.clear();
      expect(await depsVerb(['check', 'b', appKey(exe.path)], out)!(home), 0);
      expect(out.toString(), 'recommended vcrun2008 x86 (fix blur)\n');
    });
  });
}
