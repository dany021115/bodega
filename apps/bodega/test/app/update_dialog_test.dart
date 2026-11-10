import 'package:bodega/l10n/app_localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/update/update_bloc.dart';
import 'package:bodega/app/shared/widgets/update_dialog.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/app_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockUpdate extends MockBloc<UpdateEvent, UpdateState>
    implements UpdateBloc {}

void main() {
  late _MockUpdate bloc;
  const mac = AppUpdate(
    version: '1.4.0',
    current: '1.3.0',
    notes: 'Blur fixes',
    page: 'https://x/page',
    installer: 'https://x/Bodega.dmg',
    sums: 'https://x/SHA256SUMS-macos',
  );

  setUpAll(() => registerFallbackValue(const UpdateEvent.check()));
  setUp(() => bloc = _MockUpdate());

  Future<void> show(WidgetTester tester, UpdateState state) async {
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<UpdateBloc>.value(
          value: bloc,
          child: const Scaffold(body: UpdateDialog()),
        ),
      ),
    );
  }

  testWidgets('an update this Mac can install (A3)', (tester) async {
    await show(tester, const UpdateState(update: mac));
    expect(find.text('A new version is out'), findsOneWidget);
    expect(find.text('Bodega 1.4.0 (you have 1.3.0)'), findsOneWidget);
    expect(find.text('Blur fixes'), findsOneWidget);
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
    await show(
      tester,
      const UpdateState(
        update: AppUpdate(
          version: '1.4.0',
          current: '1.3.0',
          page: 'https://x/page',
          command: 'sudo apt install ./Bodega-1.4.0-linux-amd64.deb',
        ),
      ),
    );
    expect(find.text('Update'), findsNothing);
    expect(find.text('See the release'), findsOneWidget);
    expect(
      find.text('sudo apt install ./Bodega-1.4.0-linux-amd64.deb'),
      findsOneWidget,
    );
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
    expect(find.text('Downloading: 5 of 10 MB'), findsOneWidget);
    expect(find.text('Not now'), findsNothing);
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
