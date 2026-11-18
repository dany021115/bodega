part of 'dependencies_bloc.dart';

@freezed
sealed class DependenciesEvent with _$DependenciesEvent {
  /// Reads [bottle]'s runtimes and what its apps need.
  const factory DependenciesEvent.load(String bottle) = DependenciesLoadEvent;

  /// Does [items] in [bottle], one after the other: runtimes, then settings.
  const factory DependenciesEvent.install(String bottle, List<NeedItem> items) =
      DependenciesInstallEvent;

  /// Installs the runtime [item] in [bottle] from [file], a file the user
  /// picked, checked against the same SHA-256 as a download.
  const factory DependenciesEvent.installFile(
    String bottle,
    RuntimeItem item,
    String file,
  ) = DependenciesInstallFileEvent;

  /// Proposes what the app [key] of [bottle] needs, if one recommended item
  /// is not done: after "Add program".
  const factory DependenciesEvent.offer(String bottle, String key) =
      DependenciesOfferEvent;

  /// The same after a catalog install of [catalogId] into [bottle].
  const factory DependenciesEvent.offerCatalogApp(
    String bottle,
    String catalogId,
  ) = DependenciesOfferCatalogAppEvent;

  /// The proposal was shown: it goes.
  const factory DependenciesEvent.offerShown() = DependenciesOfferShownEvent;
  const factory DependenciesEvent.cancel() = DependenciesCancelEvent;
}
