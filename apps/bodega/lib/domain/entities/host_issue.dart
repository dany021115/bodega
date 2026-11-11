import 'package:freezed_annotation/freezed_annotation.dart';

part 'host_issue.freezed.dart';

/// Something the computer lacks to run games, or to use a gamepad, as a code
/// that `app/` words. [subject] is the gamepad it names, for
/// [HostIssueKind.padNoAccess]. [command] is what to paste in a terminal to
/// install what is missing, when there is one.
@freezed
abstract class HostIssue with _$HostIssue {
  const factory HostIssue({
    required HostIssueKind kind,
    String? subject,
    String? command,
  }) = _HostIssue;
}

/// What a [HostIssue] is about: the engine's `HostIssueKind`, which `data/`
/// maps here.
enum HostIssueKind {
  /// The Mac lacks Rosetta 2, which Wine x86_64 runs on.
  noRosetta,

  /// The processor is not x86_64.
  unsupportedCpu,

  /// No Vulkan loader or driver: DXVK draws with it.
  noVulkan,

  /// No PulseAudio library, which Wine plays sound through.
  noAudio,

  /// Bodega cannot open a gamepad, so Wine cannot either: the subject names
  /// it.
  padNoAccess,

  /// No SDL2: Wine falls back to udev, which knows fewer gamepads.
  noSdl,
}
