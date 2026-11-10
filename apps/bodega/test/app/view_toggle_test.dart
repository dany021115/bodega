import 'package:bodega/l10n/app_localizations.dart';
import 'package:bodega/app/shared/widgets/view_toggle.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reports the view the user picks', (tester) async {
    bool? picked;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.getDarkTheme(),
        home: Scaffold(
          body: ViewToggle(isGrid: true, onChanged: (value) => picked = value),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('List view'));
    expect(picked, isFalse);

    await tester.tap(find.byTooltip('Grid view'));
    expect(picked, isTrue);
  });
}
