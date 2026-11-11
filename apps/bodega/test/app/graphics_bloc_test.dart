import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/graphics/graphics_bloc.dart';
import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:bodega/domain/repository/backend_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockBackends extends Mock implements BackendRepository {}

void main() {
  late _MockBackends repository;
  const blur = ExeGraphics(bits: 32, directx: 'DX9', misfits: ['d3dmetal']);

  setUp(() {
    repository = _MockBackends();
    when(() => repository.graphics('games', any()))
        .thenAnswer((_) async => right(const {r'C:\Blur\Blur.exe': blur}));
  });

  blocTest<GraphicsBloc, GraphicsState>(
    'reads each exe once and never steam.exe',
    build: () => GraphicsBloc(repository),
    act: (bloc) => bloc
      ..add(
        const GraphicsEvent.load('games', [
          r'C:\Blur\Blur.exe',
          r'C:\Program Files (x86)\Steam\Steam.exe',
          r'C:\broken.exe',
        ]),
      )
      ..add(const GraphicsEvent.load('games', [r'C:\Blur\Blur.exe'])),
    verify: (bloc) {
      // What the exe draws with and its misfits, never text:
      // app/shared/text/backend_text.dart words them.
      expect(bloc.state.of('games', r'C:\Blur\Blur.exe'), blur);
      expect(bloc.state.of('games', r'C:\broken.exe'), isNull);
      expect(bloc.state.byKey, hasLength(2));
      verify(
        () => repository.graphics('games', [
          r'C:\Blur\Blur.exe',
          r'C:\broken.exe',
        ]),
      ).called(1);
    },
  );
}
