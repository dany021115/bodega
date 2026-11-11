import 'package:freezed_annotation/freezed_annotation.dart';

part 'switch_game.freezed.dart';

/// A Switch game in the list: a game file, which the emulator opens, or a
/// native game, a Mac app that a user made of their own game with nxnative,
/// which plays by itself (switch-support design §4).
@freezed
abstract class SwitchGame with _$SwitchGame {
  const factory SwitchGame({
    /// What identifies it: the file's or the app's absolute path.
    required String path,

    /// From its file name, without the extension and the bracketed tags.
    required String title,

    /// The first bracketed id of 16 hex digits in its file name, if any.
    String? titleId,

    /// A native game: it needs no emulator, keys or firmware.
    @Default(false) bool native,

    /// For a native game: whether macOS keeps the app in quarantine, which
    /// Bodega reports and never removes.
    @Default(false) bool quarantined,
  }) = _SwitchGame;
}

/// A Switch game that runs: the [game]'s path and the [log] of its run.
@freezed
abstract class SwitchRun with _$SwitchRun {
  const factory SwitchRun({required String game, required String log}) =
      _SwitchRun;
}
