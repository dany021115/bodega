import 'package:bodega/domain/entities/host_capabilities.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'runtime_status.freezed.dart';

@freezed
abstract class RuntimeStatus with _$RuntimeStatus {
  const factory RuntimeStatus({
    required List<HostIssue> issues,
    required bool runtime,
    required HostCapabilities capabilities,
  }) = _RuntimeStatus;
}
