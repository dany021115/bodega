import 'package:bodega/data/service/code_mapper.dart';
import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/host_capabilities.dart';
import 'package:bodega/domain/entities/runtime_status.dart';
import 'package:bodega/domain/repository/runtime_repository.dart';
import 'package:engine/engine.dart'
    show checkHost, hasRuntime, hostCapabilities, installRuntime;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: RuntimeRepository)
class RuntimeRepositoryImpl implements RuntimeRepository {
  final EngineHome _home;

  RuntimeRepositoryImpl(this._home);

  @override
  Future<Either<AppError, RuntimeStatus>> status() => repositoryCall(() async {
    final issues = await checkHost();
    final caps = hostCapabilities();
    return RuntimeStatus(
      issues: [for (final issue in issues) hostIssueOf(issue)],
      runtime: hasRuntime(_home.path),
      capabilities: HostCapabilities(
        highRes: caps.highRes,
        avx: caps.avx,
        dlss: caps.dlss,
        d3dmetal: caps.d3dmetal,
        sdl: caps.sdl,
        gpu: caps.gpu,
        gameMode: caps.gameMode,
        syncModes: caps.syncModes,
      ),
    );
  });

  @override
  Future<Either<AppError, Unit>> install({
    required String engine,
    required String hostlibs,
  }) => repositoryCall(() async {
    await installRuntime(_home.path, engine, hostlibs);
    return unit;
  });
}
