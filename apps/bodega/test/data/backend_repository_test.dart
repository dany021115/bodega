import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bodega/data/repository/backend_repository_impl.dart';
import 'package:bodega/data/service/downloader.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/mach9_step.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:dio/dio.dart';
import 'package:engine/engine.dart' as engine;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '_home.dart';
import '_mach9.dart';

class _MockDownloader extends Mock implements Downloader {}

/// A Mac whose macOS is too old for Mach9: the engine refuses before it
/// reads any file.
class _TooOldMac extends Mach9Mac {
  const _TooOldMac();

  @override
  engine.RuntimeBlock? get mach9Block => engine.RuntimeBlock.macosTooOld;
}

void main() {
  setUpAll(() => registerFallbackValue(CancelToken()));

  test(
    'a tarball that fails its checksum is deleted, so the next try fetches it',
    () async {
      final home = Directory.systemTemp.createTempSync('bodega-download');
      addTearDown(() => home.deleteSync(recursive: true));
      final downloader = _MockDownloader();
      final fetched = <String>[];
      when(
        () => downloader.fetch(
          any(),
          any(),
          cancel: any(named: 'cancel'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((call) async {
        final dest = call.positionalArguments[1] as String;
        fetched.add(dest);
        File(dest)
          ..createSync(recursive: true)
          ..writeAsStringSync('not the pinned tarball');
        return dest;
      });
      final repository = BackendRepositoryImpl(TestHome(home.path), downloader);
      Future<AppError?> download() async =>
          (await repository.download('dxmt', (_, _) {})).getLeft().toNullable();
      Matcher mismatch(String file) =>
          isA<ChecksumMismatchError>().having((e) => e.file, 'file', file);

      final first = await download();
      expect(fetched, hasLength(1));
      expect(first, mismatch(fetched.single));
      expect(File(fetched.single).existsSync(), isFalse);

      // One already in downloads/ is not fetched, and goes too.
      File(fetched.single).writeAsStringSync('still not it');
      expect(await download(), mismatch(fetched.single));
      expect(fetched, hasLength(1));
      expect(File(fetched.single).existsSync(), isFalse);
      expect(Directory('${home.path}/backends/dxmt').existsSync(), isFalse);
    },
    skip: Platform.isMacOS ? false : 'only the Mac pins a backend to download',
  );

  test('graphics finds an app exe inside its bottle (G1)', () async {
    final home = Directory.systemTemp.createTempSync('bodega-graphics');
    addTearDown(() => home.deleteSync(recursive: true));
    final header = ByteData(70)
      ..setUint8(0, 0x4D)
      ..setUint8(1, 0x5A)
      ..setUint32(60, 64, Endian.little)
      ..setUint8(64, 0x50)
      ..setUint8(65, 0x45)
      ..setUint16(68, 0x14C, Endian.little);
    File('${home.path}/bottles/games/prefix/drive_c/Blur/Blur.exe')
      ..createSync(recursive: true)
      ..writeAsBytesSync([
        ...header.buffer.asUint8List(),
        ...'d3d9.dll d3d10 dxgi.dll'.codeUnits,
      ]);

    final found =
        (await BackendRepositoryImpl(
          TestHome(home.path),
          _MockDownloader(),
        ).graphics('games', [r'C:\blur\BLUR.exe', r'C:\no.exe'])).getOrElse(
          (error) => fail('$error'),
        );

    expect(found.keys, [r'C:\blur\BLUR.exe']);
    final graphics = found.values.single;
    expect((graphics.directx, graphics.bits), ('DX9', 32));
  });

  group('MA4 runtimes and Mach9', () {
    late String home;
    setUp(() {
      home = Directory.systemTemp
          .createTempSync('bodega-runtimes')
          .resolveSymbolicLinksSync();
      addTearDown(() => Directory(home).deleteSync(recursive: true));
    });
    useHost(() => const Mach9Mac());

    BackendRepositoryImpl repository([Downloader? downloader]) =>
        BackendRepositoryImpl(TestHome(home), downloader ?? _MockDownloader());

    /// A 64-bit PE that names [dll].
    String exe(String path, String dll) {
      final header = ByteData(70)
        ..setUint8(0, 0x4D)
        ..setUint8(1, 0x5A)
        ..setUint32(60, 64, Endian.little)
        ..setUint8(64, 0x50)
        ..setUint8(65, 0x45)
        ..setUint16(68, 0x8664, Endian.little);
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync([...header.buffer.asUint8List(), ...dll.codeUnits]);
      return path;
    }

    test('Linux has only bodega', () async {
      engine.hostPlatform = const engine.LinuxPlatform(mangoHud: false);
      final runtimes = (await repository().runtimes()).getOrElse(
        (error) => fail('$error'),
      );
      expect(runtimes.map((r) => r.kind), [RuntimeKind.bodega]);
    });

    test('a Mac that can run Mach9 lists it with its latest release', () async {
      final missing = (await repository().runtimes())
          .getOrElse((error) => fail('$error'))
          .last;
      expect(missing.kind, RuntimeKind.mach9);
      expect(missing.installed, isFalse);
      expect(missing.blocked, isNull);
      expect(missing.appPath, isNull);
      // MU5: nothing looked up yet.
      expect(missing.latestVersion, isNull);
      expect(missing.backends, ['wine', 'dxmt', 'mtld3d']);
      expect(missing.downloadBytes, 0);
      expect(missing.diskBytes, engine.mach9Identity.diskBytes);
      expect(missing.minimumMacos, engine.mach9Identity.minimumMacos);
      File('$home/runtimes/.mach9-latest.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '{"version":"0.5.0","url":"https://x/Mach9.dmg","bytes":200,'
          '"sha256":"${'a' * 64}","minimumMacos":"26.5",'
          '"checkedAt":"2026-11-24T00:00:00Z"}',
        );
      final looked = (await repository().runtimes())
          .getOrElse((error) => fail('$error'))
          .last;
      expect(looked.latestVersion, '0.5.0');
      expect(looked.downloadBytes, 200);
      expect(looked.minimumMacos, '26.5');
      File('$home/runtimes/.mach9-latest.json').deleteSync();

      fakeMach9Runtime(home);
      final installed = (await repository().runtimes())
          .getOrElse((error) => fail('$error'))
          .last;
      expect(installed.usable, isTrue);
      expect(installed.version, '0.4.0');
      expect(installed.checked, isTrue);
      expect(installed.updateAvailable, isFalse);
    });

    test('readyBottles leaves Mach9 bottles out', () async {
      readyBottle(home, 'x86');
      readyBottle(home, 'native', mach9: true);
      expect((await repository().readyBottles()).getOrElse((e) => fail('$e')), [
        'x86',
      ]);
    });

    test('PA4 readyBottles of the Native engine gives its own', () async {
      readyBottle(home, 'x86');
      readyBottle(home, 'native', mach9: true);
      expect(
        (await repository().readyBottles(runtime: RuntimeKind.mach9))
            .getOrElse((e) => fail('$e')),
        ['native'],
      );
    });

    test('on a Mach9 bottle only wine misfits, with DX12', () async {
      final dir = readyBottle(home, 'native', mach9: true);
      exe('$dir/prefix/drive_c/G/g12.exe', 'd3d12.dll');
      exe('$dir/prefix/drive_c/G/g9.exe', 'd3d9.dll');
      final found = (await repository().graphics('native', [
        r'C:\G\g12.exe',
        r'C:\G\g9.exe',
      ])).getOrElse((error) => fail('$error'));
      expect(found[r'C:\G\g12.exe']!.misfits, ['wine']);
      expect(found[r'C:\G\g9.exe']!.misfits, isEmpty);
    });

    group('installRuntime', () {
      late _MockDownloader downloader;
      late List<String> fetched;
      late List<Mach9Step> steps;
      setUp(() {
        downloader = _MockDownloader();
        fetched = [];
        steps = [];
      });

      /// The Downloader writes [content], or returns null (a cancel).
      void downloads(String? content) =>
          when(
            () => downloader.fetch(
              any(),
              any(),
              cancel: any(named: 'cancel'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((call) async {
            fetched.add(call.positionalArguments[0] as String);
            if (content == null) return null;
            final dest = call.positionalArguments[1] as String;
            File(dest)
              ..createSync(recursive: true)
              ..writeAsStringSync(content);
            return dest;
          });

      Future<Either<AppError, bool>> install({String? file}) =>
          repository(downloader).installRuntime(
            RuntimeKind.mach9,
            file: file,
            onProgress: (_, _) {},
            onStep: steps.add,
          );

      /// GitHub as a folder (MU2): Mach9 0.4.0, whose dmg hashes as [dmg].
      Future<void> github({String dmg = 'x'}) async {
        final api = '$home/api';
        final file = File('$api/repos/athei/mach9/releases/latest')
          ..createSync(recursive: true);
        final content = File('$home/dmg-content')..writeAsStringSync(dmg);
        final hash = await engine.sha256Of(content.path);
        file.writeAsStringSync(
          jsonEncode({
            'tag_name': 'v0.4.0',
            'assets': [
              {
                'name': 'Mach9.dmg',
                'size': dmg.length,
                'digest': 'sha256:$hash',
                'browser_download_url': 'https://example.invalid/Mach9.dmg',
              },
            ],
          }),
        );
        engine.githubApi = Uri.directory(api)
            .toString()
            .replaceFirst(RegExp(r'/$'), '');
      }

      final api = engine.githubApi;
      tearDown(() => engine.githubApi = api);

      test('a cancelled download is false, and fetches nothing else', () async {
        await github();
        downloads(null);
        expect(await install(), const Right<AppError, bool>(false));
        expect(fetched, ['https://example.invalid/Mach9.dmg']);
        expect(steps, [Mach9Step.downloading]);
        expect(Directory('$home/runtimes/mach9').existsSync(), isFalse);
      });

      test(
        'a dmg unlike its digest is ChecksumMismatch, and is deleted',
        () async {
          await github(dmg: 'the real one');
          downloads('not it');
          final error = (await install()).getLeft().toNullable();
          expect(error, isA<ChecksumMismatchError>());
          expect(fetched, ['https://example.invalid/Mach9.dmg']);
          expect(
            Directory('$home/downloads').listSync().whereType<File>(),
            isEmpty,
          );
          expect(Directory('$home/runtimes/mach9').existsSync(), isFalse);
        },
      );

      test('a failure that is not about the files keeps them', () async {
        await github();
        downloads('x');
        engine.hostPlatform = const _TooOldMac();
        final error = (await install()).getLeft().toNullable();
        expect(error, isNot(isA<ChecksumMismatchError>()));
        expect(File('$home/downloads/Mach9-0.4.0.dmg').existsSync(), isTrue);
      });

      test('a file given fetches nothing before its copy', () async {
        await github();
        downloads('x');
        await install(file: '$home/Mach9.dmg');
        expect(fetched, isEmpty);
      });

      test(
        'offline, with no Mach9.app, is an error that fetches nothing',
        () async {
          engine.githubApi = 'file://$home/nowhere';
          downloads('x');
          final error = (await install()).getLeft().toNullable();
          expect(error, isNotNull);
          expect(fetched, isEmpty);
        },
      );
    });
  });
}
