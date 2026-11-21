import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../shell/customer_shell.dart';
import '../../checkout/screens/checkout_screen.dart';
import '../../stores/screens/store_detail_screen.dart';
import '../providers/cart_provider.dart';
import '../widgets/add_to_cart.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CartProvider>();
    final cart = provider.cart;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My cart'),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: () async {
                if (await confirmDialog(context, title: 'Clear cart?', message: 'Remove all items from your cart?', confirm: 'Clear', danger: true)) {
                  try {
                    await provider.clear();
                  } on ApiException catch (e) {
                    if (context.mounted) showSnack(context, e.message, error: true);
                  }
                }
              },
              child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
      body: provider.loading && cart.isEmpty
          ? const LoadingView()
          : cart.isEmpty
              ? EmptyView(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Your cart is empty',
                  message: 'Browse campus stores and add something tasty.',
                  action: SizedBox(width: 200, child: GradientButton(label: 'Browse stores', onPressed: () => goToTab(context, CustomerTab.home))),
                )
              : RefreshIndicator(
                  onRefresh: provider.load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                    if (cart.store != null)
                      Card(
                        child: ListTile(
                          leading: AppNetworkImage(cart.store!.logoUrl, width: 44, height: 44, radius: 12, icon: Icons.storefront_rounded),
                          title: Text(cart.store!.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(cart.storeOpen ? 'Open · until ${cart.store!.closingTime}' : 'Closed now — you can order when it opens',
                              style: TextStyle(color: cart.storeOpen ? AppColors.success : AppColors.danger, fontSize: 12.5)),
                          trailing: TextButton(
                            child: const Text('Add more'),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDetailScreen(storeId: cart.store!.id))),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(children: [
                        for (final item in cart.items) ...[
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              Opacity(opacity: item.available ? 1 : 0.4, child: AppNetworkImage(item.imageUrl, width: 64, height: 64)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(money(item.price), style: const TextStyle(color: AppColors.textMuted)),
                                  if (!item.available)
                                    const Text('No longer available — please remove', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(money(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                provider.isBusy(item.productId)
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                    : item.available
                                        ? QuantityStepper(compact: true, value: item.quantity, max: item.stock ?? 50,
                                            onChanged: (v) => setCartQuantity(context, item.productId, v))
                                        : TextButton(onPressed: () => provider.remove(item.id, item.productId), child: const Text('Remove')),
                              ]),
                            ]),
                          ),
                          if (item != cart.items.last) const Divider(indent: 12, endIndent: 12),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          _row('Subtotal', money(cart.subtotal)),
                          _row('Classroom delivery fee', cart.deliveryFee == 0 ? 'Free' : money(cart.deliveryFee), muted: true),
                          const Text('No delivery fee if you choose self-pickup at checkout.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const Divider(height: 24),
                          _row('Total', money(cart.total), bold: true),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GradientButton(
                      label: 'Checkout',
                      trailing: money(cart.total),
                      onPressed: cart.hasUnavailable || !cart.storeOpen
                          ? null
                          : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                    ),
                    if (cart.hasUnavailable)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Remove unavailable items to continue.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.danger)),
                      ),
                  ]),
                ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, bool muted = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 17 : 14, color: muted ? AppColors.textMuted : AppColors.text))),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? 18 : 14, color: bold ? AppColors.accent : AppColors.text)),
        ]),
      );
}
