import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../models/delivery.dart';

/// Store → classroom summary used in request, active and history lists.
class DeliveryCard extends StatelessWidget {
  const DeliveryCard({super.key, required this.delivery, this.onTap, this.actions});
  final Delivery delivery;
  final VoidCallback? onTap;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              StatusChip(status: d.status, label: d.statusLabel, small: true),
              const Spacer(),
              Text(d.orderNumber, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            _stop(Icons.storefront_rounded, AppColors.accent, d.storeName, d.storeLocation ?? ''),
            Padding(
              padding: const EdgeInsets.only(left: 13),
              child: Container(width: 2, height: 14, color: AppColors.border),
            ),
            _stop(Icons.meeting_room_rounded, AppColors.primary, d.location?.short ?? 'Classroom', d.location?.full ?? ''),
            const SizedBox(height: 12),
            Row(children: [
              _meta(Icons.shopping_bag_outlined, '${d.itemCount} item${d.itemCount == 1 ? '' : 's'}'),
              _meta(Icons.payments_outlined, d.collectCash ? 'Collect ${money(d.total)}' : 'Paid'),
              const Spacer(),
              Text('+${money(d.deliveryFee)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.success, fontSize: 16)),
            ]),
            if (d.isRequest && d.requestedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Requested ${timeAgo(d.requestedAt)} · ${d.foodReady ? 'Food is ready' : 'Food being prepared'}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
            if (d.deliveredAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Delivered ${formatDateTime(d.deliveredAt)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
            if (d.cancelledAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Cancelled ${formatDateTime(d.cancelledAt)}', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            if (actions != null) ...[const SizedBox(height: 12), actions!],
          ]),
        ),
      ),
    );
  }

  Widget _stop(IconData icon, Color color, String title, String subtitle) => Row(children: [
        CircleAvatar(radius: 14, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
      ]);

  Widget _meta(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ]),
      );
}
