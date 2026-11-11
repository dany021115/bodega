part of 'library_bloc.dart';

@freezed
abstract class LibraryState with _$LibraryState {
  const LibraryState._();

  const factory LibraryState({
    @Default(true) bool isLoading,
    @Default([]) List<LibraryApp> apps,
    @Default({}) Set<String> open,

    /// Each bottle's hints, as codes the page words (L6).
    @Default({}) Map<String, List<RunHint>> hints,

    /// The latest hint; [toastId] tells apart two equal ones.
    RunHint? toast,
    @Default(0) int toastId,
    AppError? error,
  }) = _LibraryState;

  /// The apps the library shows; [apps] has them all, hidden ones included.
  List<LibraryApp> get libraryApps => [
    for (final app in apps)
      if (app.inLibrary) app,
  ];
}
