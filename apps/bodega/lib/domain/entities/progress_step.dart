import 'package:freezed_annotation/freezed_annotation.dart';

part 'progress_step.freezed.dart';

/// A step of a long task (install, D3DMetal import). [id] and [args] say
/// which, for the app to word it; [text] is the engine's English, the
/// fallback for an unknown [id].
@freezed
abstract class ProgressStep with _$ProgressStep {
  const factory ProgressStep({
    required String id,
    @Default({}) Map<String, String> args,
    required String text,
  }) = _ProgressStep;
}
