import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/common.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/cart/providers/cart_provider.dart';
import 'features/driver/screens/driver_shell.dart';
import 'features/driver/services/location_reporter.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'shell/customer_shell.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();

class RuppEatApp extends StatelessWidget {
  const RuppEatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RUPP Eat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: messengerKey,
      home: const _AuthGate(),
    );
  }
}

/// Picks the interface by role: customers get the ordering app, drivers the driver app.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  AuthStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    final notifications = context.read<NotificationProvider>();
    notifications.onNew = (_) => messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('You have a new order update'), duration: Duration(seconds: 2)),
        );
    context.read<PushService>().onForegroundMessage = (title, body) {
      messengerKey.currentState?.showSnackBar(SnackBar(content: Text('$title\n$body')));
      notifications.refreshCount();
    };
  }

  void _onStatusChange(AuthProvider auth) {
    if (_lastStatus == auth.status) return;
    _lastStatus = auth.status;
    final notifications = context.read<NotificationProvider>();
    if (auth.status == AuthStatus.authenticated) {
      notifications.start();
      if (auth.user!.isCustomer) context.read<CartProvider>().load().catchError((_) {});
    } else {
      notifications.stop();
      context.read<CartProvider>().resetLocal();
      context.read<DriverLocationReporter>().stop(); // never keep sharing GPS after logout
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onStatusChange(auth));

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          backgroundColor: AppColors.primary,
          body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            BrandLogo(size: 1.4, light: true),
            SizedBox(height: 24),
            CircularProgressIndicator(color: AppColors.accentYellow),
          ])),
        );
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        return auth.user!.isDriver ? const DriverShell() : const CustomerShell();
    }
  }
}
