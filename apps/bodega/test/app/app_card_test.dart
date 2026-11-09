import 'package:bodega/app/shared/widgets/app_card.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _long = LibraryApp(
  bottle: 'Una botella con un nombre muy largo que no cabe en la tarjeta',
  key: 'k',
  id: 'app-largo',
  title:
      'Un título de aplicación extremadamente largo para comprobar el recorte',
);

void main() {
  Future<void> pump(WidgetTester tester, AppCard card) async {
    tester.view.physicalSize = const Size(720, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
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
    expect(find.text('En ejecución'), findsOneWidget);
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
    await tester.tap(find.byTooltip('Jugar'));
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
    await tester.tap(find.byTooltip('Parar'));
    expect(stopped, 1);
    expect(played, 1);
  });
}
