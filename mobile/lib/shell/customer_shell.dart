import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/cart/providers/cart_provider.dart';
import '../features/cart/screens/cart_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/orders/screens/orders_screen.dart';
import '../features/profile/screens/profile_screen.dart';

/// Bottom-nav tabs. Any screen (including pushed routes) can switch tabs:
///   goToTab(context, CustomerTab.cart);
enum CustomerTab { home, orders, cart, profile }

final customerTab = ValueNotifier<CustomerTab>(CustomerTab.home);

void goToTab(BuildContext context, CustomerTab tab) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  customerTab.value = tab;
}

/// Bottom navigation: Home · Orders · Cart · Profile (as in the design reference).
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  final _ordersKey = GlobalKey<OrdersScreenState>();

  @override
  void initState() {
    super.initState();
    customerTab.value = CustomerTab.home;
    customerTab.addListener(_onTab);
  }

  @override
  void dispose() {
    customerTab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    setState(() {});
    if (customerTab.value == CustomerTab.orders) _ordersKey.currentState?.refresh();
    if (customerTab.value == CustomerTab.cart) context.read<CartProvider>().load().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<CartProvider, int>((c) => c.count);
    Widget cartIcon(IconData icon) => Badge(isLabelVisible: cartCount > 0, label: Text('$cartCount'), child: Icon(icon));

    return Scaffold(
      body: IndexedStack(index: customerTab.value.index, children: [
        const HomeScreen(),
        OrdersScreen(key: _ordersKey),
        const CartScreen(),
        const ProfileScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: customerTab.value.index,
        onDestinationSelected: (i) => customerTab.value = CustomerTab.values[i],
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
          NavigationDestination(icon: cartIcon(Icons.shopping_cart_outlined), selectedIcon: cartIcon(Icons.shopping_cart_rounded), label: 'Cart'),
          const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
