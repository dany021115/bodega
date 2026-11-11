import 'package:bodega/app/shared/widgets/app_version.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../support/pump.dart';

void main() {
  setUpAll(
    () => PackageInfo.setMockInitialValues(
      appName: 'Bodega',
      packageName: 'bodega',
      version: '1.5.0',
      buildNumber: '12',
      buildSignature: '',
    ),
  );

  // AppVersion reads the version once per run, into a static future. Each
  // test has its own fake clock, and the future answers only the one it was
  // made in: so every case is in this single test.
  testWidgets('says the version in words when wide, and as its tag when '
      'narrow (L1)', (tester) async {
    final en = lookupAppL10n(const Locale('en'));
    final es = lookupAppL10n(const Locale('es'));

    await tester.pumpWidget(wrapApp(const AppVersion(compact: false)));
    await tester.pumpAndSettle();
    expect(find.text('Version 1.5.0'), findsOneWidget);

    await tester.pumpWidget(
      wrapApp(const AppVersion(compact: false), locale: const Locale('es')),
    );
    await tester.pumpAndSettle();
    expect(find.text(es.appVersionLabel('1.5.0')), findsOneWidget);
    expect(find.text(en.appVersionLabel('1.5.0')), findsNothing);

    // The tag is the same in every language.
    for (final locale in const [Locale('en'), Locale('es')]) {
      await tester.pumpWidget(
        wrapApp(const AppVersion(compact: true), locale: locale),
      );
      await tester.pumpAndSettle();
      expect(find.text('v1.5.0'), findsOneWidget);
    }
  });
}
