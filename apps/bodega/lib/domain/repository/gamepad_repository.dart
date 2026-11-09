import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/gamepad.dart';
import 'package:fpdart/fpdart.dart';

abstract class GamepadRepository {
  /// The gamepads and what is wrong with them, or null where Bodega sets them
  /// up itself and there is nothing to show (the Mac).
  Future<Either<AppError, GamepadReport?>> report();
}
