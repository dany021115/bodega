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

    /// As Windows sees it (`C:\\…`), or an absolute path outside the bottle.
    @Default('') String exe,
    @Default([]) List<String> args,

    /// A picture of it on disk, if it has one.
    String? iconPath,
  }) = _LibraryApp;
}
