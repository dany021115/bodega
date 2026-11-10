import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/entities/user_problem.dart';
import 'package:fpdart/fpdart.dart';

abstract class BottleRepository {
  Future<Either<AppError, List<Bottle>>> list();

  Future<Either<AppError, BottleDetail>> detail(String name);

  /// The bottle's backend or, with [exe], that program's exception. `auto` on
  /// a program removes its exception.
  Future<Either<AppError, Unit>> setBackend(
    String name,
    String backend, {
    String? exe,
  });

  /// Closes what is open in the bottle.
  Future<Either<AppError, Unit>> setSync(String name, String sync);

  /// Closes what is open in the bottle.
  Future<Either<AppError, Unit>> setHighRes(String name, bool value);

  /// U4: the Windows user of [name]'s games; null for the host's. Stops the
  /// bottle and takes its profile folder along.
  Future<Either<AppError, Unit>> setUser(String name, String? user);

  /// U3: why [user] cannot be a Windows user name, or null if it can.
  UserProblem? userProblem(String user);

  Future<Either<AppError, Unit>> setWindowsVersion(String name, String version);

  Future<Either<AppError, Unit>> setOptions(
    String name, {
    bool? dlss,
    bool? avx,
    String? gpu,
    bool? gamemode,
  });

  Future<Either<AppError, Unit>> delete(String name);

  /// An empty bottle with [windows] and [backend], both applied after it is made.
  Future<Either<AppError, Unit>> create(
    String name, {
    String windows = 'win11',
    String backend = 'auto',
  });

  Future<Either<AppError, Unit>> renameBottle(String name, String newName);

  /// Shows or hides an application in the library, without touching its bottle.
  Future<Either<AppError, Unit>> setInLibrary(
    String name,
    String key,
    bool value,
  );

  /// Shows or hides the performance HUD on every launch of an application.
  Future<Either<AppError, Unit>> setHud(String name, String key, bool value);

  /// Takes the application out of the bottle's list.
  Future<Either<AppError, Unit>> hideApp(String name, String key);

  /// The last 2,000 lines of a log.
  Future<Either<AppError, List<String>>> logLines(String path);
}
