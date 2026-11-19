import 'dart:io';

import 'package:bodega/data/service/code_mapper.dart';
import 'package:bodega/data/service/downloader.dart';
import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:bodega/domain/entities/gptk_step.dart';
import 'package:bodega/domain/entities/mach9_step.dart';
import 'package:bodega/domain/entities/runtime_info.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
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
  Future<Either<AppError, List<RuntimeInfo>>> runtimes() => repositoryCall(
    () => [
      for (final runtime in engine.listRuntimes(_home.path))
        _runtimeInfo(runtime),
    ],
  );

  /// MR4, design §3.3: the Mono MSI and, without [file] or a Mach9.app at the
  /// pinned version, the DMG come through the Downloader, so they show
  /// progress and stop on [cancelDownload]; then the engine checks and copies.
  /// What sits in `downloads/` goes after success and after an engine
  /// failure, never after a cancel, so the next try reuses it.
  @override
  Future<Either<AppError, bool>> installRuntime(
    RuntimeKind kind, {
    String? file,
    required void Function(int received, int? total) onProgress,
    required void Function(Mach9Step step) onStep,
  }) => repositoryCall(() async {
    if (kind == RuntimeKind.bodega) {
      throw const AppError.unknown(
        detail: "Bodega's Wine comes with the app, not from here",
      );
    }
    final release = engine.mach9Release;
    final cancel = _cancel = CancelToken();
    final downloads = <String>[];

    Future<String?> fetch(String url, String name, Mach9Step step) async {
      final dest = '${_home.path}/downloads/$name';
      downloads.add(dest);
      if (File(dest).existsSync()) return dest;
      onStep(step);
      return _downloader.fetch(
        url,
        dest,
        cancel: cancel,
        onProgress: onProgress,
      );
    }

    final mono = await fetch(
      release.mono.url,
      release.mono.file,
      Mach9Step.downloadingMono,
    );
    if (mono == null) return false;
    var source = file;
    var pinned = false;
    if (source == null) {
      final app = engine.findMach9App();
      if (app != null && app.version == release.version) {
        source = app.path;
      } else {
        source = await fetch(release.url, release.file, Mach9Step.downloading);
        if (source == null) return false;
        pinned = true;
      }
    }
    try {
      await engine.installMach9(
        _home.path,
        source: source,
        pinned: pinned,
        mono: mono,
        onStep: (step) => onStep(mach9StepOf(step)),
        cancelled: () => cancel.isCancelled,
      );
    } on engine.Cancelled {
      return false;
    } on engine.ChecksumMismatch {
      _deleteAll(downloads);
      rethrow;
    } on engine.RuntimeNotTrusted {
      _deleteAll(downloads);
      rethrow;
    } on engine.IncompleteArchive {
      // A bad file must not be reused by the next attempt; a good one is
      // kept when the failure is not about it (an open bottle, say).
      _deleteAll(downloads);
      rethrow;
    }
    _deleteAll(downloads);
    return true;
  });

  static void _deleteAll(List<String> files) {
    for (final path in files) {
      if (File(path).existsSync()) File(path).deleteSync();
    }
  }

  /// MA4: Mach9 bottles cannot run the Rosetta check.
  @override
  Future<Either<AppError, List<String>>> readyBottles() => repositoryCall(
    () => [
      for (final bottle in engine.listBottles(_home.path))
        if (bottle.ready && bottle.runtime == engine.RuntimeKind.bodega)
          bottle.name,
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
    final kind = engine.bottleRuntime(_home.path, bottle);
    final backends = engine.listBackends(_home.path, runtime: kind).keys;
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
                if (!engine.backendFitsFor(kind, backend, found)) backend,
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

/// The engine's view of one runtime kind, with the pinned release's numbers
/// for the engine card (MR3).
RuntimeInfo _runtimeInfo(engine.RuntimeInfo runtime) {
  final mach9 = runtime.kind == engine.RuntimeKind.mach9;
  final release = engine.mach9Release;
  return RuntimeInfo(
    kind: runtimeKindOf(runtime.kind),
    installed: runtime.installed,
    version: runtime.version,
    checked: runtime.checked,
    blocked: switch (runtime.blocked) {
      final block? => runtimeBlockOf(block),
      null => null,
    },
    appPath: runtime.app?.path,
    appVersion: runtime.app?.version,
    pinnedVersion: mach9 ? release.version : null,
    backends: mach9 ? engine.backendNamesFor(runtime.kind) : const [],
    downloadBytes: mach9 ? release.bytes + release.mono.bytes : 0,
    diskBytes: mach9 ? release.diskBytes : 0,
    minimumMacos: mach9 ? release.minimumMacos : null,
  );
}
