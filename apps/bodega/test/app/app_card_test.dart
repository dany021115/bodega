import 'package:bodega/app/shared/widgets/app_card.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _long = LibraryApp(
  bottle: 'A bottle with a name so very long that it does not fit on the card',
  key: 'k',
  id: 'long-app',
  title: 'An extremely long application title to check that it gets cut short',
);

void main() {
  Future<void> pump(WidgetTester tester, AppCard card) async {
    tester.view.physicalSize = const Size(720, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.getDarkTheme(),
        home: Scaffold(
          body: Center(child: SizedBox(width: 200, child: card)),
        ),
      ),
    );
  }

  testWidgets('long texts fit a grid cell at 720 px', (tester) async {
    await pump(
      tester,
      AppCard(
        app: _long,
        bottleLabel: _long.bottle,
        running: true,
        onPlay: () {},
        onStop: () {},
        onMenu: (_) {},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Running'), findsOneWidget);
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
}
