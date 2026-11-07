import 'package:bodega/app/shared/widgets/app_row.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _long = LibraryApp(
  bottle: 'Una botella con un nombre muy largo que no cabe en la fila',
  key: 'k',
  id: 'app-largo',
  title: 'Un título de aplicación extremadamente largo para comprobar el recorte',
);

void main() {
  testWidgets('long texts fit a row at 652 px', (tester) async {
    tester.view.physicalSize = const Size(720, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getDarkTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 652,
              child: AppRow(
                app: _long,
                bottleLabel: _long.bottle,
                running: false,
                onPlay: () {},
                onStop: () {},
                onMenu: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Jugar'), findsOneWidget);
    expect(find.byTooltip('Opciones de ${_long.title}'), findsOneWidget);
  });

  testWidgets('the button stops a running app', (tester) async {
    var stopped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getDarkTheme(),
        home: Scaffold(
          body: AppRow(
            app: _long,
            running: true,
            onPlay: () {},
            onStop: () => stopped++,
          ),
        ),
      ),
    );
    expect(find.text('En ejecución'), findsOneWidget);
    await tester.tap(find.text('Parar'));
    expect(stopped, 1);
  });
}
