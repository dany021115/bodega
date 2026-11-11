import 'package:freezed_annotation/freezed_annotation.dart';

part 'switch_status.freezed.dart';

/// What the Switch page shows of the emulator that opens game files: where it
/// is, or its download page while it is missing, whether the keys and the
/// firmware the user brings are there, and how games open. A native game
/// needs none of it (switch-support design §9).
@freezed
abstract class SwitchStatus with _$SwitchStatus {
  const factory SwitchStatus({
    /// The emulator's name, a brand shown as it is, such as `Ryubing`.
    required String emulator,

    /// The file name of its app, which Bodega looks for in Applications,
    /// such as `Ryujinx.app`.
    required String appName,

    /// Its official download page, which the panel opens in the browser
    /// while no install is found. Bodega never downloads the emulator.
    required String page,

    /// Its app, or null when Bodega found none.
    EmulatorInstall? install,

    /// Whether its keys (`prod.keys`) are there.
    required bool keys,

    /// Whether its firmware is there.
    required bool firmware,

    /// Whether games open full screen.
    @Default(true) bool fullscreen,

    /// The extensions of the game files it opens, lower case and without the
    /// dot, for the file picker.
    required List<String> extensions,
  }) = _SwitchStatus;
}

/// The emulator's app on this Mac.
@freezed
abstract class EmulatorInstall with _$EmulatorInstall {
  const factory EmulatorInstall({
    /// Its absolute path.
    required String app,

    /// Its own version, when it gives one.
    String? version,

    /// Chosen on the Switch page, since the Applications folders hold none.
    @Default(false) bool picked,

    /// Whether macOS keeps it in quarantine, which Bodega reports and never
    /// removes.
    @Default(false) bool quarantined,
  }) = _EmulatorInstall;
}
