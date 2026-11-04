import 'dart:convert';
import 'dart:io';

import 'package:bodega/data/repository/bottle_repository_impl.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:flutter_test/flutter_test.dart';

import '_home.dart';

void main() {
  late Directory home;
  late Directory bottle;
  late BottleRepositoryImpl repository;

  setUp(() {
    home = Directory.systemTemp.createTempSync('bodega-bottles');
    addTearDown(() => home.deleteSync(recursive: true));
    bottle = Directory('${home.path}/bottles/steam')
      ..createSync(recursive: true);
    Directory('${bottle.path}/logs').createSync();
    File('${bottle.path}/settings.json').writeAsStringSync(
      jsonEncode({
        'backend': 'dxmt',
        'sync': 'none',
        'programs': {
          'steam.exe': {'backend': 'dxvk'},
          'only-env.exe': {
            'env': {'A': '1'},
          },
        },
      }),
    );
    File('${bottle.path}/logs/a.log').writeAsStringSync('hola\n');
    File('${bottle.path}/logs/a.exit').writeAsStringSync('42\n');
    repository = BottleRepositoryImpl(TestHome(home.path));
  });

  test('the detail, leaving out programs with no backend', () async {
    final detail = (await repository.detail('steam'))
        .getOrElse((error) => fail(error.message));

    expect(detail.backend, 'dxmt');
    expect(detail.sync, 'none');
    expect(detail.exceptions, const [
      ProgramBackend(exe: 'steam.exe', backend: 'dxvk'),
    ]);
    expect(detail.logs.single.name, 'a.log');
    expect(detail.logs.single.exitCode, 42);
    expect(detail.installedBackends, ['wine']);
  });

  test('removing an exception leaves the others', () async {
    await repository.setBackend('steam', 'auto', exe: 'steam.exe');

    final detail = (await repository.detail('steam'))
        .getOrElse((error) => fail(error.message));
    expect(detail.exceptions, isEmpty);
    expect(detail.backend, 'dxmt');
  });

  test('a log gives its last 2,000 lines, whatever bytes it has', () async {
    final log = File('${bottle.path}/logs/big.log');
    final sink = log.openWrite();
    for (var line = 0; line < 2500; line++) {
      sink.writeln('line $line');
    }
    sink.add([0xFF, 0xFE, 0x0A]);
    await sink.close();

    final lines = (await repository.logLines(log.path))
        .getOrElse((error) => fail(error.message));

    expect(lines, hasLength(2000));
    expect(lines.first, 'line 501');
    expect(lines[lines.length - 2], 'line 2499');
  });

  test('an unknown bottle is an error, not an exception', () async {
    final result = await repository.detail('no-existe');
    expect(result.isLeft(), isTrue);
  });
}
