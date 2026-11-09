import 'package:bodega/domain/entities/host_issue.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'gamepad.freezed.dart';

/// A gamepad the system sees. [readable] is whether Bodega can open its
/// device, which Wine needs to see it too.
@freezed
abstract class Gamepad with _$Gamepad {
  const factory Gamepad({
    required String name,
    required String vid,
    required String pid,
    required bool readable,
  }) = _Gamepad;
}

/// The gamepads, whether SDL2 is installed, and what to fix. None of it stops
/// a game from running.
@freezed
abstract class GamepadReport with _$GamepadReport {
  const factory GamepadReport({
    required List<Gamepad> pads,
    required bool sdl,
    required List<HostIssue> issues,
  }) = _GamepadReport;
}
