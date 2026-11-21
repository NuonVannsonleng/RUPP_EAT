import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/driver_repository.dart';
import '../models/delivery.dart';
import '../widgets/driver_navigation_map.dart';
import '../../auth/providers/auth_provider.dart';

/// One assigned delivery: go to store → confirm pickup → classroom → confirm delivery.
class DeliveryDetailScreen extends StatefulWidget {
  const DeliveryDetailScreen({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  Delivery? _d;
  String? _error;
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // Keep checking whether the store has marked the food ready.
    _poll = Timer.periodic(AppConfig.pollInterval, (_) {
      if (_d?.isActive ?? true) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final d = await context.read<DriverRepository>().get(widget.deliveryId);
      if (mounted) {
        setState(() {
          _d = d;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    }
  }

  Future<void> _update(String status, {String? confirm}) async {
    if (confirm != null && !await confirmDialog(context, title: 'Confirm', message: confirm)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final (d, msg) = await context.read<DriverRepository>().updateStatus(widget.deliveryId, status);
      if (!mounted) return;
      setState(() => _d = d);
      showSnack(context, msg);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.fieldError('status') ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _release() async {
    if (!await confirmDialog(context, title: 'Release delivery?', message: 'Another driver will be able to accept it.', confirm: 'Release', danger: true)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<DriverRepository>().release(widget.deliveryId, 'Released by driver');
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _launch(Uri uri) async {
    if (!await launchUrl(uri) && mounted) showSnack(context, 'Cannot open the app for this action', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: Text(d?.orderNumber ?? 'Delivery')),
      body: d == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const LoadingView())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 140), children: [
                _progress(d),
                if (d.isActive) ...[
                  const SizedBox(height: 12),
                  DriverNavigationMap(delivery: d, vehicleType: context.read<AuthProvider>().user?.driverProfile?.vehicleType ?? 'motorbike'),
                ],
                const SizedBox(height: 12),
                _section(
                  step: '1',
                  title: 'Pick up from store',
                  done: d.pickedUpAt != null,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      AppNetworkImage(d.storeLogo, width: 44, height: 44, radius: 12, icon: Icons.storefront_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d.storeName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(d.storeLocation ?? '', style: const TextStyle(color: AppColors.textMuted)),
                        ]),
                      ),
                      if (d.storePhone != null)
                        IconButton.filledTonal(onPressed: () => _launch(Uri(scheme: 'tel', path: d.storePhone!.replaceAll(' ', ''))), icon: const Icon(Icons.call_rounded)),
                    ]),
                    if (d.status == 'assigned') ...[
                      const SizedBox(height: 10),
                      StatusChip(
                        status: d.foodReady ? 'ready' : 'preparing',
                        label: d.foodReady ? 'Food is ready for pickup' : 'Store is still preparing (${d.orderStatusLabel})',
                      ),
                    ],
                    const Divider(height: 24),
                    for (final i in d.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${i.quantity}×  ${i.name}${i.note != null ? '  (${i.note})' : ''}'),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                _section(
                  step: '2',
                  title: 'Deliver to classroom',
                  done: d.deliveredAt != null,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _kv('Faculty', d.location?.faculty ?? '-'),
                    _kv('Building', d.location?.building ?? '-'),
                    _kv('Floor', d.location?.floor ?? '-'),
                    _kv('Classroom', d.location?.room ?? '-', big: true),
                    if (d.instructions != null && d.instructions!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          const Icon(Icons.sticky_note_2_outlined, color: AppColors.accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(d.instructions!)),
                        ]),
                      ),
                    if (d.customerName != null) ...[
                      const Divider(height: 24),
                      Row(children: [
                        const CircleAvatar(backgroundColor: AppColors.primaryLight, child: Icon(Icons.person_rounded, color: AppColors.primary)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(d.customerName!, style: const TextStyle(fontWeight: FontWeight.w700))),
                        if (d.customerPhone != null && d.isActive) ...[
                          IconButton.filledTonal(onPressed: () => _launch(Uri(scheme: 'smsto', path: d.customerPhone!.replaceAll(' ', ''))), icon: const Icon(Icons.sms_outlined)),
                          IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: AppColors.success),
                            onPressed: () => _launch(Uri(scheme: 'tel', path: d.customerPhone!.replaceAll(' ', ''))),
                            icon: const Icon(Icons.call_rounded),
                          ),
                        ],
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.payments_rounded, color: AppColors.success),
                    title: Text(d.collectCash ? 'Collect ${money(d.total)} in cash' : d.paymentMethodLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('Your delivery fee: ${money(d.deliveryFee)}'),
                  ),
                ),
                if (d.status == 'assigned')
                  TextButton.icon(
                    onPressed: _busy ? null : _release,
                    icon: const Icon(Icons.undo_rounded, color: AppColors.danger),
                    label: const Text("Can't make it? Release this delivery", style: TextStyle(color: AppColors.danger)),
                  ),
              ]),
            ),
      bottomSheet: d == null || !d.isActive
          ? null
          : SafeArea(
              child: Container(
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (d.status == 'assigned')
                    GradientButton(
                      icon: Icons.inventory_2_rounded,
                      label: d.foodReady ? 'Confirm food pickup' : 'Waiting for store…',
                      loading: _busy,
                      onPressed: d.foodReady ? () => _update('picked_up', confirm: 'Have you collected all items for ${d.orderNumber}?') : null,
                    ),
                  if (d.status == 'picked_up') ...[
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _update('arriving'),
                      icon: const Icon(Icons.near_me_rounded),
                      label: const Text("I'm arriving (notify customer)"),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (d.status == 'picked_up' || d.status == 'arriving')
                    GradientButton(
                      icon: Icons.check_circle_rounded,
                      label: 'Confirm delivered',
                      loading: _busy,
                      onPressed: () => _update('delivered', confirm: d.collectCash
                          ? 'Did you hand over the food and collect ${money(d.total)}?'
                          : 'Did you hand over the food to ${d.customerName ?? 'the customer'}?'),
                    ),
                ]),
              ),
            ),
    );
  }

  Widget _progress(Delivery d) {
    final steps = ['assigned', 'picked_up', 'arriving', 'delivered'];
    final labels = ['Accepted', 'Picked up', 'Arriving', 'Delivered'];
    final idx = d.status == 'cancelled' ? -1 : steps.indexOf(d.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: d.status == 'cancelled'
            ? const Row(children: [Icon(Icons.cancel_rounded, color: AppColors.danger), SizedBox(width: 8), Text('This order was cancelled. Do not deliver.', style: TextStyle(fontWeight: FontWeight.w700))])
            : Row(children: [
                for (var i = 0; i < steps.length; i++) ...[
                  Column(children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: i <= idx ? AppColors.accent : AppColors.border,
                      child: Icon(i <= idx ? Icons.check_rounded : Icons.circle, size: i <= idx ? 16 : 6, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(labels[i], style: TextStyle(fontSize: 11, fontWeight: i == idx ? FontWeight.w800 : FontWeight.w500)),
                  ]),
                  if (i < steps.length - 1) Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 18), color: i < idx ? AppColors.accent : AppColors.border)),
                ],
              ]),
      ),
    );
  }

  Widget _section({required String step, required String title, required bool done, required Widget child}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: done ? AppColors.success : AppColors.primary,
                child: done ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );

  Widget _kv(String k, String v, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 90, child: Text(k, style: const TextStyle(color: AppColors.textMuted))),
          Expanded(child: Text(v, style: TextStyle(fontWeight: big ? FontWeight.w900 : FontWeight.w600, fontSize: big ? 18 : 14, color: big ? AppColors.primary : AppColors.text))),
        ]),
      );
}
