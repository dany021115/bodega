import 'dart:convert';
import 'dart:io';

import 'package:bodega/data/repository/game_repository_impl.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:engine/engine.dart' as engine;
import 'package:engine/probe_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '_home.dart';

void main() {
  late Directory tmp;
  late String home;
  late GameRepositoryImpl repository;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bodega-game-repo');
    home = engine.bodegaHome({'BODEGA_HOME': '${tmp.path}/home'});
    repository = GameRepositoryImpl(TestHome(home));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  /// Blur, which Bodega's own entry matches by its exe, and Other, which no
  /// entry matches: both real 32-bit PEs.
  void bottle() {
    Directory('$home/bottles/b/prefix/drive_c').createSync(recursive: true);
    for (final name in ['Blur', 'Other']) {
      final exe = File('${tmp.path}/$name/$name.exe')
        ..createSync(recursive: true)
        ..writeAsBytesSync(base64.decode(probe32Base64));
      engine.addApp(home, 'b', name, exe.path);
    }
  }

  test('every game becomes a configuration, with its source', () async {
    final games = (await repository.games()).getRight().toNullable()!;
    expect(games.length, greaterThanOrEqualTo(890));
    final blur = games.singleWhere((game) => game.id == 'blur');
    expect(blur.status, GameStatus.verified);
    expect(blur.sourceUrl, isNull);
    expect(blur.requires, ['vcrun2008']);
    final alice = (await repository.game('alice-madness-returns'))
        .getRight()
        .toNullable()!;
    expect(alice.status, GameStatus.community);
    expect(
      alice.sourceUrl,
      'https://github.com/gauthierpiarrette/highball-db/blob/'
      '${engine.fixesSourceCommit}/db/games/alice-madness-returns.json',
    );
    expect(alice.reports, greaterThan(0));
    // Its one step is the Mac's, as the test's host is.
    expect(alice.steps.single.kind, GameStepKind.registry);
    expect((await repository.game('nope')).isLeft(), isTrue);
  }, skip: !Platform.isMacOS);

  test("a bottle's apps get their plans, the switch and the verdict", () async {
    bottle();
    var apps = (await repository.appGames('b')).getRight().toNullable()!;
    final blur = apps.singleWhere((app) => app.title == 'Blur');
    expect(blur.config?.id, 'blur');
    expect(blur.by, GameMatchKind.exe);
    expect(blur.on, isTrue);
    expect(blur.requires, ['vcrun2008']);
    final other = apps.singleWhere((app) => app.title == 'Other');
    expect(other.config, isNull);
    expect(other.origin, BackendOrigin.auto);
    expect(other.graphics?.bits, 32);

    expect((await repository.setOn('b', blur.key, false)).isRight(), isTrue);
    expect(
      (await repository.setVerdict(
        'b',
        blur.key,
        GameVerdict.playable,
      )).isRight(),
      isTrue,
    );
    apps = (await repository.appGames('b')).getRight().toNullable()!;
    final off = apps.singleWhere((app) => app.key == blur.key);
    expect(off.on, isFalse);
    expect(off.config?.id, 'blur');
    expect(off.requires, isEmpty);
    expect(off.verdict, GameVerdict.playable);
    expect((await repository.setOn('b', 'nope', true)).isLeft(), isTrue);
  });

  test('the report form is prefilled, encoded', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Bodega',
      packageName: 'bodega',
      version: '1.8.0',
      buildNumber: '1',
      buildSignature: '',
    );
    const game = AppGame(
      key: 'steam:19680',
      title: 'Alice',
      config: GameConfig(
        id: 'alice-madness-returns',
        title: 'Alice: Madness Returns',
        steam: 19680,
        status: GameStatus.community,
      ),
      backend: 'dxmt',
      origin: BackendOrigin.config,
    );
    final url = (await repository.reportUrl(
      game,
      GameVerdict.playable,
      ' menu only & more ',
    )).getRight().toNullable()!;
    expect(url.scheme, 'https');
    expect(url.host, 'github.com');
    expect(url.path, '/dany021115/bodega/issues/new');
    expect(url.queryParameters, {
      'template': 'game-report.yml',
      'title': 'Alice: Madness Returns: playable',
      'game': 'Alice: Madness Returns',
      'steam_appid': '19680',
      'rating': 'playable',
      'backend': 'dxmt (config)',
      'engine': 'Rosetta',
      'bodega': '1.8.0',
      'os': startsWith(Platform.operatingSystem),
      'cpu': isA<String>(),
      'notes': 'menu only & more',
    });
    expect(url.toString(), contains('menu+only+%26+more'));
    final native = (await repository.reportUrl(
      game.copyWith(runtime: RuntimeKind.mach9),
      GameVerdict.works,
      '',
    )).getRight().toNullable()!;
    expect(native.queryParameters['engine'], 'Native (Mach9)');
    expect(native.toString(), contains('engine=Native+%28Mach9%29'));
  });

  test('the issue form has the fields the URL fills, and names CC0', () {
    final form = File('../../.github/ISSUE_TEMPLATE/game-report.yml')
        .readAsStringSync();
    for (final id in [
      'game',
      'steam_appid',
      'rating',
      'backend',
      'engine',
      'bodega',
      'os',
      'cpu',
      'notes',
    ]) {
      expect(form, contains('    id: $id\n'), reason: id);
    }
    expect(form, contains('CC0-1.0'));
    expect(form, contains('nothing is sent until you submit it'));
  });
}
