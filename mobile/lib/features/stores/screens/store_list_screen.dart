import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/common.dart';
import '../data/catalog_repository.dart';
import '../models/catalog_models.dart';
import '../widgets/store_widgets.dart';

/// All campus stores, optionally filtered by a food category.
class StoreListScreen extends StatefulWidget {
  const StoreListScreen({super.key, this.category});
  final Category? category;

  @override
  State<StoreListScreen> createState() => _StoreListScreenState();
}

class _StoreListScreenState extends State<StoreListScreen> {
  List<Store>? _stores;
  String? _error;
  String _sort = 'rating';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final page = await context.read<CatalogRepository>().stores(category: widget.category?.slug, sort: _sort);
      if (mounted) setState(() => _stores = page.items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggleFavorite(Store s) async {
    try {
      final fav = await context.read<CatalogRepository>().toggleFavorite(s.id);
      setState(() => s.isFavorite = fav);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category?.name ?? 'Campus stores'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (v) {
              setState(() => _sort = v);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rating', child: Text('Top rated')),
              PopupMenuItem(value: 'popular', child: Text('Most popular')),
              PopupMenuItem(value: 'name', child: Text('Name A–Z')),
            ],
          ),
        ],
      ),
      body: _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : _stores == null
              ? const LoadingView()
              : _stores!.isEmpty
                  ? const EmptyView(icon: Icons.storefront_outlined, title: 'No stores found', message: 'Try another category.')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _stores!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => StoreCard(store: _stores![i], onFavorite: () => _toggleFavorite(_stores![i])),
                      ),
                    ),
    );
  }
}
