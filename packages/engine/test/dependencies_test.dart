import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '_mac.dart';
import 'runtimes_test.dart' show fakeMach9Runtime, mach9Bottle;
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

/// A runtime in [home] whose Wine ships [dlls] in both of its folders, as
/// the real one ships the C runtimes, D3DX and mscoree, and no MFC or PhysX
/// (RE4).
void wineShips(String home, [List<String>? dlls]) {
  for (final folder in ['i386-windows', 'x86_64-windows']) {
    for (final dll
        in dlls ??
            const [
              'msvcr80.dll',
              'msvcr90.dll',
              'msvcr100.dll',
              'msvcp100.dll',
              'msvcr110.dll',
              'msvcr120.dll',
              'vcruntime140.dll',
              'msvcp140.dll',
              'd3dx9_43.dll',
              'mscoree.dll',
              'x3daudio1_7.dll',
            ]) {
      File('$home/runtimes/current/engine/lib/wine/$folder/$dll')
          .createSync(recursive: true);
    }
  }
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

  group('the table (DE2, RE1, RE2)', () {
    const ids = [
      'vcrun2005',
      'vcrun2008',
      'vcrun2010',
      'vcrun2012',
      'vcrun2013',
      'vcrun2022',
      'dotnet48',
      'd3dx9',
      'd3dx10',
      'd3dx11_43',
      'd3dcompiler_47',
      'xact',
      'physx',
      'corefonts',
    ];
    Dependency row(String id) => dependencies.firstWhere((r) => r.id == id);

    test('holds the fourteen runtimes, each pinned at its vendor', () {
      expect(dependencies.map((row) => row.id), ids);
      for (final row in dependencies) {
        expect(
          row.files.keys.toSet(),
          anyOf({'x86', 'x64'}, {'all'}),
          reason: row.id,
        );
        for (final file in row.files.values) {
          expect(file.downloads, isNotEmpty);
          for (final download in file.downloads) {
            final uri = Uri.parse(download.url);
            expect(uri.scheme, 'https');
            expect(
              uri.host,
              isIn(const [
                'download.microsoft.com',
                'download.visualstudio.microsoft.com',
                'us.download.nvidia.com',
                'raw.githubusercontent.com',
              ]),
            );
            if (uri.host == 'raw.githubusercontent.com') {
              expect(['d3dcompiler_47', 'corefonts'], contains(row.id));
              expect(uri.pathSegments[2], matches(RegExp(r'^[0-9a-f]{40}$')));
            }
            expect(download.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
            expect(download.bytes, greaterThan(100000));
          }
        }
        expect(row.imports, everyElement(endsWith('.dll')));
        expect(row.dlls, everyElement(isNot(contains('.'))));
      }
      for (final row in dependencies.take(6)) {
        for (final MapEntry(key: arch, value: file) in row.files.entries) {
          expect(file.kind, DependencyKind.run);
          expect(file.downloads.single.file, '${row.id}-$arch.exe');
          expect(file.args, isNotEmpty);
        }
      }
      final vc2008 = row('vcrun2008').files['x86']!;
      expect(
        vc2008.downloads.single.url,
        endsWith('/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe'),
      );
      expect(
        vc2008.downloads.single.sha256,
        '8742bcbf24ef328a72d2a27b693cc7071e38d3bb4b9b44dec42aa3d2c8d61d92',
      );
      expect(vc2008.bytes, 4483040);
      expect(vc2008.args, ['/q']);
      // Only vcrun2008 meets Wine's own assemblies at its own version (D6).
      for (final row in dependencies) {
        for (final file in row.files.values) {
          expect(
            file.wineManifests,
            row.id == 'vcrun2008' ? hasLength(2) : isEmpty,
            reason: row.id,
          );
        }
      }
      expect(
        row('vcrun2008').files['x64']!.wineManifests.first,
        'amd64_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_*.manifest',
      );
      expect(row('vcrun2022').windows, 'win10');
      // The file Mach9's own copy kept from the installer (2026-11-24).
      for (final (arch, folder) in [('x86', 'syswow64'), ('x64', 'system32')]) {
        final file = row('vcrun2022').files[arch]!;
        expect(file.marker, 'windows/$folder/msvcp140.dll');
        expect(file.repairArgs, ['/repair', '/quiet', '/norestart']);
      }
      expect(dependencies.where((row) => row.windows != null), hasLength(1));
    });

    test('the new rows hold what T2 and S1–S4 measured', () {
      // Four rows, one download: Microsoft's own DirectX file.
      final directx = {
        for (final id in ['d3dx9', 'd3dx10', 'd3dx11_43', 'xact'])
          for (final file in row(id).files.values) ...file.downloads,
      };
      expect(directx, hasLength(1));
      expect(directx.single.file, 'directx-jun2010.exe');
      expect(directx.single.bytes, 100275120);
      expect(
        directx.single.sha256,
        '053f76dcbb28802e23341b6a787e3b0791c0fa5c8d4d011b1044172dbf89c73b',
      );
      final d3dx9 = row('d3dx9').files;
      expect(d3dx9['x86']!.kind, DependencyKind.cab);
      expect(d3dx9['x86']!.cabs, ['*d3dx9*x86*.cab']);
      expect(d3dx9['x86']!.into, 'windows/syswow64');
      expect(d3dx9['x64']!.into, 'windows/system32');
      expect(row('xact').files['x86']!.register, contains('xactengine*.dll'));
      final dotnet = row('dotnet48').files['all']!;
      expect(dotnet.downloads.map((d) => d.file), [
        'dotnet40.exe',
        'dotnet48.exe',
      ]);
      expect(
        (dotnet.replacesMono, dotnet.windowsDuring, dotnet.netRelease),
        (true, 'win7', 528040),
      );
      expect(dotnet.minutes, 120);
      expect(
        row('physx').files['all']!.marker,
        'Program Files (x86)/NVIDIA Corporation/PhysX/Common/PhysXLoader.dll',
      );
      final fonts = row('corefonts').files['all']!;
      expect(fonts.downloads, hasLength(11));
      expect(fonts.fonts['arial.ttf'], 'Arial');
      expect(row('d3dcompiler_47').files['x86']!.kind, DependencyKind.copy);
    });

    test(
      "each file is on its server with its size and SHA-256",
      () async {
        final seen = <String>{};
        for (final row in dependencies) {
          for (final file in row.files.values) {
            for (final download in file.downloads) {
              if (!seen.add(download.file)) continue;
              final dest = '$tmp/${download.file}';
              final run = await Process.run('curl', [
                '-fLsS',
                '--retry',
                '3',
                '-o',
                dest,
                download.url,
              ]);
              expect(run.exitCode, 0, reason: '${download.url}: ${run.stderr}');
              expect(File(dest).lengthSync(), download.bytes, reason: dest);
              expect(await sha256Of(dest), download.sha256, reason: dest);
              File(dest).deleteSync();
            }
          }
        }
        expect(seen, hasLength(12 + 2 + 1 + 2 + 1 + 11));
      },
      skip: Platform.environment['BODEGA_NETWORK_TESTS'] == '1'
          ? false
          : 'downloads about 340 MB: BODEGA_NETWORK_TESTS=1',
      timeout: const Timeout(Duration(minutes: 60)),
    );
  });

  group('installed is read from the bottle (DE3, RE3)', () {
    late String drive;

    setUp(() {
      drive = '$home/bottles/b/prefix/drive_c';
      Directory('$drive/windows/winsxs').createSync(recursive: true);
    });

    void put(String folder, List<int> bytes, [String name = 'msvcr90.dll']) =>
        File('$drive/$folder/$name')
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

    test('D3DX9 per arch, from its own folder', () {
      put('windows/syswow64', dll(), 'd3dx9_43.dll');
      expect(dependencyStatus(home, 'b', 'd3dx9', 'x86'), isTrue);
      expect(dependencyStatus(home, 'b', 'd3dx9', 'x64'), isFalse);
    });

    test('a font counts as a file, or as the host\'s font that Wine lists', () {
      expect(dependencyStatus(home, 'b', 'corefonts', 'all'), isFalse);
      put('elsewhere', latin1.encode('a font'), 'arial.ttf');
      Directory('$drive/windows/Fonts').createSync();
      Link('$drive/windows/Fonts/arial.ttf')
          .createSync('$drive/elsewhere/arial.ttf');
      expect(dependencyStatus(home, 'b', 'corefonts', 'all'), isFalse);
      // S1: on the Mac, Wine lists macOS's own copy.
      File('$home/bottles/b/prefix/user.reg').writeAsStringSync(
        'WINE REGISTRY Version 2\n\n'
        r'[Software\\Wine\\Fonts\\External Fonts] 1795011472'
        '\n#time=1dd77669d804512\n'
        r'"Arial (TrueType)"="Z:\\System\\Library\\Fonts\\Supplemental\\Arial.ttf"'
        '\n\n',
      );
      expect(dependencyStatus(home, 'b', 'corefonts', 'all'), isTrue);
      File('$home/bottles/b/prefix/user.reg').deleteSync();
      Link('$drive/windows/Fonts/arial.ttf').deleteSync();
      put('windows/Fonts', latin1.encode('a font'), 'arial.ttf');
      expect(dependencyStatus(home, 'b', 'corefonts', 'all'), isTrue);
    });

    test('.NET needs Microsoft\'s clr.dll and its Release (S3)', () {
      const folder = 'windows/Microsoft.NET/Framework/v4.0.30319';
      void release(
        int value,
      ) => File('$home/bottles/b/prefix/system.reg').writeAsStringSync(
        'WINE REGISTRY Version 2\n\n'
        r'[Software\\Microsoft\\NET Framework Setup\\NDP\\v4\\Full] 1795011050'
        '\n"Install"=dword:00000001\n'
        '"Release"=dword:${value.toRadixString(16).padLeft(8, '0')}\n\n',
      );
      // Wine Mono: a Release, no clr.dll.
      release(533320);
      expect(dependencyStatus(home, 'b', 'dotnet48', 'all'), isFalse);
      put(folder, dll(), 'clr.dll');
      expect(dependencyStatus(home, 'b', 'dotnet48', 'all'), isTrue);
      // .NET 4.0 alone.
      release(30319);
      expect(dependencyStatus(home, 'b', 'dotnet48', 'all'), isFalse);
    });

    test(
      'a folder that can\'t be read is unknown',
      () async {
        put('windows/syswow64', dll(), 'd3dx9_43.dll');
        await Process.run('/bin/chmod', ['000', '$drive/windows/syswow64']);
        addTearDown(
          () =>
              Process.runSync('/bin/chmod', ['755', '$drive/windows/syswow64']),
        );
        expect(dependencyStatus(home, 'b', 'd3dx9', 'x86'), isNull);
        expect(dependencyInstalled(home, 'b', 'd3dx9', 'x86'), isFalse);
        final out = StringBuffer();
        expect(await depsVerb(['list', 'b'], out)!(home), 0);
        expect(out.toString(), contains('d3dx9 x86 unknown\n'));
      },
      skip: Platform.environment['USER'] == 'root'
          ? 'root reads anything'
          : false,
    );

    test('the bottle lists each runtime and arch', () {
      File('$drive/windows/syswow64/msvcr100.dll')
        ..createSync(recursive: true)
        ..writeAsBytesSync(dll());
      final all = bottleDependencies(home, 'b');
      expect(all, hasLength(25));
      expect(
        [
          for (final line in all)
            if (line.installed == true) '${line.id} ${line.arch}',
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
      expect(
        () => dependencyStatus(home, 'b', 'corefonts', 'x86'),
        throwsA(isA<BadChoice>()),
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

  group('proposals (DE5, RE4)', () {
    late String drive;

    setUp(() {
      drive = '$home/bottles/b/prefix/drive_c';
      Directory('$drive/windows/winsxs').createSync(recursive: true);
      wineShips(home);
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

    test('PE10 a Mach9 bottle reads Mach9\'s own Wine, ARM64X for x64', () async {
      fakeMach9Runtime(home);
      mach9Bottle(home, 'm9');
      final exe = File('$tmp/m9/tool64.exe')
        ..createSync(recursive: true)
        ..writeAsBytesSync(pe(bits: 64, imports: ['MFC140.dll']));
      addApp(home, 'm9', 'tool64.exe', exe.path);
      final key = appKey(exe.path);
      Future<Need> need() async =>
          (await appNeeds(home, 'm9', key)).dependencies.single.need;
      // Rosetta's Wine (wineShips) has no MFC: only Mach9's own counts.
      expect(await need(), Need.recommended);
      File(
        '$home/runtimes/mach9-0.4.0/engine/lib/wine/aarch64-windows/mfc140.dll',
      ).createSync(recursive: true);
      expect(await need(), Need.optional);
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

    test('patterns, what Wine lacks, and one install for both', () async {
      final old = add(
        'old.exe',
        pe(imports: ['d3dx9_43.dll', 'PhysXLoader.dll', 'KERNEL32.dll']),
      );
      expect((await appNeeds(home, 'b', old)).dependencies, [
        (
          id: 'd3dx9',
          arch: 'x86',
          need: Need.optional,
          reason: NeedReason.imported,
          dll: 'd3dx9_43.dll',
          fix: null,
          installed: false,
        ),
        (
          id: 'physx',
          arch: 'all',
          need: Need.recommended,
          reason: NeedReason.notInWine,
          dll: 'physxloader.dll',
          fix: null,
          installed: false,
        ),
      ]);
      final net = add(
        'net.exe',
        pe(bits: 64, imports: ['mscoree.dll']),
        folder: 'net',
      );
      final need = (await appNeeds(home, 'b', net)).dependencies.single;
      expect(
        (need.id, need.arch, need.need),
        ('dotnet48', 'all', Need.optional),
      );
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

    /// [file] as a download, pinned as it is.
    Future<Download> download(String file, [String? name]) async => (
      url: Uri.file(file).toString(),
      sha256: await sha256Of(file),
      bytes: File(file).lengthSync(),
      file: name ?? file.split('/').last,
    );

    /// [dependencyTable] with vcrun2008 and vcrun2022 pinned to [file].
    Future<void> pin(String file) async {
      final pinned = await download(file);
      DependencyFile to(DependencyFile real) => DependencyFile.run(
        [
          (
            url: pinned.url,
            sha256: pinned.sha256,
            bytes: pinned.bytes,
            file: real.downloads.single.file,
          ),
        ],
        args: real.args,
        marker: dependencies[1].files['x86']!.marker,
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
            files: {
              for (final MapEntry(:key, :value) in row.files.entries)
                key: to(value),
            },
          ),
      ];
    }

    /// One test row [id] with [file] for `x86`, which may be [arch] instead.
    void only(
      String id,
      DependencyFile file, {
      String arch = 'x86',
      List<String> dlls = const [],
    }) => dependencyTable = [
      (
        id: id,
        name: id,
        imports: const [],
        dlls: dlls,
        windows: null,
        files: {arch: file},
      ),
    ];

    /// A fake cabinet (the tests' header): a few bytes for the program around
    /// it when [wrapped], `MSCF` and four zeros, then a tar of [files] by name.
    String cabinet(
      String path,
      Map<String, List<int>> files, {
      bool wrapped = true,
    }) {
      final dir = Directory('$path.d')..createSync(recursive: true);
      for (final MapEntry(:key, :value) in files.entries) {
        File('${dir.path}/$key').writeAsBytesSync(value);
      }
      final tar =
          Process.runSync('/usr/bin/tar', [
                '-cf',
                '-',
                '-C',
                dir.path,
                ...files.keys,
              ], stdoutEncoding: null).stdout
              as List<int>;
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync([
          if (wrapped) ...latin1.encode('SFX WRAPPER'),
          ...latin1.encode('MSCF'),
          0,
          0,
          0,
          0,
          ...tar,
        ]);
      return path;
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
        files: [file],
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
      await installDependency(home, 'b', 'vcrun2022', 'x86', files: [file]);
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

    test("Wine's copy goes first, and a repair puts back what the install "
        'skipped', () async {
      // As Mach9's msvcp140 met Microsoft's installer on 2026-11-24: of the
      // same version, so the install left it, and over a registered product
      // the install does nothing at all.
      File('$prefix/drive_c/windows/syswow64/msvcp140.dll')
        ..createSync(recursive: true)
        ..writeAsBytesSync(dll('Wine builtin DLL'));
      final file = File('$installers/vcrun2022-x86.exe')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          r'd="$WINEPREFIX/drive_c/windows/syswow64"'
          '\n'
          r'echo "$2" >>"$WINEPREFIX/runs"'
          '\n'
          r'[ -e "$d/msvcp140.dll" ] && echo present >>"$WINEPREFIX/runs"'
          '\n'
          r'[ "$2" = /repair ] && printf "MZ%062d" 0 >"$d/msvcp140.dll"'
          '\n'
          'exit 0\n',
        );
      only(
        'vc',
        DependencyFile.run(
          [await download(file.path)],
          args: ['/install', '/quiet'],
          repairArgs: ['/repair', '/quiet'],
          marker: 'windows/syswow64/msvcp140.dll',
        ),
        dlls: ['msvcp140'],
      );
      await installDependency(home, 'b', 'vc', 'x86', files: [file.path]);
      expect(File('$prefix/runs').readAsLinesSync(), ['/install', '/repair']);
      expect(dependencyInstalled(home, 'b', 'vc', 'x86'), isTrue);
    });

    test('a wrong checksum runs nothing', () async {
      await pin(installer('vcrun2008-x86.exe'));
      final other = installer('other/vcrun2008-x86.exe', code: 3);
      await expectLater(
        installDependency(home, 'b', 'vcrun2008', 'x86', files: [other]),
        throwsA(isA<ChecksumMismatch>().having((f) => f.file, 'file', other)),
      );
      expect(File('$prefix/installer-args').existsSync(), isFalse);
      expect(reg(), isEmpty);
    });

    test('a failed run sets no override; 3010 counts as done', () async {
      final failing = installer('vcrun2008-x86.exe', code: 1);
      await pin(failing);
      await expectLater(
        installDependency(home, 'b', 'vcrun2008', 'x86', files: [failing]),
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
      await installDependency(home, 'b', 'vcrun2008', 'x86', files: [reboot]);
      expect(reg(), hasLength(5));
    });

    test('a good exit with nothing in place is not installed', () async {
      final file = installer('vcrun2008-x86.exe', marker: false);
      await pin(file);
      await expectLater(
        installDependency(home, 'b', 'vcrun2008', 'x86', files: [file]),
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
        installDependency(home, 'b', 'vcrun2008', 'x86', files: [file]),
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
          installDependency(home, 'b', 'vcrun2008', 'x86', files: [failing]),
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
        await installDependency(home, 'b', 'vcrun2008', 'x86', files: [good]);
        for (final name in names) {
          expect(File('$manifests/$name').existsSync(), isFalse);
        }
        expect(
          Directory('$home/bottles/b/wine-manifests').existsSync(),
          isFalse,
        );
      },
    );

    test('several files run in order, each checked first (RE5)', () async {
      String setup(String name, List<String> lines) {
        final file = File('$installers/$name')..createSync(recursive: true);
        file.writeAsStringSync([...lines, 'exit 0', ''].join('\n'));
        return file.path;
      }

      final first = setup('first-setup.exe', [
        r'echo first >>"$WINEPREFIX/order"',
      ]);
      final second = setup('second-setup.exe', [
        r'echo second >>"$WINEPREFIX/order"',
        'm="\$WINEPREFIX/drive_c/$_vc90"',
        r'mkdir -p "$m" && printf "MZ%062d" 0 >"$m/msvcr90.dll"',
      ]);
      only(
        'two',
        DependencyFile.run(
          [await download(first), await download(second)],
          args: ['/q'],
          marker: dependencies[1].files['x86']!.marker,
        ),
      );
      final wrong = setup('other/second-setup.exe', ['exit 3']);
      await expectLater(
        installDependency(home, 'b', 'two', 'x86', files: [first, wrong]),
        throwsA(isA<ChecksumMismatch>().having((f) => f.file, 'file', wrong)),
      );
      expect(File('$prefix/order').existsSync(), isFalse);
      await installDependency(home, 'b', 'two', 'x86', files: [first, second]);
      expect(File('$prefix/order').readAsLinesSync(), ['first', 'second']);
    });

    test('past its time limit, the bottle stops (RE5)', () async {
      final slow =
          (File('$installers/slow-setup.exe')
                ..createSync(recursive: true)
                ..writeAsStringSync('sleep 2\nexit 0\n'))
              .path;
      only(
        'slow',
        DependencyFile.run(
          [await download(slow)],
          marker: dependencies[1].files['x86']!.marker,
          minutes: 0,
        ),
      );
      final failure = await installDependency(
        home,
        'b',
        'slow',
        'x86',
        files: [slow],
      ).then<Object?>((_) => null, onError: (Object e) => e);
      expect(
        failure,
        isA<InstallTimedOut>()
            .having((f) => f.id, 'id', 'slow')
            .having((f) => f.log, 'log', endsWith('-slow-x86.log')),
      );
      expect(File('$prefix/server.log').readAsStringSync(), contains('k'));
      // The fake installer still ends by itself; wait for it before cleaning.
      final exit = File(
        (failure! as InstallTimedOut).log.replaceFirst('.log', '.exit'),
      );
      for (var i = 0; i < 100 && !exit.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });

    test(
      'a cabinet: the arch\'s inner one, copied and registered (RE6)',
      () async {
        final inner86 = cabinet('$installers/in/inner_x86.cab', {
          'd3dx9_43.dll': dll(),
          'readme.txt': latin1.encode('not taken'),
        }, wrapped: false);
        final inner64 = cabinet('$installers/in/inner_x64.cab', {
          'd3dx9_43.dll': dll('x64'),
        }, wrapped: false);
        final outer = cabinet('$installers/redist.exe', {
          'Jun2010_d3dx9_43_x86.cab': File(inner86).readAsBytesSync(),
          'Jun2010_d3dx9_43_x64.cab': File(inner64).readAsBytesSync(),
        });
        only(
          'dx',
          DependencyFile.cab(
            [await download(outer)],
            cabs: ['*d3dx9*X86*.cab'],
            take: ['D3DX9*.dll'],
            into: 'windows/syswow64',
            register: ['d3dx9_43.dll'],
            marker: 'windows/syswow64/d3dx9_43.dll',
          ),
          dlls: ['d3dx9_43'],
        );
        await installDependency(home, 'b', 'dx', 'x86', files: [outer]);
        final dllFile = File('$prefix/drive_c/windows/syswow64/d3dx9_43.dll');
        expect(dllFile.readAsBytesSync(), dll());
        expect(
          File('$prefix/drive_c/windows/syswow64/readme.txt').existsSync(),
          isFalse,
        );
        expect(File('$prefix/regsvr32.log').readAsLinesSync(), [
          r'C:\windows\syswow64\regsvr32.exe /s d3dx9_43.dll',
        ]);
        expect(
          Directory('$prefix/drive_c/windows/temp/bodega-dx').existsSync(),
          isFalse,
        );
        expect(reg(), [
          r'reg add HKCU\Software\Wine\DllOverrides /v d3dx9_43 /t REG_SZ '
              '/d native,builtin /f',
        ]);
        expect(dependencyStatus(home, 'b', 'dx', 'x86'), isTrue);
      },
    );

    test(
      'fonts go to Fonts in lowercase, and are registered (RE6, S1)',
      () async {
        final pack = cabinet('$installers/arial32.exe', {
          'Arial.TTF': latin1.encode('a font'),
          'FONTINST.EXE': dll(),
        });
        only(
          'fonts',
          DependencyFile.cab(
            [await download(pack)],
            take: ['*.ttf'],
            into: 'windows/Fonts',
            fonts: const {'arial.ttf': 'Arial'},
            marker: 'windows/Fonts/arial.ttf',
          ),
          arch: 'all',
        );
        await installDependency(home, 'b', 'fonts', 'all', files: [pack]);
        expect(
          File('$prefix/drive_c/windows/Fonts/arial.ttf').readAsStringSync(),
          'a font',
        );
        final reg = File('$prefix/regedit.reg').readAsStringSync();
        expect(reg, startsWith('REGEDIT4\r\n'));
        expect('"Arial (TrueType)"="arial.ttf"'.allMatches(reg), hasLength(2));
      },
    );

    test('a file with no cabinet in it is not installed (RE6)', () async {
      final plain =
          (File('$installers/plain.exe')
                ..createSync(recursive: true)
                ..writeAsBytesSync(dll()))
              .path;
      only(
        'plain',
        DependencyFile.cab(
          [await download(plain)],
          take: ['*.dll'],
          into: 'windows/syswow64',
          marker: 'windows/syswow64/x.dll',
        ),
      );
      await expectLater(
        installDependency(home, 'b', 'plain', 'x86', files: [plain]),
        throwsA(isA<DependencyNotInstalled>()),
      );
      expect(
        Directory('$prefix/drive_c/windows/temp/bodega-plain').existsSync(),
        isFalse,
      );
    });

    test('a copy is written at its marker (RE7)', () async {
      final file =
          (File('$installers/d3dcompiler_47-x86.dll')
                ..createSync(recursive: true)
                ..writeAsBytesSync(dll()))
              .path;
      only(
        'compiler',
        DependencyFile.copy([
          await download(file),
        ], marker: 'windows/syswow64/d3dcompiler_47.dll'),
        dlls: ['d3dcompiler_47'],
      );
      final log = await installDependency(
        home,
        'b',
        'compiler',
        'x86',
        files: [file],
      );
      expect(log, endsWith('-reg.log'));
      expect(
        File('$prefix/drive_c/windows/syswow64/d3dcompiler_47.dll')
            .readAsBytesSync(),
        dll(),
      );
      expect(reg().single, contains('/v d3dcompiler_47 '));
      expect(dependencyStatus(home, 'b', 'compiler', 'x86'), isTrue);
    });

    test(
      '.NET: Wine Mono leaves, Windows 7 for the run, then back (S3)',
      () async {
        File('$prefix/system.reg').writeAsStringSync(
          'WINE REGISTRY Version 2\n\n'
          r'[Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{0591009C-75D7-5F33-B5DF-4F47111155EC}] 1795011050'
          '\n"DisplayName"="Wine Mono Windows Support"\n\n',
        );
        final wineDll = File('$prefix/drive_c/windows/syswow64/mscoree.dll')
          ..writeAsBytesSync(dll('Wine builtin DLL'));
        final setup =
            (File('$installers/net-setup.exe')
                  ..createSync(recursive: true)
                  ..writeAsStringSync(
                    'm="\$WINEPREFIX/drive_c/$_vc90"\n'
                    r'mkdir -p "$m" && printf "MZ%062d" 0 >"$m/msvcr90.dll"'
                    '\nexit 0\n',
                  ))
                .path;
        only(
          'net',
          DependencyFile.run(
            [await download(setup)],
            args: ['/q'],
            marker: dependencies[1].files['x86']!.marker,
            replacesMono: true,
            windowsDuring: 'win7',
          ),
          arch: 'all',
        );
        await installDependency(home, 'b', 'net', 'all', files: [setup]);
        expect(
          File('$prefix/msi-args').readAsStringSync().trim(),
          'msiexec /x {0591009C-75D7-5F33-B5DF-4F47111155EC} /q',
        );
        expect(wineDll.existsSync(), isFalse);
        expect(File('$prefix/winecfg.log').readAsLinesSync(), [
          'winecfg -v win7',
          'winecfg -v win10',
        ]);
      },
    );

    test('returns once Wine is gone, so the next one can start', () async {
      File('$prefix/linger').createSync();
      final file = installer('vcrun2008-x86.exe');
      await pin(file);
      await installDependency(home, 'b', 'vcrun2008', 'x86', files: [file]);
      expect(File('$prefix/hang').existsSync(), isFalse);
      final next = installer('next/vcrun2022-x86.exe');
      await pin(next);
      await installDependency(home, 'b', 'vcrun2022', 'x86', files: [next]);
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
        ['install', 'b', 'corefonts', 'all', '/a.exe', '/b.exe'],
      ]) {
        expect(depsVerb(args, out), isNotNull, reason: '$args');
      }
      for (final args in [
        ['install', 'b', 'vcrun2008'],
        ['install', 'b', 'vcrun2008', 'arm64'],
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
      expect(lines, hasLength(25));
      expect(lines[2], 'vcrun2008 x86 not installed 4.5 MB');
      final exe = File('$tmp/Blur/Blur.exe')
        ..createSync(recursive: true)
        ..writeAsBytesSync(pe(imports: ['MSVCR90.dll']));
      addApp(home, 'b', 'Blur', exe.path);
      wineShips(home);
      out.clear();
      expect(await depsVerb(['check', 'b', appKey(exe.path)], out)!(home), 0);
      expect(out.toString(), 'recommended vcrun2008 x86 (fix blur)\n');
    });
  });
}
