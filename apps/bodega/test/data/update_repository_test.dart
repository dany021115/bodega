import 'dart:convert';
import 'dart:io';

import 'package:bodega/data/repository/update_repository_impl.dart';
import 'package:bodega/data/service/downloader.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/app_update.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;
  late HttpServer server;
  late String base;
  late UpdateRepositoryImpl repository;
  late DateTime clock;
  var tag = 'v1.4.0';
  var requests = 0;
  var dmg = utf8.encode('dmg nuevo');
  var sums = '';

  String sha(List<int> bytes) => Process.runSync('/usr/bin/shasum', [
    '-a',
    '256',
    _write('${tmp.path}/sha', bytes),
  ]).stdout.toString().split(' ').first;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('bodega-update');
    tag = 'v1.4.0';
    requests = 0;
    dmg = utf8.encode('dmg nuevo');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    sums = '${sha(dmg)}  Bodega-1.4.0-macos-arm64.dmg\n';
    server.listen((request) {
      final response = request.response;
      switch (request.uri.path) {
        case '/latest':
          requests++;
          response.headers.contentType = ContentType.json;
          response.write(
            jsonEncode({
              'tag_name': tag,
              'body': 'Novedades',
              'html_url': '$base/page',
              'assets': [
                {
                  'name': 'Bodega-1.4.0-macos-arm64.dmg',
                  'browser_download_url':
                      '$base/download/Bodega-1.4.0-macos-arm64.dmg',
                },
                {
                  'name': 'SHA256SUMS-macos',
                  'browser_download_url': '$base/download/SHA256SUMS-macos',
                },
              ],
            }),
          );
        case '/download/Bodega-1.4.0-macos-arm64.dmg':
          response.add(dmg);
        case '/download/SHA256SUMS-macos':
          response.write(sums);
        default:
          response.statusCode = 404;
      }
      response.close();
    });

    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Bodega',
      packageName: 'com.dany021115.bodega',
      version: '1.3.0',
      buildNumber: '1',
      buildSignature: '',
    );
    clock = DateTime(2026, 11, 9, 12);
    repository =
        UpdateRepositoryImpl(
            Dio(),
            Downloader(Dio())..httpsOnly = false,
            Preferences(await SharedPreferences.getInstance()),
          )
          ..latestUrl = '$base/latest'
          ..os = 'macos'
          ..environment = const {}
          ..now = (() => clock)
          ..downloads = '${tmp.path}/descargas';
  });

  tearDown(() async {
    await server.close(force: true);
    tmp.deleteSync(recursive: true);
  });

  Future<AppUpdate?> check() async =>
      (await repository.check()).getOrElse((error) => fail('$error'));

  test('a newer release is an update for this Mac (A1, A2)', () async {
    final update = await check();
    expect(update?.version, '1.4.0');
    expect(update?.current, '1.3.0');
    expect(update?.notes, 'Novedades');
    expect(update?.installer, '$base/download/Bodega-1.4.0-macos-arm64.dmg');
    expect(update?.installable, isTrue);
  });

  test('the same or an older release is not, nor a bad tag (A1)', () async {
    for (final old in ['v1.3.0', 'v1.2.9', '1.3', 'latest']) {
      tag = old;
      clock = clock.add(const Duration(days: 1));
      expect(await check(), isNull, reason: old);
    }
  });

  test('once a day at most, and no answer is no notice (A1)', () async {
    expect(await check(), isNotNull);
    clock = clock.add(const Duration(hours: 23));
    expect(await check(), isNull);
    expect(requests, 1);
    clock = clock.add(const Duration(hours: 2));
    repository.latestUrl = '$base/nada';
    expect(await check(), isNull);
    await server.close(force: true);
    expect(await check(), isNull);
  });

  test('"Ahora no" silences that version, not the next (A1)', () async {
    await repository.skip('1.4.0');
    expect(await check(), isNull);
    tag = 'v1.4.1';
    clock = clock.add(const Duration(days: 1));
    expect((await check())?.version, '1.4.1');
  });

  test('a Linux package only gets the command and the page (A2)', () async {
    repository.os = 'linux';
    final update = await check();
    expect(update?.installable, isFalse);
    expect(update?.command, contains('1.4.0'));
    expect(update?.page, '$base/page');
  });

  test('the download must match its SHA-256 (A4)', () async {
    final update = (await check())!;
    final file = (await repository.download(
      update,
      (_, _) {},
    )).getOrElse((error) => fail('$error'));
    expect(File(file!).readAsStringSync(), 'dmg nuevo');

    sums = '${'0' * 64}  Bodega-1.4.0-macos-arm64.dmg\n';
    File(file).deleteSync();
    final bad = await repository.download(update, (_, _) {});
    expect(
      bad.getLeft().toNullable(),
      const AppError.checksumMismatch('Bodega-1.4.0-macos-arm64.dmg'),
    );
    expect(File(file).existsSync(), isFalse);
  });

  test('a release that lists no SHA-256 for its installer downloads nothing '
      '(A4)', () async {
    sums = '${sha(dmg)}  Bodega-1.4.0-linux-x86_64.AppImage\n';
    final update = (await check())!;
    final none = await repository.download(update, (_, _) {});
    expect(
      none.getLeft().toNullable(),
      const AppError.updateNoChecksum('Bodega-1.4.0-macos-arm64.dmg'),
    );
    expect(Directory(repository.downloads).existsSync(), isFalse);
  });

  test('what this copy cannot install by itself is not installable (A2, '
      'A4)', () async {
    repository.os = 'linux';
    final update = (await check())!;
    final download = await repository.download(update, (_, _) {});
    expect(
      download.getLeft().toNullable(),
      const AppError.updateNotInstallable(),
    );

    final image = _write('${tmp.path}/Bodega.dmg', utf8.encode('dmg'));
    Future<AppError?> install() async =>
        (await repository.install(image)).getLeft().toNullable();
    // Linux without an AppImage, then a Mac that does not run a .app.
    expect(await install(), const AppError.updateNotInstallable());
    repository
      ..os = 'macos'
      ..appPath = '${tmp.path}/bodega';
    expect(await install(), const AppError.updateNotInstallable());
  });

  test('a folder Bodega cannot write to is not writable (A4)', () async {
    final locked = Directory('${tmp.path}/Locked')..createSync();
    await Process.run('chmod', ['555', locked.path]);
    addTearDown(() => Process.run('chmod', ['755', locked.path]));
    repository.appPath = '${locked.path}/Bodega.app';
    final image = _write('${tmp.path}/Bodega.dmg', utf8.encode('dmg'));

    final install = await repository.install(image);
    expect(
      install.getLeft().toNullable(),
      AppError.updateNotWritable(locked.path),
    );
  });

  test('a file that is not a dmg is hdiutil failing, with what it said as '
      'the detail (E13)', () async {
    final apps = Directory('${tmp.path}/Apps')..createSync();
    repository.appPath = '${apps.path}/Bodega.app';
    final file = _write('${tmp.path}/Bodega.dmg', utf8.encode('not a dmg'));

    final install = await repository.install(file);
    expect(
      install.getLeft().toNullable(),
      isA<ProcessFailedError>()
          .having((e) => e.command, 'command', '/usr/bin/hdiutil')
          .having((e) => e.exitCode, 'exitCode', allOf(isNotNull, isNonZero))
          .having(
            (e) => e.detail,
            'detail',
            contains('hdiutil: attach failed'),
          ),
    );
    expect(apps.listSync(), isEmpty);
  }, skip: File('/usr/bin/hdiutil').existsSync() ? false : 'needs hdiutil');

  test('a dmg without the app is incomplete (A4)', () async {
    final apps = Directory('${tmp.path}/Apps')..createSync();
    repository.appPath = '${apps.path}/Bodega.app';
    _write('${tmp.path}/other/README', utf8.encode('no app here'));
    final image = '${tmp.path}/Bodega.dmg';
    final created = await Process.run('/usr/bin/hdiutil', [
      'create',
      '-quiet',
      '-srcfolder',
      '${tmp.path}/other',
      '-ov',
      image,
    ]);
    expect(created.exitCode, 0, reason: '${created.stderr}');

    final install = await repository.install(image);
    expect(
      install.getLeft().toNullable(),
      AppError.incompleteArchive(image, 'Bodega.app'),
    );
    expect(apps.listSync(), isEmpty);
  }, skip: File('/usr/bin/hdiutil').existsSync() ? false : 'needs hdiutil');

  test('macOS: the new app waits beside the old one, and the swap keeps the '
      'data (A4, A5)', () async {
    final apps = Directory('${tmp.path}/Apps')..createSync();
    final app = '${apps.path}/Bodega.app';
    _write('$app/Contents/Info.plist', utf8.encode('vieja'));
    _write(
      '${tmp.path}/nueva/Bodega.app/Contents/Info.plist',
      utf8.encode('nueva'),
    );
    final data = _write('${tmp.path}/datos/botella.json', utf8.encode('{}'));
    final image = '${tmp.path}/Bodega.dmg';
    await Process.run('/usr/bin/hdiutil', [
      'create',
      '-quiet',
      '-srcfolder',
      '${tmp.path}/nueva',
      '-ov',
      image,
    ]);
    repository.appPath = app;

    final (command, args) = await repository.prepare(image);
    expect(command, '/bin/sh');
    expect(
      apps
          .listSync()
          .map((e) => e.uri.pathSegments.lastWhere((s) => s.isNotEmpty))
          .toList()
        ..sort(),
      ['.Bodega-update.app', 'Bodega.app'],
    );
    expect(File(image).existsSync(), isFalse);
    expect(
      '${(await Process.run('/usr/bin/hdiutil', ['info'])).stdout}',
      isNot(contains('bodega-update')),
    );

    // The swap, with a fake `open` and a process that already ended.
    final bin = Directory('${tmp.path}/bin')..createSync();
    _write(
      '${bin.path}/open',
      utf8.encode('#!/bin/sh\necho "\$@" > "${tmp.path}/opened"\n'),
    );
    await Process.run('chmod', ['755', '${bin.path}/open']);
    final swap = await Process.run(
      command,
      [args[0], '999999', args[2], args[3]],
      environment: {'PATH': '${bin.path}:/usr/bin:/bin'},
    );
    expect(swap.exitCode, 0, reason: '${swap.stderr}');
    expect(File('$app/Contents/Info.plist').readAsStringSync(), 'nueva');
    expect(Directory('$app.old').existsSync(), isFalse);
    expect(Directory('${apps.path}/.Bodega-update.app').existsSync(), isFalse);
    expect(File('${tmp.path}/opened').readAsStringSync().trim(), app);
    expect(File(data).readAsStringSync(), '{}');
  }, skip: File('/usr/bin/hdiutil').existsSync() ? false : 'needs hdiutil');

  test('an AppImage takes the place of the running one (A4)', () async {
    final appImage = _write(
      '${tmp.path}/Bodega.AppImage',
      utf8.encode('vieja'),
    );
    final download = _write('${tmp.path}/nueva.AppImage', utf8.encode('nueva'));
    repository
      ..os = 'linux'
      ..environment = {'APPIMAGE': appImage};

    final (command, args) = await repository.prepare(download);
    expect(command, appImage);
    expect(args, isEmpty);
    expect(File(appImage).readAsStringSync(), 'nueva');
    expect(File(appImage).statSync().mode & 0x40, isNonZero);
    expect(File(download).existsSync(), isFalse);
  });
}

String _write(String path, List<int> bytes) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
  return path;
}
