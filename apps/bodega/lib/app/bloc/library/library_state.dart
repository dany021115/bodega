part of 'library_bloc.dart';

@freezed
abstract class LibraryState with _$LibraryState {
  const LibraryState._();

  const factory LibraryState({
    @Default(true) bool isLoading,
    @Default([]) List<LibraryApp> apps,
    @Default({}) Set<String> open,
    @Default({}) Map<String, List<Hint>> hints,

    /// The latest hint; [toastId] tells apart two equal ones.
    Hint? toast,
    @Default(0) int toastId,
    AppError? error,
  }) = _LibraryState;

  /// The apps the library shows; [apps] has them all, hidden ones included.
  List<LibraryApp> get libraryApps => [
    for (final app in apps)
      if (app.inLibrary) app,
  ];
}
