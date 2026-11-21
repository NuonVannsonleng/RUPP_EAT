import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../data/order_repository.dart';
import '../models/order.dart';

/// Rate the store (required) and each product (optional) after a completed order.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.order});
  final Order order;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final _comment = TextEditingController();
  final Map<String, int> _productRatings = {};
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      final msg = await context.read<OrderRepository>().review(
            widget.order.id,
            _rating,
            _comment.text.trim().isEmpty ? null : _comment.text.trim(),
            _productRatings.entries.map((e) => {'product_id': e.key, 'rating': e.value}).toList(),
          );
      if (!mounted) return;
      showSnack(context, msg);
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.order.items.where((i) => i.productId != null).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Rate your order')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('How was ${widget.order.storeName}?', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        _stars(_rating, 44, (v) => setState(() => _rating = v)),
        const SizedBox(height: 16),
        TextField(
          controller: _comment,
          maxLines: 3,
          maxLength: 1000,
          decoration: const InputDecoration(hintText: 'Tell others about the food and service (optional)'),
        ),
        if (products.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Rate the items (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final p in products)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  AppNetworkImage(p.imageUrl, width: 44, height: 44, radius: 10),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  _stars(_productRatings[p.productId] ?? 0, 24, (v) => setState(() => _productRatings[p.productId!] = v)),
                ]),
              ),
            ),
        ],
        const SizedBox(height: 24),
        GradientButton(label: 'Submit review', loading: _sending, onPressed: _submit),
      ]),
    );
  }

  Widget _stars(int value, double size, ValueChanged<int> onTap) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (i) => GestureDetector(
            onTap: () => onTap(i + 1),
            child: Icon(i < value ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: AppColors.gold),
          ),
        ),
      );
}
