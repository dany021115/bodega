import 'package:freezed_annotation/freezed_annotation.dart';

part 'runtime_status.freezed.dart';

@freezed
abstract class RuntimeStatus with _$RuntimeStatus {
  const factory RuntimeStatus({required bool rosetta, required bool runtime}) =
      _RuntimeStatus;
}
