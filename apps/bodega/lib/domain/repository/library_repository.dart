import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:fpdart/fpdart.dart';

abstract class LibraryRepository {
  Future<Either<AppError, List<LibraryApp>>> apps();

  /// Every bottle by name, with or without an app.
  Future<List<String>> bottleNames();

  /// Launches the application with that [key], or else the bottle's first, and
  /// returns the log of its first process.
  Future<Either<AppError, String>> open(String bottle, {String? key});

  /// Launches [program], an absolute path, in the bottle.
  Future<Either<AppError, String>> run(String bottle, String program);

  Future<Either<AppError, Unit>> stop(String bottle);

  /// Ends when the first process of [log] exits.
  Future<void> firstExit(String log);

  /// Ends when the bottle's last process exits, or at once if nothing runs.
  Future<void> waitBottle(String bottle);

  List<String> antiCheatHints(String bottle, DateTime since);

  Future<List<String>> hintsIn(String log);
}
