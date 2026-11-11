import 'dart:async';

import 'package:bodega/data/service/code_mapper.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/path_problem.dart';
import 'package:dio/dio.dart';
import 'package:engine/engine.dart' as engine;
import 'package:fpdart/fpdart.dart';

/// What a repository's work throws, as a [Left] holding a code (design §5):
/// an [AppError] as it is, an [engine.EngineFailure] through [appErrorOf], a
/// [DioException] as [AppError.network] and anything else as
/// [AppError.unknown], each with its raw text as `detail`.
Future<Either<AppError, T>> repositoryCall<T>(
  FutureOr<T> Function() call,
) async {
  try {
    return right(await call());
  } on AppError catch (error) {
    return left(error);
  } on engine.EngineFailure catch (failure) {
    return left(appErrorOf(failure));
  } on DioException catch (e) {
    return left(AppError.network(detail: '$e'));
  } on Object catch (e) {
    return left(AppError.unknown(detail: '$e'));
  }
}

/// The code of [failure], with its English message as `detail` (E10). One
/// case per failure and no default, so a failure the engine adds fails the
/// build here until the domain has a code for it (E12).
AppError appErrorOf(engine.EngineFailure failure) {
  final detail = failure.message;
  return switch (failure) {
    engine.BottleNotFound(:final bottle) => AppError.bottleNotFound(
      bottle,
      detail: detail,
    ),
    engine.BottleExists(:final bottle) => AppError.bottleExists(
      bottle,
      detail: detail,
    ),
    engine.BottleNotReady(:final bottle) => AppError.bottleNotReady(
      bottle,
      detail: detail,
    ),
    engine.BottleOpen(:final bottle) => AppError.bottleOpen(
      bottle,
      detail: detail,
    ),
    engine.BottleSetupFailed(:final log, :final timedOut) =>
      AppError.bottleSetupFailed(log, timedOut, detail: detail),
    engine.BadBottleName(:final name) => AppError.badBottleName(
      name,
      detail: detail,
    ),
    engine.BadWindowsPath(:final problem) => AppError.badPath(
      pathProblemOf(problem),
      detail: detail,
    ),
    engine.BadUserName(:final user, :final problem) => AppError.badUserName(
      user,
      userNameProblemOf(problem),
      detail: detail,
    ),
    engine.AppNotFound(:final bottle, :final key) => AppError.appNotFound(
      bottle,
      key,
      detail: detail,
    ),
    engine.AppAlreadyAdded(:final bottle) => AppError.appAlreadyAdded(
      bottle,
      detail: detail,
    ),
    engine.MissingFile(:final path) => AppError.badPath(
      PathProblem.missing(path),
      detail: detail,
    ),
    // The checksum file beside a runtime tarball.
    engine.ChecksumMissing(:final file) => AppError.badPath(
      PathProblem.missing(file),
      detail: detail,
    ),
    engine.ChecksumMismatch(:final file) => AppError.checksumMismatch(
      file,
      detail: detail,
    ),
    engine.IncompleteArchive(:final archive, :final missing) =>
      AppError.incompleteArchive(archive, missing, detail: detail),
    engine.CorruptData(:final source) => AppError.corruptData(
      source,
      detail: detail,
    ),
    engine.NoRuntime() => AppError.noRuntime(detail: detail),
    engine.AlreadyInstalled(:final path) => AppError.alreadyInstalled(
      path,
      detail: detail,
    ),
    // The app never triggers these (design §5): its capabilities hide what
    // the host lacks, only pinned backends offer a download, its choices come
    // from lists, a blocked app has no install button and the app passes the
    // installer it downloaded.
    engine.NotAvailable() ||
    engine.NotDownloadable() ||
    engine.BadChoice() ||
    engine.CatalogBlocked() ||
    engine.NotHttps() => AppError.unknown(detail: detail),
    engine.BackendNotInstalled(:final backend) => AppError.backendNotInstalled(
      backend,
      detail: detail,
    ),
    engine.NoD3DMetal(:final source, :final missing) => AppError.noD3DMetal(
      source,
      missing,
      detail: detail,
    ),
    engine.CrossOverCopy() => AppError.crossOverCopy(detail: detail),
    engine.MountFailed(:final image) => AppError.mountFailed(
      image,
      detail: detail,
    ),
    engine.Cancelled() => AppError.cancelled(detail: detail),
    engine.LicenseNotAccepted() => AppError.licenseNotAccepted(detail: detail),
    engine.WineToolFailed(:final tool, :final exitCode, :final log) =>
      AppError.wineToolFailed(wineToolOf(tool), exitCode, log, detail: detail),
    engine.InstallerNoExe(:final exe, :final log) => AppError.installerNoExe(
      exe,
      log,
      detail: detail,
    ),
    engine.ProcessFailed(:final command, :final exitCode) =>
      AppError.processFailed(command, exitCode, detail: detail),
    engine.NoEmulator(:final name, :final app) => AppError.noEmulator(
      name,
      app,
      detail: detail,
    ),
    engine.NotAnEmulator(:final path, :final name) => AppError.notAnEmulator(
      path,
      name,
      detail: detail,
    ),
    // "Add games" takes any app bundle, so one that is not a native app gets
    // here from the app. The extensions stay in the message (design §6).
    engine.NotASwitchGame(:final path) => AppError.notASwitchGame(
      path,
      detail: detail,
    ),
    engine.SwitchGameNotFound(:final path) => AppError.switchGameNotFound(
      path,
      detail: detail,
    ),
    engine.SwitchGameRunning(:final path) => AppError.switchGameRunning(
      path,
      detail: detail,
    ),
  };
}
