import 'dart:io';
import 'dart:typed_data';

import 'package:bodega/data/repository/backend_repository_impl.dart';
import 'package:bodega/data/service/downloader.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '_home.dart';

class _MockDownloader extends Mock implements Downloader {}

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
    File('${home.path}/bottles/juegos/prefix/drive_c/Blur/Blur.exe')
      ..createSync(recursive: true)
      ..writeAsBytesSync([
        ...header.buffer.asUint8List(),
        ...'d3d9.dll d3d10 dxgi.dll'.codeUnits,
      ]);

    final found =
        (await BackendRepositoryImpl(
          TestHome(home.path),
          _MockDownloader(),
        ).graphics('juegos', [r'C:\blur\BLUR.exe', r'C:\no.exe'])).getOrElse(
          (error) => fail('$error'),
        );

    expect(found.keys, [r'C:\blur\BLUR.exe']);
    final graphics = found.values.single;
    expect((graphics.directx, graphics.bits), ('DX9', 32));
  });
}
