import 'dart:convert';
import 'dart:io';

import 'package:bodega/data/service/downloader.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/app_update.dart';
import 'package:bodega/domain/repository/update_repository.dart';
import 'package:dio/dio.dart';
import 'package:engine/engine.dart' as engine;
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The repository is public, so the app reads its own releases. Up to 1.4.1
/// it read `bodega-releases`, which the release workflows still fill for them.
const _latest =
    'https://api.github.com/repos/dany021115/bodega/releases/latest';

/// Run by `sh` apart from the app: waits for Bodega to close, then puts the
/// new version in its place and opens it. If the move fails, the old version
/// goes back.
const _swap = r'''
while kill -0 "$1" 2>/dev/null; do sleep 0.5; done
if mv "$2" "$2.old" && mv "$3" "$2"; then
  rm -rf "$2.old"
elif [ -d "$2.old" ] && [ ! -e "$2" ]; then
  mv "$2.old" "$2"
fi
open "$2"
''';

@LazySingleton(as: UpdateRepository)
class UpdateRepositoryImpl implements UpdateRepository {
  final Dio _dio;
  final Downloader _downloader;
  final Preferences _preferences;
  CancelToken? _cancel;

  UpdateRepositoryImpl(this._dio, this._downloader, this._preferences);

  @visibleForTesting
  String latestUrl = _latest;

  @visibleForTesting
  String os = Platform.operatingSystem;

  @visibleForTesting
  Map<String, String> environment = Platform.environment;

  @visibleForTesting
  DateTime Function() now = DateTime.now;

  /// The running `.app` on macOS.
  @visibleForTesting
  late String appPath = File(Platform.resolvedExecutable)
      .parent
      .parent
      .parent
      .path;

  /// Outside the data folder, which an update never touches (A5).
  @visibleForTesting
  String downloads = '${Directory.systemTemp.path}/bodega-update';

  @override
  Future<Either<AppError, AppUpdate?>> check() => repositoryCall(() async {
    try {
      final last = _preferences.getUpdateCheckedAt();
      if (last != null && now().difference(last) < const Duration(hours: 24)) {
        return null;
      }
      final release = (await _dio.get<Map<String, dynamic>>(latestUrl)).data!;
      await _preferences.saveUpdateCheckedAt(now());
      final latest = _semver('${release['tag_name']}');
      final current = (await PackageInfo.fromPlatform()).version;
      final running = _semver(current);
      if (latest == null || running == null) return null;
      if (_compare(latest, running) <= 0) return null;
      final version = latest.join('.');
      if (_preferences.getUpdateSkipped() == version) return null;

      final assets = {
        for (final asset in release['assets'] as List)
          (asset as Map)['name'] as String:
              asset['browser_download_url'] as String,
      };
      // A2: what this machine can install by itself.
      final (installer, sums) = switch (os) {
        'macos' => ('Bodega-$version-macos-arm64.dmg', 'SHA256SUMS-macos'),
        'linux' when environment.containsKey('APPIMAGE') => (
          'Bodega-$version-linux-x86_64.AppImage',
          'SHA256SUMS-linux',
        ),
        _ => (null, null),
      };
      return AppUpdate(
        version: version,
        current: current,
        notes: '${release['body'] ?? ''}'.trim(),
        page: '${release['html_url']}',
        installer: assets[installer],
        sums: assets[sums],
        command: installer != null
            ? ''
            : File('/usr/bin/pacman').existsSync()
            ? 'sudo pacman -U Bodega-$version-arch-x86_64.pkg.tar.zst'
            : 'sudo apt install ./Bodega-$version-linux-amd64.deb',
      );
    } catch (_) {
      // A1: no network, a 404 or an odd answer: no notice.
      return null;
    }
  });

  @override
  Future<Either<AppError, Unit>> skip(String version) =>
      repositoryCall(() async {
        await _preferences.saveUpdateSkipped(version);
        return unit;
      });

