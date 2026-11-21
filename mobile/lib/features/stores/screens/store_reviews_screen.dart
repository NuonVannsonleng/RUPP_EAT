import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/catalog_repository.dart';
import '../models/catalog_models.dart';

class StoreReviewsScreen extends StatefulWidget {
  const StoreReviewsScreen({super.key, required this.store});
  final Store store;

  @override
  State<StoreReviewsScreen> createState() => _StoreReviewsScreenState();
}

class _StoreReviewsScreenState extends State<StoreReviewsScreen> {
  late Future<Paged<Review>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<CatalogRepository>().storeReviews(widget.store.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.store.name} reviews')),
      body: FutureBuilder<Paged<Review>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final reviews = snap.data!.items;
          if (reviews.isEmpty) return const EmptyView(icon: Icons.rate_review_outlined, title: 'No reviews yet');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              if (i == 0) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      Text(widget.store.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _stars(widget.store.rating.round(), 22),
                        Text('${widget.store.ratingCount} ratings', style: const TextStyle(color: AppColors.textMuted)),
                      ]),
                    ]),
                  ),
                );
              }
              final r = reviews[i - 1];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(r.userName ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text(timeAgo(r.createdAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ]),
                    const SizedBox(height: 4),
                    _stars(r.rating, 16),
                    if (r.productName != null) Text(r.productName!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    if (r.comment != null) ...[const SizedBox(height: 6), Text(r.comment!)],
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _stars(int n, double size) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) => Icon(i < n ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: AppColors.gold)),
      );
}
