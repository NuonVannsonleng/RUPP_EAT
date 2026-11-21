import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../data/driver_repository.dart';
import '../models/delivery.dart';
import '../widgets/delivery_card.dart';
import 'delivery_detail_screen.dart';

/// Open delivery requests from campus stores. Auto-refreshes while visible.
class DriverRequestsScreen extends StatefulWidget {
  const DriverRequestsScreen({super.key, required this.active});
  final bool active;

  @override
  State<DriverRequestsScreen> createState() => _DriverRequestsScreenState();
}

class _DriverRequestsScreenState extends State<DriverRequestsScreen> {
  List<Delivery>? _items;
  String? _message;
  String? _error;
  final Set<String> _busy = {};
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
  void didUpdateWidget(covariant DriverRequestsScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final page = await context.read<DriverRepository>().deliveries('available');
      if (mounted) {
        setState(() {
          _items = page.items;
          _message = page.extra['message'] as String?;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    }
  }

  Future<void> _accept(Delivery d) async {
    setState(() => _busy.add(d.id));
    try {
      final accepted = await context.read<DriverRepository>().accept(d.id);
      if (!mounted) return;
      showSnack(context, 'Accepted! Head to ${accepted.storeName}.');
      await Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryDetailScreen(deliveryId: accepted.id)));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.fieldError('driver') ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(d.id));
      _load(silent: true);
    }
  }

  Future<void> _reject(Delivery d) async {
    setState(() => _items?.remove(d));
    try {
      await context.read<DriverRepository>().reject(d.id);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery requests'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: _error != null && _items == null
          ? ErrorView(message: _error!, onRetry: _load)
          : _items == null
              ? const LoadingView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items!.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 100),
                          EmptyView(
                            icon: Icons.notifications_paused_outlined,
                            title: 'No requests right now',
                            message: _message ?? 'New delivery requests appear here automatically.',
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items!.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final d = _items![i];
                            final busy = _busy.contains(d.id);
                            return DeliveryCard(
                              delivery: d,
                              actions: Row(children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, minimumSize: const Size.fromHeight(46)),
                                    onPressed: busy ? null : () => _reject(d),
                                    child: const Text('Reject'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: GradientButton(label: 'Accept', icon: Icons.check_rounded, loading: busy, onPressed: () => _accept(d)),
                                ),
                              ]),
                            );
                          },
                        ),
                ),
    );
  }
}
