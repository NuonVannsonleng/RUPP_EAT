import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/common.dart';
import '../providers/cart_provider.dart';

/// Adds/changes a product in the cart, handling the "cart has another store" case.
Future<bool> setCartQuantity(BuildContext context, String productId, int quantity, {String? productName}) async {
  final cart = context.read<CartProvider>();
  try {
    await cart.setQuantity(productId, quantity);
    return true;
  } on ApiException catch (e) {
    if (!context.mounted) return false;
    if (e.isConflict) {
      final replace = await confirmDialog(
        context,
        title: 'Start a new cart?',
        message: '${e.message}\n\nYour current cart will be cleared.',
        confirm: 'New cart',
      );
      if (replace && context.mounted) {
        try {
          await cart.add(productId, quantity: quantity, replace: true);
          if (context.mounted) showSnack(context, '${productName ?? 'Item'} added to a new cart');
          return true;
        } on ApiException catch (e2) {
          if (context.mounted) showSnack(context, e2.message, error: true);
        }
      }
    } else {
      showSnack(context, e.message, error: true);
    }
    return false;
  }
}
