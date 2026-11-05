import 'dart:isolate';

import 'package:bodega/data/service/app_mapper.dart';
import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/repository/library_repository.dart';
import 'package:engine/engine.dart' as engine;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: LibraryRepository)
class LibraryRepositoryImpl implements LibraryRepository {
  final EngineHome _home;

  LibraryRepositoryImpl(this._home);

  @override
  Future<Either<AppError, List<LibraryApp>>> apps() {
    final home = _home.path;
    return repositoryCall(
      () => Isolate.run(() => libraryApps(home, engine.installedApps(home))),
    );
  }

  @override
  Future<List<String>> bottleNames() async {
    try {
      return [for (final b in engine.listBottles(_home.path)) b.name];
    } on Object {
      return const [];
    }
  }

  @override
  Future<Either<AppError, String>> run(
    String bottle,
    String program, {
    List<String> args = const [],
  }) => repositoryCall(
    () => engine.runInBottle(_home.path, bottle, program, args),
  );

  @override
  Future<Either<AppError, String>> launch(
    String bottle,
    String program, {
    List<String> args = const [],
    Map<String, String> env = const {},
    String? backend,
    bool hud = false,
    bool avx = true,
  }) => repositoryCall(
    () => engine.runInBottle(
      _home.path,
      bottle,
      program,
      args,
      backend: backend,
      hud: hud,
      env: env,
      avx: avx,
    ),
  );

  @override
  Future<Either<AppError, Unit>> saveLauncher(
    String bottle,
    String title,
    String program, {
    List<String> args = const [],
    Map<String, String> env = const {},
  }) => repositoryCall(() {
    engine.addApp(
      _home.path,
      bottle,
      title,
      launcherExe(engine.bottleDir(_home.path, bottle), program),
      args: args,
      env: env,
    );
    return unit;
  });

  @override
  Future<Either<AppError, String>> open(String bottle, {String? key}) =>
      repositoryCall(() => engine.openApp(_home.path, bottle, key: key));

  @override
  Future<Either<AppError, Unit>> stop(String bottle) =>
      repositoryCall(() async {
        await engine.stopBottle(_home.path, bottle);
        return unit;
      });

  // A failure in these two only means there is nothing left to wait for.
  @override
  Future<void> firstExit(String log) =>
      repositoryCall(() => engine.exitOf(log));

  @override
  Future<void> waitBottle(String bottle) =>
      repositoryCall(() => engine.waitBottle(_home.path, bottle));

  @override
  List<String> antiCheatHints(String bottle, DateTime since) {
    try {
      return engine.antiCheatHints(_home.path, bottle, since: since);
    } on Object {
      return const [];
    }
  }

  @override
  Future<List<String>> hintsIn(String log) async {
    try {
      return await engine.hintsIn(log);
    } on Object {
      return const [];
    }
  }
}

/// How the engine keeps [program]: `C:\\X\\a.exe` and a path inside the
/// bottle's `drive_c` go relative to it; anything else stays absolute.
String launcherExe(String bottleDir, String program) {
  final drive = '$bottleDir/prefix/drive_c/';
  if (RegExp(r'^[A-Za-z]:\\').hasMatch(program)) {
    return program.substring(3).replaceAll(r'\', '/');
  }
  return program.startsWith(drive) ? program.substring(drive.length) : program;
}
