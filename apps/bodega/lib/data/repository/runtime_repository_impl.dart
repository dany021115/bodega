import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/engine_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/runtime_status.dart';
import 'package:bodega/domain/repository/runtime_repository.dart';
import 'package:engine/engine.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: RuntimeRepository)
class RuntimeRepositoryImpl implements RuntimeRepository {
  final EngineHome _home;

  RuntimeRepositoryImpl(this._home);

  @override
  Future<Either<AppError, RuntimeStatus>> status() => engineCall(
    () async => RuntimeStatus(
      rosetta: await rosettaInstalled(),
      runtime: hasRuntime(_home.path),
    ),
  );

  @override
  Future<Either<AppError, Unit>> install({
    required String engine,
    required String hostlibs,
  }) => engineCall(() async {
    await installRuntime(_home.path, engine, hostlibs);
    return unit;
  });
}
