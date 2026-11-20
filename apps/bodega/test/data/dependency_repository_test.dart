import 'dart:convert';
import 'dart:io';

import 'package:bodega/data/repository/dependency_repository_impl.dart';
import 'package:bodega/data/service/downloader.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/dependency.dart';
import 'package:dio/dio.dart';
import 'package:engine/engine.dart' as engine;
import 'package:engine/probe_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '_home.dart';

class _MockDownloader extends Mock implements Downloader {}

void main() {
  late Directory tmp;
  late String home;
  late _MockDownloader downloader;
  late DependencyRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(CancelToken()));

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bodega-deps-repo');
    home = engine.bodegaHome({'BODEGA_HOME': '${tmp.path}/home'});
    downloader = _MockDownloader();
    repository = DependencyRepositoryImpl(TestHome(home), downloader);
  });

  tearDown(() {
    engine.dependencyTable = engine.dependencies;
    tmp.deleteSync(recursive: true);
  });

  /// A bottle that holds Blur: a real 32-bit PE named as the game, and
  /// Microsoft's VC++ 2010 (32-bit) in place.
  void blurBottle() {
    final drive = '$home/bottles/b/prefix/drive_c';
    File('$drive/windows/syswow64/msvcr100.dll')
      ..createSync(recursive: true)
      ..writeAsBytesSync(latin1.encode('MZ'.padRight(64, '\u0000')));
    final exe = File('${tmp.path}/Blur/Blur.exe')
      ..createSync(recursive: true)
      ..writeAsBytesSync(base64.decode(probe32Base64));
    engine.addApp(home, 'b', 'Blur', exe.path);
  }

  test("a bottle's runtimes and its apps' needs become entities", () async {
    blurBottle();
    final data = (await repository.bottle('b')).getRight().toNullable()!;
    expect(data.all, hasLength(25));
    expect(data.checkedAt, isNotNull);
    expect(data.all.where((d) => d.installed), [
      const Dependency(
        id: 'vcrun2010',
        name: 'Visual C++ 2010',
        arch: Arch.x86,
        bytes: 5076456,
        status: DependencyStatus.installed,
      ),
    ]);
    final blur = data.apps.single;
    expect(blur.title, 'Blur');
    expect(blur.dependencies.single.dependency.id, 'vcrun2008');
    expect(blur.dependencies.single.dependency.arch, Arch.x86);
    expect(blur.dependencies.single.need, Need.recommended);
    expect(blur.dependencies.single.reason, NeedReason.knownFix);
    expect(blur.dependencies.single.fix, 'blur');
    expect(blur.hasRecommended, isTrue);

    final needs = (await repository.needs(
      'b',
      blur.key,
    )).getRight().toNullable()!;
    expect(needs, blur);
  });

  test('a catalog app gets the key of its exe', () async {
    final key = (await repository.catalogKey('steam')).getRight().toNullable();
    expect(key, 'program files (x86)/steam/steam.exe');
  });

  group('the installer', () {
    late String cached;

    setUp(() {
      cached = '$home/downloads/vcrun2008-x86.exe';
      File(cached)
        ..createSync(recursive: true)
        ..writeAsStringSync('the installer');
    });

    /// [engine.dependencyTable] with vcrun2008's x86 pinned to [sha256], and
    /// [more] downloads after it.
    void pin(String sha256, [List<engine.Download> more = const []]) {
      final row = engine.dependencies[1];
      final x86 = row.files['x86']!;
      engine.dependencyTable = [
        (
          id: row.id,
          name: row.name,
          imports: row.imports,
          dlls: row.dlls,
          windows: row.windows,
          files: {
            'x86': engine.DependencyFile.run(
              [
                (
                  url: 'https://example.com/vcrun2008-x86.exe',
                  sha256: sha256,
                  bytes: 13,
                  file: x86.downloads.single.file,
                ),
                ...more,
              ],
              args: x86.args,
              marker: x86.marker,
              wineManifests: x86.wineManifests,
            ),
            'x64': row.files['x64']!,
          },
        ),
      ];
    }

    test('one already downloaded that matches is used as it is', () async {
      pin(await engine.sha256Of(cached));
      final path = await repository.download('vcrun2008', Arch.x86, (_, _) {});
      expect(path.getRight().toNullable(), [cached]);
      verifyNever(
        () => downloader.fetch(
          any(),
          any(),
          cancel: any(named: 'cancel'),
          onProgress: any(named: 'onProgress'),
        ),
      );
    });

    test('one that does not match is downloaded again, in its place', () async {
      pin('0' * 64);
      when(
        () => downloader.fetch(
          any(),
          any(),
          cancel: any(named: 'cancel'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((call) async => call.positionalArguments[1] as String);
      final path = await repository.download('vcrun2008', Arch.x86, (_, _) {});
      expect(path.getRight().toNullable(), [cached]);
      verify(
        () => downloader.fetch(
          'https://example.com/vcrun2008-x86.exe',
          cached,
          cancel: any(named: 'cancel'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    });

    test('several files: only the missing ones download, and progress '
        'counts the ones there (RA3)', () async {
      pin(await engine.sha256Of(cached), [
        (
          url: 'https://example.com/second.exe',
          sha256: '0' * 64,
          bytes: 87,
          file: 'second.exe',
        ),
      ]);
      when(
        () => downloader.fetch(
          any(),
          any(),
          cancel: any(named: 'cancel'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((call) async {
        final onProgress =
            call.namedArguments[#onProgress] as void Function(int, int?);
        onProgress(40, 87);
        return call.positionalArguments[1] as String;
      });
      final seen = <(int, int?)>[];
      final paths = await repository.download(
        'vcrun2008',
        Arch.x86,
        (received, total) => seen.add((received, total)),
      );
      expect(paths.getRight().toNullable(), [
        cached,
        '$home/downloads/second.exe',
      ]);
      verify(
        () => downloader.fetch(
          'https://example.com/second.exe',
          '$home/downloads/second.exe',
          cancel: any(named: 'cancel'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      expect(seen, [(13, 100), (53, 100), (100, 100)]);
    });

    test("the engine's failures come back as codes", () async {
      final install = await repository.install('nope', 'vcrun2008', Arch.x86, [
        cached,
      ]);
      expect(install.getLeft().toNullable(), isA<BottleNotFoundError>());
      // The NFS fix's setting is the Mac's: on the Mac it looks for the bottle.
      engine.hostPlatform = const engine.MacPlatform();
      addTearDown(() => engine.hostPlatform = engine.HostPlatform.detect());
      final apply = await repository.applySettings(
        'nope',
        'need-for-speed-most-wanted-2012',
      );
      expect(apply.getLeft().toNullable(), isA<BottleNotFoundError>());
    });
  });

  test("a bottle that can't be read gives unknown (RA3)", () async {
    blurBottle();
    final syswow64 = '$home/bottles/b/prefix/drive_c/windows/syswow64';
    Process.runSync('/bin/chmod', ['000', syswow64]);
    addTearDown(() => Process.runSync('/bin/chmod', ['755', syswow64]));
    final data = (await repository.bottle('b')).getRight().toNullable()!;
    final vc2010 = data.all.firstWhere(
      (d) => d.id == 'vcrun2010' && d.arch == Arch.x86,
    );
    expect(vc2010.status, DependencyStatus.unknown);
    expect(data.all, hasLength(25));
    final dotnet = data.all.firstWhere((d) => d.id == 'dotnet48');
    expect((dotnet.arch, dotnet.files), (Arch.all, 2));
  });
}
