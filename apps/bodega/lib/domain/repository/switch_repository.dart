import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/switch_game.dart';
import 'package:bodega/domain/entities/switch_status.dart';
import 'package:fpdart/fpdart.dart';

/// Switch games (switch-support design §9), where the host supports them:
/// `HostCapabilities.switchGames`.
abstract class SwitchRepository {
  /// The emulator, its keys and its firmware, and how games open.
  Future<Either<AppError, SwitchStatus>> status();

  /// The list, sorted by title without case.
  Future<Either<AppError, List<SwitchGame>>> games();

  /// Adds game files and native games; `known` counts the paths already
  /// listed.
  Future<Either<AppError, ({int added, int known})>> addFiles(
    List<String> paths,
  );

  /// Adds what [folder] holds, found once: the folder itself is not kept.
  Future<Either<AppError, ({int added, int known})>> addFolder(String folder);

  /// Takes [path] out of the list. Its file stays where it is.
  Future<Either<AppError, Unit>> remove(String path);

  /// Keeps [app] as the emulator to use while the Applications folders hold
  /// none.
  Future<Either<AppError, Unit>> chooseEmulator(String app);

  /// Whether games open full screen, from their next launch.
  Future<Either<AppError, Unit>> setFullscreen(bool value);

  /// Plays [path] and returns the log of its run. The engine checks what a
  /// launch needs: the emulator for a game file, nothing for a native game.
  Future<Either<AppError, String>> open(String path);

  /// Copies the user's own keys where the emulator reads them: each of
  /// [sources] is a `.keys` file or a folder that holds some. It gives the
  /// names copied.
  Future<Either<AppError, List<String>>> installKeys(List<String> sources);

  /// Opens the emulator's own installer on the firmware the user picked, a
  /// file or a folder: the emulator asks and installs it in its window.
  Future<Either<AppError, Unit>> installFirmware(String source);

  /// Ends the run of [path]; a listed game that does not run is left as it
  /// is.
  Future<Either<AppError, Unit>> stop(String path);

  /// The games that run, found again after Bodega restarts; none when they
  /// cannot be read.
  Future<List<SwitchRun>> running();

  /// Ends when the run of [log] does, with its exit code, or with null when
  /// that cannot be told.
  Future<int?> waitRun(String log);
}
