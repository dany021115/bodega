import 'package:bodega/app/shared/widgets/app_card.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';

const _long = LibraryApp(
  bottle: 'A bottle with a name so very long that it does not fit the card',
  key: 'k',
  id: 'long-app',
  title:
      'An extremely long application title, long enough to check the clipping',
);

void _none() {}

void _noMenu(BuildContext _) {}

/// The gradient behind the card's picture: its cover pair.
LinearGradient _cover(WidgetTester tester) => [
  for (final box in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)))
    if (box.decoration case BoxDecoration(gradient: final LinearGradient cover))
      cover,
].single;

/// The label of the card's node, the one with its open hint.
String _label(WidgetTester tester) =>
    find.semantics.byHint('Double-click to open').evaluate().single.label;

void main() {
  Future<void> pump(
    WidgetTester tester,
    AppCard card, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(720, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: Center(child: SizedBox(width: 200, child: card)),
        ),
        locale: locale,
        theme: AppTheme.getDarkTheme(),
      ),
    );
  }

  testWidgets('long texts fit a grid cell at 720 px', (tester) async {
    final card = AppCard(
      app: _long,
      bottleLabel: _long.bottle,
      running: true,
      onPlay: () {},
      onStop: () {},
      onMenu: (_) {},
    );
    await pump(tester, card);
    expect(tester.takeException(), isNull);
    expect(find.text('Running'), findsOneWidget);

    // Spanish runs longer (L18).
    await pump(tester, card, locale: const Locale('es'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the button plays, or stops when running', (tester) async {
    var played = 0;
    var stopped = 0;
    await pump(
      tester,
      AppCard(
        app: _long,
        running: false,
        onPlay: () => played++,
        onStop: () => stopped++,
      ),
    );
    await tester.tap(find.byTooltip('Play'));
    expect(played, 1);

    await pump(
      tester,
      AppCard(
        app: _long,
        running: true,
        onPlay: () => played++,
        onStop: () => stopped++,
      ),
    );
    await tester.tap(find.byTooltip('Stop'));
    expect(stopped, 1);
    expect(played, 1);
  });

  testWidgets('its hint says to double-click to open (L14)', (tester) async {
    final card = AppCard(
      app: _long,
      running: false,
      onPlay: () {},
      onStop: () {},
    );
    await pump(tester, card);
    expect(find.semantics.byHint('Double-click to open'), findsOne);

    final es = lookupAppL10n(const Locale('es'));
    await pump(tester, card, locale: const Locale('es'));
    expect(find.semantics.byHint(es.appOpenHint), findsOne);
  });

  testWidgets('an item shows as the app with its id and title does (SA17)', (
    tester,
  ) async {
    const item = AppCard.item(
      id: 'x',
      title: 'Bodega Test',
      running: false,
      onPlay: _none,
      onStop: _none,
      onMenu: _noMenu,
    );
    final app = AppCard(
      app: const LibraryApp(
        bottle: 'b',
        key: 'k',
        id: 'x',
        title: 'Bodega Test',
      ),
      running: false,
      onPlay: _none,
      onStop: _none,
      onMenu: _noMenu,
    );

    final shown = <(LinearGradient, String)>[];
    for (final card in [item, app]) {
      await pump(tester, card);
      // No picture and no catalog logo: the initial of the title.
      expect(find.text('B'), findsOneWidget);
      expect(find.text('Bodega Test'), findsOneWidget);
      expect(find.byTooltip('Bodega Test options'), findsOneWidget);
      shown.add((_cover(tester), _label(tester)));
    }
    expect(shown.first.$2, contains('Bodega Test'));
    expect(shown.last, shown.first);
  });
}
