import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../shell/customer_shell.dart';
import '../../cart/providers/cart_provider.dart';
import '../../profile/screens/support_screen.dart';
import '../data/order_repository.dart';
import '../models/order.dart';
import '../widgets/order_tracking_map.dart';
import 'review_screen.dart';

/// Live order tracking. Refreshes every few seconds while the order is active.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  String? _error;
  Timer? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(AppConfig.pollInterval, (_) {
      if (_order?.isActive ?? true) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final o = await context.read<OrderRepository>().get(widget.orderId);
      if (mounted) {
        setState(() {
          _order = o;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    }
  }

  Future<void> _cancel() async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _CancelDialog());
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final o = await context.read<OrderRepository>().cancel(widget.orderId, reason);
      if (mounted) {
        setState(() => _order = o);
        showSnack(context, 'Order cancelled');
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reorder() async {
    setState(() => _busy = true);
    try {
      final (message, _) = await context.read<OrderRepository>().reorder(widget.orderId);
      if (!mounted) return;
      await context.read<CartProvider>().load();
      if (!mounted) return;
      showSnack(context, message);
      goToTab(context, CustomerTab.cart);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String? phone) async {
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (!await launchUrl(uri) && mounted) showSnack(context, 'Cannot open the phone app', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      appBar: AppBar(title: Text(o?.number ?? 'Order')),
      body: _error != null && o == null
          ? ErrorView(message: _error!, onRetry: _load)
          : o == null
              ? const LoadingView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
                    _statusHeader(o),
                    const SizedBox(height: 12),
                    if (o.isActive) ...[
                      OrderTrackingMap(orderId: o.id, active: o.isDelivery),
                      const SizedBox(height: 12),
                    ],
                    if (!o.isCancelled) _tracker(o),
                    if (o.isCancelled && o.cancelReason != null)
                      Card(child: ListTile(leading: const Icon(Icons.info_outline, color: AppColors.danger), title: const Text('Reason'), subtitle: Text(o.cancelReason!))),
                    const SizedBox(height: 12),
                    _fulfilmentCard(o),
                    const SizedBox(height: 12),
                    _itemsCard(o),
                    const SizedBox(height: 16),
                    if (o.canCancel)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        onPressed: _busy ? null : _cancel,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancel order'),
                      ),
                    if (o.canReview && !o.isReviewed) ...[
                      GradientButton(
                        label: 'Rate your order',
                        icon: Icons.star_rounded,
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewScreen(order: o))).then((_) => _load()),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (!o.isActive)
                      OutlinedButton.icon(onPressed: _busy ? null : _reorder, icon: const Icon(Icons.replay_rounded), label: const Text('Order again')),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupportScreen(order: o))),
                      icon: const Icon(Icons.support_agent_rounded),
                      label: const Text('Problem with this order? Contact support'),
                    ),
                  ]),
                ),
    );
  }

  Widget _statusHeader(Order o) {
    final style = StatusStyle.of(o.status);
    final subtitle = switch (o.status) {
      'pending' => 'Waiting for ${o.storeName} to confirm your order.',
      'accepted' => '${o.storeName} accepted your order.',
      'preparing' => 'Your food is being prepared.',
      'ready' => o.isDelivery ? 'Food is ready. Finding a driver for you…' : 'Ready! Show your pickup code at the store.',
      'driver_assigned' => '${o.driverName ?? 'Your driver'} is picking up your food.',
      'on_the_way' => o.deliveryStatus == 'arriving' ? 'Your driver is arriving at ${o.location?.room ?? 'your classroom'}!' : 'On the way to ${o.location?.short ?? 'you'}.',
      'delivered' => 'Delivered. Enjoy your meal!',
      'picked_up' => 'Picked up. Enjoy your meal!',
      'rejected' => 'The store could not accept this order.',
      'cancelled' => 'This order was cancelled.',
      _ => '',
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: o.isCancelled ? null : const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        color: o.isCancelled ? AppColors.danger.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        CircleAvatar(radius: 26, backgroundColor: o.isCancelled ? AppColors.danger.withValues(alpha: 0.15) : Colors.white, child: Icon(style.icon, color: style.color, size: 28)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.statusLabel, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: o.isCancelled ? AppColors.danger : Colors.white)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: o.isCancelled ? AppColors.text : Colors.white70)),
          ]),
        ),
        if (!o.isDelivery && o.pickupCode != null && !o.isCancelled)
          Column(children: [
            Text('CODE', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w800)),
            Text(o.pickupCode!, style: const TextStyle(color: AppColors.accentYellow, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ]),
      ]),
    );
  }

  /// Vertical step tracker. Steps differ for delivery vs pickup.
  Widget _tracker(Order o) {
    final steps = o.isDelivery
        ? [
            ('pending', 'Order placed'),
            ('accepted', 'Accepted by store'),
            ('preparing', 'Preparing'),
            ('ready', 'Waiting for driver'),
            ('driver_assigned', 'Driver assigned'),
            ('on_the_way', 'On the way'),
            ('delivered', 'Delivered'),
          ]
        : [
            ('pending', 'Order placed'),
            ('accepted', 'Accepted by store'),
            ('preparing', 'Preparing'),
            ('ready', 'Ready for pickup'),
            ('picked_up', 'Picked up'),
          ];
    final order = steps.map((s) => s.$1).toList();
    final current = order.indexOf(o.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            for (var i = 0; i < steps.length; i++)
              _trackerRow(
                label: steps[i].$2,
                time: o.timeOf(steps[i].$1),
                done: i <= current,
                active: i == current,
                last: i == steps.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _trackerRow({required String label, DateTime? time, required bool done, required bool active, required bool last}) {
    final color = done ? AppColors.accent : AppColors.border;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: done ? color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: active ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 8)] : null,
            ),
            child: done ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
          ),
          if (!last) Expanded(child: Container(width: 2, color: color)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: done ? AppColors.text : AppColors.textMuted)),
              ),
              if (time != null) Text(formatTime(time), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _fulfilmentCard(Order o) => Card(
        child: Column(children: [
          if (o.isDelivery) ...[
            ListTile(
              leading: const CircleAvatar(backgroundColor: AppColors.primaryLight, child: Icon(Icons.meeting_room_rounded, color: AppColors.primary)),
              title: Text(o.location?.short ?? 'Classroom', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([o.location?.full, o.instructions].whereType<String>().where((s) => s.isNotEmpty).join('\n')),
              isThreeLine: o.instructions != null,
            ),
            if (o.driverName != null) ...[
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.accentSoft, child: Icon(Icons.delivery_dining_rounded, color: AppColors.accent)),
                title: Text(o.driverName!, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Your driver'),
                trailing: o.driverPhone == null || !o.isActive
                    ? null
                    : IconButton.filled(style: IconButton.styleFrom(backgroundColor: AppColors.success), onPressed: () => _call(o.driverPhone), icon: const Icon(Icons.call_rounded)),
              ),
            ],
          ] else
            ListTile(
              leading: const CircleAvatar(backgroundColor: AppColors.primaryLight, child: Icon(Icons.storefront_rounded, color: AppColors.primary)),
              title: Text('Pick up at ${o.storeName}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(o.storeLocation ?? ''),
            ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            leading: AppNetworkImage(o.storeLogo, width: 40, height: 40, radius: 20, icon: Icons.storefront_rounded),
            title: Text(o.storeName ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Ordered ${formatDateTime(o.createdAt)}'),
            trailing: o.storePhone == null ? null : IconButton(onPressed: () => _call(o.storePhone), icon: const Icon(Icons.call_outlined, color: AppColors.primary)),
          ),
        ]),
      );

  Widget _itemsCard(Order o) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (final i in o.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i.quantity}×', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i.name),
                      if (i.note != null) Text(i.note!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ]),
                  ),
                  Text(money(i.lineTotal)),
                ]),
              ),
            const Divider(height: 22),
            _line('Subtotal', money(o.subtotal)),
            _line('Delivery fee', o.deliveryFee == 0 ? 'Free' : money(o.deliveryFee)),
            _line('Total', money(o.total), bold: true),
            const SizedBox(height: 6),
            _line('Payment', '${o.paymentMethodLabel} · ${o.paymentStatus == 'paid' ? 'Paid' : o.paymentStatus == 'cancelled' ? 'Cancelled' : 'Pay on receipt'}'),
          ]),
        ),
      );

  Widget _line(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(a, style: TextStyle(color: bold ? AppColors.text : AppColors.textMuted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, color: bold ? AppColors.accent : AppColors.text)),
        ]),
      );
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  static const _reasons = ['Ordered by mistake', 'Changed my mind', 'Taking too long', 'Class schedule changed'];
  String _reason = _reasons.first;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: RadioGroup<String>(
          groupValue: _reason,
          onChanged: (v) => setState(() => _reason = v!),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final r in _reasons) RadioListTile<String>(value: r, title: Text(r), dense: true, contentPadding: EdgeInsets.zero),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep order')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(100, 42)),
            onPressed: () => Navigator.pop(context, _reason),
            child: const Text('Cancel order'),
          ),
        ],
      );
}
