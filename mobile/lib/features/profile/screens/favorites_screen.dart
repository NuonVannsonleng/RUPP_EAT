import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../stores/data/catalog_repository.dart';
import '../../stores/models/catalog_models.dart';
import '../../stores/widgets/store_widgets.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Store>? _stores;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await context.read<CatalogRepository>().favorites();
      if (mounted) setState(() => _stores = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _unfavorite(Store s) async {
    try {
      await context.read<CatalogRepository>().toggleFavorite(s.id);
      setState(() => _stores!.remove(s));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorite stores')),
      body: _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : _stores == null
              ? const LoadingView()
              : _stores!.isEmpty
                  ? const EmptyView(icon: Icons.favorite_border_rounded, title: 'No favorites yet', message: 'Tap the heart on a store to save it here.')
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _stores!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, i) => StoreCard(store: _stores![i], onFavorite: () => _unfavorite(_stores![i])),
                    ),
    );
  }
}
