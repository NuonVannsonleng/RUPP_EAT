import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/maps/campus_map_data.dart';
import 'core/network/api_client.dart';
import 'core/services/push_service.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/cart/data/cart_repository.dart';
import 'features/cart/providers/cart_provider.dart';
import 'features/driver/data/driver_repository.dart';
import 'features/driver/services/location_reporter.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/orders/data/order_repository.dart';
import 'features/stores/data/catalog_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final push = PushService();
  await push.init(); // no-op when Firebase is not configured

  final tokens = TokenStorage();
  final api = ApiClient(tokens);
  final authRepo = AuthRepository(api);
  final orderRepo = OrderRepository(api);
  final driverRepo = DriverRepository(api);

  runApp(MultiProvider(
    providers: [
      Provider.value(value: api),
      Provider.value(value: push),
      Provider.value(value: authRepo),
      Provider(create: (_) => CatalogRepository(api)),
      Provider.value(value: orderRepo),
      Provider.value(value: driverRepo),
      Provider(create: (_) => CampusMapRepository(api)),
      ChangeNotifierProvider(create: (_) => DriverLocationReporter(driverRepo)),
      ChangeNotifierProvider(create: (_) => AuthProvider(authRepo, tokens, push, api)..bootstrap()),
      ChangeNotifierProvider(create: (_) => CartProvider(CartRepository(api))),
      ChangeNotifierProvider(create: (_) => NotificationProvider(orderRepo)),
    ],
    child: const RuppEatApp(),
  ));
}
