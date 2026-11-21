import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../shell/customer_shell.dart';
import '../../cart/providers/cart_provider.dart';
import '../data/catalog_repository.dart';
import '../models/catalog_models.dart';
import '../widgets/store_widgets.dart';
import 'store_reviews_screen.dart';

/// Store menu: cover photo, info, category filter, product rows and a "View cart" bar.
class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({super.key, required this.storeId});
  final String storeId;

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  StoreDetail? _detail;
  List<Product> _products = [];
  String? _error;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final repo = context.read<CatalogRepository>();
    try {
      final results = await Future.wait([repo.store(widget.storeId), repo.storeProducts(widget.storeId)]);
      if (!mounted) return;
      setState(() {
        _detail = results[0] as StoreDetail;
        _products = results[1] as List<Product>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggleFavorite() async {
    final store = _detail!.store;
    try {
      final fav = await context.read<CatalogRepository>().toggleFavorite(store.id);
      setState(() => store.isFavorite = fav);
      if (mounted) showSnack(context, fav ? 'Added to favorites' : 'Removed from favorites');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Scaffold(appBar: AppBar(), body: ErrorView(message: _error!, onRetry: _load));
    if (_detail == null) return Scaffold(appBar: AppBar(), body: const LoadingView());

    final store = _detail!.store;
    final cart = context.watch<CartProvider>().cart;
    final cartFromThisStore = cart.store?.id == store.id && !cart.isEmpty;
    final visible = _categoryId == null ? _products : _products.where((p) => p.category?.id == _categoryId).toList();

    // Group by category, keeping the API's ordering.
    final groups = <String, List<Product>>{};
    for (final p in visible) {
      groups.putIfAbsent(p.category?.name ?? 'Other', () => []).add(p);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                onPressed: _toggleFavorite,
                icon: Icon(store.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: store.isFavorite ? AppColors.accentYellow : Colors.white),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                AppNetworkImage(store.coverUrl, radius: 0, icon: Icons.storefront_rounded),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black38, Colors.transparent, Colors.black54]))),
              ]),
            ),
          ),
          SliverToBoxAdapter(child: _info(store)),
          if (_detail!.categories.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _chip('All', null),
                    for (final c in _detail!.categories) _chip(c.name, c.id),
                  ],
                ),
              ),
            ),
          if (visible.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: EmptyView(icon: Icons.no_food_outlined, title: 'No items yet', message: 'This store has not added its menu.'))
          else
            for (final entry in groups.entries) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.accent)),
                ),
              ),
              SliverList.separated(
                itemCount: entry.value.length,
                separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
                itemBuilder: (_, i) => ProductTile(product: entry.value[i], storeOpen: store.isOpenNow),
              ),
            ],
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ]),
      ),
      bottomSheet: cartFromThisStore
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: GradientButton(
                  icon: Icons.shopping_bag_outlined,
                  label: 'View cart (${cart.itemCount})',
                  trailing: money(cart.subtotal),
                  onPressed: () => goToTab(context, CustomerTab.cart),
                ),
              ),
            )
          : null,
    );
  }

  Widget _info(Store store) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(store.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreReviewsScreen(store: store))),
              child: RatingBadge(rating: store.rating, count: store.ratingCount),
            ),
          ]),
          if (store.description != null) ...[
            const SizedBox(height: 6),
            Text(store.description!, style: const TextStyle(color: AppColors.textMuted)),
          ],
          const SizedBox(height: 12),
          _infoRow(Icons.location_on_outlined, _detail!.pickupLocation),
          _infoRow(Icons.schedule_rounded, 'Open ${store.hours}',
              trailing: StatusChip(status: store.isOpenNow ? 'delivered' : 'cancelled', label: store.isOpenNow ? 'Open now' : 'Closed', small: true)),
          if (!store.isOpenNow)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('This store is closed right now. You can browse the menu and order when it opens.', style: TextStyle(fontSize: 13))),
              ]),
            ),
        ]),
      );

  Widget _infoRow(IconData icon, String text, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
          ?trailing,
        ]),
      );

  Widget _chip(String label, String? id) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _categoryId == id,
          showCheckmark: false,
          onSelected: (_) => setState(() => _categoryId = id),
        ),
      );
}
