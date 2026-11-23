import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bottle.freezed.dart';

@freezed
abstract class Bottle with _$Bottle {
  const factory Bottle({
    required String name,

    /// False if its prefix never got to be complete.
    required bool ready,

    /// The Wine it runs on: its prefix's (D2).
    @Default(RuntimeKind.bodega) RuntimeKind runtime,
  }) = _Bottle;
}
