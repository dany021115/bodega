import 'dart:io';
import 'dart:typed_data';

import 'package:bodega/data/repository/backend_repository_impl.dart';
import 'package:bodega/data/service/downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '_home.dart';

class _MockDownloader extends Mock implements Downloader {}

void main() {
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
    expect(found.values.single.directx, 'DX9');
    expect(found.values.single.bits, 32);
  });
}
