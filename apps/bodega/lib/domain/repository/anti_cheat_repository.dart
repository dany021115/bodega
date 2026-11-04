import 'package:bodega/domain/entities/anti_cheat_game.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:fpdart/fpdart.dart';

abstract class AntiCheatRepository {
  Future<Either<AppError, List<AntiCheatGame>>> games();
}
