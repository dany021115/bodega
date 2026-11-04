import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmptyState(
        icon: Icons.apps_rounded,
        title: 'Biblioteca',
        message: 'Esta sección llega en el siguiente hito.',
      ),
    );
  }
}
