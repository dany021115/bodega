import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/domain/entities/anti_cheat_game.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/repository/anti_cheat_repository.dart';
import 'package:bodega/domain/repository/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockCatalog extends Mock implements CatalogRepository {}

class _MockAntiCheat extends Mock implements AntiCheatRepository {}

CatalogApp _app(String id, String title, {String? bottle}) => CatalogApp(
  id: id,
  title: title,
  status: CatalogStatus.reported,
  backend: 'dxmt',
  backendInstalled: true,
  sync: 'none',
  host: 'example.com',
  hasChecksum: false,
  bottle: bottle,
);

void main() {
  late _MockCatalog catalog;
  late _MockAntiCheat antiCheat;
  final apps = [
    _app('steam', 'Steam', bottle: 'steam'),
    _app('ea-app', 'EA app'),
  ];
  const game = AntiCheatGame(
    title: 'Fortnite',
    anticheats: ['Easy Anti-Cheat'],
    verdict: AntiCheatVerdict.blocked,
  );

  setUp(() {
    catalog = _MockCatalog();
    antiCheat = _MockAntiCheat();
    when(() => catalog.apps()).thenAnswer((_) async => right(apps));
    when(() => antiCheat.games()).thenAnswer((_) async => right(const [game]));
  });

  blocTest<CatalogBloc, CatalogState>(
    'loads the apps and marks the installed ones',
    build: () => CatalogBloc(catalog, antiCheat),
    act: (bloc) => bloc.add(const CatalogEvent.load()),
    verify: (bloc) {
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.visibleApps, apps);
      expect(bloc.state.apps.first.isInstalled, isTrue);
      expect(bloc.state.apps.last.isInstalled, isFalse);
    },
  );

  blocTest<CatalogBloc, CatalogState>(
    'remembers the bottle to install into',
    build: () => CatalogBloc(catalog, antiCheat),
    act: (bloc) => bloc
      ..add(const CatalogEvent.target('steam'))
      ..add(const CatalogEvent.target(null)),
    expect: () => const [CatalogState(targetBottle: 'steam'), CatalogState()],
  );

  blocTest<CatalogBloc, CatalogState>(
    'filters without minding case',
    build: () => CatalogBloc(catalog, antiCheat),
    act: (bloc) => bloc
      ..add(const CatalogEvent.load())
      ..add(const CatalogEvent.search('sTeAm')),
    verify: (bloc) =>
        expect(bloc.state.visibleApps.map((app) => app.id), ['steam']),
  );

  blocTest<CatalogBloc, CatalogState>(
    'a search finds the game in the anti-cheat list, asking for it once',
    build: () => CatalogBloc(catalog, antiCheat),
    act: (bloc) => bloc
      ..add(const CatalogEvent.search('fort'))
      ..add(const CatalogEvent.search('fortn')),
    verify: (bloc) {
      expect(bloc.state.antiCheatMatches, [game]);
      verify(() => antiCheat.games()).called(1);
    },
  );

  blocTest<CatalogBloc, CatalogState>(
    'without the anti-cheat list the catalog keeps working',
    build: () {
      when(() => antiCheat.games()).thenAnswer(
        (_) async => left(const AppError.network(detail: 'no network')),
      );
      return CatalogBloc(catalog, antiCheat);
    },
    act: (bloc) => bloc
      ..add(const CatalogEvent.load())
      ..add(const CatalogEvent.search('steam')),
    verify: (bloc) {
      expect(
        bloc.state.antiCheatError,
        const AppError.network(detail: 'no network'),
      );
      expect(bloc.state.error, isNull);
      expect(bloc.state.visibleApps.single.id, 'steam');
    },
  );
}
