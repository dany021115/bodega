import 'package:freezed_annotation/freezed_annotation.dart';

part 'hint.freezed.dart';

/// What the engine read in a log, with a known meaning. [id] and [args] say
/// which, for the app to word it; [text] is the engine's English, the
/// fallback for an unknown [id].
@freezed
abstract class Hint with _$Hint {
  const factory Hint({
    required String id,
    @Default({}) Map<String, String> args,
    required String text,
  }) = _Hint;
}
