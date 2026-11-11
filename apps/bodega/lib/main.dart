import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/bloc/graphics/graphics_bloc.dart';
import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/locale/locale_bloc.dart';
import 'package:bodega/app/bloc/sections/sections_bloc.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/bloc/switch/switch_bloc.dart';
import 'package:bodega/app/bloc/theme/theme_bloc.dart';
import 'package:bodega/app/bloc/update/update_bloc.dart';
import 'package:bodega/app/bloc/view_mode/view_mode_bloc.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/device/helpers/breakpoints.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/di.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:toastification/toastification.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const BodegaApp());
}

class BodegaApp extends StatefulWidget {
  const BodegaApp({super.key});

  @override
  State<BodegaApp> createState() => _BodegaAppState();
}

class _BodegaAppState extends State<BodegaApp> {
  final SetupBloc _setup = getIt<SetupBloc>()..add(const SetupEvent.check());
  late final GoRouter _router = createRouter(_setup);

  /// A1: only a release build looks for updates, once per start; a
  /// development build would replace itself (design §5).
  final UpdateBloc _updates = kReleaseMode
      ? (getIt<UpdateBloc>()..add(const UpdateEvent.check()))
      : getIt<UpdateBloc>();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _setup),
        BlocProvider.value(value: getIt<BackendsBloc>()),
        BlocProvider.value(value: getIt<BottlesBloc>()),
        BlocProvider.value(value: getIt<CatalogBloc>()),
        BlocProvider.value(value: getIt<GraphicsBloc>()),
        BlocProvider.value(value: getIt<InstallBloc>()),
        BlocProvider.value(value: _updates),
        BlocProvider.value(value: getIt<LibraryBloc>()),
        BlocProvider.value(value: getIt<SwitchBloc>()),
        BlocProvider.value(value: getIt<LocaleBloc>()),
        BlocProvider.value(value: getIt<ViewModeBloc>()),
        BlocProvider(create: (_) => getIt<SectionsBloc>()),
        BlocProvider(create: (_) => getIt<ThemeBloc>()),
      ],
      child: _AppView(router: _router),
    );
  }
}

/// The app in its theme and its language, rebuilt when either changes.
class _AppView extends StatelessWidget {
  final GoRouter router;

  const _AppView({required this.router});

  @override
  Widget build(BuildContext context) {
    // ponytail: no switch yet; ThemeEvent.toggle is there for when one comes.
    final theme = context.watch<ThemeBloc>().state;
    final language = context.select((LocaleBloc bloc) => bloc.state.code);

    return ToastificationWrapper(
      child: MaterialApp.router(
        title: 'Bodega',
        debugShowCheckedModeBanner: false,
        // The language chosen in Settings. With none (null), the system's
        // ordered list picks it, and a list with neither language gets
        // English, the first supported one.
        locale: language == null ? null : Locale(language),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        builder: (context, child) => ResponsiveBreakpoints.builder(
          child: child!,
          breakpoints: appBreakpoints,
        ),
        themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
        theme: AppTheme.getLightTheme(),
        darkTheme: AppTheme.getDarkTheme(),
        routerConfig: router,
      ),
    );
  }
}
