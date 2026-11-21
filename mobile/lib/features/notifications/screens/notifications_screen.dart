import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/screens/order_detail_screen.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationProvider>().load();
  }

  IconData _icon(String type) => switch (type) {
        'order_accepted' => Icons.thumb_up_alt_rounded,
        'order_preparing' => Icons.soup_kitchen_rounded,
        'order_ready' => Icons.inventory_2_rounded,
        'driver_assigned' => Icons.two_wheeler_rounded,
        'driver_approaching' || 'order_on_the_way' => Icons.delivery_dining_rounded,
        'order_completed' => Icons.check_circle_rounded,
        'order_cancelled' || 'order_rejected' => Icons.cancel_rounded,
        'delivery_request' => Icons.notifications_active_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NotificationProvider>();
    final isCustomer = context.read<AuthProvider>().user?.isCustomer ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [if (p.unread > 0) TextButton(onPressed: p.markAllRead, child: const Text('Mark all read'))],
      ),
      body: p.loading && p.items.isEmpty
          ? const LoadingView()
          : p.error != null && p.items.isEmpty
              ? ErrorView(message: p.error!, onRetry: p.load)
              : p.items.isEmpty
                  ? const EmptyView(icon: Icons.notifications_none_rounded, title: 'No notifications yet', message: 'Order updates will appear here.')
                  : RefreshIndicator(
                      onRefresh: p.load,
                      child: ListView.separated(
                        itemCount: p.items.length,
                        separatorBuilder: (_, __) => const Divider(indent: 72),
                        itemBuilder: (_, i) {
                          final n = p.items[i];
                          return ListTile(
                            tileColor: n.isRead ? null : AppColors.accentSoft.withValues(alpha: 0.6),
                            leading: CircleAvatar(backgroundColor: AppColors.primaryLight, child: Icon(_icon(n.type), color: AppColors.primary)),
                            title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800)),
                            subtitle: Text('${n.body}\n${timeAgo(n.createdAt)}'),
                            isThreeLine: true,
                            onTap: () {
                              p.markRead(n);
                              if (n.orderId != null && isCustomer) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: n.orderId!)));
                              }
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}
