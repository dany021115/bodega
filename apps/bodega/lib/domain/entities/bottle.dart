import 'package:bodega/domain/entities/library_app.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bottle.freezed.dart';

@freezed
abstract class Bottle with _$Bottle {
  const factory Bottle({
    required String name,

    /// False if its prefix never got to be complete.
    required bool ready,
    LibraryApp? app,
  }) = _Bottle;
}
