import 'package:bodega/app/shared/widgets/app_row.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _long = LibraryApp(
  bottle: 'A bottle with a name so very long that it does not fit on the row',
  key: 'k',
  id: 'long-app',
  title: 'An extremely long application title to check that it gets cut short',
);

void main() {
  testWidgets('long texts fit a row at 652 px', (tester) async {
    tester.view.physicalSize = const Size(720, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
    expect(find.text('Play'), findsOneWidget);
    expect(find.byTooltip('Options for ${_long.title}'), findsOneWidget);
  });

  testWidgets('the button stops a running app', (tester) async {
    var stopped = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
    expect(find.text('Running'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    expect(stopped, 1);
  });
}
