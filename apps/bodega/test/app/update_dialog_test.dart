import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/update/update_bloc.dart';
import 'package:bodega/app/shared/widgets/update_dialog.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/app_update.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/pump.dart';

class _MockUpdate extends MockBloc<UpdateEvent, UpdateState>
    implements UpdateBloc {}

void main() {
  final en = lookupAppL10n(const Locale('en'));
  late _MockUpdate bloc;
  const mac = AppUpdate(
    version: '1.4.0',
    current: '1.3.0',
    notes: 'Fixes for Blur',
    page: 'https://x/page',
    installer: 'https://x/Bodega.dmg',
    sums: 'https://x/SHA256SUMS-macos',
  );
  const linux = AppUpdate(
    version: '1.4.0',
    current: '1.3.0',
    notes: 'Fixes for Blur',
    page: 'https://x/page',
    command: 'sudo apt install ./Bodega-1.4.0-linux-amd64.deb',
  );

  setUpAll(() => registerFallbackValue(const UpdateEvent.check()));
  setUp(() => bloc = _MockUpdate());

  Future<void> show(
    WidgetTester tester,
    UpdateState state, {
    Locale locale = const Locale('en'),
  }) async {
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      wrapApp(
        BlocProvider<UpdateBloc>.value(
          value: bloc,
          child: const Scaffold(body: UpdateDialog()),
        ),
        locale: locale,
      ),
    );
  }

  testWidgets('an update this Mac can install (A3)', (tester) async {
    await show(tester, const UpdateState(update: mac));
    expect(find.text('A new version is available'), findsOneWidget);
    expect(find.text('Bodega 1.4.0 (you have 1.3.0)'), findsOneWidget);
    expect(find.text('Fixes for Blur'), findsOneWidget);
    expect(
      find.text('Your bottles, games and settings stay as they are.'),
      findsOneWidget,
    );
    expect(find.text('Not now'), findsOneWidget);
    await tester.tap(find.text('Update'));
    verify(() => bloc.add(const UpdateEvent.install())).called(1);
  });

  testWidgets('a Linux package gets the command and the page (A2)', (
    tester,
  ) async {
    await show(tester, const UpdateState(update: linux));
    expect(find.text(en.updateInstall), findsNothing);
    expect(find.text('View release'), findsOneWidget);
    expect(
      find.text(
        "Update it with your package manager, using the release's file:",
      ),
      findsOneWidget,
    );
    expect(
      find.text('sudo apt install ./Bodega-1.4.0-linux-amd64.deb'),
      findsOneWidget,
    );
  });

  testWidgets('the notes and the command show as published, in both '
      'languages (L17)', (tester) async {
    for (final locale in const [Locale('en'), Locale('es')]) {
      await show(tester, const UpdateState(update: linux), locale: locale);
      // The dialog is in that language, and the release text is not.
      expect(find.text(lookupAppL10n(locale).updateTitle), findsOneWidget);
      expect(find.text('Fixes for Blur'), findsOneWidget);
      expect(
        find.text('sudo apt install ./Bodega-1.4.0-linux-amd64.deb'),
        findsOneWidget,
      );
    }
  });

  testWidgets('the download shows its progress and can be cancelled', (
    tester,
  ) async {
    await show(
      tester,
      const UpdateState(
        update: mac,
        phase: UpdatePhase.downloading,
        received: 5 << 20,
        total: 10 << 20,
      ),
    );
    // MB of 10^6 bytes (L13): 5 × 2^20 bytes are 5 MB, 10 × 2^20 are 10 MB.
    expect(find.text('Downloading · 50% · 5 MB of 10 MB'), findsOneWidget);
    expect(find.text(en.updateNotNow), findsNothing);
    await tester.tap(find.text('Cancel'));
    verify(() => bloc.add(const UpdateEvent.cancel())).called(1);
  });

  testWidgets('a failure says why, and the update stays available', (
    tester,
  ) async {
    await show(
      tester,
      const UpdateState(
        update: mac,
        error: AppError.engine(
          'the download of Bodega.dmg does not match its SHA256',
        ),
      ),
    );
    expect(find.textContaining('does not match its SHA256'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
  });
}
