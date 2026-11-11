import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/entities/run_hint.dart';
import 'package:fpdart/fpdart.dart';

abstract class LibraryRepository {
  Future<Either<AppError, List<LibraryApp>>> apps();

  /// Every bottle by name, with or without an app.
  Future<List<String>> bottleNames();

  /// Launches the application with that [key], or else the bottle's first, and
  /// returns the log of its first process.
  Future<Either<AppError, String>> open(String bottle, {String? key});

  /// Launches [program], a path or a Wine program such as `winecfg`, in the
  /// bottle.
  Future<Either<AppError, String>> run(
    String bottle,
    String program, {
    List<String> args = const [],
  });

  /// Launches with options (V11): variables, backend and AVX of this launch
  /// only.
  Future<Either<AppError, String>> launch(
    String bottle,
    String program, {
    List<String> args = const [],
    Map<String, String> env = const {},
    String? backend,
    bool avx = true,
  });

  /// Keeps [program] with [args] and [env] as an application of the bottle.
  Future<Either<AppError, Unit>> saveLauncher(
    String bottle,
    String title,
    String program, {
    List<String> args = const [],
    Map<String, String> env = const {},
  });

  Future<Either<AppError, Unit>> stop(String bottle);

  /// Ends the run of [log] and its process group, never the bottle's.
  Future<Either<AppError, Unit>> stopApp(String log);

  /// The apps of [bottle] with a run still alive, by their key and log.
  Future<Either<AppError, List<({String key, String log})>>> runningApps(
    String bottle,
  );

  /// Ends when the first process of [log] exits.
  Future<void> firstExit(String log);

  /// Ends when the bottle's last process exits, or at once if nothing runs.
  Future<void> waitBottle(String bottle);

  /// Easy Anti-Cheat's failures in the bottle since [since], one per game, as
  /// [RunHint.antiCheat]; none when they cannot be read.
  List<RunHint> antiCheatHints(String bottle, DateTime since);

  /// What the run's [log] shows, as [RunHint.log]; none when it cannot be
  /// read.
  Future<List<RunHint>> hintsIn(String log);
}
