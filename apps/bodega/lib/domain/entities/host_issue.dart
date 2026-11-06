import 'package:freezed_annotation/freezed_annotation.dart';

part 'host_issue.freezed.dart';

/// Something the computer lacks to run games. [command] is what to paste in a
/// terminal, when there is one.
@freezed
abstract class HostIssue with _$HostIssue {
  const factory HostIssue({
    required String title,
    required String detail,
    String? command,
  }) = _HostIssue;
}
