import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/entities/bottle_step.dart';
import 'package:bodega/domain/entities/native_move_step.dart';
import 'package:bodega/domain/entities/native_option.dart';
import 'package:bodega/domain/entities/retina_mode.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:bodega/domain/entities/user_name_problem.dart';
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

  /// A Native engine bottle's retina mode (PA1): its next launch puts it in
  /// place, so nothing closes.
  Future<Either<AppError, Unit>> setRetina(String name, RetinaMode mode);

  /// U4: the Windows user of [name]'s games; null for the host's. Stops the
  /// bottle and takes its profile folder along.
  Future<Either<AppError, Unit>> setUser(String name, String? user);

  /// U3: why [user] cannot be a Windows user name, or null if it can.
  UserNameProblem? userProblem(String user);

  Future<Either<AppError, Unit>> setWindowsVersion(String name, String version);

  Future<Either<AppError, Unit>> setOptions(
    String name, {
    bool? dlss,
    bool? metal4,
    bool? avx,
    bool? dxvkAsync,
    String? gpu,
    bool? gamemode,
  });

  Future<Either<AppError, Unit>> delete(String name);

  /// An empty bottle on [runtime] with [windows] and [backend], both applied
  /// after it is made; a native bottle then gets Wine Mono, last (MB5), so a
  /// Mono failure leaves the bottle made and set.
  Future<Either<AppError, Unit>> create(
    String name, {
    String windows = 'win11',
    String backend = 'auto',
    RuntimeKind runtime = RuntimeKind.bodega,
    void Function(BottleStep step)? onStep,
  });

  /// MB7: installs Wine Mono into the native bottle [name].
  Future<Either<AppError, Unit>> installMono(String name);

  Future<Either<AppError, Unit>> renameBottle(String name, String newName);

  /// Shows or hides an application in the library, without touching its bottle.
  Future<Either<AppError, Unit>> setInLibrary(
    String name,
    String key,
    bool value,
  );

  /// Shows or hides the performance HUD on every launch of an application.
  Future<Either<AppError, Unit>> setHud(String name, String key, bool value);

  /// Moves the Rosetta bottle [name] to the Native engine under the same
  /// name, and deletes the Rosetta one once that is done (PA8). Gives the
  /// runtimes (`<id> <arch>`) to install again.
  Future<Either<AppError, List<String>>> moveToNative(
    String name,
    void Function(NativeMoveStep step) onStep,
  );

  /// Turns one Native engine option of an application on or off (PA2).
  Future<Either<AppError, Unit>> setNativeOption(
    String name,
    String key,
    NativeOption option,
    bool on,
  );

  /// Takes the application out of the bottle's list.
  Future<Either<AppError, Unit>> hideApp(String name, String key);

  /// The last 2,000 lines of a log.
  Future<Either<AppError, List<String>>> logLines(String path);
}
