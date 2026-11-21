import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../shell/customer_shell.dart';
import '../data/order_repository.dart';
import '../models/order.dart';
import 'order_detail_screen.dart';

/// Order history with Active / Completed / Cancelled tabs.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => OrdersScreenState();
}

class OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _lists = [GlobalKey<_OrderListState>(), GlobalKey<_OrderListState>(), GlobalKey<_OrderListState>()];

  void refresh() {
    for (final k in _lists) {
      k.currentState?.load();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My orders'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.accent,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'Active'), Tab(text: 'Completed'), Tab(text: 'Cancelled')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _OrderList(key: _lists[0], status: 'active'),
        _OrderList(key: _lists[1], status: 'completed'),
        _OrderList(key: _lists[2], status: 'cancelled'),
      ]),
    );
  }
}

class _OrderList extends StatefulWidget {
  const _OrderList({super.key, required this.status});
  final String status;

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList> with AutomaticKeepAliveClientMixin {
  final List<Order> _orders = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<OrderRepository>().list(status: widget.status, page: more ? _page + 1 : 1);
      if (!mounted) return;
      setState(() {
        if (!more) _orders.clear();
        _orders.addAll(page.items);
        _page = page.currentPage;
        _hasMore = page.hasMore;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null && _orders.isEmpty) return ErrorView(message: _error!, onRetry: load);
    if (_loading && _orders.isEmpty) return const LoadingView();
    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: load,
        child: ListView(children: [
          const SizedBox(height: 80),
          EmptyView(
            icon: Icons.receipt_long_outlined,
            title: widget.status == 'active' ? 'No active orders' : 'Nothing here yet',
            message: widget.status == 'active' ? 'Hungry? Order from a campus store.' : null,
            action: widget.status == 'active'
                ? SizedBox(width: 200, child: GradientButton(label: 'Order food', onPressed: () => goToTab(context, CustomerTab.home)))
                : null,
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 300 && _hasMore && !_loading) load(more: true);
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length + (_hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            if (i >= _orders.length) return const Padding(padding: EdgeInsets.all(16), child: LoadingView());
            return OrderCard(
              order: _orders[i],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: _orders[i].id))).then((_) => load()),
            );
          },
        ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.onTap});
  final Order order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              AppNetworkImage(order.storeLogo, width: 56, height: 56, icon: Icons.storefront_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(order.storeName ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${order.itemCount} item${order.itemCount == 1 ? '' : 's'} · ${money(order.total)} · ${order.isDelivery ? 'Delivery' : 'Pickup'}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text('${order.number} · ${formatDateTime(order.createdAt)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                  const SizedBox(height: 6),
                  StatusChip(status: order.status, label: order.statusLabel, small: true),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ]),
          ),
        ),
      );
}
