import 'package:bodega/l10n/app_localizations.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, VoidCallback? onPressed) async {
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
            child: GradientButton(
              label: 'Play a long test title that must not overflow',
              icon: Icons.play_arrow_rounded,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('calls onPressed when enabled', (tester) async {
    var taps = 0;
    await pump(tester, () => taps++);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(GradientButton));
    expect(taps, 1);
  });

  testWidgets('is disabled without onPressed', (tester) async {
    await pump(tester, null);
    expect(tester.takeException(), isNull);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
  });
}
