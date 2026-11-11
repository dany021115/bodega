import 'package:bodega/app/shared/widgets/app_row.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';

const _long = LibraryApp(
  bottle: 'A bottle with a name so very long that it does not fit the row',
  key: 'k',
  id: 'long-app',
  title:
      'An extremely long application title, long enough to check the clipping',
);

void main() {
  testWidgets('long texts fit a row at 652 px', (tester) async {
    tester.view.physicalSize = const Size(720, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    Widget row(Locale locale) => wrapApp(
      Scaffold(
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
      locale: locale,
      theme: AppTheme.getDarkTheme(),
    );
    await tester.pumpWidget(row(const Locale('en')));
    expect(tester.takeException(), isNull);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);
    expect(find.byTooltip('${_long.title} options'), findsOneWidget);

    // Spanish runs longer (L18).
    await tester.pumpWidget(row(const Locale('es')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the button stops a running app', (tester) async {
    var stopped = 0;
    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: AppRow(
            app: _long,
            running: true,
            onPlay: () {},
            onStop: () => stopped++,
          ),
        ),
        theme: AppTheme.getDarkTheme(),
      ),
    );
    expect(find.text('Running'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    expect(stopped, 1);
  });

  testWidgets('its hint says to double-click to open (L14)', (tester) async {
    Widget row(Locale locale) => wrapApp(
      Scaffold(
        body: AppRow(app: _long, running: false, onPlay: () {}, onStop: () {}),
      ),
      locale: locale,
    );
    await tester.pumpWidget(row(const Locale('en')));
    expect(find.semantics.byHint('Double-click to open'), findsOne);

    final es = lookupAppL10n(const Locale('es'));
    await tester.pumpWidget(row(const Locale('es')));
    expect(find.semantics.byHint(es.appOpenHint), findsOne);
  });
}
