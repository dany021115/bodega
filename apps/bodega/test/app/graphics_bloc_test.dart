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
    when(() => repository.graphics('juegos', any()))
        .thenAnswer((_) async => right(const {r'C:\Blur\Blur.exe': blur}));
  });

  blocTest<GraphicsBloc, GraphicsState>(
    'reads each exe once and never steam.exe',
    build: () => GraphicsBloc(repository),
    act: (bloc) => bloc
      ..add(
        const GraphicsEvent.load('juegos', [
          r'C:\Blur\Blur.exe',
          r'C:\Program Files (x86)\Steam\Steam.exe',
          r'C:\roto.exe',
        ]),
      )
      ..add(const GraphicsEvent.load('juegos', [r'C:\Blur\Blur.exe'])),
    verify: (bloc) {
      expect(bloc.state.of('juegos', r'C:\Blur\Blur.exe'), blur);
      expect(bloc.state.of('juegos', r'C:\roto.exe'), isNull);
      expect(bloc.state.byKey, hasLength(2));
      verify(
        () => repository.graphics('juegos', [
          r'C:\Blur\Blur.exe',
          r'C:\roto.exe',
        ]),
      ).called(1);
      expect(blur.label, 'DX9 · 32 bits');
      expect(
        blur.warning('Blur', 'd3dmetal'),
        'Blur es de 32 bits con DirectX 9: d3dmetal no le sirve. '
        'Usa Automático.',
      );
      expect(blur.warning('Blur', 'wine'), isNull);
    },
  );
}
