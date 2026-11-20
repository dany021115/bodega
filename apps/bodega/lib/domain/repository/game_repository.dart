import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:fpdart/fpdart.dart';

abstract class GameRepository {
  Future<Either<AppError, List<GameConfig>>> games();

  Future<Either<AppError, GameConfig>> game(String id);

  /// What each app of [bottle] gets at launch.
  Future<Either<AppError, List<AppGame>>> appGames(String bottle);

  Future<Either<AppError, Unit>> setOn(String bottle, String key, bool on);

  Future<Either<AppError, Unit>> setVerdict(
    String bottle,
    String key,
    GameVerdict? verdict,
  );

  /// The prefilled report form of Bodega's repository (G8).
  Future<Either<AppError, Uri>> reportUrl(
    AppGame game,
    GameVerdict verdict,
    String note,
  );
}
