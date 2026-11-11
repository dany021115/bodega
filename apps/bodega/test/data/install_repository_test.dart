import 'dart:io';

import 'package:bodega/data/repository/install_repository_impl.dart';
import 'package:bodega/data/service/downloader.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '_home.dart';

class _MockDownloader extends Mock implements Downloader {}

void main() {
  setUpAll(() => registerFallbackValue(CancelToken()));

  late Directory home;
  late _MockDownloader downloader;
  late InstallRepositoryImpl repository;

  Future<String?> fetch() => downloader.fetch(
    any(),
    any(),
    cancel: any(named: 'cancel'),
    onProgress: any(named: 'onProgress'),
  );

  setUp(() {
    home = Directory.systemTemp.createTempSync('bodega-install');
    downloader = _MockDownloader();
    when(fetch)
        .thenAnswer((call) async => call.positionalArguments[1] as String);
    repository = InstallRepositoryImpl(TestHome(home.path), downloader);
  });

  tearDown(() => home.deleteSync(recursive: true));

  test('a catalog app whose bottle exists is not downloaded (E11)', () async {
    Directory('${home.path}/bottles/steam').createSync(recursive: true);

    final download = await repository.download('steam', (_, _) {});
    expect(
      download.getLeft().toNullable(),
      const AppError.bottleExists('steam'),
    );
    verifyNever(fetch);

    // Into that same bottle, it is.
    final into = await repository.download(
      'steam',
      (_, _) {},
      intoExisting: true,
    );
    expect(
      into.getRight().toNullable(),
      '${home.path}/downloads/steam-setup.exe',
    );
  });
}
