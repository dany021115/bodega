import 'package:bodega/app/shared/widgets/view_toggle.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';

void main() {
  testWidgets('reports the view the user picks', (tester) async {
    bool? picked;
    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: ViewToggle(isGrid: true, onChanged: (value) => picked = value),
        ),
        theme: AppTheme.getDarkTheme(),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('List view'));
    expect(picked, isFalse);

    await tester.tap(find.byTooltip('Grid view'));
    expect(picked, isTrue);
  });
}
