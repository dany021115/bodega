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

  /// Whether the app of [log] still runs in [bottle] after its first process
  /// exited, as a game that relaunches itself does (ER4); false when unknown.
  Future<bool> appStillRunning(String bottle, String log);

  /// Ends the Wine processes Bodega's bottles left behind (ER3) and says how
  /// many; 0 when it cannot tell.
  Future<int> reapOrphans();

  /// The CPU of the app of [log] in [bottle], or null when it runs no more
  /// or cannot be read (ER5).
  Future<double?> appCpu(String bottle, String log);

  /// Whether the run of [log] looks hung, given its CPU [samples] (ER5).
  Future<bool> runHung(String log, List<double> samples);

  /// Moves the app [key] of the Native bottle [bottle] to a Rosetta bottle,
  /// made if needed, and gives where it went (ER6).
  Future<Either<AppError, ({String bottle, String key})>> openWithRosetta(
    String bottle,
    String key,
  );

  /// Easy Anti-Cheat's failures in the bottle since [since], one per game, as
  /// [RunHint.antiCheat]; none when they cannot be read.
  List<RunHint> antiCheatHints(String bottle, DateTime since);

  /// What the run's [log] shows, as [RunHint.log]; none when it cannot be
  /// read.
  Future<List<RunHint>> hintsIn(String log);
}
