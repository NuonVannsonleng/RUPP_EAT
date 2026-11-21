import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../shell/customer_shell.dart';
import '../../orders/models/order.dart';
import '../../orders/screens/order_detail_screen.dart';

class OrderPlacedScreen extends StatelessWidget {
  const OrderPlacedScreen({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(26),
              decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 64, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            Text('Order placed!', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('${order.storeName ?? 'The store'} will confirm your order shortly.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  _row('Order number', order.number),
                  _row('Total', money(order.total)),
                  _row(order.isDelivery ? 'Deliver to' : 'Pick up at', order.isDelivery ? (order.location?.short ?? '') : (order.storeName ?? '')),
                  if (order.pickupCode != null && !order.isDelivery) ...[
                    const Divider(height: 24),
                    const Text('Pickup code', style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text(order.pickupCode!, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 8, color: AppColors.primary)),
                  ],
                ]),
              ),
            ),
            const Spacer(),
            GradientButton(
              label: 'Track my order',
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id))),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => goToTab(context, CustomerTab.home), child: const Text('Back to home')),
          ]),
        ),
      ),
    );
  }

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(a, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(width: 12),
          Expanded(child: Text(b, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}
