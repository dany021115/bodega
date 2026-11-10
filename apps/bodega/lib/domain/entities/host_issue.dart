import 'package:freezed_annotation/freezed_annotation.dart';

part 'host_issue.freezed.dart';

/// Something the computer lacks to run games. [id] and [args] say which, for
/// the app to word it; [title] and [detail] are the engine's English, the
/// fallback for an unknown [id]. [command] is what to paste in a terminal,
/// when there is one.
@freezed
abstract class HostIssue with _$HostIssue {
  const factory HostIssue({
    required String id,
    @Default({}) Map<String, String> args,
    required String title,
    required String detail,
    String? command,
  }) = _HostIssue;
}