  @override
  Future<Either<AppError, String?>> download(
    AppUpdate update,
    void Function(int received, int? total) onProgress,
  ) => repositoryCall(() async {
    final installer = update.installer, sums = update.sums;
    if (installer == null || sums == null) {
      throw const AppError.updateUnsupported();
    }
    final name = Uri.parse(installer).pathSegments.last;
    final listing = (await _dio.get<String>(
      sums,
      options: Options(responseType: ResponseType.plain),
    )).data;
    // `sha256sum` lines: `<hash>  <name>`, with `*` before binary names.
    final want = [
      for (final line in LineSplitter.split(listing ?? ''))
        if (line.trim().split(RegExp(r'\s+')) case [final hash, final file]
            when file.replaceFirst('*', '') == name)
          hash.toLowerCase(),
    ].firstOrNull;
    if (want == null) throw AppError.updateNoChecksum(name);
    final file = await _downloader.fetch(
      installer,
      '$downloads/$name',
      cancel: _cancel = CancelToken(),
      onProgress: onProgress,
    );
    if (file == null) return null;
    if (await engine.sha256Of(file) != want) {
      File(file).deleteSync();
      throw AppError.updateChecksumMismatch(name);
    }
    return file;
  });

  @override
  void cancel() => _cancel?.cancel();

  @override
  Future<Either<AppError, Unit>> install(String file) =>
      repositoryCall(() async {
        final (command, args) = await prepare(file);
        await Process.start(command, args, mode: ProcessStartMode.detached);
        return unit;
      });

  @override
  void quit() => exit(0);

  /// A4: puts the new version beside the running one and says what to run
  /// once the app closes (design §3, §4). Touches nothing else (A5).
  @visibleForTesting
  Future<(String, List<String>)> prepare(String file) async {
    if (environment['APPIMAGE'] case final appImage? when os == 'linux') {
      final next = '$appImage.new';
      File(file).copySync(next);
      await _run('chmod', ['755', next]);
      // Linux lets a running executable be replaced by a rename.
      File(next).renameSync(appImage);
      File(file).deleteSync();
      return (appImage, <String>[]);
    }
    if (os != 'macos') throw const AppError.updateUnsupported();
    if (!appPath.endsWith('.app')) throw AppError.updateNotInBundle(appPath);
    final parent = Directory(appPath).parent.path;
    try {
      File('$parent/.bodega-write-test')
        ..writeAsStringSync('')
        ..deleteSync();
    } on FileSystemException {
      throw AppError.updateNotWritable(parent);
    }
    final staged = '$parent/.Bodega-update.app';
    final mount = Directory.systemTemp.createTempSync('bodega-update').path;
    await _run('/usr/bin/hdiutil', [
      'attach',
      '-nobrowse',
      '-readonly',
      '-mountpoint',
      mount,
      file,
    ]);
    try {
      final app = Directory(mount)
          .listSync()
          .whereType<Directory>()
          .where((dir) => dir.path.endsWith('.app'))
          .firstOrNull;
      if (app == null) throw const AppError.updateNoApp();
      if (Directory(staged).existsSync()) {
        Directory(staged).deleteSync(recursive: true);
      }
      await _run('/usr/bin/ditto', [app.path, staged]);
    } finally {
      await Process.run('/usr/bin/hdiutil', ['detach', mount]);
      try {
        Directory(mount).deleteSync();
      } on FileSystemException {
        // Detaching removed it.
      }
    }
    File(file).deleteSync();
    final script = File('$downloads/swap.sh')
      ..createSync(recursive: true)
      ..writeAsStringSync(_swap);
    return ('/bin/sh', [script.path, '$pid', appPath, staged]);
  }
}

/// `X.Y.Z`, with or without `v`, as numbers; null for anything else.
List<int>? _semver(String text) {
  final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(text.trim());
  return match == null
      ? null
      : [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
}

int _compare(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

Future<void> _run(String exe, List<String> args) async {
  final result = await Process.run(exe, args);
  if (result.exitCode != 0) {
    throw AppError.processFailed(
      exe,
      result.exitCode,
      '${result.stderr}'.trim(),
    );
  }
}
