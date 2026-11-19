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

    test('a Mac that can run Mach9 lists it with the pinned release', () async {
      final missing = (await repository().runtimes())
          .getOrElse((error) => fail('$error'))
          .last;
      final release = engine.mach9Release;
      expect(missing.kind, RuntimeKind.mach9);
      expect(missing.installed, isFalse);
      expect(missing.blocked, isNull);
      expect(missing.appPath, isNull);
      expect(missing.pinnedVersion, release.version);
      expect(missing.backends, ['wine', 'dxmt', 'mtld3d']);
      expect(missing.downloadBytes, release.bytes + release.mono.bytes);
      expect(missing.diskBytes, release.diskBytes);
      expect(missing.minimumMacos, release.minimumMacos);

      fakeMach9Runtime(home);
      final installed = (await repository().runtimes())
          .getOrElse((error) => fail('$error'))
          .last;
      expect(installed.usable, isTrue);
      expect(installed.version, release.version);
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

      test(
        'a cancelled Mono download is false, and fetches nothing else',
        () async {
          downloads(null);
          expect(await install(), const Right<AppError, bool>(false));
          expect(fetched, [engine.mach9Release.mono.url]);
          expect(steps, [Mach9Step.downloadingMono]);
          expect(Directory('$home/runtimes/mach9').existsSync(), isFalse);
        },
      );

      test('without a file or app it fetches the MSI and the DMG, and an '
          'engine failure deletes both', () async {
        downloads('not the pinned file');
        final error = (await install()).getLeft().toNullable();
        expect(error, isA<ChecksumMismatchError>());
        expect(fetched, [
          engine.mach9Release.mono.url,
          engine.mach9Release.url,
        ]);
        expect(steps, [Mach9Step.downloadingMono, Mach9Step.downloading]);
        expect(
          Directory('$home/downloads').listSync().whereType<File>(),
          isEmpty,
        );
        expect(Directory('$home/runtimes/mach9').existsSync(), isFalse);
      });

      test('a failure that is not about the files keeps them', () async {
        downloads('x');
        engine.hostPlatform = const _TooOldMac();
        final error = (await install()).getLeft().toNullable();
        expect(error, isNot(isA<ChecksumMismatchError>()));
        expect(fetched, [
          engine.mach9Release.mono.url,
          engine.mach9Release.url,
        ]);
        for (final file in [
          engine.mach9Release.mono.file,
          engine.mach9Release.file,
        ]) {
          expect(File('$home/downloads/$file').existsSync(), isTrue);
        }
      });

      test('a file given fetches only the MSI', () async {
        downloads('not the pinned file');
        await install(file: '$home/Mach9.dmg');
        expect(fetched, [engine.mach9Release.mono.url]);
      });

      test('an MSI already in downloads is not fetched again', () async {
        downloads('x');
        File('$home/downloads/${engine.mach9Release.mono.file}')
          ..createSync(recursive: true)
          ..writeAsStringSync('left by a cancelled try');
        await install(file: '$home/Mach9.dmg');
        expect(fetched, isEmpty);
        expect(steps, isNot(contains(Mach9Step.downloadingMono)));
      });
    });
  });
}
