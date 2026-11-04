import 'package:flutter/widgets.dart';

class StackObserver<T> extends RouteObserver<PageRoute<T>> {
  final List<Route<dynamic>> _stackRecord = [];

  List<Route<dynamic>> get stackRecord => List.unmodifiable(_stackRecord);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stackRecord.add(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _stackRecord.remove(oldRoute);
    if (newRoute != null) _stackRecord.add(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stackRecord.remove(route);
  }

  void clear() => _stackRecord.clear();
}
