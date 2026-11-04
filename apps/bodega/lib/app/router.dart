import 'dart:async';

import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/presentation/backends/backends_page.dart';
import 'package:bodega/app/presentation/bottles/bottles_page.dart';
import 'package:bodega/app/presentation/catalog/catalog_page.dart';
import 'package:bodega/app/presentation/library/library_page.dart';
import 'package:bodega/app/presentation/setup/setup_page.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/main_shell.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/router/observer.dart';
import 'package:bodega/device/router/transitions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

enum AppRoute {
  splash,
  setup,
  library,
  catalog,
  catalogDetail,
  bottles,
  bottleDetail,
  backends,
}

/// Without Rosetta or the runtime there is only `/setup`; with them, `/setup`
/// leads to the library. While the first check runs, the splash waits.
String? setupRedirect(SetupState setup, String location) {
  final splash = RouterManager.path(AppRoute.splash);
  final setupPage = RouterManager.path(AppRoute.setup);
  final waiting = location == splash || location == setupPage;

  if (setup.isChecking) return waiting ? null : splash;
  if (!setup.isReady) return location == setupPage ? null : setupPage;
  return waiting ? RouterManager.path(AppRoute.library) : null;
}

GoRouter createRouter(SetupBloc setup) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouterManager.path(AppRoute.splash),
    observers: [StackObserver<void>()],
    refreshListenable: _StreamRefresh(setup.stream),
    redirect: (context, state) =>
        setupRedirect(setup.state, state.matchedLocation),
    routes: [
      GoRoute(
        path: RouterManager.path(AppRoute.splash),
        name: AppRoute.splash.name,
        builder: (context, state) => const Scaffold(body: CustomLoading()),
      ),
      GoRoute(
        path: RouterManager.path(AppRoute.setup),
        name: AppRoute.setup.name,
        pageBuilder: (context, state) => PageTransitions.fadeTransition(
          child: const SetupPage(),
          state: state,
        ),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        pageBuilder: (context, state, child) => PageTransitions.fadeTransition(
          child: MainShell(child: child),
          state: state,
        ),
        routes: [
          _section(AppRoute.library, const LibraryPage()),
          _section(AppRoute.catalog, const CatalogPage()),
          _section(AppRoute.bottles, const BottlesPage()),
          _section(AppRoute.backends, const BackendsPage()),
        ],
      ),
    ],
  );
}

GoRoute _section(AppRoute route, Widget page) => GoRoute(
  path: RouterManager.path(route),
  name: route.name,
  pageBuilder: (context, state) =>
      NoTransitionPage(key: state.pageKey, child: page),
);

class _StreamRefresh extends ChangeNotifier {
  late final StreamSubscription<Object?> _subscription;

  _StreamRefresh(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
