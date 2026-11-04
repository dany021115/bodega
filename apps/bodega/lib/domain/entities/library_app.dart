import 'package:freezed_annotation/freezed_annotation.dart';

part 'library_app.freezed.dart';

@freezed
abstract class LibraryApp with _$LibraryApp {
  const factory LibraryApp({
    required String bottle,

    /// What identifies it in its bottle.
    required String key,
    required String id,
    required String title,

    /// A picture of it on disk, if it has one.
    String? iconPath,
  }) = _LibraryApp;
}
