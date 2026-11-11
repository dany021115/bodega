import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/path_problem.dart';
import 'package:fpdart/fpdart.dart';

abstract class AddAppRepository {
  /// What makes [path] unusable, or null if it can be used.
  PathProblem? pathProblem(String path);

  /// Registers [exe], an absolute path, as the bottle's app, and returns its key.
  Future<Either<AppError, String>> addApp(
    String bottle,
    String title,
    String exe,
  );

  /// Runs an installer, and ends when the bottle has nothing left open.
  Future<Either<AppError, Unit>> runInstaller(String bottle, String exe);

  String driveC(String bottle);
}
