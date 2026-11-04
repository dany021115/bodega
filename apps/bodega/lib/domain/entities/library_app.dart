import 'package:freezed_annotation/freezed_annotation.dart';

part 'library_app.freezed.dart';

@freezed
abstract class LibraryApp with _$LibraryApp {
  const factory LibraryApp({
    required String bottle,
    required String id,
    required String title,
  }) = _LibraryApp;
}
