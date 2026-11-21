import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../profile/screens/profile_screen.dart';
import 'driver_history_screen.dart';
import 'driver_home_screen.dart';
import 'driver_requests_screen.dart';

/// Separate interface for drivers: Dashboard · Requests · History · Profile.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        navigationBarTheme: Theme.of(context).navigationBarTheme.copyWith(indicatorColor: AppColors.primaryLight),
      ),
      child: Scaffold(
        body: IndexedStack(index: _index, children: [
          DriverHomeScreen(onOpenRequests: () => setState(() => _index = 1), active: _index == 0),
          DriverRequestsScreen(active: _index == 1),
          const DriverHistoryScreen(),
          const ProfileScreen(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.notifications_active_outlined), selectedIcon: Icon(Icons.notifications_active_rounded), label: 'Requests'),
            NavigationDestination(icon: Icon(Icons.history_rounded), label: 'History'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
