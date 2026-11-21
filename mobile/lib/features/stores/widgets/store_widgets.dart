import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/widgets/add_to_cart.dart';
import '../models/catalog_models.dart';
import '../screens/store_detail_screen.dart';

/// Large photo card for a store (home + store list), like the reference design.
class StoreCard extends StatelessWidget {
  const StoreCard({super.key, required this.store, this.onFavorite});
  final Store store;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDetailScreen(storeId: store.id))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            AppNetworkImage(store.coverUrl, height: 150, width: double.infinity, radius: 0, icon: Icons.storefront_rounded),
            if (!store.isOpenNow)
              Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  alignment: Alignment.center,
                  child: const Text('Closed now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            Positioned(
              top: 10,
              left: 10,
              child: _pill(store.isOpenNow ? 'Open · until ${store.closingTime}' : 'Opens ${store.openingTime}',
                  store.isOpenNow ? AppColors.success : AppColors.textMuted),
            ),
            if (onFavorite != null)
              Positioned(
                top: 6,
                right: 6,
                child: IconButton.filledTonal(
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                  icon: Icon(store.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: AppColors.danger),
                  onPressed: onFavorite,
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(store.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textMuted),
                    const SizedBox(width: 2),
                    Expanded(child: Text(store.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
                  ]),
                ]),
              ),
              RatingBadge(rating: store.rating, count: store.ratingCount),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.count});
  final double rating;
  final int? count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star_rounded, size: 16, color: AppColors.gold),
          const SizedBox(width: 2),
          Text(rating > 0 ? rating.toStringAsFixed(1) : 'New', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          if (count != null && count! > 0) Text(' ($count)', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      );
}

/// Menu row: text on the left, photo + − qty + on the right.
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, this.storeOpen = true, this.onTap});
  final Product product;
  final bool storeOpen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.cart.quantityOf(product.id);
    final busy = cart.isBusy(product.id);
    final orderable = product.canOrder && storeOpen;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              const SizedBox(height: 4),
              Text(money(product.price), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
              if (product.description != null) ...[
                const SizedBox(height: 4),
                Text(product.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ],
              const SizedBox(height: 6),
              if (!product.canOrder)
                const Text('Unavailable', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 12))
              else if (product.lowStock)
                Text('Only ${product.stockQuantity} left', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 12),
          Column(children: [
            Opacity(opacity: product.canOrder ? 1 : 0.45, child: AppNetworkImage(product.imageUrl, width: 96, height: 80)),
            const SizedBox(height: 8),
            if (!orderable)
              const SizedBox(height: 28)
            else if (busy)
              const SizedBox(height: 28, width: 28, child: Padding(padding: EdgeInsets.all(5), child: CircularProgressIndicator(strokeWidth: 2.4)))
            else if (qty == 0)
              SizedBox(
                height: 30,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(90, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
                  onPressed: () => setCartQuantity(context, product.id, 1, productName: product.name),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              )
            else
              QuantityStepper(
                compact: true,
                value: qty,
                max: product.stockQuantity ?? 50,
                onChanged: (v) => setCartQuantity(context, product.id, v, productName: product.name),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Small vertical card for horizontal product carousels.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDetailScreen(storeId: product.storeId))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppNetworkImage(product.imageUrl, height: 100, width: 150, radius: 0),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(product.storeName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(money(product.price), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                ]),
              ),
            ]),
          ),
        ),
      );
}
