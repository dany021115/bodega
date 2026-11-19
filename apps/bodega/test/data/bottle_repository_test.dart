import 'dart:convert';
import 'dart:io';

import 'package:bodega/data/repository/bottle_repository_impl.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/entities/bottle_step.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:flutter_test/flutter_test.dart';

import '_home.dart';
import '_mach9.dart';

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
        'backend': 'wine',
        'sync': 'none',
        'programs': {
          'steam.exe': {'backend': 'dxvk'},
          'only-env.exe': {
            'env': {'A': '1'},
          },
        },
      }),
    );
    File('${bottle.path}/logs/a.log').writeAsStringSync('hello\n');
    File('${bottle.path}/logs/a.exit').writeAsStringSync('42\n');
    repository = BottleRepositoryImpl(TestHome(home.path));
  });

  test('the detail, leaving out programs with no backend', () async {
    final detail = (await repository.detail('steam'))
        .getOrElse((error) => fail('$error'));

    expect(detail.backend, 'wine');
    expect(detail.sync, 'none');
    expect(detail.exceptions, const [
      ProgramBackend(exe: 'steam.exe', backend: 'dxvk'),
    ]);
    expect(detail.logs.single.name, 'a.log');
    expect(detail.logs.single.exitCode, 42);
    expect(detail.installedBackends, ['wine']);
    expect(detail.ready, isFalse);
    expect(detail.apps, isEmpty);
  });

  test('removing an exception leaves the others', () async {
    await repository.setBackend('steam', 'auto', exe: 'steam.exe');

    final detail = (await repository.detail('steam'))
        .getOrElse((error) => fail('$error'));
    expect(detail.exceptions, isEmpty);
    expect(detail.backend, 'wine');
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
        .getOrElse((error) => fail('$error'));

    expect(lines, hasLength(2000));
    expect(lines.first, 'line 501');
    expect(lines[lines.length - 2], 'line 2499');
  });

  test('an unknown bottle is bottleNotFound, with the engine\'s text as detail '
      '(E10)', () async {
    expect(
      (await repository.detail('missing')).getLeft().toNullable(),
      const AppError.bottleNotFound(
        'missing',
        detail: 'the bottle missing does not exist',
      ),
    );
  });

  test('the detail brings the applications of the bottle', () async {
    File('${bottle.path}/prefix/drive_c/A/a.exe').createSync(recursive: true);
    File('${bottle.path}/prefix/drive_c/B/b.exe').createSync(recursive: true);
    File('${bottle.path}/apps.json').writeAsStringSync(
      jsonEncode({
        'apps': [
          {'id': 'custom', 'title': 'A', 'exe': 'A/a.exe', 'args': []},
          {'id': 'custom', 'title': 'B', 'exe': 'B/b.exe', 'args': []},
        ],
      }),
    );

    final detail = (await repository.detail('steam'))
        .getOrElse((error) => fail('$error'));

    expect(detail.apps.map((app) => app.key), ['a/a.exe', 'b/b.exe']);
    expect(detail.apps.first.bottle, 'steam');
    expect(detail.apps.first.iconPath, isNull);
  });

  test('hiding an application takes it out', () async {
    File('${bottle.path}/prefix/drive_c/A/a.exe').createSync(recursive: true);
    File('${bottle.path}/apps.json').writeAsStringSync(
      jsonEncode({
        'apps': [
          {'id': 'custom', 'title': 'A', 'exe': 'A/a.exe', 'args': []},
        ],
      }),
    );

    await repository.hideApp('steam', 'a/a.exe');

    final detail = (await repository.detail('steam'))
        .getOrElse((error) => fail('$error'));
    expect(detail.apps, isEmpty);
  });

  test('an application taken out of the library stays in the bottle', () async {
    File('${bottle.path}/prefix/drive_c/A/a.exe').createSync(recursive: true);
    File('${bottle.path}/apps.json').writeAsStringSync(
      jsonEncode({
        'apps': [
          {'id': 'custom', 'title': 'A', 'exe': 'A/a.exe', 'args': []},
        ],
      }),
    );

    (await repository.setInLibrary(
      'steam',
      'a/a.exe',
      false,
    )).getOrElse((error) => fail('$error'));

    final detail = (await repository.detail('steam'))
        .getOrElse((error) => fail('$error'));
    expect(detail.apps.single.key, 'a/a.exe');
    expect(detail.apps.single.inLibrary, isFalse);
  });

  test('renaming moves the bottle to its new name', () async {
    (await repository.renameBottle(
      'steam',
      'games',
    )).getOrElse((error) => fail('$error'));

    final detail = (await repository.detail('games'))
        .getOrElse((error) => fail('$error'));
    expect(detail.name, 'games');
    expect(Directory('${home.path}/bottles/steam').existsSync(), isFalse);
  });

  group('MA4 Mach9 bottles', () {
    useHost(() => const Mach9Mac());

    test('the list and the detail say the runtime; Mono and the graphics '
        'follow it', () async {
      readyBottle(home.path, 'native', mach9: true);

      final bottles = (await repository.list()).getOrElse((e) => fail('$e'));
      expect(
        {for (final b in bottles) b.name: b.runtime},
        {'steam': RuntimeKind.bodega, 'native': RuntimeKind.mach9},
      );

      var detail = (await repository.detail('native'))
          .getOrElse((error) => fail('$error'));
      expect(detail.runtime, RuntimeKind.mach9);
      expect(detail.monoMissing, isTrue);
      expect(detail.installedBackends, isEmpty);

      fakeMach9Runtime(home.path);
      detail = (await repository.detail('native'))
          .getOrElse((error) => fail('$error'));
      expect(detail.installedBackends, ['wine', 'dxmt', 'mtld3d']);

      final steam = (await repository.detail('steam'))
          .getOrElse((error) => fail('$error'));
      expect(steam.runtime, RuntimeKind.bodega);
      expect(steam.monoMissing, isFalse);
    });

    // MA11: end to end on a fake Mach9 runtime.
    test('create(runtime: mach9) makes the prefix, then Windows, graphics '
        'and Mono, in that order', () async {
      final rt = fakeMach9Runtime(home.path);
      final steps = <BottleStep>[];

      final made = await repository.create(
        'native',
        windows: 'win10',
        backend: 'dxmt',
        runtime: RuntimeKind.mach9,
        onStep: steps.add,
      );

      expect(made.isRight(), isTrue, reason: '$made');
      expect(steps, [BottleStep.prefix, BottleStep.mono]);
      final prefix = '${home.path}/bottles/native/prefix';
      expect(File('$prefix/winecfg.log').readAsStringSync(), contains('win10'));
      expect(
        File('$prefix/msi-args').readAsStringSync().trim(),
        'msiexec /i ${Directory(rt).resolveSymbolicLinksSync()}'
        '/wine-mono-11.3.0-x86.msi /qn',
      );
      final detail = (await repository.detail('native'))
          .getOrElse((error) => fail('$error'));
      expect(detail.runtime, RuntimeKind.mach9);
      expect(detail.backend, 'dxmt');
      expect(detail.windows, 'win10');
      expect(detail.monoMissing, isFalse);
      expect(detail.ready, isTrue);
    });

    test('installMono puts Mono back in a Mach9 bottle', () async {
      fakeMach9Runtime(home.path);
      readyBottle(home.path, 'native', mach9: true);

      expect((await repository.installMono('native')).isRight(), isTrue);
      final detail = (await repository.detail('native'))
          .getOrElse((error) => fail('$error'));
      expect(detail.monoMissing, isFalse);
    });

    test(
      'create(runtime: mach9) without the runtime is runtimeNotInstalled',
      () async {
        expect(
          (await repository.create(
            'native',
            runtime: RuntimeKind.mach9,
          )).getLeft().toNullable(),
          isA<RuntimeNotInstalledError>(),
        );
        expect(Directory('${home.path}/bottles/native').existsSync(), isFalse);
      },
    );
  });
}
