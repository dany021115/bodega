import 'dart:io';

import 'package:bodega/data/repository/catalog_repository_impl.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:flutter_test/flutter_test.dart';

import '_home.dart';

void main() {
  test('with several applications in the bottle, it still marks it', () async {
    final home = Directory.systemTemp.createTempSync('bodega-catalog');
    addTearDown(() => home.deleteSync(recursive: true));
    final bottle = Directory('${home.path}/bottles/steam')
      ..createSync(recursive: true);
    File('${bottle.path}/apps.json').writeAsStringSync(
      '{"apps": ['
      '{"id": "custom", "title": "Otra", "exe": "o.exe", "args": []},'
      '{"id": "steam", "title": "Steam", "exe": "S/Steam.exe", "args": []}'
      ']}',
    );

    final apps = (await CatalogRepositoryImpl(
      TestHome(home.path),
    ).apps()).getOrElse((error) => fail('$error'));

    final steam = apps.first;
    expect(steam.bottle, 'steam');
    expect(steam.appKey, 's/steam.exe');
    expect(apps.where((app) => app.isInstalled), hasLength(1));
  });

  test('the 7 of the catalog, with the installed one marked', () async {
    final home = Directory.systemTemp.createTempSync('bodega-catalog');
    addTearDown(() => home.deleteSync(recursive: true));
    final bottle = Directory('${home.path}/bottles/mi-steam')
      ..createSync(recursive: true);
    File('${bottle.path}/app.json').writeAsStringSync(
      '{"id":"steam","title":"Steam","exe":"s.exe","args":[]}',
    );

    final result = await CatalogRepositoryImpl(TestHome(home.path)).apps();

    final apps = result.getOrElse((error) => fail('$error'));
    expect(apps, hasLength(7));
    expect(apps.first.id, 'steam');
    expect(apps.first.bottle, 'mi-steam');
    expect(apps.first.host, 'cdn.akamai.steamstatic.com');
    expect(apps.first.backendInstalled, isFalse);
    expect(apps.where((app) => app.isInstalled), hasLength(1));
    final epic = apps.firstWhere((app) => app.id == 'epic-games');
    expect(epic.status, CatalogStatus.blocked);
  });

  // The prose stays in the engine: the app words it by id (L16, E11).
  test('marks the unstable ones, and keeps a source field with no data '
      'null', () async {
    final home = Directory.systemTemp.createTempSync('bodega-catalog');
    addTearDown(() => home.deleteSync(recursive: true));
    Directory('${home.path}/bottles').createSync();

    final apps = (await CatalogRepositoryImpl(
      TestHome(home.path),
    ).apps()).getOrElse((error) => fail('$error'));

    expect(
      [
        for (final app in apps)
          if (app.flaky) app.id,
      ],
      ['ea-app', 'battle-net'],
    );
    final gog = apps.firstWhere((app) => app.id == 'gog-galaxy');
    expect(gog.source, containsPair('verified', null));
    expect(gog.source, containsPair('license', 'CC0-1.0'));
  });
}
