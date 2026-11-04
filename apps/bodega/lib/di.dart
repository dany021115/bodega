import 'package:bodega/di.config.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit(initializerName: 'init', asExtension: true)
Future<void> configureDependencies() async => getIt.init();
