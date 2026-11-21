import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../data/driver_repository.dart';
import '../models/delivery.dart';
import '../widgets/delivery_card.dart';
import 'delivery_detail_screen.dart';

/// Completed and cancelled deliveries with timestamps.
class DriverHistoryScreen extends StatelessWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Delivery history'),
            bottom: const TabBar(
              labelColor: AppColors.primary,
              indicatorColor: AppColors.accent,
              tabs: [Tab(text: 'Completed'), Tab(text: 'Cancelled')],
            ),
          ),
          body: const TabBarView(children: [_HistoryList('completed'), _HistoryList('cancelled')]),
        ),
      );
}

class _HistoryList extends StatefulWidget {
  const _HistoryList(this.type);
  final String type;

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> with AutomaticKeepAliveClientMixin {
  final List<Delivery> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final page = await context.read<DriverRepository>().deliveries(widget.type, page: more ? _page + 1 : 1);
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(page.items);
        _page = page.currentPage;
        _hasMore = page.hasMore;
        _error = null;
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
    if (_error != null && _items.isEmpty) return ErrorView(message: _error!, onRetry: _load);
    if (_loading && _items.isEmpty) return const LoadingView();
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [SizedBox(height: 100), EmptyView(icon: Icons.history_rounded, title: 'No deliveries yet')]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 300 && _hasMore && !_loading) _load(more: true);
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => DeliveryCard(
            delivery: _items[i],
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryDetailScreen(deliveryId: _items[i].id))),
          ),
        ),
      ),
    );
  }
}
