import 'dart:io';

import 'package:bodega/data/repository/library_repository_impl.dart';
import 'package:bodega/domain/entities/log_hint.dart';
import 'package:bodega/domain/entities/run_hint.dart';
import 'package:engine/engine.dart' as engine;
import 'package:flutter_test/flutter_test.dart';

import '_home.dart';

void main() {
  test('the applications of every bottle, and not the empty ones', () async {
    final home = Directory.systemTemp.createTempSync('bodega-library');
    addTearDown(() => home.deleteSync(recursive: true));
    for (final name in ['b', 'a']) {
      final drive = '${home.path}/bottles/$name/prefix/drive_c';
      File('$drive/P/$name.exe').createSync(recursive: true);
      File('${home.path}/bottles/$name/apps.json').writeAsStringSync(
        '{"apps": [{"id": "custom", "title": "$name", '
        '"exe": "P/$name.exe", "args": []}]}',
      );
    }
    Directory('${home.path}/bottles/vacia').createSync();

    final apps = (await LibraryRepositoryImpl(
      TestHome(home.path),
    ).apps()).getOrElse((error) => fail('$error'));

    expect(apps.map((app) => app.bottle), ['a', 'b']);
    expect(apps.first.key, 'p/a.exe');
  });

  // What a run left behind arrives as codes, never as the engine's text.
  group('hints', () {
    late Directory home;
    late LibraryRepositoryImpl repository;

    setUp(() {
      home = Directory.systemTemp.createTempSync('bodega-hints');
      repository = LibraryRepositoryImpl(TestHome(home.path));
    });
    tearDown(() => home.deleteSync(recursive: true));

    test('each engine hint maps to the domain one of its name', () {
      for (final hint in engine.LogHint.values) {
        expect(logHintOf(hint).name, hint.name);
      }
      expect(LogHint.values, hasLength(engine.LogHint.values.length));
    });

    test('a log gives a code for each marker it holds, in order', () async {
      final log = File('${home.path}/run.log')
        ..writeAsStringSync(
          [
            '# runtime engine-x',
            for (final hint in engine.LogHint.values.reversed)
              'x ${hint.marker} y',
          ].join('\n'),
        );
      expect(await repository.hintsIn(log.path), [
        for (final hint in LogHint.values) RunHint.log(hint),
      ]);
      expect(await repository.hintsIn('${home.path}/gone.log'), isEmpty);
    });

    test("Easy Anti-Cheat's failure names its game, when its log does", () {
      final log = File(
        '${home.path}/bottles/b/prefix/drive_c/users/q/AppData/Roaming/'
        'EasyAntiCheat/x/anticheatlauncher.log',
      )..createSync(recursive: true);
      const failed =
          '[Info] Launcher finished with: 206, \'Failed to load.\'.\r\n';
      final since = DateTime(2000);

      log.writeAsStringSync('[Info]  - ProcessTitle: POLYGON.\r\n$failed');
      expect(repository.antiCheatHints('b', since), [
        const RunHint.antiCheat(game: 'POLYGON'),
      ]);
      log.writeAsStringSync(failed);
      expect(repository.antiCheatHints('b', since), [
        const RunHint.antiCheat(),
      ]);
      expect(repository.antiCheatHints('nope', since), isEmpty);
    });
  });
}
