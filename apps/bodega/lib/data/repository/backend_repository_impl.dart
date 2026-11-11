import 'dart:io';

import 'package:bodega/data/service/code_mapper.dart';
import 'package:bodega/data/service/downloader.dart';
import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:bodega/domain/entities/gptk_step.dart';
import 'package:bodega/domain/repository/backend_repository.dart';
import 'package:dio/dio.dart';
import 'package:engine/engine.dart' as engine;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: BackendRepository)
class BackendRepositoryImpl implements BackendRepository {
  final EngineHome _home;
  final Downloader _downloader;
  CancelToken? _cancel;

  BackendRepositoryImpl(this._home, this._downloader);

  @override
  Future<Either<AppError, List<BackendInfo>>> list() => repositoryCall(
    () async => [
      for (final MapEntry(:key, :value)
          in engine.listBackends(_home.path).entries)
        BackendInfo(
          name: key,
          installed: value,
          downloadable: engine.pinnedBackend(key) != null,
          role: backendRoleOf(engine.hostPlatform.backendRole(key)),
          version: key == 'd3dmetal' && value
              ? await engine.d3dmetalVersion(_home.path)
              : null,
        ),
    ],
  );

  @override
  Future<Either<AppError, List<String>>> readyBottles() => repositoryCall(
    () => [
      for (final bottle in engine.listBottles(_home.path))
        if (bottle.ready) bottle.name,
    ],
  );

  @override
  Future<Either<AppError, bool>> download(
    String name,
    void Function(int received, int? total) onProgress,
  ) => repositoryCall(() async {
    final pin = engine.pinnedBackend(name);
    // Only pinned backends get a download button: the UI cannot reach this.
    if (pin == null) {
      throw AppError.unknown(detail: 'no installer for the backend $name');
    }
    final tarball = '${_home.path}/downloads/${pin.url.split('/').last}';
    if (!File(tarball).existsSync()) {
      final path = await _downloader.fetch(
        pin.url,
        tarball,
        cancel: _cancel = CancelToken(),
        onProgress: onProgress,
      );
      if (path == null) return false;
    }
    try {
      await engine.installBackend(_home.path, name, tarball: tarball);
    } on engine.EngineFailure {
      // A bad file must not be reused by the next attempt.
      File(tarball).deleteSync();
      rethrow;
    }
    return true;
  });

  @override
  void cancelDownload() => _cancel?.cancel();

  @override
  Future<Either<AppError, Unit>> installFile(String name, String tarball) =>
      repositoryCall(() async {
        await engine.installBackend(_home.path, name, tarball: tarball);
        return unit;
      });

  @override
  List<GptkRelease> get gptkReleases => [
    for (final release in engine.gptkReleases)
      GptkRelease(
        version: release.version,
        tested: release.tested,
        url: release.url,
      ),
  ];

  @override
  Future<Either<AppError, String?>> findGptkDmg(String version) =>
      repositoryCall(
        () => engine.findGptkDmg(
          version,
          '${Platform.environment['HOME']}/Downloads',
        ),
      );

  @override
  Future<Either<AppError, String?>> installD3DMetalDmg(
    String dmg, {
    required void Function(GptkStep step) onStep,
    required bool Function() cancelled,
  }) => repositoryCall(
    () => engine.installD3DMetalDmg(
      _home.path,
      dmg,
      onStep: (step) => onStep(gptkStepOf(step)),
      cancelled: cancelled,
    ),
  );

  @override
  Future<Either<AppError, Map<String, ExeGraphics>>> graphics(
    String bottle,
    List<String> exes,
  ) => repositoryCall(() async {
    final drive = '${engine.bottleDir(_home.path, bottle)}/prefix/drive_c';
    final backends = engine.listBackends(_home.path).keys;
    return {
      for (final exe in exes)
        if (await engine.exeGraphics(
              exe.startsWith('/')
                  ? exe
                  : engine.findCI(
                      drive,
                      exe
                          .replaceFirst(RegExp(r'^[cC]:\\'), '')
                          .replaceAll(r'\', '/'),
                    ),
            )
            case final found?)
          exe: ExeGraphics(
            bits: found.bits,
            directx: found.directx,
            misfits: [
              for (final backend in backends)
                if (!engine.hostPlatform.backendFits(backend, found)) backend,
            ],
          ),
    };
  });

  @override
  Future<Either<AppError, List<ProbeResult>>> check(
    String bottle,
    String backend,
  ) => repositoryCall(() async {
    final results = await engine.backendTest(_home.path, bottle, backend);
    return [
      for (final result in results)
        ProbeResult(
          bits: result.bits,
          d3d: result.d3d,
          ok: result.ok,
          log: result.log,
        ),
    ];
  });
}
