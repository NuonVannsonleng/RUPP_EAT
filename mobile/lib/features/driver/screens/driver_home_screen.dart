import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/driver_repository.dart';
import '../widgets/delivery_card.dart';
import 'delivery_detail_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key, required this.onOpenRequests, required this.active});
  final VoidCallback onOpenRequests;
  final bool active;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  DriverDashboard? _data;
  String? _error;
  bool _toggling = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(AppConfig.pollInterval, (_) {
      if (widget.active) _load(silent: true);
    });
  }

  @override
  void didUpdateWidget(covariant DriverHomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load(silent: true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final d = await context.read<DriverRepository>().dashboard();
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    }
  }

  Future<void> _toggle(bool online) async {
    setState(() => _toggling = true);
    try {
      await context.read<DriverRepository>().setOnline(online);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.fieldError('is_online') ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final d = _data;

    return Scaffold(
      body: SafeArea(
        child: d == null
            ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const LoadingView())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Hi, ${user.firstName}', style: Theme.of(context).textTheme.titleLarge),
                        const Text('RUPP Eat Driver', style: TextStyle(color: AppColors.textMuted)),
                      ]),
                    ),
                    const BrandLogo(size: 0.6),
                  ]),
                  const SizedBox(height: 16),
                  if (!d.isVerified) _banner(
                    d.verificationStatus == 'rejected' ? 'Your driver application was not approved. Contact the RUPP Eat admin.' : 'Your account is waiting for administrator verification. You can go online once verified.',
                    d.verificationStatus == 'rejected' ? AppColors.danger : AppColors.accent,
                  ) else if (!d.isActive) _banner('Your driver account is deactivated. Contact the RUPP Eat admin.', AppColors.danger),
                  _onlineCard(d),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _stat('Today', '${d.stats.todayDeliveries}', 'deliveries', Icons.delivery_dining_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Earned today', money(d.stats.todayEarnings), 'delivery fees', Icons.payments_rounded)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _stat('This week', '${d.stats.weekDeliveries}', money(d.stats.weekEarnings), Icons.calendar_today_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('All time', '${d.stats.totalDeliveries}', 'completed', Icons.emoji_events_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  if (d.isOnline && d.stats.availableRequests > 0)
                    Card(
                      color: AppColors.accentSoft,
                      child: ListTile(
                        leading: const Icon(Icons.notifications_active_rounded, color: AppColors.accent),
                        title: Text('${d.stats.availableRequests} delivery request${d.stats.availableRequests == 1 ? '' : 's'} waiting',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: widget.onOpenRequests,
                      ),
                    ),
                  const SectionHeader('Current deliveries'),
                  if (d.active.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: EmptyView(icon: Icons.two_wheeler_rounded, title: 'No active delivery', message: 'Accepted deliveries will show here.'),
                    )
                  else
                    for (final del in d.active) ...[
                      DeliveryCard(
                        delivery: del,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryDetailScreen(deliveryId: del.id))).then((_) => _load()),
                      ),
                      const SizedBox(height: 10),
                    ],
                ]),
              ),
      ),
    );
  }

  Widget _banner(String text, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      );

  Widget _onlineCard(DriverDashboard d) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: d.isOnline ? [AppColors.primary, AppColors.primaryDark] : [const Color(0xFF59637A), const Color(0xFF3D4558)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Icon(d.isOnline ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.isOnline ? 'You are online' : 'You are offline', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
              Text(d.isOnline ? 'Receiving campus delivery requests' : 'Go online to receive requests', style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          _toggling
              ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Switch(
                  value: d.isOnline,
                  activeThumbColor: AppColors.accentYellow,
                  onChanged: d.isVerified && d.isActive ? _toggle : null,
                ),
        ]),
      );

  Widget _stat(String label, String value, String sub, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
      );
}
