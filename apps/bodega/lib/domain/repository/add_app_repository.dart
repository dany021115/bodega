import 'package:bodega/domain/entities/app_error.dart';
import 'package:fpdart/fpdart.dart';

abstract class AddAppRepository {
  /// The bottles an application can go into.
  Future<Either<AppError, List<String>>> readyBottles();

  /// What makes [path] unusable, or null if it can be used.
  String? pathProblem(String path);

  /// Creates a bottle named after [title], and returns that name.
  Future<Either<AppError, String>> createBottle(String title);

  /// Registers [exe], an absolute path, as the bottle's app.
  Future<Either<AppError, Unit>> addApp(
    String bottle,
    String title,
    String exe,
  );

  /// Runs an installer, and ends when the bottle has nothing left open.
  Future<Either<AppError, Unit>> runInstaller(String bottle, String exe);

  String driveC(String bottle);
}
